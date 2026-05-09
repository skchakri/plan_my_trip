class TripsController < ApplicationController
  include MarkdownHelper

  before_action :set_trip, only: %i[show edit update destroy rename plan checklist copilot copilot_question]

  def index
    @trips = policy_scope(Trip).ordered.includes(:owner)
  end

  def show
    authorize @trip
    @membership = @trip.trip_memberships.find_by(user: current_user)
    @rendered_body = render_markdown(@trip.body)
    @booking = BookingLinks.new(@trip, viewer: current_user)
  end

  def new
    @trip = Trip.new(start_date: Date.current, end_date: Date.current + 3)
    @trip.trails.build
    authorize @trip
  end

  def edit
    authorize @trip, :update?
    @trip.trails.build if @trip.trails.empty?
  end

  def create
    @trip = current_user.owned_trips.new(trip_params)
    authorize @trip
    if @trip.save
      redirect_to @trip, notice: "Trip created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @trip
    if @trip.update(trip_params)
      redirect_to @trip, notice: "Trip updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @trip
    @trip.discard
    redirect_to trips_path, notice: "Trip removed."
  end

  # GET /trips/:id/plan — rich day-by-day Final plan with photos and deep-linked maps
  def plan
    authorize @trip, :show?
    @days = @trip.trip_days.ordered.includes(:activities)
    @rendered_body = render_markdown(@trip.body)
    @reading_scenes = build_reading_scenes(@trip, @days)
  end

  # GET /trips/:id/checklist — sectioned checklist (Before trip / By day / By activity)
  def checklist
    authorize @trip, :show?
    @items = @trip.checklist_items.ordered

    # group: scope -> section_key -> items
    @grouped = ChecklistItem::SCOPES.index_with do |scope_key|
      scoped = @items.select { |i| i.scope == scope_key }
      scoped.group_by(&:section_key)
    end

    @section_progress = ChecklistItem::SCOPES.index_with do |scope_key|
      scoped = @items.select { |i| i.scope == scope_key }
      { total: scoped.size, packed: scoped.count(&:packed) }
    end

    @day_options = @trip.checklist_items.for_day.distinct.pluck(:day_label).compact.sort
    @activity_options = @trip.checklist_items.for_activity.distinct.pluck(:activity_label).compact.sort
  end

  # GET /trips/:id/copilot — driving-time engagement screen (pick-a-traveler, then play)
  def copilot
    authorize @trip, :show?
    @people = @trip.people.ordered
  end

  # GET /trips/:id/copilot_question?person_id=X — pulls a question for the picked person
  def copilot_question
    authorize @trip, :show?
    @person = @trip.people.find(params[:person_id])
    @question = TriviaPool.pick_for(@person)
    @playlist = RoadTripPlaylists.for_person(@person)
  end

  # PATCH /trips/:id/rename — per-user title via membership.custom_title
  def rename
    authorize @trip, :rename?
    membership = @trip.trip_memberships.find_by!(user: current_user)
    new_title = params.require(:trip_membership).permit(:custom_title)[:custom_title]
    membership.update!(custom_title: new_title.presence)
    redirect_to @trip, notice: "Trip renamed for you."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:id])
  end

  def trip_params
    params.require(:trip).permit(
      :title, :destination, :origin, :start_date, :end_date, :traveler_count, :body,
      :pwa_plan_url, :pwa_packing_url,
      trails_attributes: [ :id, :name, :alltrails_url, :notes, :position, :_destroy ]
    )
  end

  # Flat list of "scenes" the reading-mode modal walks through. Each scene
  # has the photo, OSM tile array, and the text-to-speak for that step.
  def build_reading_scenes(trip, days)
    scenes = []

    if trip.excitement_pitch.present?
      scenes << {
        type: "intro",
        eyebrow: "Final plan",
        title: trip.title_for(current_user),
        text: trip.excitement_pitch,
        photo: nil, tiles: []
      }
    end

    days.each_with_index do |day, di|
      scenes << {
        type: "day",
        eyebrow: "Day #{di + 1}#{day.theme.present? ? " · #{day.theme}" : ''}",
        title: day.title,
        text: [day.summary.to_s, day.activities.map { |a| "#{a.time_label} #{a.title}" }.join(", then ")].reject(&:blank?).join(". "),
        photo: nil,
        tiles: []
      }

      day.activities.each do |a|
        map = a.map_tiles
        scenes << {
          type: "activity",
          eyebrow: "Day #{di + 1}#{a.time_label.present? ? " · #{a.time_label}" : ''}",
          title: a.title,
          location: a.location_name,
          address: a.address,
          photo: a.photo_url.presence,
          tiles: map ? map[:tiles] : [],
          pin_x_pct: map ? map[:pin_x_pct].round(2) : 50,
          pin_y_pct: map ? map[:pin_y_pct].round(2) : 50,
          maps_link: a.maps_link,
          text: [a.location_name, a.famous_for.presence, a.notes.to_s.gsub(/[*_`]/, ' ')].compact.reject(&:blank?).join('. ')
        }
      end
    end

    scenes
  end
end
