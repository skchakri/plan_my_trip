class TripsController < ApplicationController
  include MarkdownHelper

  before_action :set_trip, only: %i[show edit update destroy rename archive plan checklist copilot copilot_question copilot_response concierge duplicate calendar wallet printable rebuild skip_build edit_plan brief]
  before_action :set_owned_trip, only: %i[restore destroy_permanently]

  def index
    if params[:archived].present?
      @archived = true
      @trips = current_user.owned_trips.discarded.ordered.includes(:owner).with_cover_data
      render :archived
    else
      @trips = policy_scope(Trip).ordered.includes(:owner).with_cover_data
    end
  end

  def show
    authorize @trip
    # While BuildTripJob assembles the plan, show a lightweight "building" page
    # that streams in the finished trip via a Turbo refresh broadcast.
    return render("trips/building", layout: "application") if @trip.building? || @trip.build_failed?

    @membership = @trip.trip_memberships.find_by(user: current_user)
    @rendered_body = render_markdown(@trip.body)
    @booking = BookingLinks.new(@trip, viewer: current_user)
    @known_traveler_interests = Person.known_interests_for(current_user)
    @destination_country = Country.for_destination(@trip.destination)
  end

  # POST /trips/:id/rebuild — re-run the async assembler after a failed build.
  def rebuild
    authorize @trip, :update?
    if @trip.building?
      redirect_to @trip, notice: "Already building…"
    else
      @trip.update!(build_status: "building", build_error: nil)
      # Both jobs replay from the trip's persisted build_args.
      (@trip.day_trip? ? BuildDayTripJob : BuildTripJob).perform_later(@trip.id)
      redirect_to @trip, notice: "Rebuilding your plan…"
    end
  end

  # Escape hatch when the AI build keeps failing: flip the trip to "ready" with
  # whatever it already has so the user can fill in the plan by hand instead of
  # being stuck on the failure page.
  def skip_build
    authorize @trip, :update?
    @trip.update!(build_status: "ready", build_error: nil)
    redirect_to edit_trip_path(@trip), notice: "Started a blank plan — add your days and notes here."
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

  # PATCH /trips/:id/archive — remove a trip from the current user's dashboard.
  # The owner soft-deletes (discards) it for everyone — restorable from the
  # Archived view; a member just drops their own access (leaves the trip).
  def archive
    authorize @trip, :archive?
    if @trip.owner_id == current_user.id
      @trip.discard
      redirect_to trips_path, notice: "Trip archived. Restore it anytime from Archived."
    else
      title = @trip.title_for(current_user)
      @trip.trip_memberships.where(user: current_user).destroy_all
      redirect_to trips_path, notice: "Removed “#{title}” from your trips."
    end
  end

  # PATCH /trips/:id/restore — owner un-archives a discarded trip.
  def restore
    authorize @trip, :restore?
    @trip.undiscard
    redirect_to trips_path(archived: 1), notice: "Trip restored."
  end

  # DELETE /trips/:id/destroy_permanently — owner hard-deletes a discarded
  # trip and everything under it. Irreversible; only reachable from Archived.
  def destroy_permanently
    authorize @trip, :destroy_permanently?
    @trip.destroy
    redirect_to trips_path(archived: 1), notice: "Trip permanently deleted."
  end

  # GET /trips/:id/plan — rich day-by-day Final plan with photos and deep-linked maps
  def plan
    authorize @trip, :show?
    # Mirror #show: a trip that's still building (or failed) has no plan to
    # render yet — show the building page, which streams in via Turbo refresh
    # when BuildTripJob finishes. The "Final plan" link is on every trip card
    # regardless of build_status, so this path is reachable mid-build.
    return render("trips/building", layout: "application") if @trip.building? || @trip.build_failed?

    @days = @trip.trip_days.ordered.includes(
      activities: { comments: :author },
      suggestions: %i[author suggestion_votes]
    )
    @rendered_body = render_markdown(@trip.body)
    @reading_scenes = build_reading_scenes(@trip, @days)
  end

  # GET /trips/:id/edit_plan — structured day/activity editor (add, edit,
  # reorder, delete) for owners and editors. Replaces hand-editing markdown.
  def edit_plan
    authorize @trip, :update?
    @days = @trip.trip_days.ordered.includes(:activities)
  end

  # GET /trips/:id/brief — lazy turbo-frame target: an honest "trip snapshot"
  # (DestinationBrief, cached 30d). Loaded off the trip page so a cache miss
  # never blocks the page; the frame-timeout controller guards a slow call.
  def brief
    authorize @trip, :show?
    @brief = DestinationBrief.call(@trip.destination)
    render partial: "trips/brief", locals: { brief: @brief }, layout: false
  rescue StandardError => e
    # DestinationBrief self-rescues AI errors, but a cache-layer fault (e.g.
    # Redis blip) could still escape. Never let the lazy frame render a 500 —
    # the frame-timeout controller can't recover from an HTTP error response.
    Rails.logger.warn("[TripsController#brief] trip=#{@trip.id}: #{e.class}: #{e.message}")
    render partial: "trips/brief", locals: { brief: DestinationBrief::EMPTY }, layout: false
  end

  # GET /trips/:id/checklist — sectioned checklist (Before trip / By day / By activity)
  def checklist
    authorize @trip, :show?
    @items = @trip.checklist_items.kept.ordered

    # group: scope -> section_key -> items
    @grouped = ChecklistItem::SCOPES.index_with do |scope_key|
      scoped = @items.select { |i| i.scope == scope_key }
      scoped.group_by(&:section_key)
    end

    @section_progress = ChecklistItem::SCOPES.index_with do |scope_key|
      scoped = @items.select { |i| i.scope == scope_key }
      { total: scoped.size, packed: scoped.count(&:packed) }
    end

    @day_options = @trip.checklist_items.kept.for_day.distinct.pluck(:day_label).compact.sort
    @activity_options = @trip.checklist_items.kept.for_activity.distinct.pluck(:activity_label).compact.sort
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

  # POST /trips/:id/concierge — ask the Trip Concierge agent a free-text
  # question about this trip. Answers are grounded in the trip's own dossier
  # (TripAgent) and streamed back as a turbo-stream appended to the chat log.
  def concierge
    authorize @trip, :show?
    @question = params[:question].to_s.strip
    return head :bad_request if @question.blank?

    @answer = TripAgent.new(trip: @trip, user: current_user, question: @question).answer.text.presence ||
              "Sorry — I couldn't answer that just now. Try rephrasing, or check the trip details."

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @trip }
    end
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

  # GET /trips/:id/printable — full day-by-day itinerary in a clean, print- and
  # PDF-ready layout. Reuses the wallet print chrome ("Save as PDF" + @media
  # print). Distinct from #wallet, which is a bookings/addresses survival sheet.
  def printable
    authorize @trip, :show?
    return redirect_to(@trip) if @trip.building? || @trip.build_failed?

    @days = @trip.trip_days.ordered.includes(:activities)
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

  # Restore / permanent-delete act on discarded trips, which Trip.kept can't
  # see. Scope to the owner's trips — Discard adds no default scope, so this
  # still finds archived rows, and non-owners get a 404 rather than access.
  def set_owned_trip
    @trip = current_user.owned_trips.find(params[:id])
  end

  def trip_params
    params.require(:trip).permit(
      :title, :destination, :origin, :start_date, :end_date, :traveler_count, :body,
      :pace, :budget, :preferences, :transport_mode,
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
