require "test_helper"

class Admin::AppSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "adm-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Adm", admin: true)
    @user  = User.create!(email: "usr-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Usr")
  end

  test "non-admin is redirected away" do
    sign_in_as(@user)
    get admin_app_settings_path
    assert_response :redirect
  end

  test "admin sees the settings page grouped by category" do
    sign_in_as(@admin)
    get admin_app_settings_path
    assert_response :success
    assert_includes response.body, "Perplexity API key"
    assert_includes response.body, "Affiliate programs"
  end

  test "admin can save a new secret value" do
    sign_in_as(@admin)
    patch admin_app_settings_path, params: { app_settings: { "PERPLEXITY_API_KEY" => "pplx-new-key" } }
    assert_redirected_to admin_app_settings_path
    assert_equal "pplx-new-key", AppSetting.get("PERPLEXITY_API_KEY")
  end

  test "blank input leaves an existing secret unchanged" do
    AppSetting.set("PERPLEXITY_API_KEY", "pplx-keep-me")
    sign_in_as(@admin)
    patch admin_app_settings_path, params: { app_settings: { "PERPLEXITY_API_KEY" => "" } }
    assert_equal "pplx-keep-me", AppSetting.get("PERPLEXITY_API_KEY"), "blank must not wipe the stored secret"
  end

  test "remove checkbox clears a stored value" do
    AppSetting.set("OPENAI_API_KEY", "sk-bye")
    sign_in_as(@admin)
    patch admin_app_settings_path, params: { remove: { "OPENAI_API_KEY" => "1" } }
    refute AppSetting.exists?(key: "OPENAI_API_KEY")
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
