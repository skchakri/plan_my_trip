require "test_helper"

class IpBlocklistTest < ActiveSupport::TestCase
  setup { IpBlocklist.reset! }
  teardown { IpBlocklist.reset! }

  def set_blocklist(raw)
    AppSetting.set("BLOCKED_IPS", raw)
  end

  test "nothing is blocked when the setting is blank" do
    assert_not IpBlocklist.blocked?("203.0.113.7")
  end

  test "blocks an exact IPv4 match and passes others" do
    set_blocklist("203.0.113.7")

    assert IpBlocklist.blocked?("203.0.113.7")
    assert_not IpBlocklist.blocked?("203.0.113.8")
  end

  test "blocks any address inside a CIDR range" do
    set_blocklist("198.51.100.0/24")

    assert IpBlocklist.blocked?("198.51.100.1")
    assert IpBlocklist.blocked?("198.51.100.254")
    assert_not IpBlocklist.blocked?("198.51.101.1")
  end

  test "accepts comma, space, and newline separated entries" do
    set_blocklist("203.0.113.7, 198.51.100.0/24\n192.0.2.99")

    assert IpBlocklist.blocked?("203.0.113.7")
    assert IpBlocklist.blocked?("198.51.100.50")
    assert IpBlocklist.blocked?("192.0.2.99")
    assert_not IpBlocklist.blocked?("192.0.2.98")
  end

  test "blocks IPv6 addresses and ranges" do
    set_blocklist("2001:db8::/32")

    assert IpBlocklist.blocked?("2001:db8::1")
    assert_not IpBlocklist.blocked?("2001:db9::1")
  end

  test "ignores invalid entries without breaking valid ones" do
    set_blocklist("not-an-ip, 203.0.113.7, 999.999.999.999")

    assert IpBlocklist.blocked?("203.0.113.7")
    assert_not IpBlocklist.blocked?("192.0.2.1")
  end

  test "an unparseable request IP is never blocked" do
    set_blocklist("203.0.113.0/24")

    assert_not IpBlocklist.blocked?("garbage")
    assert_not IpBlocklist.blocked?(nil)
    assert_not IpBlocklist.blocked?("")
  end

  test "editing the setting takes effect without a restart" do
    set_blocklist("203.0.113.7")
    assert IpBlocklist.blocked?("203.0.113.7")

    set_blocklist("192.0.2.1")
    assert_not IpBlocklist.blocked?("203.0.113.7")
    assert IpBlocklist.blocked?("192.0.2.1")
  end

  test "parse returns IPAddr ranges and skips blanks" do
    ranges = IpBlocklist.parse(" 203.0.113.7 ,, 198.51.100.0/24 ")

    assert_equal 2, ranges.length
    assert ranges.all? { |r| r.is_a?(IPAddr) }
  end
end
