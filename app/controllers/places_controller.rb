class PlacesController < ApplicationController
  # JSON autocomplete for any input that lets a user pick a known place
  # from the shared catalog. Currently called from the wizard's
  # destination input.
  def search
    q = params[:q].to_s.strip
    limit = params[:limit].to_i
    limit = 8 if limit <= 0 || limit > 25
    return render(json: { results: [] }) if q.length < 2

    pattern = "%#{q.downcase}%"
    matches = Place.kept
                   .where("lower(name) LIKE ? OR lower(canonical_name) LIKE ?", pattern, pattern)
                   .order(usage_count: :desc, name: :asc)
                   .limit(limit)

    render json: {
      results: matches.map do |p|
        {
          id: p.id,
          name: p.name,
          canonical_name: p.canonical_name,
          kind: p.kind,
          image_url: p.image_url,
          lat: p.latitude&.to_f,
          lng: p.longitude&.to_f,
          usage_count: p.usage_count,
          summary: p.description.to_s[0, 140]
        }
      end
    }
  end

  def show
    @place = Place.kept.find(params[:id])
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
  end
end
