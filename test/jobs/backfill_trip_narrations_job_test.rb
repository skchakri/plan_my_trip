require "test_helper"

# Narration backfill fans out one NarrateActivityJob per blank activity. The
# per-activity work runs OFFLINE here (no activity_narration prompt seeded in the
# test DB → ActivityNarrator yields nil), so we assert the orchestration +
# idempotency without hitting the network.
class BackfillTripNarrationsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "n-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Nat")
    @trip = @user.owned_trips.create!(title: "T", destination: "Moab, UT", start_date: Date.current, end_date: Date.current, build_status: "ready")
    @day = @trip.trip_days.create!(label: "day-1", title: "Day 1", accent: "blue", position: 0, date: @trip.start_date)
  end

  test "fans out one NarrateActivityJob per blank activity" do
    @day.activities.create!(title: "Delicate Arch", location_name: "Delicate Arch", position: 0)
    @day.activities.create!(title: "Dead Horse Point", location_name: "Dead Horse Point", position: 1)
    assert_enqueued_jobs 2, only: NarrateActivityJob do
      BackfillTripNarrationsJob.perform_now(@trip.id)
    end
  end

  test "does not enqueue for activities that already have a script" do
    @day.activities.create!(title: "Narrated", location_name: "Narrated", guide_script: "Already.", position: 0)
    @day.activities.create!(title: "Blank", location_name: "Blank", position: 1)
    assert_enqueued_jobs 1, only: NarrateActivityJob do
      BackfillTripNarrationsJob.perform_now(@trip.id)
    end
  end

  test "missing trip is a no-op" do
    assert_no_enqueued_jobs(only: NarrateActivityJob) do
      BackfillTripNarrationsJob.perform_now(SecureRandom.uuid)
    end
  end

  # ── NarrateActivityJob (the per-activity worker) ──

  test "NarrateActivityJob offline leaves a blank script blank without raising" do
    a = @day.activities.create!(title: "Delicate Arch", location_name: "Delicate Arch", position: 0)
    assert_nothing_raised { NarrateActivityJob.perform_now(a.id) }
    assert_nil a.reload.guide_script
  end

  test "NarrateActivityJob never overwrites an existing script" do
    a = @day.activities.create!(title: "Delicate Arch", guide_script: "Keep me.", position: 0)
    NarrateActivityJob.perform_now(a.id)
    assert_equal "Keep me.", a.reload.guide_script
  end

  test "NarrateActivityJob on a missing activity is a no-op" do
    assert_nothing_raised { NarrateActivityJob.perform_now(SecureRandom.uuid) }
  end

  test "ActivityNarrator skips admin stops without a narration" do
    admin = @day.activities.create!(title: "Check in to hotel", position: 0)
    assert_nil ActivityNarrator.call(admin, destination: @trip.destination)
  end
end
