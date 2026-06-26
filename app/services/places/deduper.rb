module Places
  # Catalog hygiene: finds and (optionally) merges duplicate Place rows that
  # the seed/persist path accumulated — same sight stored several times under
  # name variants ("Great Salt Lake" / "Great Salt Lake State Park") or with
  # sloppy coordinates ("Lake Hillier" x3). Dry-run by default; on commit it
  # keeps the best canonical row, re-points activities + reviews onto it, sums
  # usage_count, and soft-deletes (discards) the redundant rows.
  #
  # Because this MERGES (soft-deletes) rows, the rule is deliberately strict:
  # two rows are the same place only when they share an identical
  # significant-word set AND sit within DUP_RADIUS_KM of each other. That
  # catches the real accidents — the same spot re-seeded ("Antelope Island
  # State Park" x2) and reordered/parenthetical variants ("Lake Hillier (Pink
  # Lake)" vs "Pink Lake (Lake Hillier)") — without the false merges a looser
  # rule produces: proximity alone would fuse a dozen distinct Eataly counters
  # in one food hall, and name-subsumption would fold "Las Vegas (LAS)" into
  # "Las Vegas Strip". The softer subsumption/2 km rule lives only in the
  # non-destructive day-trip display dedup (NearbyIdeas#dedupe_same_place).
  class Deduper
    DUP_RADIUS_KM = 2.0
    STOPWORDS = %w[the a an of at on in and to].freeze

    Result = Struct.new(:groups, :committed, keyword_init: true) do
      # groups: [{ canonical: Place, redundant: [Place, ...] }, ...]
      def discarded_count = groups.sum { |g| g[:redundant].size }
    end

    def self.call(...) = new(...).call

    def initialize(commit: false, scope: Place.kept)
      @commit = commit
      @scope = scope
    end

    def call
      groups = duplicate_groups
      groups.each { |g| merge!(g[:canonical], g[:redundant]) } if @commit
      Result.new(groups: groups, committed: @commit)
    end

    private

    # Greedy single-linkage clustering, then drop singletons. Each surviving
    # cluster is ordered canonical-first.
    def duplicate_groups
      clusters = []
      @scope.to_a.each do |place|
        cluster = clusters.find { |c| c.any? { |other| same_place?(place, other) } }
        cluster ? cluster << place : clusters << [ place ]
      end

      clusters.filter_map do |cluster|
        canonical, *rest = order_canonical_first(cluster)
        # Single-linkage can chain rows that don't each match the canonical
        # directly; only merge the ones that genuinely duplicate it.
        redundant = rest.select { |other| same_place?(canonical, other) }
        next if redundant.empty?
        { canonical: canonical, redundant: redundant }
      end
    end

    def same_place?(a, b)
      return false if a.id == b.id

      ta = tokens(a.name)
      return false if ta.empty? || ta != tokens(b.name)

      d = mutual_distance_m(a, b)
      d.nil? || d <= DUP_RADIUS_KM * 1000
    end

    def mutual_distance_m(a, b)
      return nil unless a.latitude && a.longitude && b.latitude && b.longitude

      Place.haversine_m(a.latitude.to_f, a.longitude.to_f, b.latitude.to_f, b.longitude.to_f)
    end

    def tokens(name)
      name.to_s.downcase.scan(/[a-z0-9]+/)
          .reject { |t| t.length < 2 || STOPWORDS.include?(t) }
          .to_set
    end

    # Best canonical first: verified, then most-used, then most-reviewed, then
    # has an image, then oldest (the original row).
    def order_canonical_first(cluster)
      cluster.sort_by do |p|
        [ p.verified? ? 0 : 1, -p.usage_count.to_i, -p.community_rating_count.to_i,
          p.image_url.present? ? 0 : 1, p.created_at ]
      end
    end

    def merge!(canonical, redundant)
      Place.transaction do
        redundant.each do |dup|
          Activity.where(place_id: dup.id).update_all(place_id: canonical.id, updated_at: Time.current)
          reassign_reviews(canonical, dup)
          canonical.usage_count = canonical.usage_count.to_i + dup.usage_count.to_i
          dup.discard
        end
        canonical.save!
      end
      canonical.recompute_community_rating! if canonical.respond_to?(:recompute_community_rating!)
    end

    # Move reviews to the canonical row, but respect the one-review-per-author
    # uniqueness: if the author already has a kept review on the canonical,
    # discard the duplicate review instead of re-pointing it.
    def reassign_reviews(canonical, dup)
      taken = PlaceReview.kept.where(place_id: canonical.id).pluck(:author_id).to_set
      PlaceReview.where(place_id: dup.id).find_each do |review|
        if review.kept? && taken.include?(review.author_id)
          review.discard
        else
          review.update_columns(place_id: canonical.id)
          taken << review.author_id if review.kept?
        end
      end
    end
  end
end
