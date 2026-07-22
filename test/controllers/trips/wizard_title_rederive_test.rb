require "test_helper"

# Step 1 pre-fills the title field, so an auto-derived title gets resubmitted
# as if the user typed it. Re-entering step 1 and changing the destination or
# dates must re-derive the title; a genuinely user-typed title must survive.
class Trips::WizardTitleRederiveTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "wt-#{SecureRandom.hex(4)}@test.example",
                         password: "password123", name: "Owner")
    sign_in_as(@user)
    @start = Date.current
  end

  test "auto-derived title re-derives when the destination changes" do
    post wizard_destination_path, params: { wizard: base_attrs(title: "") }
    stale_title = DraftTrip.find_by(user_id: @user.id).payload["title"]
    assert_includes stale_title, "San Francisco"

    # Second pass: the form resubmits the pre-filled (auto) title alongside
    # the edited destination and a new end date.
    post wizard_destination_path, params: {
      wizard: base_attrs(title: stale_title, destination: "Los Angeles, CA",
                         end_date: (@start + 6).to_s)
    }

    title = DraftTrip.find_by(user_id: @user.id).payload["title"]
    assert_includes title, "Los Angeles"
    assert_not_includes title, "San Francisco"
  end

  test "user-typed custom title survives a destination change" do
    post wizard_destination_path, params: { wizard: base_attrs(title: "Summer mega trip") }
    post wizard_destination_path, params: {
      wizard: base_attrs(title: "Summer mega trip", destination: "Los Angeles, CA")
    }
    assert_equal "Summer mega trip", DraftTrip.find_by(user_id: @user.id).payload["title"]
  end

  test "unchanged destination keeps the same auto title" do
    post wizard_destination_path, params: { wizard: base_attrs(title: "") }
    auto_title = DraftTrip.find_by(user_id: @user.id).payload["title"]

    post wizard_destination_path, params: { wizard: base_attrs(title: auto_title) }
    assert_equal auto_title, DraftTrip.find_by(user_id: @user.id).payload["title"]
  end

  private

  def base_attrs(overrides = {})
    {
      title:          "",
      destination:    "San Francisco, CA",
      origin:         "Salt Lake City, UT",
      start_date:     @start.to_s,
      end_date:       (@start + 5).to_s,
      traveler_count: "4"
    }.merge(overrides)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
