require "test_helper"

class TripPreferencesTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "p-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Pat")
  end

  def trip(**attrs)
    @user.owned_trips.new({ title: "T", start_date: Date.current, end_date: Date.current + 1 }.merge(attrs))
  end

  test "accepts valid pace + budget" do
    assert trip(pace: "relaxed", budget: "luxury").valid?
  end

  test "blank pace/budget are allowed (no preference)" do
    assert trip(pace: "", budget: "").valid?
    assert trip(pace: nil, budget: nil).valid?
  end

  test "rejects out-of-range pace or budget" do
    refute trip(pace: "frantic").valid?
    refute trip(budget: "free").valid?
  end
end
