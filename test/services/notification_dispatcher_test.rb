require "test_helper"

class NotificationDispatcherTest < ActiveSupport::TestCase
  setup do
    @owner    = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owner")
    @friend   = User.create!(email: "f-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Friend")
    @third    = User.create!(email: "t-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Third")
    @trip     = @owner.owned_trips.create!(title: "Vegas", start_date: Date.current, end_date: Date.current + 2)
    @trip.trip_memberships.create!(user: @friend, role: "member", accepted_at: Time.current)
    @trip.trip_memberships.create!(user: @third,  role: "member", accepted_at: Time.current)
    @day      = @trip.trip_days.create!(label: "day-1", title: "Drive", accent: "blue", position: 1)
    @activity = @day.activities.create!(title: "Buc-ee's", position: 1)
  end

  test "comment_posted notifies every member except the author" do
    comment = @activity.comments.create!(author: @friend, body: "stopping here?")
    assert_difference -> { Notification.count }, +2 do
      NotificationDispatcher.comment_posted(comment)
    end
    recipients = Notification.last(2).map(&:recipient_id)
    assert_includes recipients, @owner.id
    assert_includes recipients, @third.id
    refute_includes recipients, @friend.id, "author shouldn't notify themselves"
  end

  test "comment_posted dispatch is idempotent on the same comment" do
    comment = @activity.comments.create!(author: @friend, body: "ping")
    NotificationDispatcher.comment_posted(comment)
    assert_no_difference -> { Notification.count } do
      NotificationDispatcher.comment_posted(comment)
    end
  end

  test "trip_share_accepted notifies the owner once" do
    new_user = User.create!(email: "n-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Newbie")
    membership = @trip.trip_memberships.create!(user: new_user, role: "member", accepted_at: Time.current)
    assert_difference -> { @owner.notifications_received.count }, +1 do
      NotificationDispatcher.trip_share_accepted(membership)
    end
    n = @owner.notifications_received.recent.first
    assert_equal "trip_share_accepted", n.kind
    assert_equal new_user.id, n.actor_id
  end

  test "trip_share_accepted no-ops when the membership is the owner themselves" do
    owner_membership = @trip.trip_memberships.find_by(user: @owner)
    assert_no_difference -> { Notification.count } do
      NotificationDispatcher.trip_share_accepted(owner_membership)
    end
  end
end

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "User")
    @other = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Other")
    @n1 = Notification.create!(recipient: @user, kind: "comment_posted", body: "ping 1")
    @n2 = Notification.create!(recipient: @user, kind: "comment_posted", body: "ping 2", read_at: 1.hour.ago)
    @other_notif = Notification.create!(recipient: @other, kind: "comment_posted", body: "not yours")
  end

  test "index shows only the current user's notifications" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    get notifications_path
    assert_response :success
    assert_includes response.body, "ping 1"
    assert_includes response.body, "ping 2"
    refute_includes response.body, "not yours"
  end

  test "read marks the notification and redirects to its url" do
    @n1.update!(url: "/trips")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    post read_notification_path(@n1)
    assert_response :redirect
    assert @n1.reload.read_at.present?
  end

  test "read_all clears unread for the current user only" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    post read_all_notifications_path
    assert_equal 0, @user.notifications_received.unread.count
    assert_equal 1, @other.notifications_received.unread.count, "other users' unread should not be affected"
  end
end
