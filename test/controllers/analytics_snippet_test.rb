require "test_helper"

# The analytics snippet is opt-in: it must be completely absent until a
# POSTHOG_API_KEY is set at /admin/app_settings, and must appear on the pages
# the sign-up funnel actually crosses (marketing → auth → application), which
# are three different layouts.
class AnalyticsSnippetTest < ActionDispatch::IntegrationTest
  teardown do
    AppSetting.set("POSTHOG_API_KEY", "")
  end

  # The policy and the tracker must never disagree. Both read analytics_enabled?,
  # and these two tests are what keep that honest as either side changes.
  test "the privacy policy claims no analytics profiles while tracking is off" do
    get privacy_path
    assert_includes response.body, "or analytics profiles"
    assert_not_includes response.body, "PostHog"
  end

  test "the privacy policy discloses analytics once tracking is on" do
    AppSetting.set("POSTHOG_API_KEY", "phc_test_key_123")

    get privacy_path
    assert_includes response.body, "PostHog"
    assert_includes response.body, "Usage analytics"
    # The old blanket denial must be gone — it would be a false statement now.
    assert_not_includes response.body, "or analytics profiles"
  end

  test "no tracking script is served when no key is configured" do
    assert_nil AppSetting.get("POSTHOG_API_KEY"), "precondition: no key set in test"

    get root_path
    assert_response :success
    assert_not_includes response.body, "posthog"
  end

  test "the snippet appears once a key is set" do
    AppSetting.set("POSTHOG_API_KEY", "phc_test_key_123")

    get root_path
    assert_includes response.body, "phc_test_key_123"
    assert_includes response.body, "us.i.posthog.com"      # default host
    # Turbo apps must capture pageviews on turbo:load, or only the first page
    # of each session is ever recorded.
    assert_includes response.body, "turbo:load"
    assert_includes response.body, "capture_pageview: false"
  end

  test "the snippet honours a custom host" do
    AppSetting.set("POSTHOG_API_KEY", "phc_test_key_123")
    AppSetting.set("POSTHOG_HOST", "https://eu.i.posthog.com")

    get root_path
    assert_includes response.body, "eu.i.posthog.com"
  ensure
    AppSetting.set("POSTHOG_HOST", "")
  end

  # The sign-up page is the conversion step — it's on the `auth` layout, not the
  # marketing one, so a partial wired into only one layout would silently break
  # the funnel at exactly the step that matters.
  test "the snippet reaches the sign-up page, which is a different layout" do
    AppSetting.set("POSTHOG_API_KEY", "phc_test_key_123")

    get new_user_registration_path
    assert_response :success
    assert_includes response.body, "phc_test_key_123"
  end

  test "a signed-in user is identified by UUID only, never by email" do
    AppSetting.set("POSTHOG_API_KEY", "phc_test_key_123")
    user = User.create!(email: "an-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Ana")
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    get trips_path
    assert_includes response.body, %(posthog.identify("#{user.id}"))

    # Scoped to the snippet, not the page: the nav legitimately shows the user
    # their own email. What matters is that no PII is handed to the tracker.
    snippet = response.body[/<script nonce="[^"]*">\s*!function\(t,e\).*?<\/script>/m]
    assert snippet, "expected to find the PostHog snippet in the page"
    assert_not_includes snippet, user.email
    assert_not_includes snippet, user.name
  end
end
