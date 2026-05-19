module Trips
  # Multi-step trip-creation wizard. Replaces the single-page /trips/new form.
  #
  # Steps: destination → travelers → highlights → review.
  # Draft state lives in session[:trip_wizard] until the user submits the
  # final review step; the Trip row is only persisted at that point.
  class WizardController < ApplicationController
    SESSION_KEY = :trip_wizard

    before_action :load_draft
    before_action :require_destination, only: %i[travelers save_travelers highlights save_highlights highlight_details review create]
    before_action :require_travelers,   only: %i[highlights save_highlights highlight_details review create]
    before_action :require_highlights,  only: %i[review create]

    # ---- Step 1: destination + dates -----------------------------------

    def destination
      @draft = @draft.merge(defaults_for_destination)
    end

    def save_destination
      attrs = params.require(:wizard).permit(:title, :origin, :destination, :start_date, :end_date, :departure_time, :return_time, :traveler_count, :place_id, :destination_lat, :destination_lng)
      errors = validate_destination(attrs)
      if errors.any?
        @draft = @draft.merge(attrs.to_h)
        flash.now[:alert] = errors.join(" · ")
        return render :destination, status: :unprocessable_entity
      end

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

    def highlights
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

    def create
      people = Array(@draft["people"]).map(&:symbolize_keys)
      highlights = selected_highlights_from_cache.map { |h| h.to_h.symbolize_keys }

      body = ItineraryBuilder.call(
        destination: @draft["destination"],
        origin: @draft["origin"],
        start_date: @draft["start_date"],
        end_date: @draft["end_date"],
        people: people,
        highlights: highlights
      )

      structure = TripStructureBuilder.call(
        destination: @draft["destination"],
        origin: @draft["origin"],
        start_date: @draft["start_date"],
        end_date: @draft["end_date"],
        people: people,
        highlights: highlights,
        transport_mode: @draft["transport_mode"]
      )

      itinerary_stops = Array(structure["days"]).flat_map do |d|
        Array(d["activities"]).filter_map do |a|
          next unless a["latitude"].present? && a["longitude"].present?
          { name: a["location_name"].presence || a["title"], lat: a["latitude"], lng: a["longitude"] }
        end
      end

      trip = current_user.owned_trips.new(
        title: @draft["title"].presence || derived_title(@draft),
        origin: @draft["origin"],
        destination: @draft["destination"],
        start_date: @draft["start_date"],
        end_date: @draft["end_date"],
        departure_time: @draft["departure_time"].presence,
        return_time: @draft["return_time"].presence,
        traveler_count: traveler_count_or_people,
        body: body,
        excitement_pitch: structure["excitement_pitch"].presence
      )
      authorize trip, :create?

      people.each_with_index do |p, i|
        trip.people.build(
          name: p[:name],
          age: p[:age].presence,
          interests: Array(p[:interests]),
          position: i
        )
      end

      build_days_and_activities(trip, structure, highlights)
      build_checklist(trip, structure)

      if trip.save
        # Drive-by landmarks (RouteLandmark rows) — historic markers, scenic
        # overlooks, geological features along the route. Created post-save
        # so the builder can persist directly on the trip.
        RouteLandmarksBuilder.call(
          destination: @draft["destination"],
          origin: @draft["origin"],
          transport_mode: @draft["transport_mode"],
          itinerary_stops: itinerary_stops,
          trip: trip
        )
        reset_session_draft!
        redirect_to trip, notice: "Trip created · #{trip.trip_days.size} days, #{trip.checklist_items.size} checklist items, #{highlights.size} highlights woven in."
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

    # Builds (but does not save — trip.save cascades) TripDay + Activity
    # rows from the structured TripStructureBuilder payload. Activities
    # whose location matches a selected highlight inherit that highlight's
    # photo + Wikipedia URL so the plan view shows real imagery.
    def build_days_and_activities(trip, structure, highlights)
      photo_by_name = highlights.each_with_object({}) do |h, acc|
        key = h[:name].to_s.downcase.strip
        acc[key] = h[:image_url] if key.present? && h[:image_url].present?
      end
      # Track images already used on this trip so two activities don't get
      # the same hero photo when geosearch falls back to the nearest
      # Wikipedia-documented landmark.
      used_photo_urls = photo_by_name.values.compact.to_set
      # Track places used on this trip so the shared catalog gets one
      # Place row per real-world location, even when the same spot shows
      # up across multiple days (e.g. lodging used for 3 nights).
      seeded_places = {}

      Array(structure["days"]).each_with_index do |day_data, di|
        day = trip.trip_days.build(
          label: day_data["label"].presence || "day-#{di + 1}",
          title: day_data["title"].presence || "Day #{di + 1}",
          theme: day_data["theme"],
          summary: day_data["summary"],
          accent: day_data["accent"],
          date: (Date.parse(day_data["date"]) rescue nil),
          position: di
        )
        Array(day_data["activities"]).each_with_index do |a, ai|
          name_key = a["location_name"].to_s.downcase.strip
          title_key = a["title"].to_s.downcase.strip

          # Find-or-seed a Place in the shared catalog. The Seeder handles
          # Wikipedia/AI image lookup once per real-world location; later
          # trips reuse the row instead of re-fetching.
          place = nil
          if a["location_name"].to_s.strip.present? && a["latitude"].present? && a["longitude"].present?
            place_key = "#{a["location_name"].to_s.downcase.strip}|#{a["latitude"].to_f.round(3)}|#{a["longitude"].to_f.round(3)}"
            place = seeded_places[place_key] ||= Places::Seeder.call(
              name: a["location_name"],
              lat: a["latitude"],
              lng: a["longitude"],
              kind: kind_for(a["group_label"]),
              image_query: a["image_query"],
              famous_for: a["famous_for"],
              user: current_user
            )
          end

          # Per-activity photo: highlight match first (most accurate), then
          # the Place's canonical image. Skip if already taken so a Day-1
          # motel and Day-2 motel don't share the same hero when their
          # Places happen to share an image (e.g. both linked to the
          # same nearby town article).
          photo = photo_by_name[name_key] || photo_by_name[title_key]
          if photo.blank? && place&.image_url.present? && !used_photo_urls.include?(place.image_url)
            photo = place.image_url
          end
          used_photo_urls << photo if photo.present?

          day.activities.build(
            time_label: a["time_label"],
            title: a["title"].presence || "Activity",
            location_name: a["location_name"],
            address: a["address"],
            latitude: a["latitude"],
            longitude: a["longitude"],
            famous_for: a["famous_for"],
            notes: a["notes"],
            group_label: a["group_label"],
            photo_url: photo,
            guide_script: a["guide_script"].to_s.strip.presence,
            place: place,
            position: ai
          )
        end
      end
    end

    # Builds ChecklistItem rows (3 scopes) from the structured payload.
    def build_checklist(trip, structure)
      Array(structure.dig("checklist", "before_trip")).each_with_index do |item, i|
        next if item["title"].blank?
        trip.checklist_items.build(
          scope: "before_trip",
          title: item["title"],
          category: item["category"].presence || "General",
          position: i
        )
      end
      Array(structure.dig("checklist", "day")).each_with_index do |item, i|
        next if item["title"].blank? || item["day_label"].blank?
        trip.checklist_items.build(
          scope: "day",
          day_label: item["day_label"],
          title: item["title"],
          position: i
        )
      end
      Array(structure.dig("checklist", "activity")).each_with_index do |item, i|
        next if item["title"].blank? || item["day_label"].blank? || item["activity_label"].blank?
        trip.checklist_items.build(
          scope: "activity",
          day_label: item["day_label"],
          activity_label: item["activity_label"],
          title: item["title"],
          position: i
        )
      end
    end

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

    def defaults_for_destination
      {
        "start_date" => @draft["start_date"].presence || Date.current.to_s,
        "end_date"   => @draft["end_date"].presence   || (Date.current + 3).to_s,
        "traveler_count" => @draft["traveler_count"].presence || 2
      }
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

    # Maps Claude's group_label (free-form) to the Place model's
    # canonical kind enum so the shared catalog stays clean.
    GROUP_LABEL_TO_PLACE_KIND = {
      "lodging"    => "lodging",
      "hotel"      => "lodging",
      "motel"      => "lodging",
      "campsite"   => "lodging",
      "meal"       => "restaurant",
      "lunch"      => "restaurant",
      "dinner"     => "restaurant",
      "breakfast"  => "cafe",
      "hike"       => "trail",
      "trail"      => "trail",
      "drive"      => "drive_segment",
      "viewpoint"  => "viewpoint",
      "overlook"   => "overlook",
      "park"       => "park",
      "museum"     => "museum",
      "historic"   => "historic"
    }.freeze
    private_constant :GROUP_LABEL_TO_PLACE_KIND

    def kind_for(group_label)
      return nil if group_label.blank?
      GROUP_LABEL_TO_PLACE_KIND[group_label.to_s.strip.downcase]
    end
  end
end
