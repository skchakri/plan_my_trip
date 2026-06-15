require "test_helper"

class TripFormErrorsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    sign_in_as(@owner)
  end

  test "invalid update re-renders the form with an inline field error" do
    patch trip_path(@trip), params: { trip: { end_date: (Date.current - 5).to_s } }
    assert_response :unprocessable_entity
    # field-level message rendered near the input (rose text)
    assert_includes response.body, "must be on or after start date"
    assert_includes response.body, "text-rose-300"
  end

  test "blank title shows an inline error on the title field" do
    patch trip_path(@trip), params: { trip: { title: "" } }
    assert_response :unprocessable_entity
    assert_includes response.body, "can&#39;t be blank"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
