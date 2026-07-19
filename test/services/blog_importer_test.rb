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
end
