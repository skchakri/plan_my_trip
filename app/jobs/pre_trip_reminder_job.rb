# Recurring entry point (config/recurring.yml) — emails every trip member a
# countdown reminder 7, 3, and 1 days before the trip starts, with a link to
# finalise the plan + packing list. Idempotent: each (offset + start_date) is
# recorded in Trip#reminders_sent so a re-run never double-sends, and moving the
# trip date re-arms the reminders (the key includes the date).
class PreTripReminderJob < ApplicationJob
  queue_as :default

  OFFSETS = [ 7, 3, 1 ].freeze

  def perform
    today = Date.current
    OFFSETS.each do |days|
      Trip.kept.where(start_date: today + days).find_each do |trip|
        key = "#{days}:#{trip.start_date.iso8601}"
        next if trip.reminders_sent[key].present?

        recipients(trip).each do |user|
          PreTripReminderMailer.reminder(trip, user, days).deliver_later
        end
        trip.update_column(:reminders_sent, trip.reminders_sent.merge(key => today.iso8601)) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  private

  # All members (owner included) who haven't opted out of email.
  def recipients(trip)
    User.where(id: trip.trip_memberships.select(:user_id), digest_optout_at: nil)
  end
end
