class BackfillRouteLandmarksFromJsonb < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    # Light shadow class so the migration doesn't depend on the Trip model.
    trip_class = Class.new(ActiveRecord::Base) { self.table_name = "trips" }
    landmark_class = Class.new(ActiveRecord::Base) { self.table_name = "route_landmarks" }
    allowed_kinds = %w[
      historic geological scenic cultural engineering natural
      ghost_town battlefield river_crossing pass_summit observatory tribal
    ]

    trip_class.where("jsonb_array_length(route_landmarks) > 0").find_each do |trip|
      next unless trip.route_landmarks.is_a?(Array)

      trip.route_landmarks.each_with_index do |raw, idx|
        next unless raw.is_a?(Hash)
        name = raw["name"].to_s.strip
        narration = raw["narration"].to_s.strip
        lat = Float(raw["lat"]) rescue nil
        lng = Float(raw["lng"]) rescue nil
        next if name.blank? || narration.blank? || lat.nil? || lng.nil?
        kind = raw["kind"].to_s.strip.downcase
        kind = "scenic" unless allowed_kinds.include?(kind)

        landmark_class.create!(
          trip_id: trip.id,
          name: name,
          kind: kind,
          latitude: lat,
          longitude: lng,
          narration: narration,
          image_url: raw["image_url"].presence,
          wikipedia_url: raw["wikipedia_url"].presence,
          position: idx,
          source: "ai"
        )
      end
    end
  end

  def down
    execute "DELETE FROM route_landmarks"
  end
end
