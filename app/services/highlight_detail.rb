# Generates richer "exciting" detail content for a single highlight (a place
# the user might tap on in the wizard). The prompt + model + provider live
# in the DB (AiPrompt slug `highlight_detail.v1`) so they can be tuned via
# the admin UI without a deploy.
#
# Returns a Hash with string keys ready to send as JSON to the client.
# Falls back to a minimal {summary, category} hash when the AI call fails.
class HighlightDetail
  PROMPT_SLUG = "highlight_detail.v1".freeze
  CACHE_TTL = 30.days

  def self.call(...)
    new(...).call
  end

  def initialize(destination:, name:, category: nil, summary: nil)
    @destination = destination.to_s.strip
    @name = name.to_s.strip
    @category = category.to_s.strip
    @summary = summary.to_s.strip
  end

  def call
    return fallback if @name.blank? || @destination.blank?
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_detail }
  end

  private

  def cache_key
    "highlight_detail/v2/#{Digest::SHA256.hexdigest("#{@destination.downcase}|#{@name.downcase}")}"
  end

  def fetch_detail
    result = Ai::Caller.call(
      slug: PROMPT_SLUG,
      variables: { destination: @destination, name: @name, category: @category, summary: @summary }
    )
    parsed = result.json
    return fallback unless parsed.is_a?(Hash)
    coerce(parsed)
  end

  def coerce(hash)
    hash["things_to_do"] = Array(hash["things_to_do"])
    hash["why_youll_love_it"] = Array(hash["why_youll_love_it"])
    hash["pro_tips"] = Array(hash["pro_tips"])
    hash["perfect_for"] = Array(hash["perfect_for"])
    hash
  end

  def fallback
    {
      "tagline" => nil,
      "overview" => @summary.presence,
      "things_to_do" => [],
      "why_youll_love_it" => [],
      "best_time" => nil,
      "pro_tips" => [],
      "perfect_for" => Array(@category.presence)
    }
  end
end
