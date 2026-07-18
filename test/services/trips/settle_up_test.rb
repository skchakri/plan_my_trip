require "test_helper"

class Trips::SettleUpTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "O")
    @trip = @owner.owned_trips.create!(title: "Trip", start_date: Date.current, end_date: Date.current + 2)
    @alice = @trip.people.create!(name: "Alice", position: 0)
    @bob   = @trip.people.create!(name: "Bob", position: 1)
    @carol = @trip.people.create!(name: "Carol", position: 2)
  end

  def expense(desc, cents, payer, currency: "USD", split: [])
    @trip.expenses.create!(description: desc, amount_cents: cents, currency: currency,
                           paid_by: payer, split_between: split.map(&:id))
  end

  test "splits evenly and produces the minimal transfer set" do
    expense("Dinner", 3000, @alice) # split among all 3 → each owes 1000
    expense("Gas", 1500, @bob)      # split among all 3 → each owes 500

    group = Trips::SettleUp.new(@trip).groups.first
    assert_equal "USD", group.currency
    assert_equal 4500, group.total_cents

    nets = group.balances.to_h { |b| [ b.person.name, b.net_cents ] }
    assert_equal 1500,  nets["Alice"]
    assert_equal 0,     nets["Bob"]
    assert_equal(-1500, nets["Carol"])

    assert_equal 1, group.transfers.size
    t = group.transfers.first
    assert_equal "Carol", t.from.name
    assert_equal "Alice", t.to.name
    assert_equal 1500, t.amount_cents
  end

  test "an explicit split limits who shares the cost" do
    expense("Alice + Bob lunch", 2000, @alice, split: [ @alice, @bob ]) # 1000 each, Carol none

    group = Trips::SettleUp.new(@trip).groups.first
    nets = group.balances.to_h { |b| [ b.person.name, b.net_cents ] }
    assert_equal 1000, nets["Alice"] # paid 2000, owes 1000
    assert_equal(-1000, nets["Bob"])
    assert_equal 0, nets["Carol"]    # not part of the split
  end

  test "remainder cents are distributed so shares sum exactly" do
    expense("Odd", 1000, @alice) # 1000 / 3 = 334 + 333 + 333
    group = Trips::SettleUp.new(@trip).groups.first
    shares = group.balances.map(&:share_cents).sort
    assert_equal [ 333, 333, 334 ], shares
    assert_equal 1000, shares.sum
  end

  test "different currencies settle independently" do
    expense("USD dinner", 3000, @alice)
    expense("EUR train", 900, @bob, currency: "EUR")

    groups = Trips::SettleUp.new(@trip).groups
    assert_equal %w[EUR USD], groups.map(&:currency)
  end

  test "all-square trip yields no transfers" do
    expense("A", 900, @alice)
    expense("B", 900, @bob)
    expense("C", 900, @carol)
    group = Trips::SettleUp.new(@trip).groups.first
    assert_empty group.transfers
  end

  test "an expense whose payer was deleted still counts toward the total but not the settle math" do
    dave = @trip.people.create!(name: "Dave", position: 3)
    expense("Dave paid", 400, dave)
    dave.destroy # FK nullifies paid_by

    group = Trips::SettleUp.new(@trip).groups.first
    assert_equal 400, group.total_cents
    # No transfers — the only expense's payer is gone, so nothing reconciles.
    assert_empty group.transfers
  end
end
