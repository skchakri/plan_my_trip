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
  before_action :require_anchor,     only: %i[suggestions suggestions_results create idea_detail idea_more]

  # GET /day_trips/new — anchor + interests + date picker.
  def new
    @date = (params[:date].presence && (Date.parse(params[:date]) rescue nil)) || Date.current
    @anchor_label = params[:anchor_label].presence || current_user.home_label
    @anchor_lat   = params[:anchor_lat].presence  || current_user.home_lat&.to_f
    @anchor_lng   = params[:anchor_lng].presence  || current_user.home_lng&.to_f
    @radius_km    = (params[:radius_km].presence || current_user.default_radius_km || 80).to_i
    @interests    = params[:interests].present? ? Array(params[:interests]).map(&:to_s) : Array(current_user.default_interests)
  end

  # GET /day_trips/suggestions — page shell only. Renders instantly with the
  # ask bar + a lazy turbo-frame whose `src` points at #suggestions_results.
  # The slow NearbyIdeas research happens in that frame request, not here, so
  # the page never blocks on a multi-minute AI/web-search call.
  def suggestions
    load_suggestion_params

    # Optional "save as my home base" affordance: surface a flag the view
    # checks so the chip only appears when this differs from the saved one.
    @diff_from_home = current_user.home_base? &&
                      (current_user.home_lat.to_f.round(3) != @anchor_lat.round(3) ||
                       current_user.home_lng.to_f.round(3) != @anchor_lng.round(3))
  end

  # GET /day_trips/suggestions_results — the lazy turbo-frame body. Runs the
  # NearbyIdeas research (server-side cache: 7 days) and renders the cards
  # grid + build form. Loaded by the frame on the suggestions page, so the
  # user sees a skeleton until this resolves instead of a frozen page.
  def suggestions_results
    load_suggestion_params

    @ideas = NearbyIdeas.call(
      anchor_label: @anchor_label,
      lat: @anchor_lat,
      lng: @anchor_lng,
      radius_km: @radius_km,
      interests: @interests,
      user_query: @user_query,
      trip_date: @date.iso8601
    )

    render partial: "day_trips/results", layout: false
  rescue StandardError => e
    # The lazy frame must always return a renderable 200. A 500 here paints the
    # Rails error page *inside* the frame and fires turbo:frame-load, which
    # clears the frame-timeout timer so the retry card never appears. Degrade to
    # the existing empty-ideas state instead. (NearbyIdeas self-rescues to [];
    # this catches a cache-layer fault around it.)
    Rails.logger.warn("[DayTripsController#suggestions_results] #{e.class}: #{e.message}")
    @ideas = []
    render partial: "day_trips/results", layout: false
  end

  # GET /day_trips/idea_detail — renders a single idea's full details inside
  # the day-trip-idea-modal turbo-frame. Re-runs NearbyIdeas (cache hit), then
  # picks the idea by slug. Kept independent of any persistent record so the
  # LLM-only ideas (not yet seeded to Place) can still open in a modal.
  def idea_detail
    @idea = find_idea_from_params
    if @idea.nil?
      render plain: "Not found", status: :not_found
    else
      render layout: false
    end
  end

  # GET /day_trips/idea_more — the click-to-load "More about this place"
  # turbo-frame inside the idea modal. Runs HighlightDetail (30-day cached AI)
  # only when the user asks for it, so the modal itself stays instant.
  def idea_more
    @idea = find_idea_from_params
    return render(plain: "Not found", status: :not_found) if @idea.nil?

    @detail = HighlightDetail.call(
      destination: @anchor_label.presence || "the local area",
      name: @idea.name,
      category: @idea.category,
      summary: @idea.summary
    )
    render layout: false
  end

  # POST /day_trips — persist a day-trip *shell* (status: building) and hand the
  # slow assembly (DayPlanBuilder + per-stop image lookups) to BuildDayTripJob.
  # The user is redirected to the trip page right away, which streams in the plan
  # when the job broadcasts a Turbo refresh. Mirrors the multi-day wizard.
  def create
    # Same account-side spend cap as the multi-day wizard — a day plan fans out
    # DayPlanBuilder + per-stop narrations, so it isn't a free path around it.
    quota = BuildQuota.new(current_user)
    if quota.exceeded?
      redirect_to(day_trips_new_path, alert: quota.message) and return
    end

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
      build_status: "building",
      build_args: {
        "selected_slugs" => selected_slugs,
        "q" => params[:q].to_s.strip,
        "depart_time" => params[:depart_time].to_s,
        "return_time" => params[:return_time].to_s
      }
    )
    authorize trip, :create?

    if trip.save
      BuildDayTripJob.perform_later(trip.id)
      redirect_to trip, notice: "Building your day plan — this takes a moment. It'll fill in here automatically."
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

  # Shared by #idea_detail and #idea_more: re-runs NearbyIdeas (cache hit for
  # any anchor the user is already browsing) and picks one idea by slug. Kept
  # independent of any persistent record so LLM-only ideas (not yet seeded to
  # Place) still open in the modal.
  def find_idea_from_params
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
    ideas.find { |i| i.slug == slug }
  end

  def load_user_defaults
    @user_has_home_base = current_user.home_base?
  end

  # Shared by #suggestions (shell) and #suggestions_results (frame body) so
  # both agree on the anchor/interests/query that key the NearbyIdeas cache.
  def load_suggestion_params
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
end
