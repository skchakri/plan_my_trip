require "test_helper"

class CountryForDestinationTest < ActiveSupport::TestCase
  setup do
    @france = Country.create!(name: "France", capital: "Paris", iso2: "fr")
    @japan = Country.create!(name: "Japan", capital: "Tokyo", iso2: "jp")
    Country.create!(name: "Chad", capital: "N'Djamena", iso2: "td")
  end

  test "matches the country named in a destination string" do
    assert_equal @france, Country.for_destination("Paris, France")
    assert_equal @japan, Country.for_destination("Tokyo, Japan")
  end

  test "matches whole words only" do
    # "Chadds Ford, PA" should NOT match Chad
    assert_nil Country.for_destination("Chadds Ford, PA")
  end

  test "returns nil for blank or unmatched destinations" do
    assert_nil Country.for_destination("")
    assert_nil Country.for_destination("Springdale, UT")
  end
end
