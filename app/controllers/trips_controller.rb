class TripsController < ApplicationController
  include MarkdownHelper

  before_action :set_trip, only: %i[show edit update destroy rename plan checklist copilot copilot_question copilot_response duplicate calendar wallet]

  def index
    @trips = policy_scope(Trip).ordered.includes(:owner).with_cover_data
  end

  def show
    authorize @trip
    @membership = @trip.trip_memberships.find_by(user: current_user)
    @rendered_body = render_markdown(@trip.body)
    @booking = BookingLinks.new(@trip, viewer: current_user)
    @known_traveler_interests = Person.known_interests_for(current_user)
  end

  def new
    # Single-page form replaced by the guided wizard (Trips::WizardController).
    redirect_to wizard_destination_path
  end

  def edit
    authorize @trip, :update?
    @trip.trails.build if @trip.trails.empty?
    @trip.people.build # one fresh row at the end for adding another traveler
    @known_traveler_interests = Person.known_interests_for(current_user)
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
      @known_traveler_interests = Person.known_interests_for(current_user)
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
    @days = @trip.trip_days.ordered.includes(
      activities: { comments: :author },
      suggestions: %i[author suggestion_votes]
    )
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
  # Optional ?mode=riddle switches the page into Riddles mode, which only
  # changes which pool we sample from when a traveler is picked.
  def copilot
    authorize @trip, :show?
    @people = @trip.people.ordered
    @mode = (params[:mode] == "riddle") ? "riddle" : "trivia"
  end

  # GET /trips/:id/copilot_question?person_id=X
  # Optional ?question_id=Y picks a specific question (used to continue a
  # chained word-problem after a correct answer); otherwise picks a random
  # unanswered chain-root for the person. ?mode=riddle scopes the pick to
  # the shared riddles pool instead of interest-matched trivia.
  def copilot_question
    authorize @trip, :show?
    @person = @trip.people.find(params[:person_id])
    @mode = (params[:mode] == "riddle") ? "riddle" : "trivia"
    @question =
      if params[:question_id].present? && (rec = TriviaQuestion.kept.find_by(id: params[:question_id]))
        TriviaPool.as_hash(rec)
      elsif @mode == "riddle"
        TriviaPool.pick_riddle_for(@person)
      else
        TriviaPool.pick_for(@person)
      end
    @playlist = RoadTripPlaylists.for_person(@person)
  end

  # POST /trips/:id/copilot_response — records a TriviaResponse so the same
  # question won't reappear for that person. Fired by copilot_question.html.erb
  # JS when the user taps an answer. Idempotent (uses upsert via uniqueness).
  def copilot_response
    authorize @trip, :show?
    person = @trip.people.find(params[:person_id])
    question = TriviaQuestion.find_by(id: params[:question_id])

    if question
      response = TriviaResponse.find_or_initialize_by(person: person, trivia_question: question)
      response.correct = ActiveModel::Type::Boolean.new.cast(params[:correct])
      response.answered_at = Time.current
      response.save
    end

    head :no_content
  end

  # PATCH /trips/:id/rename — per-user title via membership.custom_title
  # POST /trips/:id/duplicate — anyone with show access can clone into their
  # own trips list. Optionally shifts dates if new_start_date is given.
  def duplicate
    authorize @trip, :show?
    new_trip = TripDuplicator.new(
      source:         @trip,
      owner:          current_user,
      new_title:      params[:new_title].presence,
      new_start_date: params[:new_start_date].presence
    ).call
    redirect_to new_trip, notice: "Trip duplicated. Edit anything you'd like to change."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @trip, alert: "Couldn't duplicate: #{e.record.errors.full_messages.to_sentence}"
  end

  # GET /trips/:id/wallet — terse, paper-optimised survival sheet of
  # confirmations, addresses, and lat/lng coords. Save-as-PDF target.
  def wallet
    authorize @trip, :show?
    @days = @trip.trip_days.ordered.includes(:activities)
    @bookings = @trip.booking_claims.includes(documents_attachments: :blob)
    render layout: "wallet"
  end

  # GET /trips/:id/calendar.ics — auth-gated iCalendar feed for the owner
  # or any trip member to subscribe in Google/Apple/Outlook.
  def calendar
    authorize @trip, :show?
    send_data TripIcsBuilder.new(@trip).to_ics,
              type: "text/calendar; charset=utf-8",
              filename: "#{@trip.title.parameterize.presence || 'trip'}.ics",
              disposition: "inline"
  end

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
      trails_attributes: [ :id, :name, :alltrails_url, :notes, :position, :_destroy ],
      people_attributes: [ :id, :name, :age, :_destroy, { interests: [] } ]
    )
  end

  # Flat list of podcast-style scenes; each scene carries dialogue lines
  # that the reading-mode controller plays through with two voices.
  def build_reading_scenes(trip, days)
    PodcastScriptBuilder.new(
      trip: trip,
      days: days,
      viewer_name: current_user&.display_name
    ).build
  end
end
