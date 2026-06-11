# Trip Concierge agent — answers a traveler's free-text question about ONE
# trip, grounded in that trip's own data.
#
#   TripAgent.new(trip: @trip, user: current_user, question: "drive time day 3?").answer
#   # => Ai::Result (.text is the markdown answer)
#
# This is a *retrieval-grounded* agent: the "tools" (read the itinerary, the
# traveler roster, route landmarks, booking context) run here in Ruby to build
# a compact dossier, which is handed to `trip_concierge.v1` as a single grounded
# Anthropic call. Read-only in v1 — it can recommend edits but never mutates the
# plan. A future version can promote these readers to real Anthropic tool-calls
# and add itinerary mutations + multi-turn memory.
class TripAgent
  # Keep the dossier bounded so a huge trip can't blow the context/token budget.
  MAX_DAYS       = 14
  MAX_ACTS_PER_DAY = 12
  MAX_LANDMARKS  = 20

  # Injectable AI backend so tests can swap a fake (this suite avoids mocks).
  # Defaults to the real Ai::Caller; reset with `TripAgent.ai_caller = nil`.
  class << self
    attr_writer :ai_caller

    def ai_caller
      @ai_caller || Ai::Caller
    end
  end

  def initialize(trip:, user:, question:)
    @trip = trip
    @user = user
    @question = question.to_s.strip
  end

  def answer
    return Ai::Result.new(text: nil, error: "blank question") if @question.blank?

    self.class.ai_caller.call(
      slug: "trip_concierge.v1",
      variables: {
        dossier: dossier,
        question: @question,
        viewer_name: @user&.display_name.to_s,
        today: Date.current.strftime("%A, %B %-d, %Y")
      },
      user: @user,
      trip: @trip
    )
  end

  # Public so it can be unit-tested and reused by an admin sandbox.
  def dossier
    [ overview, travelers, itinerary, landmarks, booking ].compact.join("\n\n")
  end

  private

  def overview
    lines = [ "TRIP: #{@trip.title}" ]
    where = @trip.destination.presence
    where = "#{where} (from #{@trip.origin})" if @trip.origin.present?
    lines << "Where: #{where}" if where
    if @trip.start_date && @trip.end_date
      span = "#{@trip.start_date.strftime('%a %b %-d, %Y')} – #{@trip.end_date.strftime('%a %b %-d, %Y')}"
      span += " (#{@trip.nights} nights)" if @trip.nights
      lines << "When: #{span}"
    end
    lines << "Pace: #{@trip.pace}"   if @trip.pace.present?
    lines << "Budget: #{@trip.budget}" if @trip.budget.present?
    lines << "Transport: #{@trip.transport_mode}" if @trip.transport_mode.present?
    lines << "Preferences: #{@trip.preferences}" if @trip.preferences.present?
    lines.join("\n")
  end

  def travelers
    people = @trip.people.to_a.first(20)
    return nil if people.empty?

    rows = people.map do |p|
      bits = [ p.name ]
      bits << "age #{p.age}" if p.age.present?
      interests = Array(p.interests).reject(&:blank?)
      bits << "likes: #{interests.join(', ')}" if interests.any?
      "- #{bits.join(' — ')}"
    end
    "TRAVELERS (#{people.size}):\n#{rows.join("\n")}"
  end

  def itinerary
    days = @trip.trip_days.includes(:activities).ordered.to_a.first(MAX_DAYS)
    return "ITINERARY: not built yet." if days.empty?

    blocks = days.each_with_index.map do |day, i|
      header = "Day #{i + 1}"
      header += " — #{day.date.strftime('%a %b %-d')}" if day.date
      header += " — #{day.title}" if day.title.present?
      acts = day.activities.sort_by { |a| a.position.to_i }.first(MAX_ACTS_PER_DAY).map do |a|
        seg = [ a.time_label.presence, a.title.presence ].compact.join(" ")
        seg = seg.presence || "(untitled stop)"
        seg += " @ #{a.location_name}" if a.location_name.present?
        seg += ", #{a.address}" if a.address.present?
        if a.latitude.present? && a.longitude.present?
          seg += " [#{a.latitude.to_f.round(4)},#{a.longitude.to_f.round(4)}]"
        end
        "  • #{seg}"
      end
      [ header, *acts ].join("\n")
    end
    "ITINERARY:\n#{blocks.join("\n")}"
  end

  def landmarks
    marks = @trip.route_landmarks.to_a.first(MAX_LANDMARKS)
    return nil if marks.empty?

    rows = marks.map do |l|
      seg = l.name.to_s
      seg += " (#{l.kind})" if l.kind.present?
      if l.latitude.present? && l.longitude.present?
        seg += " [#{l.latitude.to_f.round(4)},#{l.longitude.to_f.round(4)}]"
      end
      "- #{seg}"
    end
    "ROUTE LANDMARKS:\n#{rows.join("\n")}"
  end

  # Booking context is summarized (categories + the viewer's member rates), not
  # dumped as URLs — the concierge talks about deals, the app surfaces the links.
  def booking
    links = BookingLinks.new(@trip, viewer: @user)
    perks = links.discount_tips.to_a.filter_map { |t| t[:title] || t["title"] }.uniq
    summary = [ "BOOKING CONTEXT:" ]
    summary << "- Hotel, car, flight, and activity search links are available in the app."
    summary << "- Available booking perks: #{perks.join('; ')}" if perks.any?
    summary << "- Own-car trip: rental suggestions are suppressed." if links.own_car?
    summary.join("\n")
  rescue StandardError
    nil # booking context is best-effort; never block an answer on it
  end
end
