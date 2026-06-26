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

  # Authorization boundary — plain members (viewers) may collaborate but cannot
  # change the plan, so checklist mutations must be denied and leave rows
  # untouched. Pundit denials redirect (302) rather than mutate.
  test "plain member cannot create a checklist item" do
    sign_in_as(member)
    assert_no_difference -> { @trip.checklist_items.count } do
      post trip_checklist_items_path(@trip),
           params: { checklist_item: { scope: "before_trip", title: "Snacks", category: "Food" } }
    end
    assert_redirected_to root_path
  end

  test "plain member cannot update a checklist item" do
    sign_in_as(member)
    patch trip_checklist_item_path(@trip, @item),
          params: { checklist_item: { title: "Hijacked", packed: true } }
    @item.reload
    assert_equal "Pack passport", @item.title
    assert_not @item.packed
    assert_redirected_to root_path
  end

  test "plain member cannot destroy a checklist item" do
    sign_in_as(member)
    delete trip_checklist_item_path(@trip, @item)
    assert @item.reload.kept?
    assert_redirected_to root_path
  end

  test "plain member cannot restore a checklist item" do
    @item.discard
    sign_in_as(member)
    patch restore_trip_checklist_item_path(@trip, @item)
    assert @item.reload.discarded?
    assert_redirected_to root_path
  end

  # Editors have edit rights (parity with the owner), proving the fix gates on
  # edit rights, not ownership.
  test "editor can create, update and destroy a checklist item" do
    sign_in_as(editor)

    assert_difference -> { @trip.checklist_items.count }, 1 do
      post trip_checklist_items_path(@trip),
           params: { checklist_item: { scope: "before_trip", title: "Charger", category: "Tech" } }
    end

    patch trip_checklist_item_path(@trip, @item),
          params: { checklist_item: { title: "Pack passports" } }
    assert_equal "Pack passports", @item.reload.title

    delete trip_checklist_item_path(@trip, @item)
    assert @item.reload.discarded?
  end

  private

  def sign_in_as(user)
    # Sign out any current session first — Devise's require_no_authentication
    # would otherwise skip re-login and keep the previously signed-in user.
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  def member
    @member ||= create_collaborator("member")
  end

  def editor
    @editor ||= create_collaborator("editor")
  end

  def create_collaborator(role)
    user = User.create!(email: "#{role}-#{SecureRandom.hex(4)}@test.example", password: "password123", name: role.capitalize)
    @trip.trip_memberships.create!(user: user, role: role, accepted_at: Time.current)
    user
  end
end
