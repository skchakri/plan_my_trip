module Trips
  # Assembles a persisted (shell) Trip into a full plan: runs the structured
  # itinerary AI call, fills missing coordinates via the geocoder, builds
  # TripDay/Activity/ChecklistItem rows + drive-by RouteLandmarks, and derives
  # the markdown body. Extracted from WizardController#create so it can run in
  # BuildTripJob off the request (the AI calls take minutes).
  #
  # The trip must already be saved (so people + associations attach cleanly).
  # On success the trip has days/activities/checklist/landmarks/body/pitch.
  class Assembler
    # Budgeted geocoder fills per build so a trip with many coordinate-less
    # activities can't hammer Nominatim's 1-req/sec policy.
    GEOCODE_BUDGET = 12

    # Claude's free-form group_label → the Place model's canonical kind enum.
    GROUP_LABEL_TO_PLACE_KIND = {
      "lodging" => "lodging", "hotel" => "lodging", "motel" => "lodging",
      "campsite" => "lodging", "meal" => "restaurant", "lunch" => "restaurant",
      "dinner" => "restaurant", "breakfast" => "cafe", "hike" => "trail",
      "trail" => "trail", "drive" => "drive_segment", "viewpoint" => "viewpoint",
      "overlook" => "overlook", "park" => "park", "museum" => "museum",
      "historic" => "historic"
    }.freeze

    def self.call(...)
      new(...).call
    end

    # highlights: array of Hashes (symbol keys) with at least :name, :summary,
    # and optionally :image_url — the picks chosen in the wizard.
    def initialize(trip:, highlights: [])
      @trip = trip
      @highlights = Array(highlights)
      @geocode_budget = GEOCODE_BUDGET
      @anchor = nil
      @anchor_resolved = false
    end

    def call
      # Idempotent: a rebuild (POST /trips/:id/rebuild) runs against a trip that
      # may already have days/activities/checklist/landmarks from a prior build,
      # so clear them first — otherwise the rebuild stacks a fresh plan on top of
      # the old one. On a first build the shell is empty, so this is a no-op.
      reset_generated_content!

      structure = TripStructureBuilder.call(
        destination: @trip.destination,
        origin: @trip.origin,
        start_date: @trip.start_date,
        end_date: @trip.end_date,
        people: people_payload,
        highlights: @highlights,
        transport_mode: @trip.transport_mode,
        pace: @trip.pace,
        budget: @trip.budget,
        preferences: @trip.preferences
      )

      build_days_and_activities(structure)
      build_checklist(structure)
      @trip.excitement_pitch = structure["excitement_pitch"].presence || @trip.excitement_pitch
      @trip.body = MarkdownItinerary.from_structure(structure, destination: @trip.destination, people: people_payload)
      @trip.save!

      build_route_landmarks(structure)
      @trip
    end

    private

    # Wipe AI-generated plan rows so a rebuild replaces rather than duplicates.
    # Destroying trip_days cascades to activities (and their comments/photos/
    # suggestions). Route landmarks and checklist items are trip-scoped.
    def reset_generated_content!
      return unless @trip.persisted?
      @trip.trip_days.destroy_all
      @trip.checklist_items.destroy_all
      @trip.route_landmarks.destroy_all
    end

    def people_payload
      @trip.people.map { |p| { name: p.name, age: p.age, interests: Array(p.interests) } }
    end

    def build_days_and_activities(structure)
      photo_by_name = @highlights.each_with_object({}) do |h, acc|
        key = h[:name].to_s.downcase.strip
        acc[key] = h[:image_url] if key.present? && h[:image_url].present?
      end
      used_photo_urls = photo_by_name.values.compact.to_set
      seeded_places = {}

      Array(structure["days"]).each_with_index do |day_data, di|
        day = @trip.trip_days.build(
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
          lat, lng = verified_coords(a["location_name"], a["latitude"]&.to_f, a["longitude"]&.to_f)

          place = nil
          if a["location_name"].to_s.strip.present? && lat && lng
            place_key = "#{name_key}|#{lat.round(3)}|#{lng.round(3)}"
            place = seeded_places[place_key] ||= Places::Seeder.call(
              name: a["location_name"], lat: lat, lng: lng,
              kind: kind_for(a["group_label"]),
              image_query: a["image_query"], famous_for: a["famous_for"],
              user: @trip.owner
            )
          end

          photo = photo_by_name[name_key] || photo_by_name[title_key]
          if photo.blank? && place&.image_url.present? && !used_photo_urls.include?(place.image_url)
            photo = place.image_url
          end
          used_photo_urls << photo if photo.present?

          day.activities.build(
            time_label: a["time_label"], title: a["title"].presence || "Activity",
            location_name: a["location_name"], address: a["address"],
            latitude: lat, longitude: lng,
            famous_for: a["famous_for"], notes: a["notes"], group_label: a["group_label"],
            photo_url: photo, guide_script: a["guide_script"].to_s.strip.presence,
            place: place, position: ai
          )
        end
      end
    end

    def build_checklist(structure)
      Array(structure.dig("checklist", "before_trip")).each_with_index do |item, i|
        next if item["title"].blank?
        @trip.checklist_items.build(scope: "before_trip", title: item["title"], category: item["category"].presence || "General", position: i)
      end
      Array(structure.dig("checklist", "day")).each_with_index do |item, i|
        next if item["title"].blank? || item["day_label"].blank?
        @trip.checklist_items.build(scope: "day", day_label: item["day_label"], title: item["title"], position: i)
      end
      Array(structure.dig("checklist", "activity")).each_with_index do |item, i|
        next if item["title"].blank? || item["day_label"].blank? || item["activity_label"].blank?
        @trip.checklist_items.build(scope: "activity", day_label: item["day_label"], activity_label: item["activity_label"], title: item["title"], position: i)
      end
    end

    def build_route_landmarks(structure)
      itinerary_stops = Array(structure["days"]).flat_map do |d|
        Array(d["activities"]).filter_map do |a|
          next unless a["latitude"].present? && a["longitude"].present?
          { name: a["location_name"].presence || a["title"], lat: a["latitude"], lng: a["longitude"] }
        end
      end
      RouteLandmarksBuilder.call(
        destination: @trip.destination, origin: @trip.origin,
        transport_mode: @trip.transport_mode, itinerary_stops: itinerary_stops, trip: @trip
      )
    rescue StandardError => e
      Rails.logger.warn("[Trips::Assembler] route landmarks: #{e.class}: #{e.message}")
    end

    # Fills missing activity coordinates from the geocoder (LLMs often omit or
    # invent them), biased toward the destination. Only spends a lookup when
    # coords are absent and a name is present — present coords are trusted.
    def verified_coords(name, lat, lng)
      return [ lat, lng ] if lat && lng
      return [ lat, lng ] if name.to_s.strip.blank? || @geocode_budget <= 0

      @geocode_budget -= 1
      # Nominatim 1 req/sec pacing happens inside Places::Geocoder, only when
      # a live Nominatim call is actually made.
      geo = Places::Geocoder.call(name, near_lat: anchor&.first, near_lng: anchor&.last, bias_km: 300)
      geo ? [ geo.lat, geo.lng ] : [ lat, lng ]
    end

    # Destination centroid, resolved once and reused to bias activity geocodes.
    def anchor
      return @anchor if @anchor_resolved
      @anchor_resolved = true
      geo = Places::Geocoder.call(@trip.destination) if @trip.destination.present?
      @anchor = geo ? [ geo.lat, geo.lng ] : nil
    end

    def kind_for(group_label)
      return nil if group_label.blank?
      GROUP_LABEL_TO_PLACE_KIND[group_label.to_s.strip.downcase]
    end
  end
end
