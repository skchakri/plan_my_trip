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

    ### Admin-managed IP blocklist (/admin/app_settings → BLOCKED_IPS) ###
    # Safelists always win over blocklists in Rack::Attack, so localhost above
    # can never lock itself out.
    blocklist("blocked ips") do |req|
      IpBlocklist.blocked?(req.ip)
    end

    ### Auto-ban IPs hammering the login endpoint ###
    # The logins/ip throttle below slows a brute-forcer to 10/min; this bans an
    # IP outright for an hour once it has made 20 login POSTs inside 10 minutes
    # (counted at the middleware layer, so "attempts", not "failures").
    blocklist("fail2ban/logins") do |req|
      Rack::Attack::Fail2Ban.filter(
        "login-ban-#{req.ip}", maxretry: 20, findtime: 10.minutes, bantime: 1.hour
      ) do
        req.path == "/users/sign_in" && req.post?
      end
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
end
