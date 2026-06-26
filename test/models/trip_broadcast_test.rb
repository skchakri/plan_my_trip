require "test_helper"
require "turbo/broadcastable/test_helper"

# Live collaborative editing (board 1257aed1): Trip#broadcasts_refreshes and
# Activity#broadcasts_refreshes_to :trip push a Turbo 8 refresh to the trip's
# own stream — the one trips/show subscribes to via `turbo_stream_from @trip`.
#
# The refresh broadcast is normally async + debounced (Turbo::Debouncer wraps it
# in a 0.5s Concurrent::ScheduledTask, then BroadcastStreamJob.perform_later does
# the cable write). To assert it deterministically we (a) swap the debouncer for
# a synchronous one and (b) run enqueued jobs inline.
class TripBroadcastTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  include ActiveJob::TestHelper

  # Fires the debounced block immediately instead of after a 0.5s timer.
  class ImmediateDebouncer
    def initialize(delay: nil); end
    def debounce(&block) = block.call
    def wait; end
  end

  setup do
    @previous_debouncer_class = Turbo::ThreadDebouncer.debouncer_class
    Turbo::ThreadDebouncer.debouncer_class = ImmediateDebouncer

    @user = User.create!(
      email: "broadcast-#{SecureRandom.hex(4)}@test.example",
      password: "password123",
      name: "Broadcaster"
    )
    @trip = @user.owned_trips.create!(
      title: "Live Trip", start_date: Date.current, end_date: Date.current + 2
    )
  end

  teardown do
    Turbo::ThreadDebouncer.debouncer_class = @previous_debouncer_class
  end

  test "updating a trip broadcasts a refresh to its own stream" do
    assert_turbo_stream_broadcasts(@trip) do
      perform_enqueued_jobs do
        @trip.update!(title: "Renamed live")
      end
    end
  end

  test "editing an activity broadcasts a refresh to the parent trip's stream" do
    day = @trip.trip_days.create!(title: "Day 1", label: "Day 1", accent: "blue")
    activity = day.activities.create!(title: "Lunch")

    assert_turbo_stream_broadcasts(@trip) do
      perform_enqueued_jobs do
        activity.update!(title: "Dinner")
      end
    end
  end
end
