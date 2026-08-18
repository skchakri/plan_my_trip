require "test_helper"

class ReferralCreditTest < ActiveSupport::TestCase
  setup do
    @sharer = User.create!(email: "sharer@example.com", password: "password123", name: "Sharer")
    @saver  = User.create!(email: "saver@example.com",  password: "password123", name: "Saver")
  end

  test "grant! is idempotent per pair and refuses self-referral" do
    assert ReferralCredit.grant!(referrer: @sharer, referee: @saver)
    assert_nil ReferralCredit.grant!(referrer: @sharer, referee: @saver)
    assert_nil ReferralCredit.grant!(referrer: @sharer, referee: @sharer)
    assert_equal 1, ReferralCredit.count
  end

  test "both sides earn a bonus, capped" do
    ReferralCredit.grant!(referrer: @sharer, referee: @saver)
    assert_equal 1, ReferralCredit.bonus_for(@sharer)
    assert_equal 1, ReferralCredit.bonus_for(@saver)
    assert_equal 0, ReferralCredit.bonus_for(nil)
    assert ReferralCredit::MAX_PER_USER >= 1
  end

  test "BuildQuota adds referral bonus to the monthly allowance only" do
    AppSetting.set("TRIP_BUILD_MONTHLY_LIMIT", "2")
    AppSetting.set("TRIP_BUILD_DAILY_LIMIT", "1")
    q = BuildQuota.new(@sharer)
    assert_equal 2, q.monthly_limit
    ReferralCredit.grant!(referrer: @sharer, referee: @saver)
    assert_equal 3, BuildQuota.new(@sharer).monthly_limit
    assert_equal 1, BuildQuota.limit(BuildQuota::DAILY_KEY, BuildQuota::DAILY_DEFAULT)
  ensure
    AppSetting.set("TRIP_BUILD_MONTHLY_LIMIT", nil)
    AppSetting.set("TRIP_BUILD_DAILY_LIMIT", nil)
  end
end
