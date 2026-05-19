# Day-trip flow: home base (or any anchor) + interests + radius → AI-curated
# nearby ideas → pick a handful → one-day Trip persisted with `day_trip: true`.
#
# Reuses the same TripDay + Activity + ChecklistItem persistence as the
# multi-day wizard so /trips/:id/show works unchanged. Multi-day pieces
# (lodging, before-trip packing) are suppressed at render time when
# `trip.day_trip?`.
class DayTripsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_user_defaults, only: %i[new suggestions]
  before_action :require_anchor,     only: %i[suggestions create idea_detail]

  # GET /day_trips/new — anchor + interests + date picker.
  def new
    @date = (params[:date].presence && (Date.parse(params[:date]) rescue nil)) || Date.current
    @anchor_label = params[:anchor_label].presence || current_user.home_label
    @anchor_lat   = params[:anchor_lat].presence  || current_user.home_lat&.to_f
    @anchor_lng   = params[:anchor_lng].presence  || current_user.home_lng&.to_f
    @radius_km    = (params[:radius_km].presence || current_user.default_radius_km || 80).to_i
    @interests    = params[:interests].present? ? Array(params[:interests]).map(&:to_s) : Array(current_user.default_interests)
  end

  # GET /day_trips/suggestions — lazy turbo-frame body. Renders the
  # NearbyIdeas results once available (server-side cache: 7 days).
  def suggestions
    @date         = (Date.parse(params[:date].to_s) rescue Date.current)
    @anchor_label = params[:anchor_label].to_s.strip
    @anchor_lat   = params[:anchor_lat].to_f
    @anchor_lng   = params[:anchor_lng].to_f
    @radius_km    = params[:radius_km].to_i.nonzero? || 80
    @interests    = Array(params[:interests]).map(&:to_s).reject(&:blank?)
    # `q` is the free-form ask box on the suggestions page — voice or typed
    # ("any waterfalls nearby?", "events this weekend"). When present, it
    # gets its own cache slot via NearbyIdeas#cache_key.
    @user_query   = params[:q].to_s.strip

    @ideas = NearbyIdeas.call(
      anchor_label: @anchor_label,
      lat: @anchor_lat,
      lng: @anchor_lng,
      radius_km: @radius_km,
      interests: @interests,
      user_query: @user_query,
      trip_date: @date.iso8601
    )

    # Optional "save as my home base" affordance: surface a flag the view
    # checks so the chip only appears when this differs from the saved one.
    @diff_from_home = current_user.home_base? &&
                      (current_user.home_lat.to_f.round(3) != @anchor_lat.round(3) ||
                       current_user.home_lng.to_f.round(3) != @anchor_lng.round(3))
  end

  # GET /day_trips/idea_detail — renders a single idea's full details inside
  # the day-trip-idea-modal turbo-frame. Re-runs NearbyIdeas (cache hit), then
  # picks the idea by slug. Kept independent of any persistent record so the
  # LLM-only ideas (not yet seeded to Place) can still open in a modal.
  def idea_detail
    @date         = (Date.parse(params[:date].to_s) rescue Date.current)
    @anchor_label = params[:anchor_label].to_s.strip
    @anchor_lat   = params[:anchor_lat].to_f
    @anchor_lng   = params[:anchor_lng].to_f
    @radius_km    = params[:radius_km].to_i.nonzero? || 80
    @interests    = Array(params[:interests]).map(&:to_s).reject(&:blank?)
    @user_query   = params[:q].to_s.strip
    slug          = params[:slug].to_s

    ideas = NearbyIdeas.call(
      anchor_label: @anchor_label,
      lat: @anchor_lat, lng: @anchor_lng,
      radius_km: @radius_km, interests: @interests,
      user_query: @user_query, trip_date: @date.iso8601
    )

    @idea = ideas.find { |i| i.slug == slug }
    if @idea.nil?
      render plain: "Not found", status: :not_found
    else
      render layout: false
    end
  end

  # POST /day_trips — persist the chosen ideas as a same-day Trip.
  def create
    @date         = (Date.parse(params[:date].to_s) rescue Date.current)
    @anchor_label = params[:anchor_label].to_s.strip.presence || "Home"
    @anchor_lat   = params[:anchor_lat].to_f
    @anchor_lng   = params[:anchor_lng].to_f
    @radius_km    = params[:radius_km].to_i.nonzero? || 80
    @interests    = Array(params[:interests]).map(&:to_s).reject(&:blank?)
    selected_slugs = Array(params[:selected_slugs]).map(&:to_s).reject(&:blank?).uniq

    if selected_slugs.empty?
      redirect_to(
        day_trip_suggestions_path(
          date: @date, anchor_label: @anchor_label,
          anchor_lat: @anchor_lat, anchor_lng: @anchor_lng,
          radius_km: @radius_km, interests: @interests
        ),
        alert: "Pick at least one spot to build a day plan."
      ) and return
    end

    all_ideas = NearbyIdeas.call(
      anchor_label: @anchor_label, lat: @anchor_lat, lng: @anchor_lng,
      radius_km: @radius_km, interests: @interests,
      user_query: params[:q].to_s.strip, trip_date: @date.iso8601
    )
    chosen = all_ideas.select { |i| selected_slugs.include?(i.slug) }

    structure = DayPlanBuilder.call(
      anchor_label: @anchor_label,
      anchor_lat: @anchor_lat,
      anchor_lng: @anchor_lng,
      date: @date,
      depart_time: params[:depart_time].presence || "8:00 AM",
      return_time: params[:return_time].presence || "7:00 PM",
      interests: @interests,
      ideas: chosen.map(&:to_h),
      people: []
    )

    trip = current_user.owned_trips.new(
      title: derived_title,
      origin: @anchor_label,
      destination: "Day trip · #{@anchor_label}",
      start_date: @date,
      end_date: @date,
      traveler_count: 2,
      transport_mode: "own_car",
      day_trip: true,
      anchor_lat: @anchor_lat,
      anchor_lng: @anchor_lng,
      anchor_label: @anchor_label,
      max_radius_km: @radius_km,
      interests: @interests,
      excitement_pitch: structure["excitement_pitch"].presence
    )
    authorize trip, :create?

    build_days_and_activities(trip, structure, chosen)
    build_checklist(trip, structure)

    if trip.save
      redirect_to trip, notice: "Day trip planned — #{trip.trip_days.first&.activities&.size.to_i} stops, drive there & back."
    else
      flash.now[:alert] = trip.errors.full_messages.to_sentence
      redirect_to day_trips_new_path(
        date: @date, anchor_label: @anchor_label,
        anchor_lat: @anchor_lat, anchor_lng: @anchor_lng,
        radius_km: @radius_km, interests: @interests
      )
    end
  end

  # POST /day_trips/save_home_base — quick chip on the suggestions page
  # so the user can persist a non-default anchor as their home base.
  def save_home_base
    current_user.update(
      home_city: params[:anchor_label].presence,
      home_lat: params[:anchor_lat].presence,
      home_lng: params[:anchor_lng].presence
    )
    redirect_back fallback_location: day_trips_new_path, notice: "Saved as your home base."
  end

  private

  def load_user_defaults
    @user_has_home_base = current_user.home_base?
  end

  def require_anchor
    lat = params[:anchor_lat].to_f
    lng = params[:anchor_lng].to_f
    return if lat.abs.positive? && lng.abs.positive?
    redirect_to day_trips_new_path, alert: "Set a home base (or pick an anchor) first."
  end

  def derived_title
    base = @anchor_label.presence || "Home"
    "Day trip · #{base} · #{@date.strftime('%b %-d')}"
  end

  # Same shape as Trips::WizardController#build_days_and_activities but
  # trimmed to one day. Reuses Places::Seeder so cards get photos.
  def build_days_and_activities(trip, structure, chosen_ideas)
    photo_by_name = chosen_ideas.each_with_object({}) do |idea, acc|
      key = idea.name.to_s.downcase.strip
      acc[key] = idea.image_url if key.present? && idea.image_url.present?
    end
    used_photos = photo_by_name.values.compact.to_set
    seeded_places = {}

    Array(structure["days"]).first(1).each_with_index do |day_data, di|
      day = trip.trip_days.build(
        label: day_data["label"].presence || "day-1",
        title: day_data["title"].presence || "Day trip",
        theme: day_data["theme"],
        summary: day_data["summary"],
        accent: day_data["accent"],
        date: @date,
        position: di
      )

      Array(day_data["activities"]).each_with_index do |a, ai|
        name_key = a["location_name"].to_s.downcase.strip
        title_key = a["title"].to_s.downcase.strip

        place = nil
        if a["location_name"].to_s.strip.present? && a["latitude"].present? && a["longitude"].present?
          key = "#{name_key}|#{a["latitude"].to_f.round(3)}|#{a["longitude"].to_f.round(3)}"
          place = seeded_places[key] ||= Places::Seeder.call(
            name: a["location_name"],
            lat: a["latitude"],
            lng: a["longitude"],
            kind: place_kind_for(a["group_label"]),
            image_query: a["image_query"],
            famous_for: a["famous_for"],
            user: current_user
          )
        end

        photo = photo_by_name[name_key] || photo_by_name[title_key]
        if photo.blank? && place&.image_url.present? && !used_photos.include?(place.image_url)
          photo = place.image_url
        end
        used_photos << photo if photo.present?

        day.activities.build(
          time_label: a["time_label"],
          title: a["title"].presence || "Activity",
          location_name: a["location_name"],
          address: a["address"],
          latitude: a["latitude"],
          longitude: a["longitude"],
          famous_for: a["famous_for"],
          notes: a["notes"],
          group_label: a["group_label"],
          photo_url: photo,
          guide_script: a["guide_script"].to_s.strip.presence,
          place: place,
          position: ai
        )
      end
    end
  end

  def build_checklist(trip, structure)
    Array(structure.dig("checklist", "before_trip")).each_with_index do |item, i|
      next if item["title"].blank?
      trip.checklist_items.build(
        scope: "before_trip",
        title: item["title"],
        category: item["category"].presence || "Day-of",
        position: i
      )
    end
  end

  GROUP_LABEL_TO_PLACE_KIND = {
    "meal"      => "restaurant",
    "lunch"     => "restaurant",
    "dinner"    => "restaurant",
    "coffee"    => "cafe",
    "breakfast" => "cafe",
    "hike"      => "trail",
    "trail"     => "trail",
    "drive"     => "drive_segment",
    "viewpoint" => "viewpoint",
    "overlook"  => "overlook",
    "park"      => "park",
    "museum"    => "museum",
    "historic"  => "historic",
    "family"    => "park"
  }.freeze
  private_constant :GROUP_LABEL_TO_PLACE_KIND

  def place_kind_for(group_label)
    return nil if group_label.blank?
    GROUP_LABEL_TO_PLACE_KIND[group_label.to_s.strip.downcase]
  end
end
