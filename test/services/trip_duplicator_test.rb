require "test_helper"

class TripDuplicatorTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(
      email: "o-#{SecureRandom.hex(4)}@test.example",
      password: "password123",
      name: "Owner"
    )
    @other = User.create!(
      email: "n-#{SecureRandom.hex(4)}@test.example",
      password: "password123",
      name: "Friend"
    )
    @trip = @owner.owned_trips.create!(
      title: "Vegas",
      destination: "Las Vegas, NV",
      origin: "Salt Lake City, UT",
      body: "## Day 1\nDrive",
      traveler_count: 4,
      transport_mode: "own_car",
      start_date: Date.new(2026, 6, 1),
      end_date:   Date.new(2026, 6, 4)
    )
    @trip.people.create!(name: "Alice", position: 1, interests: %w[food art])
    @trip.people.create!(name: "Bob",   position: 2)
    @trip.trails.create!(name: "Red Rocks Loop", alltrails_url: "https://www.alltrails.com/trail/x", position: 1)

    @day1 = @trip.trip_days.create!(label: "day-1", title: "Drive out",  accent: "blue",   position: 1, date: @trip.start_date)
    @day2 = @trip.trip_days.create!(label: "day-2", title: "On the Strip", accent: "gold", position: 2, date: @trip.start_date + 1)
    @day1.activities.create!(title: "Lunch at Buc-ee's", time_label: "12:30", position: 1)
    @day2.activities.create!(title: "Bellagio Fountains", time_label: "20:00", position: 1, latitude: 36.11, longitude: -115.17)

    @trip.checklist_items.create!(scope: "before_trip", title: "Pack snacks", category: "Food", position: 1)
    @trip.checklist_items.create!(scope: "day", title: "Sunscreen", day_label: "day-2", position: 1)
    @trip.route_landmarks.create!(name: "Valley of Fire", kind: "scenic", latitude: 36.43, longitude: -114.51, narration: "Sandstone canyons.", position: 1, source: "ai")
  end

  test "produces a new Trip owned by the cloning user, not the source owner" do
    new_trip = duplicate_for(@other)
    assert_not_equal @trip.id, new_trip.id
    assert_equal @other.id, new_trip.owner_id
    assert_equal "Copy of Vegas", new_trip.title
  end

  test "respects custom title" do
    new_trip = TripDuplicator.new(source: @trip, owner: @other, new_title: "Vegas 2027").call
    assert_equal "Vegas 2027", new_trip.title
  end

  test "carries over planning levers: pace, budget, and preferences" do
    @trip.update!(pace: "relaxed", budget: "shoestring",
                  preferences: "Vegetarian; wheelchair-accessible; must see the Grand Canyon")
    new_trip = duplicate_for(@other)
    assert_equal "relaxed", new_trip.pace
    assert_equal "shoestring", new_trip.budget
    assert_equal "Vegetarian; wheelchair-accessible; must see the Grand Canyon", new_trip.preferences
  end

  test "clones structure: people, trails, days, activities, checklist, landmarks" do
    new_trip = duplicate_for(@other)
    assert_equal 2, new_trip.people.count
    assert_equal 1, new_trip.trails.count
    assert_equal 2, new_trip.trip_days.count
    assert_equal 2, new_trip.trip_days.flat_map { |d| d.activities.to_a }.size
    assert_equal 2, new_trip.checklist_items.count
    assert_equal 1, new_trip.route_landmarks.count
  end

  test "does not clone share token, memberships, or invitations" do
    @trip.enable_share_link!
    new_trip = duplicate_for(@other)
    assert_nil new_trip.share_token
    assert_nil new_trip.share_revoked_at
    # New trip only has the owner membership, auto-created by Trip after_create.
    assert_equal 1, new_trip.trip_memberships.count
    assert_equal @other.id, new_trip.trip_memberships.first.user_id
  end

  test "fresh clone has all checklist items unpacked" do
    @trip.checklist_items.update_all(packed: true)
    new_trip = duplicate_for(@other)
    assert_equal 0, new_trip.checklist_items.where(packed: true).count
  end

  test "shifts dates by new_start_date delta" do
    new_trip = TripDuplicator.new(
      source: @trip, owner: @other,
      new_start_date: Date.new(2026, 8, 10)
    ).call
    assert_equal Date.new(2026, 8, 10), new_trip.start_date
    assert_equal Date.new(2026, 8, 13), new_trip.end_date
    # trip_day dates shift in lockstep
    days = new_trip.trip_days.ordered
    assert_equal Date.new(2026, 8, 10), days.first.date
    assert_equal Date.new(2026, 8, 11), days.last.date
  end

  test "rolls back the entire clone on any failure" do
    # Force a failure midway: stub TripDuplicator to raise after creating the trip.
    before = Trip.count
    assert_raises(ActiveRecord::RecordInvalid) do
      Trip.transaction do
        new_trip = @other.owned_trips.create!(title: "Half-clone", start_date: Date.current, end_date: Date.current + 1)
        new_trip.trip_days.create!(label: "", title: "", accent: "blue", position: 1) # invalid
      end
    end
    assert_equal before, Trip.count, "transaction should have rolled back"
  end

  private

  def duplicate_for(user, **opts)
    TripDuplicator.new(source: @trip, owner: user, **opts).call
  end
end
