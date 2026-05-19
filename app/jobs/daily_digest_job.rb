class DailyDigestJob < ApplicationJob
  queue_as :default

  # Recurring entry point — scoped narrowly so a stray bug can't accidentally
  # spam everyone. We only consider users who:
  #   - have at least one unread notification in the last 24h
  #   - have NOT opted out
  #   - have NOT already received a digest in the last 12h (idempotency
  #     under retries / accidental re-trigger)
  def perform
    eligible_users.find_each do |user|
      DailyDigestMailer.daily(user).deliver_later
      user.update_column(:digest_last_sent_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  private

  def eligible_users
    User
      .where(digest_optout_at: nil)
      .where("digest_last_sent_at IS NULL OR digest_last_sent_at < ?", 12.hours.ago)
      .joins(:notifications_received)
      .where(notifications: { read_at: nil })
      .where("notifications.created_at >= ?", 24.hours.ago)
      .distinct
  end
end
