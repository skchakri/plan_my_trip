require "test_helper"

# The trip builder creates Place rows with `defer_image: true` so it never pays
# the ~2s-per-stop Wikipedia lookup on the critical path (BackfillTripImagesJob
# fills them after). This locks that contract: deferred → no lookup + blank
# image; default → lookup runs.
class SeederDeferImageTest < ActiveSupport::TestCase
  def with_fake_lookup(ret)
    calls = []
    original = PlaceImageLookup.method(:call)
    PlaceImageLookup.singleton_class.send(:define_method, :call) do |name, **kwargs|
      calls << name
      ret
    end
    yield calls
  ensure
    PlaceImageLookup.singleton_class.send(:define_method, :call, original)
  end

  test "defer_image: true creates the place without any image lookup" do
    with_fake_lookup("https://img/x.jpg") do |calls|
      place = Places::Seeder.call(name: "Factory Butte #{SecureRandom.hex(3)}",
                                  lat: 38.5, lng: -110.7, defer_image: true)
      assert place.persisted?
      assert_nil place.image_url
      assert_empty calls # never hit the lookup
    end
  end

  test "by default the image lookup still runs" do
    with_fake_lookup("https://img/x.jpg") do |calls|
      place = Places::Seeder.call(name: "Goblin Valley #{SecureRandom.hex(3)}", lat: 38.5, lng: -110.7)
      assert_equal "https://img/x.jpg", place.image_url
      assert_equal 1, calls.size
    end
  end
end
