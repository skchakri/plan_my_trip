class CommentsController < ApplicationController
  before_action :set_activity

  def create
    @comment = @activity.comments.build(comment_params.merge(author: current_user))
    authorize @comment, :create?

    if @comment.save
      NotificationDispatcher.comment_posted(@comment)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("activity-#{@activity.id}-comments",
                                partial: "comments/comment", locals: { comment: @comment }),
            turbo_stream.replace("activity-#{@activity.id}-comment-form",
                                 partial: "comments/form",
                                 locals: { trip: @trip, activity: @activity, comment: @activity.comments.build })
          ]
        end
        format.html { redirect_to plan_trip_path(@trip, anchor: "activity-#{@activity.id}") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "activity-#{@activity.id}-comment-form",
            partial: "comments/form",
            locals: { trip: @trip, activity: @activity, comment: @comment }
          ), status: :unprocessable_entity
        end
        format.html { redirect_to plan_trip_path(@trip), alert: @comment.errors.full_messages.to_sentence }
      end
    end
  end

  # Cancel target for the inline editor — re-renders the read-only comment
  # body back into its turbo-frame.
  def show
    comment = @activity.comments.find(params[:id])
    authorize comment, :show?
    render partial: "comments/body_frame", locals: { comment: comment }
  end

  def edit
    comment = @activity.comments.find(params[:id])
    authorize comment, :update?
    render partial: "comments/edit_form", locals: { comment: comment }
  end

  def update
    comment = @activity.comments.find(params[:id])
    authorize comment, :update?

    if comment.update(comment_params)
      render partial: "comments/body_frame", locals: { comment: comment }
    else
      render partial: "comments/edit_form", locals: { comment: comment }, status: :unprocessable_entity
    end
  end

  def destroy
    comment = @activity.comments.find(params[:id])
    authorize comment, :destroy?
    comment.discard

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("comment-#{comment.id}") }
      format.html { redirect_to plan_trip_path(@trip) }
    end
  end

  private

  def set_activity
    @activity = Activity.joins(trip_day: :trip).find(params[:activity_id])
    @trip     = @activity.trip
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
