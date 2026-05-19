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

    ### Log throttled requests ###
    ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
      req = payload[:request]
      Rails.logger.warn(
        "[rack-attack] throttled ip=#{req.ip} path=#{req.path} matched=#{req.env['rack.attack.matched']}"
      )
    end
  end
end
