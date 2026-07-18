require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "O")
    @trip = @owner.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 1)
    @p1 = @trip.people.create!(name: "P1", position: 0)
    @p2 = @trip.people.create!(name: "P2", position: 1)
  end

  test "amount= parses dollars into cents; amount reads back" do
    e = @trip.expenses.new(description: "X", currency: "USD", paid_by: @p1)
    e.amount = "12.50"
    assert_equal 1250, e.amount_cents
    assert_in_delta 12.50, e.amount, 0.001
  end

  test "amount= tolerates a currency symbol and commas" do
    e = @trip.expenses.new(description: "X", paid_by: @p1)
    e.amount = "$1,234.00"
    assert_equal 123_400, e.amount_cents
  end

  test "requires a positive amount and a description" do
    refute @trip.expenses.new(description: "", amount_cents: 100).valid?
    refute @trip.expenses.new(description: "ok", amount_cents: 0).valid?
    assert @trip.expenses.new(description: "ok", amount_cents: 100, currency: "USD").valid?
  end

  test "currency is upcased and defaults to USD" do
    e = @trip.expenses.create!(description: "X", amount_cents: 100, currency: "eur", paid_by: @p1)
    assert_equal "EUR", e.currency
    e2 = @trip.expenses.create!(description: "Y", amount_cents: 100, paid_by: @p1)
    assert_equal "USD", e2.currency
  end

  test "split_person_ids defaults to everyone when unset and filters stale ids" do
    all = [ @p1.id.to_s, @p2.id.to_s ]
    e = @trip.expenses.new(description: "X", amount_cents: 100)
    assert_equal all.sort, e.split_person_ids(all).sort

    e.split_between = [ @p1.id.to_s, "ghost" ]
    assert_equal [ @p1.id.to_s ], e.split_person_ids(all)
  end

  test "compact_split strips blanks and dupes" do
    e = @trip.expenses.create!(description: "X", amount_cents: 100, paid_by: @p1,
                               split_between: [ @p1.id.to_s, "", @p1.id.to_s, @p2.id.to_s ])
    assert_equal [ @p1.id.to_s, @p2.id.to_s ], e.split_between
  end
end
