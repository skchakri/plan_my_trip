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
end
