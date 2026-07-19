require "test_helper"

class BlogPostTest < ActiveSupport::TestCase
  test "generates a slug from the title when blank" do
    post = BlogPost.create!(title: "Hello, Wanderply World!", body: "Body")
    assert_equal "hello-wanderply-world", post.slug
  end

  test "rejects a malformed slug" do
    post = BlogPost.new(title: "T", body: "B", slug: "Not Valid!")
    refute post.valid?
    assert_includes post.errors[:slug].join, "lowercase"
  end

  test "published scope excludes drafts, future-dated, and discarded posts" do
    live    = BlogPost.create!(title: "Live", body: "b", status: "published", published_at: 1.day.ago)
    draft   = BlogPost.create!(title: "Draft", body: "b", status: "draft")
    future  = BlogPost.create!(title: "Future", body: "b", status: "published", published_at: 1.day.from_now)
    gone    = BlogPost.create!(title: "Gone", body: "b", status: "published", published_at: 1.day.ago)
    gone.discard

    slugs = BlogPost.published.pluck(:slug)
    assert_includes slugs, live.slug
    refute_includes slugs, draft.slug
    refute_includes slugs, future.slug
    refute_includes slugs, gone.slug
  end

  test "reading_minutes is estimated from the body when not set" do
    post = BlogPost.create!(title: "R", body: ([ "word" ] * 400).join(" "))
    assert_equal 2, post.reading_minutes
  end

  test "compat readers mirror the old file-based attribute names" do
    post = BlogPost.create!(title: "C", body: "b", cover_image_url: "http://x/y.jpg",
                            tags: %w[Destinations Tips], author_name: "Kalyan",
                            status: "published", published_at: Time.utc(2026, 5, 1, 12))
    assert_equal "http://x/y.jpg", post.cover
    assert_equal "Destinations", post.tag
    assert_equal "Kalyan", post.author
    assert_equal Date.new(2026, 5, 1), post.published_on
    assert_equal post.slug, post.to_param
  end
end
