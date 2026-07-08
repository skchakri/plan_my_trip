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

  test "sitemap lists marketing pages and blog posts" do
    get sitemap_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, root_url
    assert_includes response.body, blog_index_url
    assert_includes response.body, blog_url(BlogPost.all.first.slug)
  end
end
