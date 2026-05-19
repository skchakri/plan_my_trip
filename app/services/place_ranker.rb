require "set"

# Composite ranking for a list of place "cards" (Highlight, Idea, or any
# struct that responds to name/tags/category/usage_count/distance_km/
# wikipedia_url/community_rating/community_rating_count).
#
# Stamps each item with:
#   - rank          (1-indexed position in the returned, sorted array)
#   - score         (0-100 composite)
#   - tier          ("must-see" | "worth-it" | "bonus")
#   - rating        (0-5 float — community rating if any, else derived
#                    "editor score" so cards always have a star value)
#   - score_breakdown (Hash of component contributions for debugging /
#                      tooltip use later)
#
# Weights are tuned so:
#   - A famous, catalog-backed, on-vibe spot beats an obscure off-vibe one
#   - Real community ratings can override the algorithmic score once a
#     few people have weighed in (capped at +30 from the cold start)
#   - Distance is only weighted when the caller passed an anchor — for
#     destination-wide highlights it's neutral
class PlaceRanker
  # Tier cutoffs on the 0..100 composite score. A fresh LLM hit with no
  # community rating and one interest match scores around 35-40, so the
  # absolute cutoffs are calibrated to flag a place as "must-see" only
  # when it picks up *some* additional signal (Wikipedia article, catalog
  # usage, community love, multi-interest match).
  TIER_MUST_SEE = 55
  TIER_WORTH_IT = 38

  # Hard guarantee: top N items are always at least "worth-it" — even
  # when the absolute scores are flat, the leaderboard still has visual
  # separation. (Top-3 must-see, next-5 worth-it, rest as-scored.)
  GUARANTEED_MUST_SEE_TOP = 3
  GUARANTEED_WORTH_IT_TOP = 8

  def self.rank!(items, interests: [], anchor_lat: nil, anchor_lng: nil)
    new(items, interests: interests, anchor_lat: anchor_lat, anchor_lng: anchor_lng).rank!
  end

  def initialize(items, interests: [], anchor_lat: nil, anchor_lng: nil)
    @items = Array(items)
    @interests = Array(interests).map { |i| i.to_s.strip.downcase }.reject(&:blank?).uniq.to_set
    @anchor_lat = anchor_lat
    @anchor_lng = anchor_lng
    @has_distance = @items.any? { |i| i.respond_to?(:distance_km) && i.distance_km.present? }
  end

  def rank!
    scored = @items.map { |item| [ item, score_for(item) ] }
    scored.sort_by! { |(_, s)| -s[:total] }
    scored.each_with_index do |(item, s), idx|
      stamp(item, :rank,             idx + 1)
      stamp(item, :score,            s[:total])
      stamp(item, :tier,             tier_for(s[:total], idx))
      stamp(item, :rating,           rating_for(item, s[:total]))
      stamp(item, :score_breakdown,  s)
    end
    scored.map(&:first)
  end

  private

  # 0..100 composite. Components:
  #   popularity       0..30  (catalog usage, Wikipedia article, "iconic" tag)
  #   interest_match   0..30  (overlap with caller-supplied interests / vibes)
  #   distance         0..20  (only when anchor + distance_km known; else neutral 12)
  #   community        0..30  (community rating × log(count), additive bonus)
  def score_for(item)
    pop = popularity_score(item)        # 0..30
    int = interest_score(item)          # 0..30
    dis = distance_score(item)          # 0..20
    com = community_score(item)         # 0..30
    raw = pop + int + dis + com
    total = [ raw, 100 ].min.round(1)
    { total: total, popularity: pop, interest: int, distance: dis, community: com }
  end

  def popularity_score(item)
    score = 0.0
    usage = (item.respond_to?(:usage_count) ? item.usage_count.to_i : 0)
    # Diminishing returns: 1 trip = 5, 3 = 11, 10 = 17, 30 = 22
    score += [ 22.0, 5 * Math.log2(usage + 1) ].min if usage.positive?
    score += 5 if item.respond_to?(:wikipedia_url) && item.wikipedia_url.present?
    tags = Array(item.respond_to?(:tags) ? item.tags : [])
    score += 5 if tags.include?("iconic")
    score += 2 if tags.include?("crowd_favorite")
    [ score, 30.0 ].min.round(1)
  end

  def interest_score(item)
    return 15.0 if @interests.empty? # neutral when no interests supplied
    cat = item.respond_to?(:category) ? item.category.to_s.downcase : ""
    int = item.respond_to?(:interest) ? item.interest.to_s.downcase : ""
    tags = Array(item.respond_to?(:tags) ? item.tags : []).map { |t| t.to_s.downcase }
    haystack = ([ cat, int ] + tags).reject(&:blank?).to_set
    hits = @interests.count { |i| haystack.any? { |h| h.include?(i) || i.include?(h) } }
    return 5.0 if hits.zero?
    # 1 match → 18, 2 → 24, 3+ → 30
    [ 12 + 6 * hits, 30 ].min.to_f.round(1)
  end

  def distance_score(item)
    return 12.0 unless @has_distance && item.respond_to?(:distance_km) && item.distance_km.present?
    km = item.distance_km.to_f
    # Linear falloff: 0 km → 20, 25 km → 15, 50 km → 10, 100+ km → 5
    score = 20.0 - (km / 100.0) * 15.0
    [ [ score, 5.0 ].max, 20.0 ].min.round(1)
  end

  def community_score(item)
    rating = item.respond_to?(:community_rating) ? item.community_rating : nil
    count  = (item.respond_to?(:community_rating_count) ? item.community_rating_count.to_i : 0)
    return 0.0 if rating.blank? || count.zero?
    rating_f = rating.to_f
    # (rating-2.5) shifts midpoint so a 2.5★ is neutral; log keeps a single
    # 5★ from dominating before the place has a few real reviews.
    boost = (rating_f - 2.5) * 4 * Math.log2(count + 1)
    [ [ boost, 30.0 ].min, -10.0 ].max.round(1)
  end

  def tier_for(total, idx)
    return "must-see" if total >= TIER_MUST_SEE || idx < GUARANTEED_MUST_SEE_TOP
    return "worth-it" if total >= TIER_WORTH_IT || idx < GUARANTEED_WORTH_IT_TOP
    "bonus"
  end

  # Stars to show on the card. Prefer the real community rating once
  # any review exists; otherwise derive a 0..5 from the composite so
  # the picker isn't a sea of identical "no rating" stubs.
  def rating_for(item, total)
    real = item.respond_to?(:community_rating) ? item.community_rating : nil
    count = (item.respond_to?(:community_rating_count) ? item.community_rating_count.to_i : 0)
    return real.to_f.round(1) if real.present? && count.positive?
    # Editor score: map 35..95 → 3.0..5.0
    derived = 3.0 + ((total - 35.0) / 60.0) * 2.0
    [ [ derived, 5.0 ].min, 1.0 ].max.round(1)
  end

  # The Highlight/Idea structs are keyword_init with members declared
  # in the service files. Use []= which Struct supports, falling back
  # to instance_variable_set for plain objects.
  def stamp(item, attr, value)
    if item.respond_to?(:"#{attr}=")
      item.public_send(:"#{attr}=", value)
    else
      item.instance_variable_set("@#{attr}", value)
    end
  end
end
