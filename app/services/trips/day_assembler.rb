module Trips
  # Assembles a persisted (shell) day-trip into a one-day plan: runs DayPlanBuilder
  # for the chosen nearby ideas, then builds the single TripDay + activities (with
  # photos from the chosen ideas / Places::Seeder) + a day-of checklist. Extracted
  # from DayTripsController#create so it can run in BuildDayTripJob off the request.
  #
  # The trip must already be saved. Mirrors Trips::Assembler (multi-day) but for
  # the single-day shape.
  class DayAssembler
    GROUP_LABEL_TO_PLACE_KIND = {
      "meal" => "restaurant", "lunch" => "restaurant", "dinner" => "restaurant",
      "coffee" => "cafe", "breakfast" => "cafe", "hike" => "trail", "trail" => "trail",
      "drive" => "drive_segment", "viewpoint" => "viewpoint", "overlook" => "overlook",
      "park" => "park", "museum" => "museum", "historic" => "historic", "family" => "park"
    }.freeze

    def self.call(...)
      new(...).call
    end

    # ideas: the chosen NearbyIdeas::Idea structs (respond to to_h / name / image_url).
    def initialize(trip:, ideas: [], depart_time: nil, return_time: nil)
      @trip = trip
      @ideas = Array(ideas)
      @depart_time = depart_time.to_s.strip.presence
      @return_time = return_time.to_s.strip.presence
    end

    def call
      # Idempotent rebuild — clear any prior generated rows first (see
      # Trips::Assembler#reset_generated_content!). No-op on a first build.
      reset_generated_content!
      advance_build_step!(0)

      structure = DayPlanBuilder.call(
        anchor_label: @trip.anchor_label,
        anchor_lat: @trip.anchor_lat,
        anchor_lng: @trip.anchor_lng,
        date: @trip.start_date,
        depart_time: @depart_time || "8:00 AM",
        return_time: @return_time || "7:00 PM",
        interests: Array(@trip.interests),
        ideas: @ideas.map(&:to_h),
        people: []
      )

      advance_build_step!(1)
      build_days_and_activities(structure)
      advance_build_step!(2)
      build_checklist(structure)
      @trip.excitement_pitch = structure["excitement_pitch"].presence || @trip.excitement_pitch
      advance_build_step!(3)
      @trip.save!
      @trip
    end

    private

    # Mirror Trips::Assembler — push each stage to the waiting screen's Turbo
    # stream so the day-plan build shows live progress. Best-effort.
    def advance_build_step!(step)
      @trip.update_columns(build_step: step)
      @trip.broadcast_replace_to(@trip, target: "trip-build-progress",
                                 partial: "trips/build_progress", locals: { trip: @trip })
    rescue StandardError => e
      Rails.logger.warn("[Trips::DayAssembler] build progress: #{e.class}: #{e.message}")
    end

    def reset_generated_content!
      return unless @trip.persisted?
      @trip.trip_days.destroy_all
      @trip.checklist_items.destroy_all
    end

    def build_days_and_activities(structure)
      photo_by_name = @ideas.each_with_object({}) do |idea, acc|
        key = idea.name.to_s.downcase.strip
        acc[key] = idea.image_url if key.present? && idea.image_url.present?
      end
      used_photos = photo_by_name.values.compact.to_set
      seeded_places = {}

      Array(structure["days"]).first(1).each_with_index do |day_data, di|
        day = @trip.trip_days.build(
          label: day_data["label"].presence || "day-1",
          title: day_data["title"].presence || "Day trip",
          theme: day_data["theme"], summary: day_data["summary"], accent: day_data["accent"],
          date: @trip.start_date, position: di
        )

        Array(day_data["activities"]).each_with_index do |a, ai|
          name_key = a["location_name"].to_s.downcase.strip
          title_key = a["title"].to_s.downcase.strip

          place = nil
          if a["location_name"].to_s.strip.present? && a["latitude"].present? && a["longitude"].present?
            key = "#{name_key}|#{a["latitude"].to_f.round(3)}|#{a["longitude"].to_f.round(3)}"
            place = seeded_places[key] ||= Places::Seeder.call(
              name: a["location_name"], lat: a["latitude"], lng: a["longitude"],
              kind: place_kind_for(a["group_label"]),
              image_query: a["image_query"], famous_for: a["famous_for"], user: @trip.owner
            )
          end

          photo = photo_by_name[name_key] || photo_by_name[title_key]
          if photo.blank? && place&.image_url.present? && !used_photos.include?(place.image_url)
            photo = place.image_url
          end
          used_photos << photo if photo.present?

          day.activities.build(
            time_label: a["time_label"], title: a["title"].presence || "Activity",
            location_name: a["location_name"], address: a["address"],
            latitude: a["latitude"], longitude: a["longitude"],
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
        @trip.checklist_items.build(scope: "before_trip", title: item["title"], category: item["category"].presence || "Day-of", position: i)
      end
    end

    def place_kind_for(group_label)
      return nil if group_label.blank?
      GROUP_LABEL_TO_PLACE_KIND[group_label.to_s.strip.downcase]
    end
  end
end
