require "test_helper"

# Step 1 now asks for the commute (transport_mode) and must-include
# favourites; both must persist to the draft, survive to the Trip shell at
# create, and reach the trip_structure prompt as hard constraints.
class Trips::WizardTransportMustIncludesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "wt-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Tia")
    sign_in_as(@user)
  end

  test "save_destination persists transport_mode and cleaned must_includes to the draft" do
    post wizard_destination_path, params: { wizard: {
      destination: "Los Angeles", start_date: Date.current.to_s, end_date: (Date.current + 5).to_s,
      transport_mode: "own_car",
      must_includes: [ "Disneyland — 2 days", "  Yosemite  ", "", "Disneyland — 2 days", "LA beach" ]
    } }
    assert_redirected_to wizard_travelers_path
    draft = DraftTrip.find_by(user_id: @user.id)
    assert_equal "own_car", draft.payload["transport_mode"]
    assert_equal [ "Disneyland — 2 days", "Yosemite", "LA beach" ], draft.payload["must_includes"]
  end

  test "save_destination drops an unknown transport_mode instead of storing it" do
    post wizard_destination_path, params: { wizard: {
      destination: "Los Angeles", start_date: Date.current.to_s, end_date: (Date.current + 2).to_s,
      transport_mode: "jetpack"
    } }
    assert_redirected_to wizard_travelers_path
    draft = DraftTrip.find_by(user_id: @user.id)
    assert_nil draft.payload["transport_mode"]
  end

  test "save_destination caps must_includes at the model maximum" do
    post wizard_destination_path, params: { wizard: {
      destination: "Los Angeles", start_date: Date.current.to_s, end_date: (Date.current + 2).to_s,
      must_includes: (1..20).map { |i| "Favourite #{i}" }
    } }
    draft = DraftTrip.find_by(user_id: @user.id)
    assert_equal Trip::MUST_INCLUDES_MAX, draft.payload["must_includes"].size
  end

  test "create carries transport_mode and must_includes onto the Trip shell" do
    DraftTrip.create!(user: @user, payload: {
      "destination" => "Los Angeles", "origin" => "Salt Lake City",
      "start_date" => Date.current.to_s, "end_date" => (Date.current + 5).to_s,
      "people" => [ { "name" => "Tia" } ], "selected_slugs" => [],
      "transport_mode" => "own_car",
      "must_includes" => [ "Disneyland — 2 days", "Yosemite", "LA beach" ]
    })
    assert_enqueued_with(job: BuildTripJob) { post wizard_create_path }
    trip = Trip.order(:created_at).last
    assert_equal "own_car", trip.transport_mode
    assert_equal [ "Disneyland — 2 days", "Yosemite", "LA beach" ], trip.must_includes
  end

  test "review shows the commute and must-include favourites" do
    DraftTrip.create!(user: @user, payload: {
      "destination" => "Los Angeles", "start_date" => Date.current.to_s, "end_date" => (Date.current + 5).to_s,
      "people" => [ { "name" => "Tia" } ], "selected_slugs" => [],
      "transport_mode" => "flying", "must_includes" => [ "Disneyland — 2 days" ]
    })
    get wizard_review_path
    assert_response :success
    assert_match "Flying", response.body
    assert_match "Disneyland — 2 days", response.body
  end

  test "trip_structure prompt renders must-includes and the road-trip line for drivers" do
    capture_io { load Rails.root.join("db/seed_ai_prompts.rb").to_s }
    prompt = AiPrompt.find_by!(slug: "trip_structure.v1")
    rendered = prompt.render(
      destination: "Los Angeles", origin: "Salt Lake City",
      start_date_label: "Mon Jul 20, 2026", end_date_label: "Sat Jul 25, 2026", day_count: 6,
      transport_mode: "own_car", must_includes: [ "Disneyland — 2 days", "LA beach" ],
      pace: nil, budget: nil, preferences: nil, people: [], highlights: []
    )
    assert_match "Must-include favourites", rendered[:user]
    assert_match "- Disneyland — 2 days", rendered[:user]
    assert_match "- LA beach", rendered[:user]
    assert_match "Road trip: the Salt Lake City → Los Angeles drive", rendered[:user]
    assert_match "MUST-INCLUDE favourites are non-negotiable anchors", rendered[:system]
  end

  test "trip_structure prompt omits the road-trip line when flying" do
    capture_io { load Rails.root.join("db/seed_ai_prompts.rb").to_s }
    prompt = AiPrompt.find_by!(slug: "trip_structure.v1")
    rendered = prompt.render(
      destination: "Los Angeles", origin: "Salt Lake City",
      start_date_label: "Mon Jul 20, 2026", end_date_label: "Sat Jul 25, 2026", day_count: 6,
      transport_mode: "flying", must_includes: [],
      pace: nil, budget: nil, preferences: nil, people: [], highlights: []
    )
    assert_no_match(/Road trip:/, rendered[:user])
    assert_no_match(/Must-include favourites/, rendered[:user])
  end

  test "TripStructureBuilder fallback still seats must-includes across days" do
    structure = with_fake_ai("not json at all") do
      TripStructureBuilder.call(
        destination: "Los Angeles", origin: "Salt Lake City",
        start_date: Date.current, end_date: Date.current + 2,
        must_includes: [ "Disneyland — 2 days", "LA beach" ]
      )
    end
    titles = structure["days"].flat_map { |d| d["activities"].map { |a| a["title"] } }
    assert_includes titles, "Disneyland — 2 days"
    assert_includes titles, "LA beach"
  end

  test "must_includes setter strips, dedups, and drops blanks" do
    trip = Trip.new(must_includes: [ " Disneyland ", "Disneyland", "", nil, "Yosemite" ])
    assert_equal [ "Disneyland", "Yosemite" ], trip.must_includes
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
