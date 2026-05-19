class NotificationsController < ApplicationController
  # GET /notifications — dropdown content (turbo-frame target) + full page fallback.
  def index
    @notifications = current_user.notifications_received.recent.limit(50)
    @unread_count  = @notifications.count(&:unread?)
  end

  # POST /notifications/:id/read — mark one as read and redirect to its url.
  def read
    n = current_user.notifications_received.find(params[:id])
    n.mark_read!
    redirect_to(n.url.presence || notifications_path)
  end

  # POST /notifications/read_all — clear the inbox.
  def read_all
    current_user.notifications_received.unread.update_all(read_at: Time.current)
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.json { render json: { ok: true } }
    end
  end
end
