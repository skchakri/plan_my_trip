# frozen_string_literal: true

require "net/http"

# IndexNow (indexnow.org) — push-notifies Bing, DuckDuckGo, Yandex, Naver, Seznam
# the moment a public URL is published/changed, instead of waiting for a crawl.
# Google doesn't participate (it needs Search Console + the sitemap), but for the
# rest of the search market this is free, instant indexing.
#
# Setup: `INDEXNOW_KEY` at /admin/app_settings (any 32-hex string; `IndexNow.ensure_key!`
# generates one). The key file is served at /<key>.txt by PagesController#indexnow_key.
# Blank key → every call is a silent no-op, so dev/test never phone home.
class IndexNow
  ENDPOINT = URI("https://api.indexnow.org/indexnow")
  HOST     = "wanderply.com"
  MAX_URLS = 10_000 # protocol limit per POST

  Result = Struct.new(:ok, :status, :submitted, keyword_init: true)

  def self.key = AppSetting.get("INDEXNOW_KEY").to_s.strip.presence

  def self.enabled? = key.present? && Rails.env.production?

  # Generate + persist a key if none is set. Idempotent.
  def self.ensure_key!
    key || SecureRandom.hex(16).tap { |k| AppSetting.set("INDEXNOW_KEY", k) }
  end

  # Submit one or many absolute URLs. Non-production or unkeyed → no-op.
  def self.submit(urls)
    list = Array(urls).map(&:to_s).select { |u| u.start_with?("https://#{HOST}/", "https://#{HOST}") }.uniq.first(MAX_URLS)
    return Result.new(ok: false, status: :disabled, submitted: 0) unless enabled? && list.any?

    body = { host: HOST, key: key, keyLocation: "https://#{HOST}/#{key}.txt", urlList: list }
    req = Net::HTTP::Post.new(ENDPOINT, "Content-Type" => "application/json; charset=utf-8")
    req.body = body.to_json
    res = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(req) }
    ok = res.code.to_i.between?(200, 299)
    Rails.logger.info("[IndexNow] #{res.code} for #{list.size} url(s)")
    Result.new(ok: ok, status: res.code.to_i, submitted: list.size)
  rescue StandardError => e
    Rails.logger.warn("[IndexNow] #{e.class}: #{e.message}")
    Result.new(ok: false, status: :error, submitted: 0)
  end

  # Every public, indexable URL — the union of the three sitemaps.
  def self.all_public_urls
    h = Rails.application.routes.url_helpers
    opts = { host: HOST, protocol: "https" }
    urls = [
      h.root_url(**opts), h.about_url(**opts), h.blog_index_url(**opts), h.road_trips_url(**opts),
      h.quizzes_url(**opts), h.quiz_explore_url(**opts)
    ]
    urls += BlogPost.published.pluck(:slug).map { |s| h.blog_url(s, **opts) }
    urls += RoadTrip.published.pluck(:slug).map { |s| h.road_trip_url(s, **opts) }
    urls += QuizCatalog.keys.map { |k| h.quiz_url(k, **opts) }
    if defined?(Place)
      urls += Place.kept.where.not(slug: nil).where.not(image_url: nil).pluck(:slug).map { |s| h.public_place_url(s, **opts) }
    end
    urls.uniq
  end
end
