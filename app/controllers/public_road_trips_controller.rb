# SEO-indexed public road-trip guides at /road-trips and /road-trips/:slug.
# Public (no auth), marketing-styled, crawlable. Content is fully pre-stored on
# the RoadTrip row, so these pages render with ZERO per-request AI calls even
# under crawler load. Mirrors PublicPlacesController.
class PublicRoadTripsController < ApplicationController
  layout "marketing"
  skip_before_action :authenticate_user!

  def index
    @road_trips = RoadTrip.published.ordered
  end

  def show
    # find_by! → RecordNotFound → standard 404 (drafts/unknown slugs stay private).
    @road_trip = RoadTrip.published.find_by!(slug: params[:slug])
    @related = RoadTrip.published.ordered.where.not(id: @road_trip.id).limit(3)
  end

  # Lazy turbo-frame: "typical conditions" weather for the destination. Undated
  # guide, so we ask WeatherReport for a representative near-term window (it
  # returns climatology beyond the 16-day forecast horizon). Always rescues to a
  # nil report → the frame collapses to nothing.
  def weather
    @road_trip = RoadTrip.published.find_by!(slug: params[:slug])
    start_date = 30.days.from_now.to_date
    report = WeatherReport.call(
      destination: @road_trip.destination,
      start_date:  start_date,
      end_date:    start_date + [ @road_trip.suggested_days.to_i - 1, 0 ].max.days,
      lat:         @road_trip.destination_lat,
      lng:         @road_trip.destination_lng
    )
    render partial: "trips/weather", locals: { report: report, frame_id: "road-trip-weather" }
  rescue StandardError
    render partial: "trips/weather", locals: { report: nil, frame_id: "road-trip-weather" }
  end

  def sitemap
    @road_trips = RoadTrip.published.ordered
    respond_to { |format| format.xml { render layout: false } }
  end
end
