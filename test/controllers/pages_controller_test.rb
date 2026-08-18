require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "landing renders without auth" do
    get root_path
    assert_response :success
  end

  test "about renders without auth" do
    get about_path
    assert_response :success
  end

  test "privacy policy renders without auth" do
    get privacy_path
    assert_response :success
    assert_select "h1", text: /Privacy Policy/
  end

  test "landing carries canonical, social cards, and structured data" do
    get root_path
    assert_response :success
    assert_select "link[rel=canonical]", 1
    assert_select "meta[property='og:title']", 1
    assert_select "meta[name='twitter:card']", 1
    assert_select "script[type='application/ld+json']" do |nodes|
      graph = JSON.parse(nodes.first.text).fetch("@graph")
      types = graph.map { |n| n["@type"] }
      assert_includes types, "Organization"
      assert_includes types, "SoftwareApplication"
      assert_includes types, "FAQPage"
      faq = graph.find { |n| n["@type"] == "FAQPage" }
      assert_operator faq["mainEntity"].size, :>=, 4
    end
    # The visible FAQ must exist so the schema matches page content.
    assert_select "#faq details summary", minimum: 4
  end

  test "sitemap lists marketing pages and published blog posts" do
    post = BlogPost.create!(title: "Sitemap Post", body: "b", status: "published", published_at: 1.day.ago)
    draft = BlogPost.create!(title: "Draft Post", body: "b", status: "draft")

    get sitemap_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, root_url
    assert_includes response.body, blog_index_url
    assert_includes response.body, blog_url(post.slug)
    refute_includes response.body, blog_url(draft.slug), "drafts must not be in the sitemap"
  end

  test "sitemap lists every public quiz deck" do
    get sitemap_path
    assert_includes response.body, quizzes_url
    assert_includes response.body, quiz_explore_url
    QuizCatalog.keys.each do |key|
      assert_includes response.body, quiz_url(key), "#{key} must be in the sitemap to be indexable"
    end
  end

  test "indexnow key file 404s when no key is configured and serves it when set" do
    get "/#{"a" * 32}.txt"
    assert_response :not_found

    AppSetting.set("INDEXNOW_KEY", "b" * 32)
    get "/#{"a" * 32}.txt"
    assert_response :not_found
    get "/#{"b" * 32}.txt"
    assert_response :success
    assert_equal "b" * 32, response.body
  ensure
    AppSetting.set("INDEXNOW_KEY", nil)
  end
end
