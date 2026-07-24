# Safe, authorization-gated, trip-scoped mutation core for a single trip's
# itinerary. This is the write layer that the agentic concierge (and any future
# "edit by chat / edit by API" surface) drives — kept deliberately free of any
# AI so it can be unit-tested and reasoned about on its own.
#
#   editor = TripEditor.new(trip: @trip, user: current_user)
#   editor.add_activity(day_number: 2, title: "Sunset at Red Rock")  # => Result
#
# Every mutation:
#   - refuses unless the user may edit the trip (TripPolicy#update? ⇔
#     Trip#editable_by?) — a mere viewer can read via the concierge but never
#     write, so this is the single authorization chokepoint;
#   - is scoped to THIS trip only (day/activity lookups can never reach another
#     trip's rows);
#   - re-syncs the derived markdown (Trips::BodySync) so the public share view
#     never drifts; the Activity/TripDay `broadcasts_refreshes_to :trip` callback
#     morphs the change onto every open trips/show;
#   - returns a Result (ok?/summary/error) rather than raising, so a caller
#     (including an LLM tool loop) gets a plain-language outcome to relay.
class TripEditor
  Result = Struct.new(:ok, :summary, :error, keyword_init: true) do
    def ok? = ok
  end

  def initialize(trip:, user:)
    @trip = trip
    @user = user
  end

  def can_edit?
    @trip.editable_by?(@user)
  end

  # Append a stop to the end of a day. Only `title` is required; the rest mirror
  # the fields the manual editor (ActivitiesController) permits.
  def add_activity(day_number:, title:, time_label: nil, location_name: nil, notes: nil)
    guard do
      day = find_day!(day_number)
      title = title.to_s.strip
      return failure("A title is required to add a stop.") if title.blank?

      day.activities.create!(
        title: title, time_label: time_label.presence, location_name: location_name.presence,
        notes: notes.presence, position: (day.activities.maximum(:position) || -1) + 1
      )
      sync
      success(%(Added "#{title}" to day #{day_number}.))
    end
  end

  # Remove a stop identified by (case-insensitive) title within a day. Refuses
  # ambiguous matches so the model must disambiguate rather than guess.
  def remove_activity(day_number:, activity_title:)
    guard do
      day = find_day!(day_number)
      act = find_one_activity!(day, activity_title)
      name = act.title
      act.destroy!
      sync
      success(%(Removed "#{name}" from day #{day_number}.))
    end
  end

  # Reorder a stop one slot up or down within its day (mirrors the manual
  # editor's swap-with-neighbour move).
  def move_activity(day_number:, activity_title:, direction:)
    guard do
      dir = direction.to_s.downcase
      return failure(%(Direction must be "up" or "down".)) unless %w[up down].include?(dir)

      day = find_day!(day_number)
      stops = day.activities.to_a
      act = find_one_activity!(day, activity_title)
      i = stops.index(act)
      j = dir == "up" ? i - 1 : i + 1
      return failure(%("#{act.title}" is already at the #{dir == 'up' ? 'top' : 'bottom'} of day #{day_number}.)) unless j.between?(0, stops.size - 1)

      stops[i], stops[j] = stops[j], stops[i]
      stops.each_with_index { |s, idx| s.update_column(:position, idx) }
      sync
      success(%(Moved "#{act.title}" #{dir} on day #{day_number}.))
    end
  end

  def update_day_title(day_number:, title:)
    guard do
      day = find_day!(day_number)
      title = title.to_s.strip
      return failure("A title is required.") if title.blank?

      day.update!(title: title)
      sync
      success(%(Renamed day #{day_number} to "#{title}".))
    end
  end

  # Set (or clear) a stop's time label — "9:00 AM", "after lunch", etc. Blank
  # clears it. Mirrors the manual editor's inline time edit.
  def update_activity_time(day_number:, activity_title:, time_label:)
    guard do
      day = find_day!(day_number)
      act = find_one_activity!(day, activity_title)
      act.update!(time_label: time_label.to_s.strip.presence)
      sync
      label = act.time_label.presence
      success(label ? %(Set "#{act.title}" to #{label} on day #{day_number}.) : %(Cleared the time on "#{act.title}".))
    end
  end

  # Add a trip-level (before-trip) checklist item — e.g. "Pack rain jacket".
  # Only the packing/prep scope is exposed here; day/activity-scoped items need
  # a label the concierge can't reliably supply.
  def add_checklist_item(title:, category: nil)
    guard do
      title = title.to_s.strip
      return failure("A title is required to add a checklist item.") if title.blank?

      @trip.checklist_items.create!(
        title: title, category: category.to_s.strip.presence, scope: "before_trip",
        position: (@trip.checklist_items.before_trip.maximum(:position) || -1) + 1
      )
      success(%(Added "#{title}" to the checklist.))
    end
  end

  # Change the trip's planning pace. Validated against Trip::PACES by the model.
  def update_pace(pace:)
    guard do
      value = pace.to_s.strip.downcase
      return failure(%(Pace must be one of: #{Trip::PACES.join(', ')}.)) unless Trip::PACES.include?(value)

      @trip.update!(pace: value)
      success(%(Set the pace to #{value}.))
    end
  end

  # Change the trip's budget band. Validated against Trip::BUDGETS by the model.
  def update_budget(budget:)
    guard do
      value = budget.to_s.strip.downcase
      return failure(%(Budget must be one of: #{Trip::BUDGETS.join(', ')}.)) unless Trip::BUDGETS.include?(value)

      @trip.update!(budget: value)
      success(%(Set the budget to #{value}.))
    end
  end

  private

  # Wrap every mutation: enforce edit rights and turn record errors into a
  # Result instead of a raised exception.
  def guard
    return failure("You don't have permission to edit this trip.") unless can_edit?

    yield
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    failure(e.record.errors.full_messages.to_sentence.presence || e.message)
  rescue ArgumentError => e
    failure(e.message)
  end

  # 1-based day number → the trip's own TripDay. Raises ArgumentError (caught by
  # #guard) with a friendly message the model can relay.
  def find_day!(day_number)
    n = day_number.to_i
    days = @trip.trip_days.ordered.to_a
    raise ArgumentError, "Day #{day_number} doesn't exist — this trip has #{days.size} day(s)." unless n.between?(1, days.size)

    days[n - 1]
  end

  def find_one_activity!(day, activity_title)
    q = activity_title.to_s.strip.downcase
    raise ArgumentError, "Which stop? Give me the stop's name." if q.blank?

    matches = day.activities.select { |a| a.title.to_s.downcase.include?(q) }
    raise ArgumentError, %(No stop matching "#{activity_title}" on that day.) if matches.empty?
    if matches.size > 1
      names = matches.map { |a| %("#{a.title}") }.join(", ")
      raise ArgumentError, %(Several stops match "#{activity_title}": #{names}. Which one?)
    end

    matches.first
  end

  def sync
    Trips::Resync.call(@trip)
  end

  def success(summary)
    Result.new(ok: true, summary: summary, error: nil)
  end

  def failure(error)
    Result.new(ok: false, summary: nil, error: error)
  end
end
