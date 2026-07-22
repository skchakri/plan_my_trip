module Trips
  # Multi-step trip-creation wizard. Replaces the single-page /trips/new form.
  #
  # Steps: destination → travelers → highlights → review.
  # Draft state lives in session[:trip_wizard] until the user submits the
  # final review step; the Trip row is only persisted at that point.
  class WizardController < ApplicationController
    SESSION_KEY = :trip_wizard

    before_action :load_draft
    before_action :require_destination, only: %i[travelers save_travelers highlights highlights_results save_highlights highlight_details review create]
    before_action :require_travelers,   only: %i[highlights highlights_results save_highlights highlight_details review create]
    before_action :require_highlights,  only: %i[review create]

    # ---- Step 1: destination + dates -----------------------------------

    def destination
      @draft = @draft.merge(defaults_for_destination)
    end

    def save_destination
      attrs = params.require(:wizard).permit(:title, :origin, :destination, :start_date, :end_date, :departure_time, :return_time, :traveler_count, :place_id, :destination_lat, :destination_lng, :pace, :budget, :preferences, :transport_mode, must_includes: [])
      attrs[:transport_mode] = nil unless Trip::TRANSPORT_MODES.include?(attrs[:transport_mode])
      attrs[:must_includes] = Array(attrs[:must_includes]).map { |v| v.to_s.strip }.reject(&:blank?).uniq.first(Trip::MUST_INCLUDES_MAX)
      errors = validate_destination(attrs)
      if errors.any?
        @draft = @draft.merge(attrs.to_h)
        flash.now[:alert] = errors.join(" · ")
        return render :destination, status: :unprocessable_entity
      end

      # The step-1 form pre-fills the title field, so a title we auto-derived
      # on an earlier pass comes back as if the user typed it — and would stick
      # even after they change the destination or dates. If the submitted title
      # matches what we'd derive from the pre-edit draft, it's ours: blank it
      # so it re-derives from the new values. A user-typed title never matches
      # and is preserved.
      attrs[:title] = "" if attrs[:title].to_s.strip == derived_title(@draft)

      @draft.merge!(attrs.to_h)
      @draft["title"] = derived_title(@draft) if @draft["title"].to_s.strip.blank?
      persist_draft!
      redirect_to wizard_travelers_path
    end

    # ---- Step 2: travelers --------------------------------------------

    def travelers
      @draft["people"] ||= default_people(@draft["traveler_count"].to_i)
      @known_traveler_interests = Person.known_interests_for(current_user)
      @known_travelers = Person.known_travelers_for(current_user)
    end

    def save_travelers
      people_param = params.dig(:wizard, :people)
      raw_rows = people_param.respond_to?(:to_unsafe_h) ? people_param.to_unsafe_h.values : Array(people_param)
      rows = raw_rows.map do |row|
        h = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
        {
          "name" => h["name"].to_s.strip,
          "age" => h["age"].presence,
          "interests" => Array(h["interests"]).map { |i| i.to_s.strip }.reject(&:blank?).uniq
        }
      end
      cleaned = rows.reject { |r| r["name"].blank? }

      if cleaned.empty?
        flash.now[:alert] = "Add at least one traveler — names power the podcast intro and drive game."
        @draft["people"] = rows.presence || default_people(@draft["traveler_count"].to_i)
        @known_traveler_interests = Person.known_interests_for(current_user)
        @known_travelers = Person.known_travelers_for(current_user)
        return render :travelers, status: :unprocessable_entity
      end

      @draft["people"] = cleaned
      persist_draft!
      redirect_to wizard_highlights_path
    end

    # ---- Step 3: pick highlights --------------------------------------

    # Step 3 shell — renders instantly with a lazy turbo-frame. The slow
    # DestinationHighlights + DestinationBrief research happens in
    # #highlights_results so the page never blocks on it.
    def highlights
      @vibes = Array(params[:vibes]).map(&:to_s) & DestinationHighlights::VIBES
      @selected_slugs = draft_selected_slug_set
    end

    # GET /trip_wizard/highlights/results — the lazy frame body: runs the
    # research (cached 30 days) and renders the picker.
    def highlights_results
      # Vibes are a *client-side* filter on the already-fetched list (instant
      # — no server round-trip per chip). We still read them from the query
      # string here so a deep-linked / reloaded page restores the chip state.
      @vibes = Array(params[:vibes]).map(&:to_s) & DestinationHighlights::VIBES
      @highlights = DestinationHighlights.call(
        @draft["destination"],
        lat: @draft["destination_lat"],
        lng: @draft["destination_lng"]
      )
      @brief = DestinationBrief.call(@draft["destination"])
      @selected_slugs = draft_selected_slug_set
      # Step 1's must-include favourites surface here too: highlights whose
      # name matches one are pre-selected on the first visit (before the user
      # has saved any picks) and badged in the grid; the rest are shown in an
      # "anchored in your plan" strip so travelers see they're covered even
      # when the research didn't return them as cards.
      @must_slug_map = must_include_slug_map
      unless @draft.key?("selected_slugs") || @draft.key?("selected_highlights")
        @selected_slugs |= @must_slug_map.keys
      end
      @must_unmatched = Array(@draft["must_includes"]) - @must_slug_map.values
      render partial: "trips/wizard/highlights_body"
    rescue StandardError => e
      # Same guard as the day-trip suggestions frame: never 500 inside the lazy
      # wizard frame (the frame-timeout controller can't recover from it, and the
      # "Skip & continue" button is outside the frame). Render the body's
      # built-in empty state instead.
      Rails.logger.warn("[Wizard#highlights_results] #{e.class}: #{e.message}")
      @highlights = []
      @brief = DestinationBrief::EMPTY
      @selected_slugs ||= draft_selected_slug_set
      @must_slug_map ||= {}
      @must_unmatched ||= Array(@draft["must_includes"])
      render partial: "trips/wizard/highlights_body"
    end

    def save_highlights
      # Store only slugs in the session — the full Highlight payload (name,
      # summary, image URL, wikipedia URL, tags) is ~600 bytes per item and
      # 16 picks overflows Rails' 4KB cookie cap. We can always re-derive the
      # full objects from DestinationHighlights.call (cached 30 days).
      picks = Array(params.dig(:wizard, :selected_slugs)).map(&:to_s).reject(&:blank?).uniq
      @draft["selected_slugs"] = picks
      @draft.delete("selected_highlights") # clear legacy bloat if present
      persist_draft!
      redirect_to wizard_review_path
    end

    # GET /trip_wizard/highlights/:slug/details (JSON)
    # Returns the Claude-generated detail blob for a single highlight, used
    # by the highlight-detail modal to fill in async content after the user
    # taps a card. Cached for 30 days so repeat opens are instant.
    def highlight_details
      all = DestinationHighlights.call(@draft["destination"])
      highlight = all.find { |h| h.slug == params[:slug] }
      return render(json: { error: "not found" }, status: :not_found) unless highlight

      detail = HighlightDetail.call(
        destination: @draft["destination"],
        name: highlight.name,
        category: highlight.category,
        summary: highlight.summary
      )
      render json: detail
    end

    # ---- Step 4: review + create --------------------------------------

    def review
      @selected_highlights = selected_highlights_from_cache
    end

    # GET /trip_wizard/weather — lazy turbo-frame target on the review step:
    # per-day weather for the drafted destination + dates (WeatherReport /
    # Open-Meteo). The draft already carries geocoded destination coords, so
    # this usually skips the geocoder entirely. A nil report renders an empty
    # frame — never a 500 the frame can't recover from.
    def weather
      report =
        begin
          WeatherReport.call(
            destination: @draft["destination"],
            start_date: @draft["start_date"],
            end_date: @draft["end_date"],
            lat: @draft["destination_lat"],
            lng: @draft["destination_lng"]
          )
        rescue StandardError => e
          Rails.logger.warn("[Trips::WizardController#weather] #{e.class}: #{e.message}")
          nil
        end
      render partial: "trips/weather",
             locals: { report: report, frame_id: "wizard-weather", margin: "" },
             layout: false
    end

    # Persist a Trip *shell* immediately (status: building) and hand the slow
    # AI assembly (structured itinerary + route landmarks, minutes long) to
    # BuildTripJob. The user is redirected to the trip page right away, which
    # streams in the finished plan when the job broadcasts a Turbo refresh.
    # This keeps create from blocking the request for minutes and never wastes
    # AI work on a record that failed to save.
    def create
      # Refuse before persisting anything: a build is real AI spend, so the cap
      # has to bite ahead of the shell + BuildTripJob, not after.
      quota = BuildQuota.new(current_user)
      if quota.exceeded?
        flash.now[:alert] = quota.message
        return render :review, status: :too_many_requests
      end

      people = Array(@draft["people"]).map(&:symbolize_keys)

      trip = current_user.owned_trips.new(
        title: @draft["title"].presence || derived_title(@draft),
        origin: @draft["origin"],
        destination: @draft["destination"],
        start_date: @draft["start_date"],
        end_date: @draft["end_date"],
        departure_time: @draft["departure_time"].presence,
        return_time: @draft["return_time"].presence,
        transport_mode: @draft["transport_mode"].presence,
        must_includes: Array(@draft["must_includes"]),
        pace: @draft["pace"].presence,
        budget: @draft["budget"].presence,
        preferences: @draft["preferences"].presence,
        traveler_count: traveler_count_or_people,
        build_status: "building",
        # Saved so BuildTripJob (and #rebuild) can re-derive the chosen highlights.
        build_args: { "selected_slugs" => draft_selected_slug_set.to_a }
      )
      authorize trip, :create?

      people.each_with_index do |p, i|
        trip.people.build(name: p[:name], age: p[:age].presence, interests: Array(p[:interests]), position: i)
      end

      if trip.save
        BuildTripJob.perform_later(trip.id)
        reset_session_draft!
        redirect_to trip, notice: "Building your plan — this takes a moment. It'll fill in here automatically."
      else
        flash.now[:alert] = trip.errors.full_messages.to_sentence
        render :review, status: :unprocessable_entity
      end
    end

    # ---- Reset wizard --------------------------------------------------

    def reset
      reset_session_draft!
      redirect_to wizard_destination_path, notice: "Started a fresh plan."
    end

    private

    # The wizard persists state in a DraftTrip row (one per user) so a
    # deploy / cookie eviction mid-flow doesn't wipe progress. `@draft`
    # exposes the same hash-style interface the rest of this controller
    # already expects, backed by DraftTrip#payload.
    #
    # Migration note: an in-flight session hash (legacy storage) is
    # adopted on first hit so users mid-wizard during deploy don't lose
    # their draft.
    def load_draft
      @draft_record = DraftTrip.fetch_or_build(current_user)
      legacy = session.delete(SESSION_KEY)
      if legacy.is_a?(Hash) && legacy.any? && @draft_record.payload.blank?
        @draft_record.payload = legacy.deep_stringify_keys
      end
      @draft = @draft_record
    end

    def persist_draft!
      @draft_record.save_step!(action_name)
    end

    def reset_session_draft!
      session.delete(SESSION_KEY)
      DraftTrip.where(user_id: current_user.id).delete_all
      @draft_record = DraftTrip.fetch_or_build(current_user)
      @draft = @draft_record
    end

    def require_destination
      return if @draft["destination"].present? && @draft["start_date"].present? && @draft["end_date"].present?
      redirect_to wizard_destination_path, alert: "Tell us where you're heading first."
    end

    def require_travelers
      return if Array(@draft["people"]).any? { |p| p["name"].to_s.strip.present? }
      redirect_to wizard_travelers_path, alert: "Add at least one traveler first."
    end

    def require_highlights
      # Visiting the highlights step writes the key (possibly an empty array
      # if the user chose to skip). Use key presence — not array contents —
      # as the gate, and accept either the new slug-only form or the legacy
      # full-payload form so in-flight sessions don't break.
      return if @draft.key?("selected_slugs") || @draft.key?("selected_highlights")
      redirect_to wizard_highlights_path, alert: "Pick some highlights — or skip and write the plan yourself."
    end

    def draft_selected_slug_set
      slugs = @draft["selected_slugs"]
      return slugs.to_set if slugs.is_a?(Array)
      # Back-compat: derive slugs from the legacy embedded payload if a
      # user has an old session draft.
      Array(@draft["selected_highlights"]).map { |h| h["slug"] || h[:slug] }.compact.to_set
    end

    def selected_highlights_from_cache
      slugs = draft_selected_slug_set
      return [] if slugs.empty?
      DestinationHighlights.call(@draft["destination"]).select { |h| slugs.include?(h.slug) }
    end

    # { highlight slug => the must-include string it matched }. First match
    # wins so one favourite doesn't pre-select half the grid.
    def must_include_slug_map
      musts = Array(@draft["must_includes"]).map(&:to_s)
      return {} if musts.empty?
      claimed = []
      Array(@highlights).each_with_object({}) do |h, map|
        hit = (musts - claimed).find { |m| must_include_matches?(m, h.name) }
        next unless hit
        claimed << hit
        map[h.slug] = hit
      end
    end

    # "Disneyland — 2 days" matches "Disneyland Park", and "Disney" matches
    # "Disneyland": strip any duration suffix, then accept an exact match,
    # whole-word containment either way, or all favourite tokens prefixing
    # highlight tokens ("disney" → "disneyland"). Every token must land (so
    # "LA beach" won't grab every beach) and one must be ≥4 chars.
    def must_include_matches?(must, name)
      a = normalized_must(must)
      b = name.to_s.downcase.strip
      return false if a.length < 3 || b.blank?
      return true if a == b
      return true if b.match?(/\b#{Regexp.escape(a)}\b/) || a.match?(/\b#{Regexp.escape(b)}\b/)

      a_tokens = a.split(/[^a-z0-9]+/).reject(&:empty?)
      return false if a_tokens.none? { |t| t.length >= 4 }
      b_tokens = b.split(/[^a-z0-9]+/)
      a_tokens.all? { |t| b_tokens.any? { |bt| bt.start_with?(t) } }
    end

    def normalized_must(must)
      must.to_s.downcase.strip
          .sub(/\s*[—–-]\s*\d+(\.\d+)?\s*(day|days|hour|hours|hr|hrs|night|nights)\b.*\z/, "")
          .strip
    end

    def defaults_for_destination
      defaults = {
        "start_date" => @draft["start_date"].presence || Date.current.to_s,
        "end_date"   => @draft["end_date"].presence   || (Date.current + 3).to_s,
        "traveler_count" => @draft["traveler_count"].presence || 2
      }
      # Pre-fill origin/destination/transport from a road-trip page's "Build your
      # own" deep-link (?origin=&destination=&transport_mode=), but never clobber
      # an in-progress draft.
      defaults["origin"]      = params[:origin]      if @draft["origin"].blank?      && params[:origin].present?
      defaults["destination"] = params[:destination] if @draft["destination"].blank? && params[:destination].present?
      if @draft["transport_mode"].blank? && Trip::TRANSPORT_MODES.include?(params[:transport_mode])
        defaults["transport_mode"] = params[:transport_mode]
      end
      defaults
    end

    def default_people(count)
      [ count.to_i, 2 ].max.times.map { { "name" => "", "age" => nil, "interests" => [] } }
    end

    def validate_destination(attrs)
      errors = []
      errors << "Destination is required" if attrs[:destination].to_s.strip.blank?
      errors << "Start date is required" if attrs[:start_date].blank?
      errors << "End date is required"   if attrs[:end_date].blank?
      if attrs[:start_date].present? && attrs[:end_date].present?
        begin
          s = Date.parse(attrs[:start_date])
          e = Date.parse(attrs[:end_date])
          errors << "End date must be on or after start date" if e < s
        rescue ArgumentError
          errors << "Dates aren't valid"
        end
      end
      errors
    end

    def derived_title(draft)
      dest = draft["destination"].to_s.strip
      return "New trip" if dest.blank?
      begin
        s = Date.parse(draft["start_date"].to_s)
        e = Date.parse(draft["end_date"].to_s)
        if s.year == e.year && s.month == e.month
          "#{dest} — #{s.strftime('%b %-d')}-#{e.strftime('%-d, %Y')}"
        else
          "#{dest} — #{s.strftime('%b %-d')} to #{e.strftime('%b %-d, %Y')}"
        end
      rescue ArgumentError
        dest
      end
    end

    def traveler_count_or_people
      [ Array(@draft["people"]).size, @draft["traveler_count"].to_i ].max
    end
  end
end
