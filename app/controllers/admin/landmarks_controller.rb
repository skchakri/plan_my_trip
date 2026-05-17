module Admin
  class LandmarksController < BaseController
    # Route landmarks live as either:
    #   * RouteLandmark rows (preferred — once the migration lands), or
    #   * jsonb on Trip#route_landmarks (legacy storage).
    # We surface whichever exists so admins can audit Drive Co-Pilot content
    # without a deploy.
    def index
      @kind  = params[:kind].presence
      @q     = params[:q].presence
      @scope = (params[:scope].presence_in(%w[all trip global]) || "all")
      @entries = collect_landmarks(scope: @scope)
      @entries = @entries.select { |e| e[:kind].to_s == @kind } if @kind
      if @q
        needle = @q.downcase
        @entries = @entries.select do |e|
          e[:name].to_s.downcase.include?(needle) ||
            e[:narration].to_s.downcase.include?(needle) ||
            e[:trip_title].to_s.downcase.include?(needle)
        end
      end
      @entries = @entries.first(300)
      @kinds = RouteLandmark::KINDS
      @counts = {
        all:    RouteLandmark.kept.count,
        trip:   RouteLandmark.kept.where.not(trip_id: nil).count,
        global: RouteLandmark.kept.global.count
      }
    end

    def show
      @entry = collect_landmarks.find { |e| e[:client_id] == params[:id] || e[:id] == params[:id] }
      redirect_to admin_landmarks_path, alert: "Landmark not found." and return unless @entry
    end

    private

    def collect_landmarks(scope: "all")
      rows = []
      unless scope == "trip"
        RouteLandmark.kept.global.order(:name).find_each do |rec|
          rows << landmark_hash_from_record(rec, nil)
        end
      end

      unless scope == "global"
        Trip.kept.includes(:owner).order(created_at: :desc).limit(500).find_each do |trip|
          list = trip.route_landmarks
          next if list.blank?

          list.each do |l|
            if l.respond_to?(:attributes)
              rows << landmark_hash_from_record(l, trip)
            elsif l.is_a?(Hash)
              rows << landmark_hash_from_jsonb(l, trip)
            end
          end
        end
      end

      rows.sort_by { |r| -(r[:created_at_i] || 0) }
    rescue ActiveRecord::StatementInvalid
      jsonb_only_landmarks
    end

    def jsonb_only_landmarks
      Trip.kept.includes(:owner).order(created_at: :desc).limit(500).flat_map do |trip|
        raw = trip.read_attribute(:route_landmarks) || []
        raw.map { |h| landmark_hash_from_jsonb(h, trip) }
      end
    end

    def landmark_hash_from_record(rec, trip)
      {
        id: rec.id,
        client_id: rec.respond_to?(:client_id) ? rec.client_id : nil,
        name: rec.name,
        kind: rec.kind,
        source: rec.respond_to?(:source) ? rec.source : nil,
        narration: rec.narration,
        latitude: rec.latitude,
        longitude: rec.longitude,
        image_url: rec.image_url,
        wikipedia_url: rec.wikipedia_url,
        trip: trip,
        trip_title: trip&.title || "— global —",
        created_at: rec.created_at,
        created_at_i: rec.created_at&.to_i
      }
    end

    def landmark_hash_from_jsonb(h, trip)
      h = h.with_indifferent_access
      {
        id: h["id"] || "#{trip.id}-#{h['name']}",
        client_id: h["id"],
        name: h["name"],
        kind: h["kind"],
        source: h["source"],
        narration: h["narration"],
        latitude: h["lat"] || h["latitude"],
        longitude: h["lng"] || h["longitude"],
        image_url: h["image_url"],
        wikipedia_url: h["wikipedia_url"],
        trip: trip,
        trip_title: trip.title,
        created_at: trip.updated_at,
        created_at_i: trip.updated_at&.to_i
      }
    end
  end
end
