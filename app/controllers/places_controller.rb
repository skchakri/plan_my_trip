class PlacesController < ApplicationController
  PER_PAGE = 36

  # Browse the shared place catalog — the more people plan, the richer it gets.
  # Sorted by usage (social proof), filterable by kind / region / free text.
  def index
    @kind = params[:kind].to_s.presence
    @region = params[:region].to_s.presence
    @q = params[:q].to_s.strip

    scope = Place.kept.with_image
    scope = scope.where(kind: @kind) if @kind && Place::KINDS.include?(@kind)
    scope = scope.where(region: @region) if @region
    if @q.length >= 2
      pattern = "%#{@q.downcase}%"
      scope = scope.where("lower(name) LIKE ? OR lower(canonical_name) LIKE ?", pattern, pattern)
    end

    @places = scope.order(usage_count: :desc, community_rating: :desc, name: :asc).limit(PER_PAGE)
    # Kinds that actually have entries, for the filter chips.
    @available_kinds = Place.kept.with_image.where.not(kind: nil).distinct.pluck(:kind).compact.sort
  end

  # JSON autocomplete for any input that lets a user pick a known place
  # from the shared catalog. Currently called from the wizard's
  # destination input.
  def search
    q = params[:q].to_s.strip
    limit = params[:limit].to_i
    limit = 8 if limit <= 0 || limit > 25
    return render(json: { results: [] }) if q.length < 2

    pattern = "%#{q.downcase}%"
    catalog = Place.kept
                   .where("lower(name) LIKE ? OR lower(canonical_name) LIKE ?", pattern, pattern)
                   .order(autocomplete_rank(q))
                   .limit(limit)
                   .to_a

    # AI discovery (Perplexity web search, ~3-5s) is gated behind an explicit
    # `discover=1` second pass so the FIRST autocomplete request returns instantly
    # from the catalog and never blocks the dropdown. The client renders catalog
    # hits immediately, then (when `discoverable`) fires the slow pass and appends.
    # Discoverer caches per query 30d and persists results via Places::Seeder, so
    # repeat searches hit the catalog directly.
    discoverable = catalog.size < 4 && q.length >= Places::Discoverer::MIN_QUERY_LENGTH
    discovered = []
    if discoverable && params[:discover].present?
      seen_ids = catalog.map(&:id).to_set
      discovered = Places::Discoverer.call(q, user: current_user).reject { |p| seen_ids.include?(p.id) }
    end

    render json: {
      discoverable: discoverable && params[:discover].blank?,
      results: (catalog + discovered).first(limit).map do |p|
        {
          id: p.id,
          name: p.name,
          canonical_name: p.canonical_name,
          kind: p.kind,
          image_url: p.image_url,
          lat: p.latitude&.to_f,
          lng: p.longitude&.to_f,
          usage_count: p.usage_count,
          summary: p.description.to_s[0, 140],
          ai_discovered: discovered.include?(p)
        }
      end
    }
  end

  def show
    @place = Place.kept.find_by(slug: params[:id]) || Place.kept.find(params[:id])
    # "Trips that visited" — only those the current user has access to.
    # Catalog reuse is shared across users, but trip-level details are
    # still per-membership.
    visible_trip_ids = current_user.trips.kept.pluck(:id)
    @visiting_activities = @place.activities
                                 .joins(trip_day: :trip)
                                 .where(trip_days: { trip_id: visible_trip_ids })
                                 .includes(trip_day: :trip)
                                 .order("trip_days.position ASC, activities.position ASC")
                                 .to_a

    # Total count of trips that referenced this place across the whole
    # platform (not filtered). Useful "1,247 trips visited here" copy.
    @total_visits = @place.usage_count
    @other_trip_count = [ @total_visits - @visiting_activities.size, 0 ].max

    @reviews = @place.reviews.includes(:author).to_a
    @my_review = @reviews.find { |r| r.author_id == current_user.id }
  end

  # GET /places/:id/more_info — click-to-load "More about this place" frame
  # on the place page. HighlightDetail is 30-day cached, so the AI cost is
  # paid once per place, and only when someone actually asks.
  def more_info
    @place = Place.kept.find_by(slug: params[:id]) || Place.kept.find(params[:id])
    @detail = HighlightDetail.call(
      destination: @place.region.presence || "the local area",
      name: @place.name,
      category: @place.kind,
      summary: @place.famous_for.presence || @place.description.to_s.truncate(160)
    )
    render layout: false
  end

  # POST /places/rate
  # Accepts a card payload (name + coords + optional metadata) plus
  # rating and optional body. Resolves to a catalog Place (creating
  # one when the card came purely from the LLM), then upserts the
  # current_user's review. Returns JSON the modal uses to refresh
  # the stars + rating chip inline.
  def rate
    rating = params[:rating].to_i
    return render(json: { error: "rating must be 1..5" }, status: :unprocessable_entity) unless (1..5).include?(rating)

    place = Places.find_or_create_from_card!(
      name:          params[:name],
      lat:           params[:latitude],
      lng:           params[:longitude],
      summary:       params[:summary],
      image_url:     params[:image_url],
      wikipedia_url: params[:wikipedia_url],
      kind:          params[:kind],
      user:          current_user
    )
    return render(json: { error: "could not resolve place" }, status: :unprocessable_entity) unless place

    review = PlaceReview.where(place_id: place.id, author_id: current_user.id).kept.first ||
             PlaceReview.new(place_id: place.id, author_id: current_user.id)
    review.rating = rating
    review.body   = params[:body].to_s.strip.presence
    if review.save
      place.reload
      render json: {
        place_id: place.id,
        slug: place.slug,
        path: place.slug.present? ? place_path(place.slug) : place_path(place.id),
        rating: place.community_rating&.to_f,
        rating_count: place.community_rating_count.to_i,
        my_rating: review.rating,
        my_body: review.body
      }
    else
      render json: { error: review.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  private

  # Autocomplete relevance for the destination pickers. The old
  # `usage_count DESC, name ASC` collapses to *alphabetical* on a cold
  # catalog (every row usage 0), which surfaced entities like
  # "San Francisco AIDS Foundation" above the city itself. Rank instead:
  # exact match → destination kinds (city/town) → prefix match → usage.
  def autocomplete_rank(q)
    Arel.sql(
      Place.sanitize_sql_array([ <<~SQL.squish, q: q.downcase, prefix: "#{Place.sanitize_sql_like(q.downcase)}%" ])
        (lower(name) = :q OR lower(canonical_name) = :q) IS TRUE DESC,
        (kind IN ('city', 'town')) IS TRUE DESC,
        (lower(name) LIKE :prefix OR lower(canonical_name) LIKE :prefix) IS TRUE DESC,
        usage_count DESC,
        name ASC
      SQL
    )
  end
end
