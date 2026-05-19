require "test_helper"
require "action_mailer/test_helper"

class DailyDigestJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @opted_in = User.create!(email: "in-#{SecureRandom.hex(4)}@test.example",  password: "password123", name: "In")
    @opted_out = User.create!(email: "out-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Out", digest_optout_at: 1.day.ago)
    @no_unread = User.create!(email: "nu-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "NoUnread")
    @stale = User.create!(email: "st-#{SecureRandom.hex(4)}@test.example",     password: "password123", name: "Stale")

    Notification.create!(recipient: @opted_in, kind: "comment_posted", body: "fresh", created_at: 2.hours.ago)
    Notification.create!(recipient: @opted_out, kind: "comment_posted", body: "ignored")
    Notification.create!(recipient: @no_unread, kind: "comment_posted", body: "read", read_at: 1.hour.ago)
    Notification.create!(recipient: @stale, kind: "comment_posted", body: "too old", created_at: 3.days.ago)
  end

  test "delivers to users with fresh unread, skips opted-out / read-only / stale" do
    assert_enqueued_emails 1 do
      DailyDigestJob.new.perform
    end
  end

  test "stamps digest_last_sent_at after delivery" do
    DailyDigestJob.new.perform
    assert @opted_in.reload.digest_last_sent_at.present?
    assert_nil @opted_out.reload.digest_last_sent_at
  end

  test "is idempotent within the 12h window" do
    DailyDigestJob.new.perform
    assert_no_enqueued_emails do
      DailyDigestJob.new.perform
    end
  end
end

class DailyDigestMailerTest < ActionMailer::TestCase
  test "renders subject with the unread count" do
    user = User.create!(email: "m-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "M")
    Notification.create!(recipient: user, kind: "comment_posted", body: "Bob commented on Lunch (Vegas)")
    Notification.create!(recipient: user, kind: "comment_posted", body: "Carol commented on Drive (Vegas)")

    mail = DailyDigestMailer.daily(user)
    assert_equal "2 updates on your trips", mail.subject
    assert_equal [ user.email ], mail.to
    assert_includes mail.body.encoded, "Bob commented on Lunch"
  end

  test "renders nothing when opted out" do
    user = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "O", digest_optout_at: Time.current)
    Notification.create!(recipient: user, kind: "comment_posted", body: "ignored")
    mail = DailyDigestMailer.daily(user)
    assert_kind_of ActionMailer::Base::NullMail, mail.message
  end
end

class UserDigestPreferenceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "U")
  end

  test "receive_digest defaults true and toggles the timestamp" do
    assert @user.receive_digest
    @user.receive_digest = "0"
    assert @user.digest_optout_at.present?
    refute @user.receive_digest
  end

  test "flipping back to receive clears the opt-out timestamp" do
    @user.update!(digest_optout_at: 1.day.ago)
    @user.receive_digest = "1"
    assert_nil @user.digest_optout_at
  end
end
