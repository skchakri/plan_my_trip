require "test_helper"

class PersonTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @older = @user.owned_trips.create!(title: "Old", destination: "Zion", start_date: Date.current, end_date: Date.current + 1)
    @newer = @user.owned_trips.create!(title: "New", destination: "Moab", start_date: Date.current + 10, end_date: Date.current + 12)
  end

  test "known_travelers_for keeps remembered interests when a newer row has none" do
    @older.people.create!(name: "Mani", age: 43, interests: [ "movies", "music" ], position: 0)
    # Newer trip saved without interests (e.g. chips never rendered) — must not
    # wipe what we already know.
    @newer.people.create!(name: "Mani", age: 43, interests: [], position: 0)
    Person.where(name: "Mani").update_all(updated_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    Person.find_by(trip: @newer, name: "Mani").touch

    mani = Person.known_travelers_for(@user).find { |t| t[:name] == "Mani" }
    assert_equal [ "movies", "music" ], mani[:interests]
    assert_equal({ "mani" => [ "movies", "music" ] }, Person.known_interests_for(@user).slice("mani"))
  end

  test "known_travelers_for still lets a newer non-empty list win" do
    @older.people.create!(name: "Kalyan", age: 45, interests: [ "sports" ], position: 0)
    k = @newer.people.create!(name: "Kalyan", age: 46, interests: [ "hiking" ], position: 0)
    Person.where(name: "Kalyan").where.not(id: k.id).update_all(updated_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

    kalyan = Person.known_travelers_for(@user).find { |t| t[:name] == "Kalyan" }
    assert_equal [ "hiking" ], kalyan[:interests]
    assert_equal 46, kalyan[:age]
    assert_equal [ "hiking" ], Person.known_interests_for(@user)["kalyan"]
  end
end
