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

  # One concierge turn: the markdown `reply` plus any `edits` the model
  # PROPOSED (never applied — the traveler confirms each via TripEditor).
  Exchange = Struct.new(:reply, :edits, :error, keyword_init: true)

  # The edit actions the concierge may propose, mapped to the TripEditor
  # keyword each one accepts. This is the allowlist: an action or field outside
  # it is dropped before it ever reaches the (editor-gated) apply endpoint.
  EDIT_FIELDS = {
    "add_activity"     => %i[day_number title time_label location_name notes],
    "remove_activity"  => %i[day_number activity_title],
    "move_activity"    => %i[day_number activity_title direction],
    "update_day_title" => %i[day_number title]
  }.freeze

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

  # Agentic turn (trip_concierge.v2): returns an Exchange with the reply text
  # and a sanitized list of proposed edits. The model only *proposes*; nothing
  # is mutated here. Falls back gracefully when the backend returns plain text
  # (no JSON) — the whole text becomes the reply with no edits.
  def converse
    return Exchange.new(reply: nil, edits: [], error: "blank question") if @question.blank?

    result = self.class.ai_caller.call(
      slug: "trip_concierge.v2",
      variables: {
        dossier: dossier,
        question: @question,
        viewer_name: @user&.display_name.to_s,
        can_edit: @trip.editable_by?(@user),
        today: Date.current.strftime("%A, %B %-d, %Y")
      },
      user: @user,
      trip: @trip
    )
    return Exchange.new(reply: nil, edits: [], error: result.error) unless result.success?

    parsed = result.json
    if parsed.is_a?(Hash) && parsed.key?("reply")
      Exchange.new(reply: parsed["reply"].to_s, edits: sanitize_edits(parsed["proposed_edits"]))
    else
      # Non-JSON backend (e.g. a test fake, or a prompt swapped back to prose):
      # treat the raw text as the reply, propose nothing.
      Exchange.new(reply: result.text.to_s, edits: [])
    end
  end

  # Public so it can be unit-tested and reused by an admin sandbox.
  def dossier
    [ overview, travelers, itinerary, landmarks, booking ].compact.join("\n\n")
  end

  private

  # Keep only well-formed edits with a known action, drop unknown/blank fields,
  # and cap the batch so one turn can't queue an unbounded pile of edits. Each
  # returned hash is safe to hand to the apply endpoint (which re-authorizes
  # and re-validates via TripEditor).
  MAX_EDITS = 6
  def sanitize_edits(raw)
    Array(raw).filter_map do |e|
      next unless e.is_a?(Hash)

      action = e["action"].to_s
      fields = EDIT_FIELDS[action]
      next unless fields

      day = e["day_number"].to_i
      next unless day.positive?

      edit = { "action" => action, "day_number" => day }
      fields.each do |f|
        next if f == :day_number

        val = e[f.to_s].to_s.strip
        edit[f.to_s] = val if val.present?
      end
      edit
    end.first(MAX_EDITS)
  end

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
    lines << "Must-includes: #{Array(@trip.must_includes).join('; ')}" if Array(@trip.must_includes).any?
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

    # What the traveler has actually confirmed (with any note — often the hotel
    # name / confirmation #), so the concierge can answer "where am I staying?".
    claims = @trip.booking_claims.to_a
    if claims.any?
      summary << "Confirmed by the traveler:"
      claims.each do |c|
        line = "- #{c.kind_label}: booked"
        line += " — #{c.note.to_s.strip.truncate(160)}" if c.note.to_s.strip.present?
        summary << line
      end
      pending = BookingClaim::KINDS - claims.map(&:kind)
      summary << "- Not booked yet: #{pending.map { |k| BookingClaim::KIND_LABELS[k] }.join(', ')}" if pending.any?
    else
      summary << "- Nothing booked yet — hotel, car, flight, and activity search links are in the app."
    end

    summary << "- Available booking perks: #{perks.join('; ')}" if perks.any?
    summary << "- Own-car trip: rental suggestions are suppressed." if links.own_car?
    summary.join("\n")
  rescue StandardError
    nil # booking context is best-effort; never block an answer on it
  end
end
