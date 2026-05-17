require "digest"

# Fetches a one-card honest pitch for a destination — the tagline + 2-3
# sentence character paragraph + practical watch-outs + best-for tags shown
# above the highlights grid on the wizard's "Pick the must-sees" step.
#
# Generic across any destination (tiny town, neighborhood, national park,
# major city). Powered by the admin-editable prompt `destination_brief.v1`.
# Result cached 30 days per (destination, vibes) pair.
class DestinationBrief
  CACHE_TTL = 30.days

  Brief = Struct.new(:tagline, :pitch, :watchouts, :best_for, keyword_init: true) do
    def empty?
      tagline.to_s.strip.blank? && pitch.to_s.strip.blank?
    end

    def to_h
      { tagline: tagline, pitch: pitch, watchouts: Array(watchouts), best_for: Array(best_for) }
    end
  end

  EMPTY = Brief.new(tagline: nil, pitch: nil, watchouts: [], best_for: []).freeze

  def self.call(destination, vibes: [])
    new(destination, vibes: vibes).call
  end

  def initialize(destination, vibes: [])
    @destination = destination.to_s.strip
    @vibes = Array(vibes).map { |v| v.to_s.strip.downcase }.reject(&:blank?)
  end

  def call
    return EMPTY if @destination.blank?
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch }
  end

  private

  def cache_key
    digest = Digest::SHA256.hexdigest("#{@destination.downcase}|#{@vibes.sort.join(',')}")
    "destination_brief/v1/#{digest}"
  end

  def fetch
    result = Ai::Caller.call(
      slug: "destination_brief.v1",
      variables: { destination: @destination, vibes: @vibes }
    )
    payload = result.json
    return EMPTY unless payload.is_a?(Hash)

    Brief.new(
      tagline: payload["tagline"].to_s.strip.presence,
      pitch: payload["pitch"].to_s.strip.presence,
      watchouts: Array(payload["watchouts"]).map { |w| w.to_s.strip }.reject(&:blank?),
      best_for: Array(payload["best_for"]).map { |b| b.to_s.strip.downcase }.reject(&:blank?)
    )
  rescue => e
    Rails.logger.warn("[DestinationBrief] #{@destination}: #{e.class}: #{e.message}")
    EMPTY
  end
end
