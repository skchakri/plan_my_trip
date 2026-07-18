module Trails
  # Best-effort enrichment for a Trail: geocode the trailhead by name (biased
  # to the trip's area) via the shared Places::Geocoder, then a single free
  # Open-Elevation lookup for the elevation. Stores a *snapshot* on the Trail
  # (trailhead_lat/lng/elevation_ft) — not a full AllTrails-style profile; we
  # don't have the trail polyline, only the trailhead point.
  #
  # Everything rescues to nil and stamps `enriched_at` regardless, so a slow or
  # flaky free API degrades to "no data" and never retries in a tight loop.
  class TrailheadEnricher
    ELEVATION_ENDPOINT = "https://api.open-elevation.com/api/v1/lookup".freeze
    METERS_TO_FEET = 3.28084

    def self.call(trail) = new(trail).call

    def initialize(trail)
      @trail = trail
      @trip  = trail.trip
    end

    def call
      lat, lng = geocode
      elevation_ft = lat && lng ? elevation_feet(lat, lng) : nil

      @trail.update_columns(
        trailhead_lat: lat,
        trailhead_lng: lng,
        trailhead_elevation_ft: elevation_ft,
        enriched_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.warn("[trailhead-enricher] #{@trail.id}: #{e.class} #{e.message}")
      @trail.update_columns(enriched_at: Time.current)
    end

    private

    def geocode
      result = Places::Geocoder.call(
        @trail.name,
        near_lat: @trip.anchor_lat&.to_f,
        near_lng: @trip.anchor_lng&.to_f
      )
      result ? [ result.lat, result.lng ] : [ nil, nil ]
    end

    def elevation_feet(lat, lng)
      uri = URI(ELEVATION_ENDPOINT)
      uri.query = URI.encode_www_form(locations: "#{lat},#{lng}")
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 6) do |http|
        http.get(uri.request_uri, "Accept" => "application/json")
      end
      return nil unless res.is_a?(Net::HTTPSuccess)

      meters = Array(JSON.parse(res.body)["results"]).first&.dig("elevation")
      return nil if meters.nil?

      (meters.to_f * METERS_TO_FEET).round
    end
  end
end
