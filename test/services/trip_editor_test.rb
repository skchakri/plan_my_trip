require "test_helper"

# The safe mutation core behind the agentic concierge. No AI here — just the
# authorization gate, trip-scoping, and the four itinerary edits.
class TripEditorTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "own-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "Own")
    @trip = @owner.owned_trips.create!(title: "UT", destination: "Utah",
                                       start_date: Date.current, end_date: Date.current + 2)
    @d1 = @trip.trip_days.create!(label: "day-1", title: "Arrival", accent: "blue", position: 0, date: Date.current)
    @d2 = @trip.trip_days.create!(label: "day-2", title: "Adventure", accent: "gold", position: 1, date: Date.current + 1)
    @d1.activities.create!(title: "Goblin Valley", position: 0)
    @d1.activities.create!(title: "Lunch at Stan's", position: 1)
  end

  def editor(user = @owner)
    TripEditor.new(trip: @trip, user: user)
  end

  test "add_activity appends a stop to the named day" do
    res = editor.add_activity(day_number: 2, title: "Sunset hike", time_label: "6:00 PM")
    assert res.ok?, res.error
    assert_equal 1, @d2.activities.reload.size
    assert_equal "Sunset hike", @d2.activities.first.title
    assert_match(/day 2/, res.summary)
  end

  test "add_activity requires a title" do
    res = editor.add_activity(day_number: 1, title: "  ")
    refute res.ok?
    assert_match(/title/i, res.error)
  end

  test "remove_activity deletes the matched stop" do
    assert_difference -> { @d1.activities.count }, -1 do
      res = editor.remove_activity(day_number: 1, activity_title: "goblin")
      assert res.ok?, res.error
    end
  end

  test "remove_activity refuses an ambiguous match" do
    @d1.activities.create!(title: "Goblin Valley Overlook", position: 2)
    res = editor.remove_activity(day_number: 1, activity_title: "goblin")
    refute res.ok?
    assert_match(/several stops match/i, res.error)
    assert_equal 3, @d1.activities.reload.size # nothing deleted
  end

  test "remove_activity reports when nothing matches" do
    res = editor.remove_activity(day_number: 1, activity_title: "museum")
    refute res.ok?
    assert_match(/no stop matching/i, res.error)
  end

  test "move_activity reorders within the day" do
    res = editor.move_activity(day_number: 1, activity_title: "lunch", direction: "up")
    assert res.ok?, res.error
    assert_equal [ "Lunch at Stan's", "Goblin Valley" ], @d1.activities.reload.order(:position).pluck(:title)
  end

  test "move_activity rejects a bad direction" do
    res = editor.move_activity(day_number: 1, activity_title: "lunch", direction: "sideways")
    refute res.ok?
    assert_match(/up.*down/i, res.error)
  end

  test "update_day_title renames the day" do
    res = editor.update_day_title(day_number: 2, title: "Canyon day")
    assert res.ok?, res.error
    assert_equal "Canyon day", @d2.reload.title
  end

  test "an out-of-range day number is a friendly error, not a crash" do
    res = editor.add_activity(day_number: 9, title: "X")
    refute res.ok?
    assert_match(/doesn't exist/i, res.error)
  end

  test "a viewer (non-editor) cannot mutate" do
    viewer = User.create!(email: "view-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "View")
    @trip.trip_memberships.create!(user: viewer, role: "member")
    refute @trip.editable_by?(viewer), "sanity: member is not an editor"

    res = editor(viewer).add_activity(day_number: 1, title: "sneaky edit")
    refute res.ok?
    assert_match(/permission/i, res.error)
    assert_equal 2, @d1.activities.reload.size # unchanged
  end

  test "update_activity_time sets and clears a stop's time" do
    res = editor.update_activity_time(day_number: 1, activity_title: "goblin", time_label: "9:00 AM")
    assert res.ok?, res.error
    assert_equal "9:00 AM", @d1.activities.order(:position).first.reload.time_label

    res = editor.update_activity_time(day_number: 1, activity_title: "goblin", time_label: "  ")
    assert res.ok?, res.error
    assert_nil @d1.activities.order(:position).first.reload.time_label
    assert_match(/cleared/i, res.summary)
  end

  test "add_checklist_item appends a before-trip item" do
    assert_difference -> { @trip.checklist_items.count }, +1 do
      res = editor.add_checklist_item(title: "Pack rain jacket", category: "Clothing")
      assert res.ok?, res.error
    end
    item = @trip.checklist_items.order(:created_at).last
    assert_equal "before_trip", item.scope
    assert_equal "Clothing", item.category
  end

  test "add_checklist_item requires a title" do
    res = editor.add_checklist_item(title: " ")
    refute res.ok?
    assert_match(/title/i, res.error)
  end

  test "update_pace only accepts a valid pace" do
    assert editor.update_pace(pace: "Relaxed").ok?
    assert_equal "relaxed", @trip.reload.pace

    res = editor.update_pace(pace: "warp speed")
    refute res.ok?
    assert_equal "relaxed", @trip.reload.pace
  end

  test "update_budget only accepts a valid band" do
    assert editor.update_budget(budget: "luxury").ok?
    assert_equal "luxury", @trip.reload.budget

    refute editor.update_budget(budget: "free").ok?
    assert_equal "luxury", @trip.reload.budget
  end

  test "a viewer cannot use the new day-less actions either" do
    viewer = User.create!(email: "v2-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "V2")
    @trip.trip_memberships.create!(user: viewer, role: "member")
    refute editor(viewer).add_checklist_item(title: "sneaky").ok?
    refute editor(viewer).update_pace(pace: "packed").ok?
  end

  test "edits never reach another trip's rows (trip-scoped)" do
    other = @owner.owned_trips.create!(title: "Other", destination: "Nevada",
                                       start_date: Date.current, end_date: Date.current + 1)
    other.trip_days.create!(label: "day-1", title: "Vegas", accent: "teal", position: 0)
    # day_number 1 on @trip must resolve to @trip's day, never `other`'s.
    res = editor.update_day_title(day_number: 1, title: "Renamed")
    assert res.ok?
    assert_equal "Renamed", @trip.trip_days.ordered.first.reload.title
    assert_equal "Vegas", other.trip_days.first.reload.title # untouched
  end
end
