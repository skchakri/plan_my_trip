class SuggestionsController < ApplicationController
  before_action :set_trip_day

  def create
    @suggestion = @trip_day.suggestions.build(suggestion_params.merge(author: current_user))
    authorize @suggestion, :create?

    if @suggestion.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("day-#{@trip_day.id}-suggestions",
                                partial: "suggestions/suggestion", locals: { suggestion: @suggestion }),
            turbo_stream.replace("day-#{@trip_day.id}-suggestion-form",
                                 partial: "suggestions/form",
                                 locals: { trip: @trip, trip_day: @trip_day, suggestion: @trip_day.suggestions.build })
          ]
        end
        format.html { redirect_to plan_trip_path(@trip, anchor: "day-#{@trip_day.id}") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "day-#{@trip_day.id}-suggestion-form",
            partial: "suggestions/form",
            locals: { trip: @trip, trip_day: @trip_day, suggestion: @suggestion }
          ), status: :unprocessable_entity
        end
        format.html { redirect_to plan_trip_path(@trip), alert: @suggestion.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    suggestion = @trip_day.suggestions.find(params[:id])
    authorize suggestion, :destroy?
    suggestion.discard

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("suggestion-#{suggestion.id}") }
      format.html { redirect_to plan_trip_path(@trip) }
    end
  end

  # POST /trips/:trip_id/days/:day_id/suggestions/:id/vote
  def vote
    suggestion = @trip_day.suggestions.find(params[:id])
    authorize suggestion, :vote?
    vote = suggestion.suggestion_votes.find_or_initialize_by(user: current_user)
    if vote.persisted?
      vote.destroy
    else
      vote.save!
    end
    suggestion = Suggestion.find(suggestion.id) # reload with computed vote_count
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "suggestion-#{suggestion.id}",
          partial: "suggestions/suggestion", locals: { suggestion: suggestion }
        )
      end
      format.html { redirect_to plan_trip_path(@trip) }
    end
  end

  private

  def set_trip_day
    @trip_day = TripDay.joins(:trip).where(trips: { discarded_at: nil }).find(params[:trip_day_id])
    @trip     = @trip_day.trip
  end

  def suggestion_params
    params.require(:suggestion).permit(:title, :url, :notes)
  end
end
