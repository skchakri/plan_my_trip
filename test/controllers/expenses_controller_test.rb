require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "Owner")
    @member = User.create!(email: "m-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "Member")
    @stranger = User.create!(email: "s-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "Stranger")

    @trip = @owner.owned_trips.create!(title: "Trip", start_date: Date.current, end_date: Date.current + 2)
    @trip.trip_memberships.create!(user: @member, role: "member", accepted_at: Time.current)
    @alice = @trip.people.create!(name: "Alice", position: 0)
    @bob   = @trip.people.create!(name: "Bob", position: 1)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  test "a member can view the ledger" do
    sign_in_as(@member)
    get trip_expenses_path(@trip)
    assert_response :success
  end

  test "a stranger cannot view the ledger" do
    sign_in_as(@stranger)
    get trip_expenses_path(@trip)
    assert_response :redirect
  end

  test "a member can add an expense with a dollar amount" do
    sign_in_as(@member)
    assert_difference -> { @trip.expenses.count }, +1 do
      post trip_expenses_path(@trip), params: {
        expense: { description: "Dinner", amount: "42.00", currency: "USD",
                   paid_by_id: @alice.id, split_between: [ @alice.id, @bob.id ] }
      }
    end
    e = @trip.expenses.order(:created_at).last
    assert_equal 4200, e.amount_cents
    assert_equal @member.id, e.created_by_id
    assert_equal [ @alice.id.to_s, @bob.id.to_s ], e.split_between
  end

  test "invalid expense re-renders with an error" do
    sign_in_as(@member)
    assert_no_difference -> { @trip.expenses.count } do
      post trip_expenses_path(@trip), params: { expense: { description: "", amount: "0" } }
    end
    assert_response :unprocessable_entity
  end

  test "the logger can remove their own expense" do
    sign_in_as(@member)
    e = @trip.expenses.create!(description: "X", amount_cents: 100, paid_by: @alice, created_by: @member)
    assert_difference -> { @trip.expenses.kept.count }, -1 do
      delete trip_expense_path(@trip, e)
    end
  end

  test "a member cannot remove someone else's expense, but the owner can" do
    e = @trip.expenses.create!(description: "X", amount_cents: 100, paid_by: @alice, created_by: @owner)

    sign_in_as(@member)
    delete trip_expense_path(@trip, e)
    refute e.reload.discarded?

    reset! # drop the member session before switching users
    sign_in_as(@owner)
    delete trip_expense_path(@trip, e)
    assert e.reload.discarded?
  end
end
