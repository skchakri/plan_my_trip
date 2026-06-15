require "test_helper"

class ChecklistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    @item = @trip.checklist_items.create!(scope: "before_trip", title: "Pack passport", category: "Documents")
    sign_in_as(@owner)
  end

  test "inline edit updates title, person and category" do
    patch trip_checklist_item_path(@trip, @item),
          params: { checklist_item: { title: "Pack passports", person: "Olive", category: "Docs" } }
    @item.reload
    assert_equal "Pack passports", @item.title
    assert_equal "Olive", @item.person
    assert_equal "Docs", @item.category
  end

  test "destroy soft-deletes (discards) instead of hard delete" do
    assert_difference -> { @trip.checklist_items.kept.count }, -1 do
      delete trip_checklist_item_path(@trip, @item)
    end
    assert @item.reload.discarded?
    assert_equal 1, @trip.checklist_items.count # row still present
  end

  test "restore undiscards a soft-deleted item" do
    @item.discard
    patch restore_trip_checklist_item_path(@trip, @item)
    assert @item.reload.kept?
  end

  test "checklist page hides discarded items" do
    @item.discard
    @kept = @trip.checklist_items.create!(scope: "before_trip", title: "Sunscreen")
    get checklist_trip_path(@trip)
    assert_response :success
    assert_includes response.body, "Sunscreen"
    assert_not_includes response.body, "Pack passport"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
