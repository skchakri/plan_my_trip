module Admin
  class RoadTripsController < BaseController
    before_action :set_road_trip, only: %i[edit update destroy publish unpublish]

    def index
      @road_trips = RoadTrip.kept.ordered
    end

    def new
      @road_trip = RoadTrip.new(status: "draft", transport_mode: "own_car")
    end

    def create
      @road_trip = RoadTrip.new
      if assign_and_save(@road_trip)
        redirect_to admin_road_trips_path, notice: "Road trip created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if assign_and_save(@road_trip)
        redirect_to admin_road_trips_path, notice: "Road trip updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @road_trip.discard
      redirect_to admin_road_trips_path, notice: "Road trip removed."
    end

    def publish
      @road_trip.update(status: "published")
      redirect_to admin_road_trips_path, notice: "Road trip published."
    end

    def unpublish
      @road_trip.update(status: "draft")
      redirect_to admin_road_trips_path, notice: "Road trip unpublished."
    end

    private

    def set_road_trip
      # to_param is the slug (same gotcha as blog), so :id arrives as the slug.
      @road_trip = RoadTrip.find_by!(slug: params[:id])
    end

    # Assigns scalar params + the three JSONB textarea fields (parsed here so an
    # invalid paste surfaces as a form error instead of a 500).
    def assign_and_save(record)
      record.assign_attributes(road_trip_params)
      json_errors = assign_json_fields(record)
      if json_errors.any?
        json_errors.each { |field, msg| record.errors.add(field, msg) }
        return false
      end
      record.save
    end

    def assign_json_fields(record)
      errors = {}
      %i[stops itinerary faqs].each do |field|
        raw = params.dig(:road_trip, field)
        next if raw.nil?
        parsed = JSON.parse(raw.to_s.presence || "[]")
        unless parsed.is_a?(Array)
          errors[field] = "must be a JSON array"
          next
        end
        record[field] = parsed
      rescue JSON::ParserError => e
        errors[field] = "is not valid JSON (#{e.message.truncate(60)})"
      end
      errors
    end

    def road_trip_params
      params.require(:road_trip).permit(
        :slug, :origin, :destination, :title, :tagline, :hero_image_url,
        :distance_label, :drive_time_label, :suggested_days, :best_season,
        :transport_mode, :destination_lat, :destination_lng, :intro,
        :seo_description, :status, :position
      )
    end
  end
end
