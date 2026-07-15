require "test_helper"

class BuildQuotaTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "q-#{SecureRandom.hex(4)}@test.example",
      password: "password123", name: "Quota Tester"
    )
  end

  def build_trip!(owner: @user, created_at: Time.current)
    owner.owned_trips.create!(
      title: "Trip #{SecureRandom.hex(2)}",
      destination: "Moab, UT",
      start_date: Date.new(2026, 6, 1),
      end_date:   Date.new(2026, 6, 2),
      created_at: created_at
    )
  end

  test "a fresh account is under quota" do
    assert_not BuildQuota.new(@user).exceeded?
  end

  test "hitting the daily limit trips the quota" do
    BuildQuota::DAILY_DEFAULT.to_i.times { build_trip! }

    quota = BuildQuota.new(@user)
    assert quota.exceeded?
    assert quota.daily_exceeded?
    assert_match(/24 hours/, quota.message)
  end

  test "builds older than the daily window do not count against it" do
    BuildQuota::DAILY_DEFAULT.to_i.times { build_trip!(created_at: 25.hours.ago) }

    assert_not BuildQuota.new(@user).daily_exceeded?
  end

  test "discarded trips still count so delete-and-rebuild cannot loop around the cap" do
    BuildQuota::DAILY_DEFAULT.to_i.times { build_trip!.discard! }

    assert BuildQuota.new(@user).exceeded?
  end

  test "the monthly limit trips once the rolling 30 days fill up" do
    # Spread them outside the 24h window so it's unambiguously the monthly cap.
    BuildQuota::MONTHLY_DEFAULT.to_i.times { |i| build_trip!(created_at: (i + 2).days.ago) }

    quota = BuildQuota.new(@user)
    assert_not quota.daily_exceeded?
    assert quota.monthly_exceeded?
    assert_match(/this month/, quota.message)
  end

  test "admins are exempt" do
    admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@test.example",
      password: "password123", name: "Admin", admin: true
    )
    (BuildQuota::MONTHLY_DEFAULT.to_i + 1).times { build_trip!(owner: admin) }

    assert BuildQuota.new(admin).exempt?
    assert_not BuildQuota.new(admin).exceeded?
  end

  test "another account's builds do not count against this one" do
    other = User.create!(
      email: "other-#{SecureRandom.hex(4)}@test.example",
      password: "password123", name: "Other"
    )
    (BuildQuota::DAILY_DEFAULT.to_i + 1).times { build_trip!(owner: other) }

    assert_not BuildQuota.new(@user).exceeded?
  end

  test "limit falls back to the default when unset, and parses an override" do
    # No DB row and no ENV for this key → the registry/BuildQuota default.
    assert_equal BuildQuota::DAILY_DEFAULT.to_i, BuildQuota.limit(BuildQuota::DAILY_KEY, BuildQuota::DAILY_DEFAULT)
    # A blank override must not read as 0 (which would disable the cap by accident).
    assert_equal 7, BuildQuota.limit("NOPE_UNSET_KEY_#{SecureRandom.hex(2)}", "7")
  end
end
