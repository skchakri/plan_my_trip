require "test_helper"

# The Google Search Console verification <meta> tag renders on public pages only
# when GOOGLE_SITE_VERIFICATION is set at /admin/app_settings.
class GoogleVerificationTest < ActionDispatch::IntegrationTest
  teardown { AppSetting.set("GOOGLE_SITE_VERIFICATION", "") }

  test "no verification tag is rendered when the token is unset" do
    AppSetting.set("GOOGLE_SITE_VERIFICATION", "")
    get root_path
    assert_response :success
    refute_includes response.body, "google-site-verification"
  end

  test "verification tag renders on the homepage when the token is set" do
    AppSetting.set("GOOGLE_SITE_VERIFICATION", "test-gsc-token-123")
    get root_path
    assert_response :success
    assert_includes response.body, %(<meta name="google-site-verification" content="test-gsc-token-123">)
  end
end
