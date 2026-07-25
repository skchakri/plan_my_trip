# Rack::Attack throttles for unauthenticated / public endpoints.
#
# Cache store: uses Rails.cache (Solid Cache, DB-backed) so throttle counters
# survive process restarts. For higher-volume traffic, swap to a Redis-backed
# store via Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(...).
#
# Disabled in development/test so local hammering doesn't 429.

if Rails.env.production?
  class Rack::Attack
    ### Cache store ###
    self.cache.store = Rails.cache

    ### Allow internal/healthcheck IPs through unconditionally ###
    safelist("allow from localhost") do |req|
      %w[127.0.0.1 ::1].include?(req.ip)
    end

    ### Operator/trusted IP allowlist (RACK_ATTACK_SAFELIST, comma/space-sep) ###
    # Safelists win over every throttle and blocklist below, so a trusted IP
    # (e.g. the operator) can never be locked out by the login fail2ban. Env so
    # it can be changed/removed without a code edit.
    safelist("trusted ip allowlist") do |req|
      ENV["RACK_ATTACK_SAFELIST"].to_s.split(/[\s,]+/).reject(&:empty?).include?(req.ip)
    end

    ### Admin-managed IP blocklist (/admin/app_settings → BLOCKED_IPS) ###
    # Safelists always win over blocklists in Rack::Attack, so localhost above
    # can never lock itself out.
    blocklist("blocked ips") do |req|
      IpBlocklist.blocked?(req.ip)
    end

    ### Auto-ban IPs with too many FAILED logins ###
    # Bans an IP only after repeated *authentication failures* (bad password /
    # unknown email), counted by the Warden before_failure hook at the bottom of
    # this file — NOT by raw request volume. A SUCCESSFUL sign-in never trips it,
    # so a correct password always gets through no matter how many times the IP
    # has hit /users/sign_in (this was the old fail2ban's fatal flaw: it counted
    # every POST, locking out legit users on shared/rotating IPs). The logins/ip
    # throttle below still caps raw attempt volume at 10/min.
    blocklist("failed-logins") do |req|
      req.path == "/users/sign_in" && req.post? &&
        Rails.cache.read("failed-login-ban/#{req.ip}").present?
    end

    ### Public share links — token routes are guessable-resistant but bots crawl ###
    throttle("public_trip/ip", limit: 60, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/s/")
    end

    ### Public SEO place pages + sitemap ###
    throttle("public_place/ip", limit: 120, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/p/") || req.path == "/places-sitemap.xml"
    end

    ### Blog (public marketing pages) ###
    throttle("blog/ip", limit: 120, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/blog")
    end

    ### Invitation magic links ###
    throttle("invitations/ip", limit: 30, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/invitations")
    end

    ### Devise — sign-in / sign-up brute force ###
    throttle("logins/ip", limit: 10, period: 1.minute) do |req|
      req.ip if req.path == "/users/sign_in" && req.post?
    end

    throttle("logins/email", limit: 10, period: 1.minute) do |req|
      if req.path == "/users/sign_in" && req.post?
        req.params.dig("user", "email").to_s.downcase.presence
      end
    end

    throttle("signups/ip", limit: 5, period: 1.hour) do |req|
      req.ip if req.path == "/users" && req.post?
    end

    ### Global fall-through for hot crawlers ###
    throttle("req/ip", limit: 300, period: 1.minute) do |req|
      req.ip unless req.path.start_with?("/assets", "/packs", "/rails/active_storage")
    end

    ### Response ###
    self.throttled_responder = lambda do |request|
      match_data = request.env["rack.attack.match_data"] || {}
      retry_after = (match_data[:period] || 60).to_s
      [
        429,
        { "Content-Type" => "text/plain", "Retry-After" => retry_after },
        [ "Too many requests. Try again in #{retry_after}s.\n" ]
      ]
    end

    self.blocklisted_responder = lambda do |_request|
      [
        403,
        { "Content-Type" => "text/plain" },
        [ "Forbidden.\n" ]
      ]
    end

    ### Log throttled requests ###
    ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
      req = payload[:request]
      Rails.logger.warn(
        "[rack-attack] throttled ip=#{req.ip} path=#{req.path} matched=#{req.env['rack.attack.matched']}"
      )
    end

    ### Log blocked requests ###
    ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _id, payload|
      req = payload[:request]
      Rails.logger.warn(
        "[rack-attack] blocked ip=#{req.ip} path=#{req.path} matched=#{req.env['rack.attack.matched']}"
      )
    end
  end

  # Count FAILED logins only, feeding the "failed-logins" blocklist above.
  # Warden fires before_failure on every failed authentication (and only then —
  # a correct password bypasses it entirely), so we tick a per-IP failure
  # counter here and set a short ban once it crosses the limit. Uses plain
  # Rails.cache keys (same store Rack::Attack reads) — no raw fail2ban internals.
  FAILED_LOGIN_LIMIT = 15       # failures within the window before a ban
  FAILED_LOGIN_WINDOW = 10.minutes
  FAILED_LOGIN_BAN = 15.minutes

  Warden::Manager.before_failure do |env, _opts|
    req = ActionDispatch::Request.new(env)
    next unless req.path == "/users/sign_in" && req.post?

    key = "failed-login-count/#{req.ip}"
    count = Rails.cache.read(key).to_i + 1
    Rails.cache.write(key, count, expires_in: FAILED_LOGIN_WINDOW)
    if count >= FAILED_LOGIN_LIMIT
      Rails.cache.write("failed-login-ban/#{req.ip}", true, expires_in: FAILED_LOGIN_BAN)
    end
  end
end
