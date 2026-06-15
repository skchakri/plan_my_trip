require "test_helper"
require "digest"

class TripBriefTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    sign_in_as(@owner)
  end

  test "brief frame renders the snapshot when a brief is cached" do
    with_memory_cache do
      brief = DestinationBrief::Brief.new(
        tagline: "Red rock and river light",
        pitch: "A small gateway town under towering canyon walls.",
        watchouts: [ "Summer heat is real" ],
        best_for: [ "hiking", "families" ]
      )
      # Seed the same cache key DestinationBrief.call computes for ("Springdale", []).
      key = "destination_brief/v1/#{Digest::SHA256.hexdigest('springdale|')}"
      Rails.cache.write(key, brief)

      get brief_trip_path(@trip)
      assert_response :success
      assert_includes response.body, "Trip snapshot"
      assert_includes response.body, "Red rock and river light"
      assert_includes response.body, "trip-brief"
    end
  end

  test "brief endpoint always succeeds and returns the frame" do
    get brief_trip_path(@trip)
    assert_response :success
    assert_includes response.body, "trip-brief"
  end

  test "trip show embeds the lazy brief frame" do
    get trip_path(@trip)
    assert_response :success
    assert_includes response.body, brief_trip_path(@trip)
  end

  private

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
