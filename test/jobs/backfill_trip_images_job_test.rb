require "test_helper"

# Photos are resolved AFTER the plan is viewable so the build returns fast.
# The Wikipedia lookup is swapped for a fake here (the suite never hits the
# network) to assert the orchestration: only blank places are filled, the fill
# is idempotent, and a missing trip is a no-op.
class BackfillTripImagesJobTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "img-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Iris")
    @trip = @user.owned_trips.create!(title: "T", destination: "Hanksville, UT",
                                      start_date: Date.current, end_date: Date.current, build_status: "ready")
    @day = @trip.trip_days.create!(label: "day-1", title: "Day 1", accent: "blue", position: 0, date: @trip.start_date)
  end

  # Swap PlaceImageLookup.call for a fake returning `ret`, recording calls.
  def with_fake_lookup(ret)
    calls = []
    original = PlaceImageLookup.method(:call)
    PlaceImageLookup.singleton_class.send(:define_method, :call) do |name, **kwargs|
      calls << [ name, kwargs ]
      ret
    end
    yield calls
  ensure
    PlaceImageLookup.singleton_class.send(:define_method, :call, original)
  end

  def place_with_activity(name, image: nil)
    place = Place.create!(name: name, latitude: 38.5, longitude: -110.7, image_url: image)
    @day.activities.create!(title: name, location_name: name, latitude: 38.5, longitude: -110.7, place: place, position: @day.activities.count)
    place
  end

  test "fills blank place images and leaves existing ones alone" do
    blank = place_with_activity("Factory Butte")
    kept  = place_with_activity("Goblin Valley", image: "https://img/keep.jpg")

    with_fake_lookup("https://img/new.jpg") do |calls|
      BackfillTripImagesJob.perform_now(@trip.id)
      assert_equal [ "Factory Butte" ], calls.map(&:first) # only the blank one looked up
    end

    assert_equal "https://img/new.jpg", blank.reload.image_url
    assert_equal "wikipedia", blank.image_source
    assert_equal "https://img/keep.jpg", kept.reload.image_url # untouched
  end

  test "a lookup miss leaves the place photo-less without raising" do
    p = place_with_activity("Obscure Stop")
    with_fake_lookup(nil) do
      assert_nothing_raised { BackfillTripImagesJob.perform_now(@trip.id) }
    end
    assert_nil p.reload.image_url
  end

  test "is idempotent — a second run does no lookups once filled" do
    place_with_activity("Factory Butte")
    with_fake_lookup("https://img/new.jpg") { BackfillTripImagesJob.perform_now(@trip.id) }
    with_fake_lookup("https://img/other.jpg") do |calls|
      BackfillTripImagesJob.perform_now(@trip.id)
      assert_empty calls # nothing left blank
    end
  end

  test "missing trip is a no-op" do
    assert_nothing_raised { BackfillTripImagesJob.perform_now(SecureRandom.uuid) }
  end
end
