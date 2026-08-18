require "test_helper"

class IndexNowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "is a no-op outside production / without a key" do
    res = IndexNow.submit([ "https://wanderply.com/blog/x" ])
    assert_equal :disabled, res.status
    assert_equal 0, res.submitted
  end

  test "all_public_urls covers blog, road trips and quizzes on the canonical host" do
    BlogPost.create!(title: "Indexed Post", body: "b", status: "published", published_at: 1.day.ago)
    urls = IndexNow.all_public_urls
    assert urls.all? { |u| u.start_with?("https://wanderply.com/") }, urls.reject { |u| u.start_with?("https://wanderply.com/") }.inspect
    assert_includes urls, "https://wanderply.com/blog/indexed-post"
    assert_includes urls, "https://wanderply.com/quizzes/flags_countries"
    assert_includes urls, "https://wanderply.com/road-trips"
  end

  test "publishing a blog post enqueues an IndexNow ping" do
    assert_enqueued_with(job: IndexNowPingJob, args: [ [ "https://wanderply.com/blog/ping-me" ] ]) do
      BlogPost.create!(title: "Ping Me", body: "b", status: "published", published_at: 1.day.ago)
    end
  end

  test "a draft does not enqueue a ping" do
    assert_no_enqueued_jobs(only: IndexNowPingJob) do
      BlogPost.create!(title: "Quiet Draft", body: "b", status: "draft")
    end
  end
end
