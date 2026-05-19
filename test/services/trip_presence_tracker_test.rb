require "test_helper"

class TripPresenceTrackerTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "p-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Pat")
    @bob   = User.create!(email: "b-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Bob")
    @carol = User.create!(email: "c-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Carol")
    @trip  = @owner.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 1)
    @trip.trip_memberships.create!(user: @bob,   role: "member", accepted_at: Time.current)
    @trip.trip_memberships.create!(user: @carol, role: "member", accepted_at: Time.current)

    # Use an in-memory cache for deterministic tests — the test env default
    # is NullStore, which would silently drop every write.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "touch then viewers_for includes the user" do
    TripPresenceTracker.touch(trip_id: @trip.id, user_id: @bob.id)
    viewers = TripPresenceTracker.viewers_for(@trip)
    assert_includes viewers.map(&:id), @bob.id
  end

  test "viewers_for excludes the requesting user when excluding: is set" do
    TripPresenceTracker.touch(trip_id: @trip.id, user_id: @bob.id)
    TripPresenceTracker.touch(trip_id: @trip.id, user_id: @carol.id)
    viewers = TripPresenceTracker.viewers_for(@trip, excluding: @bob)
    assert_equal [ @carol.id ], viewers.map(&:id)
  end

  test "remove drops the user from the live set" do
    TripPresenceTracker.touch(trip_id: @trip.id, user_id: @bob.id)
    TripPresenceTracker.remove(trip_id: @trip.id, user_id: @bob.id)
    refute_includes TripPresenceTracker.viewers_for(@trip).map(&:id), @bob.id
  end

  test "non-trip-members are never returned even if their cache key is set" do
    # Simulating a stray cache key from another trip — the membership check
    # is the gate, not just the cache hit.
    stranger = User.create!(email: "x-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Stranger")
    TripPresenceTracker.touch(trip_id: @trip.id, user_id: stranger.id)
    refute_includes TripPresenceTracker.viewers_for(@trip).map(&:id), stranger.id
  end
end
