# The public "see a finished plan" on-ramp: a real, share-link-enabled trip
# picked at /admin/app_settings (SHOWCASE_TRIP_ID). Cached per request; falls
# back to nil so callers can degrade to the static sample page.
module ShowcaseHelper
  def showcase_trip
    return @showcase_trip if defined?(@showcase_trip)
    @showcase_trip = begin
      id = AppSetting.get("SHOWCASE_TRIP_ID").to_s.strip
      trip = id.present? ? Trip.kept.find_by(id: id) : nil
      trip if trip&.share_link_active? && trip.build_status == "ready"
    rescue StandardError
      nil
    end
  end

  # Where "See a sample plan" should go: the live public trip, else the
  # pre-Rails static itinerary page.
  def sample_plan_path
    (t = showcase_trip) ? public_trip_path(t.share_token) : "/sample-trips.html"
  end

  # Pinterest card for a road-trip guide: the pre-rendered 2:3 PNG in
  # public/pins/ (bin/generate-pins) when present, else the hero photo.
  def road_trip_pin_url(road_trip)
    file = Rails.public_path.join("pins", "#{road_trip.slug}.jpg")
    file.exist? ? "#{canonical_base_url}/pins/#{road_trip.slug}.jpg" : road_trip.hero_image_url.to_s
  end
end
