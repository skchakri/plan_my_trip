require "test_helper"

class BlogControllerTest < ActionDispatch::IntegrationTest
  test "an unknown blog slug returns 404, not a 500" do
    get blog_path("this-slug-does-not-exist")
    assert_response :not_found
  end

  test "a published blog post renders" do
    post = BlogPost.create!(title: "Rendered Post", body: "# Hi\n\nSome body.", status: "published", published_at: 1.day.ago)
    get blog_path(post.slug)
    assert_response :success
    assert_includes response.body, "Rendered Post"
  end

  test "a draft blog post is not publicly visible" do
    post = BlogPost.create!(title: "Secret Draft", body: "b", status: "draft")
    get blog_path(post.slug)
    assert_response :not_found
  end

  test "a published post ends with a plan-a-trip CTA" do
    post = BlogPost.create!(title: "CTA Post", body: "body", status: "published", published_at: 1.day.ago)
    get blog_path(post.slug)
    assert_response :success
    assert_select "a[href=?]", wizard_destination_path, text: /Plan a trip/
    assert_includes response.body, '"dateModified"'
  end

  test "the RSS feed lists published posts with absolute links, not drafts" do
    live  = BlogPost.create!(title: "Feed Live", body: "See [guides](/road-trips).", status: "published", published_at: 1.day.ago)
    BlogPost.create!(title: "Feed Draft", body: "b", status: "draft")
    get blog_feed_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, "<title>Feed Live</title>"
    assert_includes response.body, blog_url(live.slug)
    assert_includes response.body, %(href="#{request.base_url}/road-trips")
    refute_includes response.body, "Feed Draft"
  end
end
