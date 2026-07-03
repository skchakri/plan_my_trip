require "test_helper"

class PlaceImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @user = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Pat")
    sign_in_as(@user)
  end

  teardown { Rails.cache = @original_cache }

  test "cache hit redirects to the resolved photo" do
    Rails.cache.write(ResolvePlaceImageJob.cache_key("Goblin Valley"), "https://img.example/g.jpg")
    get place_image_path(q: "Goblin Valley")
    assert_redirected_to "https://img.example/g.jpg"
  end

  test "cache miss enqueues a resolve job and returns a transparent pixel" do
    assert_enqueued_with(job: ResolvePlaceImageJob) do
      get place_image_path(q: "Unknown Place", d: "Moab, Utah")
    end
    assert_response :success
    assert_equal "image/gif", response.media_type
    assert_equal PlaceImagesController::PIXEL, response.body
  end

  test "resolved-empty ('none') returns a pixel and does not re-enqueue" do
    Rails.cache.write(ResolvePlaceImageJob.cache_key("Empty Place"), "none")
    assert_no_enqueued_jobs do
      get place_image_path(q: "Empty Place")
    end
    assert_response :success
    assert_equal "image/gif", response.media_type
  end

  test "does not enqueue twice for the same name within the dedupe window" do
    get place_image_path(q: "Dedup Place")
    assert_no_enqueued_jobs do
      get place_image_path(q: "Dedup Place")
    end
  end

  test "blank query returns a pixel without enqueuing" do
    assert_no_enqueued_jobs do
      get place_image_path(q: "  ")
    end
    assert_response :success
    assert_equal "image/gif", response.media_type
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
