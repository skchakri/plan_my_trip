class TripsController < ApplicationController
  include MarkdownHelper

  before_action :set_trip, only: %i[show edit update destroy rename archive plan checklist copilot copilot_question copilot_response concierge concierge_edit duplicate calendar wallet printable rebuild skip_build edit_plan brief road_trip_stats weather day_weather stops_kml]
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
    previous_start = @trip.start_date
    body_was = @trip.body

    if @trip.update(trip_params)
      redirect_to @trip, notice: reconcile_plan_after_edit(previous_start, body_was)
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

  # GET /trips/:id/road_trip_stats — lazy turbo-frame target: per-leg mileage,
  # drive time, and estimated fuel cost for own-car trips (RoadTripEstimator,
  # cached). Loaded off the trip page so OSRM/EIA latency never blocks it; the
  # frame-timeout controller guards a slow call. Renders an empty state (the
  # partial with stats: nil) when there's nothing to estimate. ?detail=1 asks
  # for the per-leg breakdown used on the Drive Co-Pilot.
  def road_trip_stats
    authorize @trip, :show?
    # RoadTripEstimator self-rescues network/parse faults, but a cache-layer
    # blip could still escape — never let the lazy frame return a 500, which
    # the frame-timeout controller can't recover from. Guarding only the
    # estimator call (not #authorize) keeps Pundit denials a real redirect.
    @stats =
      begin
        RoadTripEstimator.call(@trip, viewer: current_user)
      rescue StandardError => e
        Rails.logger.warn("[TripsController#road_trip_stats] trip=#{@trip.id}: #{e.class}: #{e.message}")
        nil
      end
    render partial: "trips/road_trip_stats",
           locals: { stats: @stats, detail: params[:detail].present? },
           layout: false
  end

  # GET /trips/:id/weather — lazy turbo-frame target: per-day weather strip
  # for the trip's dates (WeatherReport / Open-Meteo, cached). Loaded off the
  # trip page so geocode + API latency never blocks it; a nil report renders
  # an empty frame. Guarded like the other lazy frames — never a 500.
  def weather
    authorize @trip, :show?
    report =
      begin
        WeatherReport.call(
          destination: @trip.destination,
          start_date: @trip.start_date,
          end_date: @trip.end_date
        )
      rescue StandardError => e
        Rails.logger.warn("[TripsController#weather] trip=#{@trip.id}: #{e.class}: #{e.message}")
        nil
      end
    render partial: "trips/weather",
           locals: { report: report, place: @trip.destination },
           layout: false
  end

  # GET /trips/:id/day_weather/:day_id — lazy day-header chip: ONE day's
  # weather at that day's own coordinates (a road trip's days happen in
  # different places, so the trip-level destination would be wrong for most
  # of them). Same guarantees as #weather: cached WeatherReport (3h TTL for
  # live forecasts, so the chip self-refreshes on the day), never a 500,
  # nil → empty frame.
  def day_weather
    authorize @trip, :show?
    day = @trip.trip_days.find_by(id: params[:day_id])
    report =
      begin
        if day&.date
          lat, lng = day.representative_coords
          WeatherReport.call(
            destination: @trip.destination,
            start_date: day.date, end_date: day.date,
            lat: lat, lng: lng
          )
        end
      rescue StandardError => e
        Rails.logger.warn("[TripsController#day_weather] trip=#{@trip.id} day=#{params[:day_id]}: #{e.class}: #{e.message}")
        nil
      end
    render partial: "trips/day_weather_chip", locals: { day: day, report: report }, layout: false
  end

  # GET /trips/:id/stops.kml — every mapped stop as a KML file. Google gives
  # websites no way to push pins into the Maps app, so this is the hand-off:
  # import at mymaps.google.com and the map (all stops, layered by day)
  # appears in Google Maps under Saved → Maps.
  def stops_kml
    authorize @trip, :show?
    send_data TripKmlBuilder.new(@trip).to_kml,
              type: "application/vnd.google-earth.kml+xml; charset=utf-8",
              filename: "#{@trip.title.parameterize.presence || 'trip'}-stops.kml",
              disposition: "attachment"
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

    exchange = TripAgent.new(trip: @trip, user: current_user, question: @question).converse
    @answer = exchange.reply.presence ||
              "Sorry — I couldn't answer that just now. Try rephrasing, or check the trip details."
    # Only surface Apply buttons to a user who may actually edit the plan; a
    # viewer still gets the conversational reply.
    @proposed_edits = @trip.editable_by?(current_user) ? exchange.edits : []

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @trip }
    end
  end

  # Apply ONE concierge-proposed edit. The LLM never reaches this path — it's a
  # normal authenticated, CSRF-protected, editor-only POST that dispatches to
  # the TripEditor mutation core. Params are an allowlisted (action, fields)
  # tuple; TripEditor re-authorizes and re-validates.
  def concierge_edit
    authorize @trip, :update?
    action_name = params[:edit_action].to_s
    fields = TripAgent::EDIT_FIELDS[action_name]
    return head :bad_request unless fields

    # Pass every keyword the action declares (nil when absent) so a missing
    # optional field never becomes a missing-keyword ArgumentError — TripEditor
    # validates required values itself and returns a friendly Result.
    editor = TripEditor.new(trip: @trip, user: current_user)
    kwargs = fields.index_with { |f| params[f].presence }
    kwargs[:day_number] = params[:day_number].to_i if kwargs.key?(:day_number)
    @edit_result = editor.public_send(action_name, **kwargs)

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
    return redirect_to(@trip) if @trip.building? || @trip.build_failed?

    @days = @trip.trip_days.ordered.includes(:activities)
    @bookings = @trip.booking_claims.includes(documents_attachments: :blob)
    @reservations = @trip.reservations.parsed
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

  # After a successful #update, bring the built plan back in line with the
  # edited trip — or, when it can't be, say so instead of silently leaving a
  # plan that describes a different trip.
  #
  #   • Dates moved  → slide every TripDay by the same delta (deterministic,
  #                    free) and re-derive the markdown body from the rows.
  #   • Destination / travelers / style changed, or the day count no longer
  #     spans the range → flag the plan stale; trips/show then offers Rebuild.
  #
  # Returns the flash notice.
  def reconcile_plan_after_edit(previous_start, body_was)
    return "Trip updated." unless @trip.built_plan?

    parts = [ "Trip updated." ]

    delta = previous_start && @trip.start_date ? (@trip.start_date - previous_start).to_i : 0
    if delta != 0 && @trip.shift_plan_dates!(delta).positive?
      # Skip when the edit also rewrote the markdown by hand — BodySync
      # regenerates `body` from the rows and would throw that away.
      Trips::BodySync.call(@trip) if @trip.body == body_was
      parts << "Moved the day-by-day plan #{helpers.pluralize(delta.abs, 'day')} #{delta.positive? ? 'later' : 'earlier'}."
    end

    changed = @trip.previous_changes.keys & Trip::PLAN_INPUT_ATTRIBUTES
    if changed.any? || @trip.plan_day_count_mismatch?
      @trip.mark_plan_stale!
      parts << "The day-by-day plan was built for the old details — rebuild it to regenerate."
    end

    parts.join(" ")
  end

  def trip_params
    params.require(:trip).permit(
      :title, :destination, :origin, :start_date, :end_date, :traveler_count, :body,
      :pace, :budget, :preferences, :transport_mode, :vehicle_mpg,
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
