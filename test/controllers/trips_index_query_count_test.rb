require "test_helper"

# Pins the dashboard query count so a missing eager-load can't silently
# reintroduce the cover_image_url N+1 across activities + photos + places +
# landmarks.
class TripsIndexQueryCountTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "qc-#{SecureRandom.hex(4)}@test.example",
                          password: "password123", name: "Owner")

    # Three trips, each with two days, each day with two activities. If the
    # cover lookup N+1s, each extra activity adds at least one query.
    3.times do |t|
      trip = @owner.owned_trips.create!(title: "T#{t}", destination: "Dest #{t}",
                                        start_date: Date.current,
                                        end_date: Date.current + 2)
      2.times do |d|
        day = trip.trip_days.create!(label: "day-#{d}", title: "D#{d}",
                                     accent: "blue", position: d,
                                     date: trip.start_date + d)
        2.times do |i|
          day.activities.create!(title: "A#{t}-#{d}-#{i}",
                                 time_label: "09:00", position: i,
                                 location_name: "L", address: "Addr",
                                 latitude: 0, longitude: 0)
        end
      end
    end
  end

  test "trips#index stays under a fixed query budget regardless of trip volume" do
    sign_in_as(@owner)

    query_count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA"
      next if payload[:sql].start_with?("BEGIN", "COMMIT", "ROLLBACK")
      query_count += 1
    end

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get trips_path
    end

    assert_response :success
    # Budget reflects the policy_scope + trip + owner + days + activities +
    # photo attachments/blobs + places + landmarks fan-out, plus one fixed
    # EXISTS for the "Archived" header link, plus two fixed AppSetting lookups
    # in the layout's analytics snippet (POSTHOG_API_KEY + GOOGLE_SITE_VERIFICATION;
    # Solid Cache is DB-backed, so a cached read is still a query). With the
    # `with_cover_data` scope this is bounded and does not grow with the number
    # of trips — which is what this test actually guards. Constant additions
    # belong in the budget; anything that scales with trip count does not.
    assert_operator query_count, :<=, 28, "trips#index used #{query_count} queries (budget 28). New N+1?"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
