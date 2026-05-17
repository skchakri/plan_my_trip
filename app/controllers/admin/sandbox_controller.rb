require "digest"

module Admin
  # Read-only test rig for the trip-planning AI pipeline + place catalog.
  #
  # Why this exists: when you tweak a prompt or a service you want to see
  # the *full* output (brief → highlights → route landmarks → structured
  # plan → markdown itinerary) for a concrete origin/destination without
  # going through the wizard and creating a Trip row. The sandbox is also
  # how we eyeball Place.near(...) — pick a city, pick a radius, see the
  # cataloged results on a map.
  #
  # The form GET renders the page with one lazy-loaded turbo-frame per
  # block; each frame's GET runs a single service call. Frames load in
  # parallel from the browser, so the page paints immediately and each
  # block streams in as its AI call returns. Results memoized for 1 hour
  # via Rails.cache so iterating on the same scenario is cheap.
  class SandboxController < BaseController
    # Sensible defaults for the SLC → Yellowstone scenario the user keeps
    # asking about — and for the "around SLC" nearby scenario. Pre-filling
    # these lets you visit /admin/sandbox and click Run without typing.
    DEFAULT_PLAN = {
      origin: "Salt Lake City, UT",
      destination: "Yellowstone National Park",
      start_date: Date.current.next_occurring(:friday),
      end_date: Date.current.next_occurring(:friday) + 2,
      transport_mode: "drive",
      people: [
        { name: "Alex",  age: 38, interests: %w[scenic photography hiking] },
        { name: "Sam",   age: 36, interests: %w[food relaxing] }
      ]
    }.freeze

    DEFAULT_NEARBY = {
      lat: 40.7608,
      lng: -111.8910,
      radius_km: 50,
      label: "Salt Lake City"
    }.freeze

    CACHE_TTL = 1.hour
    CACHE_NAMESPACE = "admin_sandbox/v1".freeze

    def show
      @plan_defaults = DEFAULT_PLAN
      @nearby_defaults = DEFAULT_NEARBY
      @plan_params = plan_params_from_query
      @nearby_params = nearby_params_from_query
      @plan_ready = @plan_params[:origin].present? && @plan_params[:destination].present?
      @nearby_ready = @nearby_params[:lat].present? && @nearby_params[:lng].present?
    end

    def brief
      p = plan_params_from_query
      @result = cached(:brief, [ p[:destination] ]) do
        timed do
          DestinationBrief.call(p[:destination])
        end
      end
      render layout: false
    end

    def highlights
      p = plan_params_from_query
      @result = cached(:highlights, [ p[:destination], p[:destination_lat], p[:destination_lng] ]) do
        timed do
          DestinationHighlights.call(p[:destination], lat: p[:destination_lat], lng: p[:destination_lng])
        end
      end
      render layout: false
    end

    def route_landmarks
      p = plan_params_from_query
      @result = cached(:route_landmarks, [ p[:origin], p[:destination], p[:transport_mode], stop_signature(p) ]) do
        timed do
          RouteLandmarksBuilder.new(
            origin: p[:origin], destination: p[:destination],
            transport_mode: p[:transport_mode], itinerary_stops: []
          ).call
        end
      end
      render layout: false
    end

    def structure
      p = plan_params_from_query
      @result = cached(:structure, structure_cache_key(p)) do
        timed do
          TripStructureBuilder.call(
            destination: p[:destination], origin: p[:origin],
            start_date: p[:start_date], end_date: p[:end_date],
            people: p[:people], highlights: p[:highlights_for_builder],
            transport_mode: p[:transport_mode]
          )
        end
      end
      render layout: false
    end

    def itinerary
      p = plan_params_from_query
      @result = cached(:itinerary, structure_cache_key(p)) do
        timed do
          ItineraryBuilder.call(
            destination: p[:destination], origin: p[:origin],
            start_date: p[:start_date], end_date: p[:end_date],
            people: p[:people], highlights: p[:highlights_for_builder]
          )
        end
      end
      render layout: false
    end

    # Renders a single place's details inside the sandbox-place-modal
    # turbo-frame, so clicking a row in the nearby table (or "Open →" on a
    # map pin popup) shows the info inline instead of navigating away.
    def place_modal
      @place = Place.find(params[:id])
      @recent_activities = Activity.where(place_id: @place.id)
                                   .joins(trip_day: :trip)
                                   .includes(trip_day: :trip)
                                   .order(created_at: :desc)
                                   .limit(10)
      render layout: false
    end

    def nearby
      p = nearby_params_from_query
      radius_m = (p[:radius_km].to_i * 1_000).clamp(1_000, 500_000)
      lat = p[:lat]
      lng = p[:lng]

      scope = Place.near(lat, lng, radius_m: radius_m)
      scope = scope.where(kind: p[:kind]) if p[:kind].present?
      scope = scope.where(tier: p[:tier]) if p[:tier].present?

      @origin_lat = lat
      @origin_lng = lng
      @radius_km = p[:radius_km].to_i
      @label = p[:label].presence || "(#{lat}, #{lng})"
      @kind = p[:kind]
      @tier = p[:tier]

      @places = scope.limit(400)
                     .map { |pl| [ pl, pl.distance_m_from(lat, lng) ] }
                     .select { |(_, d)| d <= radius_m }
                     .sort_by { |(_, d)| d }
                     .first(80)

      render layout: false
    end

    private

    # ───────────────────── params shaping ──────────────────────

    def plan_params_from_query
      raw = params.permit(
        :origin, :destination, :start_date, :end_date, :transport_mode,
        :origin_lat, :origin_lng, :destination_lat, :destination_lng,
        people: [ :name, :age, { interests: [] } ]
      ).to_h

      # HTML forms serialize `people[0][name]` etc. so Rails parses it as a
      # Hash keyed by "0"/"1"/"2" rather than a plain Array. Normalize both
      # shapes to a list of row hashes.
      people_raw = case raw[:people]
      when Hash  then raw[:people].values
      when Array then raw[:people]
      else            []
      end
      people = people_raw.map do |row|
        h = row.is_a?(Hash) ? row : {}
        # The interests input is a single comma-separated text field, but it
        # arrives wrapped in a one-element array (because the input name ends
        # in `[]`). Split on commas so each chip becomes its own interest.
        interests = Array(h["interests"]).flat_map { |s| s.to_s.split(",") }
                                         .map(&:strip).reject(&:blank?).uniq
        {
          name: h["name"].to_s.strip,
          age: h["age"].presence,
          interests: interests
        }
      end.reject { |p| p[:name].blank? }
      people = DEFAULT_PLAN[:people] if people.empty?

      origin = raw[:origin].to_s.strip.presence || DEFAULT_PLAN[:origin]
      destination = raw[:destination].to_s.strip.presence || DEFAULT_PLAN[:destination]
      start_date = parse_date(raw[:start_date]) || DEFAULT_PLAN[:start_date]
      end_date = parse_date(raw[:end_date]) || DEFAULT_PLAN[:end_date]
      end_date = start_date if end_date < start_date
      transport_mode = raw[:transport_mode].to_s.strip.presence || DEFAULT_PLAN[:transport_mode]

      # Re-shape the (slug-only) wizard highlights into the {name, summary}
      # rows that TripStructureBuilder / ItineraryBuilder want. We don't
      # ask the user to pick highlights in the sandbox — we just feed in
      # the top-6 from DestinationHighlights so the structure call has
      # something to anchor days against.
      highlights_for_builder = top_highlights_for(destination, raw[:destination_lat], raw[:destination_lng])

      {
        origin: origin, destination: destination,
        start_date: start_date, end_date: end_date,
        transport_mode: transport_mode, people: people,
        origin_lat: raw[:origin_lat].presence, origin_lng: raw[:origin_lng].presence,
        destination_lat: raw[:destination_lat].presence, destination_lng: raw[:destination_lng].presence,
        highlights_for_builder: highlights_for_builder
      }
    end

    def nearby_params_from_query
      raw = params.permit(:lat, :lng, :radius_km, :label, :kind, :tier).to_h
      lat = (raw[:lat].presence || DEFAULT_NEARBY[:lat]).to_f
      lng = (raw[:lng].presence || DEFAULT_NEARBY[:lng]).to_f
      radius_km = (raw[:radius_km].presence || DEFAULT_NEARBY[:radius_km]).to_i
      radius_km = 50 if radius_km <= 0
      label = raw[:label].presence || DEFAULT_NEARBY[:label]
      {
        lat: lat, lng: lng, radius_km: radius_km, label: label,
        kind: raw[:kind].presence, tier: raw[:tier].presence
      }
    end

    def parse_date(v)
      Date.parse(v.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # ───────────────────── caching ─────────────────────────────

    def cached(block, key_parts, &blk)
      digest = Digest::SHA256.hexdigest(Array(key_parts).map(&:to_s).join("|"))
      key = "#{CACHE_NAMESPACE}/#{block}/#{digest}"
      hit = Rails.cache.exist?(key)
      payload = Rails.cache.fetch(key, expires_in: CACHE_TTL, &blk)
      payload.merge(cache_hit: hit, cache_key: key)
    end

    def timed
      started = Time.current
      value = yield
      latency_ms = ((Time.current - started) * 1000).round
      { value: value, latency_ms: latency_ms, ran_at: started.iso8601 }
    end

    # ───────────────────── helpers ─────────────────────────────

    def stop_signature(p)
      [ p[:start_date], p[:end_date], p[:people].size ].join(",")
    end

    def structure_cache_key(p)
      [
        p[:origin], p[:destination], p[:start_date], p[:end_date], p[:transport_mode],
        p[:people].map { |x| "#{x[:name]}:#{x[:age]}:#{x[:interests].sort.join(',')}" }.join("|"),
        p[:highlights_for_builder].map { |h| h[:name] }.sort.join("|")
      ]
    end

    # Pull the first 6 highlights for the destination — these feed the
    # structure/itinerary AI calls so the day plan has something concrete
    # to anchor against. Cached 30d inside DestinationHighlights, so this
    # is cheap on repeat sandbox runs.
    def top_highlights_for(destination, lat, lng)
      DestinationHighlights.call(destination, lat: lat, lng: lng)
                           .first(6)
                           .map { |h| { name: h.name, summary: h.summary } }
    rescue StandardError => e
      Rails.logger.warn("[Admin::Sandbox] top_highlights_for #{destination}: #{e.class}: #{e.message}")
      []
    end

    public

    helper_method :sandbox_plan_qs

    # Whitelisted plan params forwarded to each lazy-frame URL. Lets Rails
    # serialize the nested people[] array correctly via its built-in URL
    # encoder. Empty fields are dropped so URLs stay short.
    def sandbox_plan_qs
      params.permit(
        :origin, :destination, :start_date, :end_date, :transport_mode,
        :origin_lat, :origin_lng, :destination_lat, :destination_lng,
        people: [ :name, :age, { interests: [] } ]
      ).to_h.compact_blank
    end
  end
end
