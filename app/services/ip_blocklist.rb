# Admin-managed IP blocklist consulted by Rack::Attack on every request.
# The list lives in the BLOCKED_IPS AppSetting (/admin/app_settings) as
# comma/whitespace-separated IPv4/IPv6 addresses or CIDR ranges, e.g.
# "203.0.113.7, 198.51.100.0/24" — editable live, no redeploy.
class IpBlocklist
  SETTING_KEY = "BLOCKED_IPS".freeze

  class << self
    def blocked?(ip)
      return false if ip.blank?

      addr = IPAddr.new(ip)
      ranges.any? { |range| range.include?(addr) }
    rescue IPAddr::InvalidAddressError
      false
    end

    # Parsed ranges, memoized against the raw setting value — AppSetting.get is
    # already cache-backed, so a warm request costs one cache read + a string
    # compare, and an admin edit (new raw value) reparses automatically.
    def ranges
      raw = AppSetting.get(SETTING_KEY).to_s
      memo = @parsed
      return memo[1] if memo && memo[0] == raw

      parsed = parse(raw)
      @parsed = [ raw, parsed ]
      parsed
    end

    def parse(raw)
      raw.to_s.split(/[,\s]+/).filter_map do |entry|
        next if entry.blank?

        begin
          IPAddr.new(entry)
        rescue IPAddr::InvalidAddressError
          Rails.logger.warn("[ip-blocklist] ignoring invalid entry #{entry.inspect}")
          nil
        end
      end
    end

    def reset!
      @parsed = nil
    end
  end
end
