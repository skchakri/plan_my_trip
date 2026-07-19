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
end
