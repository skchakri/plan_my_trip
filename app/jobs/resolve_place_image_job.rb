require "digest"

# Resolves a stock photo (Pexels/Unsplash/Pixabay via LandmarkImageFinder) for a
# place name that has no Wikimedia image, and caches the URL for the lazy
# PlaceImagesController. Runs off-request so LandmarkImageFinder's provider
# throttle never blocks a web worker; pixabay first (1s throttle) keeps
# enrichment fast. Idempotent, and caches "none" for known misses so a place
# without any stock photo isn't re-resolved on every page view.
class ResolvePlaceImageJob < ApplicationJob
  queue_as :default

  CACHE_TTL = 30.days
  # Pixabay first: its 1s throttle keeps this off-request work fast, vs. Pexels
  # 19s / Unsplash 75s which are tuned for slow batch landmark seeding.
  PROVIDERS = %i[pixabay pexels unsplash].freeze

  def self.cache_key(name)
    "place_image/v1/#{Digest::SHA256.hexdigest(name.to_s.strip.downcase)}"
  end

  def perform(name, context = nil)
    name = name.to_s.strip
    return if name.blank?

    key = self.class.cache_key(name)
    return if Rails.cache.read(key).present? # already resolved (idempotent)

    # Pull a US state off a "City, State" destination string for disambiguation.
    state = context.to_s[/,\s*([A-Za-z][A-Za-z .]+)\z/, 1].to_s.strip
    # LandmarkImageFinder returns { url:, source:, attribution: } or nil.
    result = LandmarkImageFinder.call(name, state: state, providers: PROVIDERS)
    url = result.is_a?(Hash) ? result[:url] : result
    Rails.cache.write(key, url.presence || "none", expires_in: CACHE_TTL)
  end
end
