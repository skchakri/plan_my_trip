class TripsController < ApplicationController
  before_action :set_trip, only: %i[show edit update destroy rename]

  def index
    @trips = policy_scope(Trip).ordered.includes(:owner)
  end

  def show
    authorize @trip
    @membership = @trip.trip_memberships.find_by(user: current_user)
    @rendered_body = render_markdown(@trip.body)
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
      :title, :destination, :start_date, :end_date, :body,
      :pwa_plan_url, :pwa_packing_url,
      trails_attributes: [ :id, :name, :alltrails_url, :notes, :position, :_destroy ]
    )
  end

  def render_markdown(text)
    return "".html_safe if text.blank?
    renderer = Redcarpet::Render::HTML.new(escape_html: true, hard_wrap: true)
    Redcarpet::Markdown.new(renderer, autolink: true, fenced_code_blocks: true, tables: true).render(text).html_safe
  end
end
