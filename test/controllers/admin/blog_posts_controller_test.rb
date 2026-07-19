require "test_helper"

class Admin::BlogPostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "adm-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Adm", admin: true)
    @user  = User.create!(email: "usr-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Usr")
  end

  test "non-admin is redirected away" do
    sign_in_as(@user)
    get admin_blog_posts_path
    assert_response :redirect
  end

  test "admin index, new, and edit pages render" do
    blog_post = BlogPost.create!(title: "Renders", body: "b")
    sign_in_as(@admin)
    get admin_blog_posts_path
    assert_response :success
    assert_includes response.body, "Renders"
    get new_admin_blog_post_path
    assert_response :success
    get edit_admin_blog_post_path(blog_post)
    assert_response :success
  end

  test "admin can create a post with comma-separated tags" do
    sign_in_as(@admin)
    assert_difference "BlogPost.count", 1 do
      post admin_blog_posts_path, params: { blog_post: {
        title: "A New Post", body: "# Hi\n\nBody text.", status: "draft", tags: "Tips, Destinations"
      } }
    end
    created = BlogPost.order(:created_at).last
    assert_equal "a-new-post", created.slug
    assert_equal %w[Tips Destinations], created.tags
    assert_redirected_to admin_blog_posts_path
  end

  test "publish and unpublish toggle status" do
    sign_in_as(@admin)
    blog_post = BlogPost.create!(title: "Toggle", body: "b", status: "draft")

    post publish_admin_blog_post_path(blog_post)
    assert blog_post.reload.published?

    post unpublish_admin_blog_post_path(blog_post)
    assert_equal "draft", blog_post.reload.status
  end

  test "destroy soft-deletes the post" do
    sign_in_as(@admin)
    blog_post = BlogPost.create!(title: "Bye", body: "b")
    delete admin_blog_post_path(blog_post)
    assert blog_post.reload.discarded?
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
