module Admin
  # Inbox for the public contact form — the in-app counterpart to the
  # "[Wanderply contact]" emails, so triage doesn't depend on Gmail.
  class ContactMessagesController < BaseController
    FILTERS = %w[inbox unread replied spam].freeze

    before_action :set_message, only: %i[show reply spam destroy]

    def index
      @filter = params[:filter].presence_in(FILTERS) || "inbox"
      scope = case @filter
      when "unread"  then ContactMessage.unread
      when "replied" then ContactMessage.ham.where.not(replied_at: nil)
      when "spam"    then ContactMessage.where(spam: true)
      else ContactMessage.ham
      end
      if params[:q].present?
        like = "%#{ContactMessage.sanitize_sql_like(params[:q].to_s.downcase)}%"
        scope = scope.where("LOWER(name) LIKE :q OR LOWER(email) LIKE :q OR LOWER(body) LIKE :q", q: like)
      end
      @messages = scope.recent.limit(200)
      @counts = {
        "inbox"   => ContactMessage.ham.count,
        "unread"  => ContactMessage.unread.count,
        "replied" => ContactMessage.ham.where.not(replied_at: nil).count,
        "spam"    => ContactMessage.where(spam: true).count
      }
    end

    def show
      @message.mark_read!
    end

    def reply
      body = params.require(:reply).permit(:body)[:body].to_s.strip
      if body.blank?
        redirect_to admin_contact_message_path(@message), alert: "Reply was empty." and return
      end

      ContactMailer.reply(@message, body, current_user).deliver_later
      @message.update!(replied_at: Time.current, reply_body: body, read_at: @message.read_at || Time.current)
      redirect_to admin_contact_message_path(@message), notice: "Reply sent to #{@message.email}."
    end

    def spam
      flag = params[:flag] != "false"
      @message.mark_spam!(flag)
      redirect_to admin_contact_message_path(@message), notice: flag ? "Marked as spam." : "Marked as not spam."
    end

    def destroy
      @message.destroy!
      redirect_to admin_contact_messages_path, notice: "Message deleted."
    end

    private

    def set_message
      @message = ContactMessage.find(params[:id])
    end
  end
end
