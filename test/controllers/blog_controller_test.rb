require "test_helper"

class BlogControllerTest < ActionDispatch::IntegrationTest
  test "an unknown blog slug returns 404, not a 500" do
    get blog_path("this-slug-does-not-exist")
    assert_response :not_found
  end

  test "a known blog post renders" do
    slug = BlogPost.all.first&.slug
    skip "no blog posts available" if slug.nil?
    get blog_path(slug)
    assert_response :success
  end
end
