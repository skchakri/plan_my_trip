module Trips
  # Deterministically re-derives the "complete trip + final plan" after any
  # edit, so the header and the rendered markdown never drift from the edited
  # details. This is the single chokepoint every edit path funnels through
  # (the trip edit form, the structured day/activity editor, and the concierge)
  # — previously each did a partial subset (some only ran BodySync, some only
  # re-derived the title, the concierge did neither for pace/budget).
  #
  # It only touches DERIVED fields — it never calls the AI. Three steps:
  #   1. Auto-title  — refresh it from the current destination + dates, but only
  #      when the title is still one we generated (see Trip#auto_generated_title?);
  #      a title the user customised is left alone.
  #   2. Day dates   — when `previous_start` is given and the start moved, slide
  #      every dated day by the same delta so the plan stays aligned.
  #   3. Final plan  — regenerate Trip#body from the TripDay/Activity rows via
  #      BodySync, unless the caller says the body was hand-edited this request.
  #
  # Idempotent: re-running yields the same result. Uses update_column-based
  # writes (via BodySync / shift_plan_dates!) so it won't recurse through
  # model callbacks.
  class Resync
    def self.call(trip, previous_start: nil, regenerate_body: true)
      new(trip, previous_start: previous_start, regenerate_body: regenerate_body).call
    end

    def initialize(trip, previous_start: nil, regenerate_body: true)
      @trip = trip
      @previous_start = previous_start
      @regenerate_body = regenerate_body
    end

    def call
      refresh_title
      shift_dates
      Trips::BodySync.call(@trip) if @regenerate_body && @trip.built_plan?
      @trip
    end

    private

    def refresh_title
      return unless @trip.auto_generated_title?
      fresh = @trip.derived_title
      @trip.update_column(:title, fresh) if fresh.present? && fresh != @trip.title
    end

    def shift_dates
      return unless @previous_start && @trip.start_date
      delta = (@trip.start_date - @previous_start).to_i
      @trip.shift_plan_dates!(delta) unless delta.zero?
    end
  end
end
