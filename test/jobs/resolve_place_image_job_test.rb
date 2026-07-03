require "test_helper"

class ResolvePlaceImageJobTest < ActiveSupport::TestCase
  # The test env uses :null_store; this job (and its controller) are cache-driven,
  # so swap in a real MemoryStore for the duration of each test.
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @original_cache }

  # Replaces LandmarkImageFinder.call with a fake returning `ret`, records args.
  def with_fake_finder(ret)
    calls = []
    original = LandmarkImageFinder.method(:call)
    LandmarkImageFinder.singleton_class.send(:define_method, :call) do |name, **kwargs|
      calls << [ name, kwargs ]
      ret
    end
    yield calls
  ensure
    LandmarkImageFinder.singleton_class.send(:define_method, :call, original)
  end

  test "caches the resolved url from the finder hash" do
    with_fake_finder({ url: "https://img.example/goblin.jpg", source: "pexels" }) do
      ResolvePlaceImageJob.new.perform("Goblin Valley", "Green River, Utah")
    end
    key = ResolvePlaceImageJob.cache_key("Goblin Valley")
    assert_equal "https://img.example/goblin.jpg", Rails.cache.read(key)
  end

  test "passes the state parsed from the destination context to the finder" do
    with_fake_finder({ url: "https://img.example/x.jpg" }) do |calls|
      ResolvePlaceImageJob.new.perform("Zion", "Springdale, Utah")
      assert_equal "Utah", calls.first.last[:state]
      assert_equal ResolvePlaceImageJob::PROVIDERS, calls.first.last[:providers]
    end
  end

  test "caches 'none' when the finder returns nil" do
    with_fake_finder(nil) do
      ResolvePlaceImageJob.new.perform("Nowhere Bluff", nil)
    end
    assert_equal "none", Rails.cache.read(ResolvePlaceImageJob.cache_key("Nowhere Bluff"))
  end

  test "is idempotent: skips the finder when already cached" do
    key = ResolvePlaceImageJob.cache_key("Cached Place")
    Rails.cache.write(key, "https://img.example/cached.jpg")
    with_fake_finder({ url: "https://img.example/NEW.jpg" }) do |calls|
      ResolvePlaceImageJob.new.perform("Cached Place", nil)
      assert_empty calls, "finder should not be called when a value is already cached"
    end
    assert_equal "https://img.example/cached.jpg", Rails.cache.read(key)
  end

  test "no-ops on blank name" do
    with_fake_finder({ url: "https://img.example/x.jpg" }) do |calls|
      ResolvePlaceImageJob.new.perform("  ", nil)
      assert_empty calls
    end
  end

  test "cache_key normalizes whitespace and case" do
    assert_equal ResolvePlaceImageJob.cache_key("goblin valley"),
                 ResolvePlaceImageJob.cache_key("  Goblin Valley  ")
  end
end
