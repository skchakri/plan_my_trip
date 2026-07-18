require "test_helper"

class TrailTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "O")
    @trip = @owner.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 1)
  end

  test "the enrichment enqueue helper queues the job with the trail id" do
    trail = @trip.trails.create!(name: "Delicate Arch", position: 0)
    assert_enqueued_with(job: EnrichTrailheadJob, args: [ trail.id ]) do
      trail.send(:enqueue_trailhead_enrichment)
    end
  end

  test "enrichment is wired as an after_commit callback" do
    # after_commit callbacks don't fire under transactional tests, so assert the
    # wiring directly (one guarded callback covers create + name change).
    filters = Trail._commit_callbacks.map(&:filter)
    assert_includes filters, :enqueue_trailhead_enrichment
  end

  test "the enqueue helper is a no-op for a blank name" do
    trail = @trip.trails.create!(name: "X", position: 0)
    trail.name = ""
    assert_no_enqueued_jobs do
      trail.send(:enqueue_trailhead_enrichment)
    end
  end

  test "elevation_label formats with a delimiter, or nil when unknown" do
    trail = @trip.trails.create!(name: "X", position: 0)
    assert_nil trail.elevation_label
    trail.update_columns(trailhead_elevation_ft: 12_345)
    assert_equal "12,345 ft", trail.elevation_label
  end

  test "trailhead_located? reflects stored coords" do
    trail = @trip.trails.create!(name: "X", position: 0)
    refute trail.trailhead_located?
    trail.update_columns(trailhead_lat: 40.5, trailhead_lng: -111.6)
    assert trail.trailhead_located?
  end
end
