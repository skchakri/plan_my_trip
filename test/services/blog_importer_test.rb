require "test_helper"

class BlogImporterTest < ActiveSupport::TestCase
  test "imports the file-based posts into blog_posts and is idempotent" do
    created = BlogImporter.call
    assert created.any?, "expected at least one .md post to import"
    count = BlogPost.count
    assert count >= created.size

    post = BlogPost.find_by(slug: created.first)
    assert_equal "published", post.status
    assert post.body.present?
    assert_not_nil post.published_at

    # Re-running imports nothing new and doesn't duplicate.
    assert_empty BlogImporter.call
    assert_equal count, BlogPost.count
  end

  test "strips YAML-style quotes around front-matter values" do
    BlogImporter.call
    post = BlogPost.find_by!(slug: "yellowstone-3-day-itinerary-first-timers")
    assert post.title.start_with?("Yellowstone in 3 days:"), post.title
    refute post.title.start_with?('"')
  end
end
