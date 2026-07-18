require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owner")
    @friend = User.create!(email: "f-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Friend")
    @stranger = User.create!(email: "s-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Stranger")

    @trip = @owner.owned_trips.create!(
      title: "Vegas",
      start_date: Date.current,
      end_date: Date.current + 2
    )
    @trip.trip_memberships.create!(user: @friend, role: "member", accepted_at: Time.current)

    @day = @trip.trip_days.create!(label: "day-1", title: "Drive", accent: "blue", position: 1)
    @activity = @day.activities.create!(title: "Buc-ee's", position: 1)
  end

  test "trip member can post a comment" do
    sign_in_as(@friend)
    assert_difference -> { Comment.count }, +1 do
      post trip_activity_comments_path(@trip, @activity),
           params: { comment: { body: "Should we stop here?" } }
    end
    comment = Comment.last
    assert_equal @friend.id, comment.author_id
    assert_equal "Should we stop here?", comment.body
  end

  test "non-member cannot post a comment" do
    sign_in_as(@stranger)
    assert_no_difference -> { Comment.count } do
      post trip_activity_comments_path(@trip, @activity),
           params: { comment: { body: "Crashing your party" } }
    end
  end

  test "blank body is rejected" do
    sign_in_as(@friend)
    assert_no_difference -> { Comment.count } do
      post trip_activity_comments_path(@trip, @activity),
           params: { comment: { body: "" } }
    end
  end

  test "author can delete their own comment" do
    sign_in_as(@friend)
    comment = @activity.comments.create!(author: @friend, body: "oops")
    assert_difference -> { Comment.kept.count }, -1 do
      delete trip_activity_comment_path(@trip, @activity, comment)
    end
  end

  test "trip owner can delete any comment for moderation" do
    sign_in_as(@owner)
    comment = @activity.comments.create!(author: @friend, body: "spam")
    delete trip_activity_comment_path(@trip, @activity, comment)
    assert comment.reload.discarded?
  end

  test "another member cannot delete someone else's comment" do
    third = User.create!(email: "t-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Third")
    @trip.trip_memberships.create!(user: third, role: "member", accepted_at: Time.current)
    comment = @activity.comments.create!(author: @friend, body: "mine")

    sign_in_as(third)
    delete trip_activity_comment_path(@trip, @activity, comment)
    refute comment.reload.discarded?
  end

  test "author can edit their own comment" do
    sign_in_as(@friend)
    comment = @activity.comments.create!(author: @friend, body: "orignal typo")

    patch trip_activity_comment_path(@trip, @activity, comment),
          params: { comment: { body: "original, fixed" } }

    assert_response :success
    assert_equal "original, fixed", comment.reload.body
  end

  test "editing to a blank body is rejected" do
    sign_in_as(@friend)
    comment = @activity.comments.create!(author: @friend, body: "keep me")

    patch trip_activity_comment_path(@trip, @activity, comment),
          params: { comment: { body: "" } }

    assert_response :unprocessable_entity
    assert_equal "keep me", comment.reload.body
  end

  test "a member cannot edit someone else's comment (owner included)" do
    comment = @activity.comments.create!(author: @friend, body: "friend's words")

    sign_in_as(@owner) # owner may delete for moderation, but not edit
    patch trip_activity_comment_path(@trip, @activity, comment),
          params: { comment: { body: "putting words in your mouth" } }

    assert_response :redirect # Pundit failure is rescued to a redirect
    assert_equal "friend's words", comment.reload.body
  end

  test "edit form is reachable by the author" do
    sign_in_as(@friend)
    comment = @activity.comments.create!(author: @friend, body: "edit me")
    get edit_trip_activity_comment_path(@trip, @activity, comment)
    assert_response :success
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
