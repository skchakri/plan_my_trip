require "test_helper"

class MentionParserTest < ActiveSupport::TestCase
  setup do
    @owner    = User.create!(email: "alice-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Alice Wonderland")
    @bob      = User.create!(email: "bob-#{SecureRandom.hex(4)}@test.example",   password: "password123", name: "Bob")
    @stranger = User.create!(email: "s-#{SecureRandom.hex(4)}@test.example",     password: "password123", name: "Stranger")

    @trip = @owner.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 1)
    @trip.trip_memberships.create!(user: @bob, role: "member", accepted_at: Time.current)
    @trip.people.create!(name: "Carol", position: 1)

    @parser = MentionParser.new(@trip)
  end

  test "tokens_in extracts unique lowercased @-tokens" do
    assert_equal [ "alice", "bob" ], @parser.tokens_in("@Alice ping @bob, hi @Alice!")
  end

  test "does not treat email addresses as mentions" do
    assert_equal [], @parser.tokens_in("write to alice@example.com")
  end

  test "mentioned_users only returns trip-member Users matched by name" do
    users = @parser.mentioned_users("hey @alice and @bob, what about @stranger?")
    ids = users.map(&:id)
    assert_includes ids, @owner.id
    assert_includes ids, @bob.id
    refute_includes ids, @stranger.id, "non-members must not be mentionable"
  end

  test "render_html wraps known mentions and html-escapes everything else" do
    html = @parser.render_html("<script>@alice you ok?</script>")
    assert html.html_safe?
    assert_includes html, "&lt;script&gt;"
    assert_match(/bg-amber-500\/20[^"]*">@alice/, html)
  end

  test "unknown @tokens are left as plain text (escaped)" do
    html = @parser.render_html("ping @ghost").to_s
    assert_match "@ghost", html
    refute_match(/bg-amber-500/, html)
  end
end

class MentionDispatcherIntegrationTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owner")
    @bob   = User.create!(email: "b-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Bob")
    @carol = User.create!(email: "c-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Carol")
    @trip  = @owner.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 2)
    @trip.trip_memberships.create!(user: @bob,   role: "member", accepted_at: Time.current)
    @trip.trip_memberships.create!(user: @carol, role: "member", accepted_at: Time.current)
    @day      = @trip.trip_days.create!(label: "d1", title: "x", accent: "blue", position: 1)
    @activity = @day.activities.create!(title: "Stop", position: 1)
  end

  test "@-tagged users get a comment_mention; others get the generic comment_posted" do
    comment = @activity.comments.create!(author: @owner, body: "hey @bob check this")
    NotificationDispatcher.comment_posted(comment)

    bob_notifs = @bob.notifications_received.where(subject_id: comment.id)
    assert_equal 1, bob_notifs.count
    assert_equal "comment_mention", bob_notifs.first.kind

    carol_notifs = @carol.notifications_received.where(subject_id: comment.id)
    assert_equal 1, carol_notifs.count
    assert_equal "comment_posted", carol_notifs.first.kind
  end
end
