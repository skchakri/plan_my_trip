require "test_helper"

class PreTripReminderJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @member = User.create!(email: "m-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Mo")
  end

  def trip_starting_in(days)
    t = @owner.owned_trips.create!(
      title: "Zion", destination: "Springdale",
      start_date: Date.current + days, end_date: Date.current + days + 2
    )
    t.trip_memberships.create!(user: @member, role: "member", accepted_at: Time.current)
    t
  end

  test "emails every member of a trip starting in 7 days" do
    trip_starting_in(7)
    # owner + member = 2 recipients
    assert_enqueued_emails 2 do
      PreTripReminderJob.perform_now
    end
  end

  test "does not double-send on a second run" do
    trip_starting_in(3)
    assert_enqueued_emails 2 do
      PreTripReminderJob.perform_now
    end
    assert_no_enqueued_emails do
      PreTripReminderJob.perform_now
    end
  end

  test "ignores trips outside the 7/3/1 windows" do
    trip_starting_in(5)
    assert_no_enqueued_emails do
      PreTripReminderJob.perform_now
    end
  end

  test "skips members who opted out of email" do
    trip_starting_in(1)
    @member.update_column(:digest_optout_at, Time.current)
    # only the owner gets it
    assert_enqueued_emails 1 do
      PreTripReminderJob.perform_now
    end
  end
end
