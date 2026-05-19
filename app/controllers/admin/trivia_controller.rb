module Admin
  class TriviaController < BaseController
    # Trivia powers the Drive Co-Pilot road-trip game. Questions live in
    # the trivia_questions table — seeded from TriviaPool::SEED_POOL,
    # augmented by AI runs and manual entries.
    def index
      kept = TriviaQuestion.kept
      @tags = kept.group(:tag).count.sort_by { |_, c| -c }
      @sources = kept.group(:source).count
      @stats = {
        total:    kept.count,
        global:   kept.global.count,
        trip:     kept.where.not(trip_id: nil).count,
        answered: TriviaResponse.count
      }
      # Single DISTINCT ON query in place of N per-tag LIMIT 1 lookups.
      @previews = kept
        .select("DISTINCT ON (tag) tag, question")
        .order(:tag, :created_at)
        .each_with_object({}) { |q, h| h[q.tag] = q.question }
    end

    PER_PAGE = 25

    def show
      @tag = params[:id]
      @page = [ params[:page].to_i, 1 ].max

      roots_scope = TriviaQuestion.kept.for_tag(@tag).chain_roots.order(:created_at)
      @total_roots = roots_scope.count

      if @total_roots.zero?
        redirect_to admin_trivia_path, alert: "Unknown category." and return
      end

      @total_pages = (@total_roots / PER_PAGE.to_f).ceil
      @page = [ @page, @total_pages ].min

      page_roots = roots_scope.includes(:trip)
        .offset((@page - 1) * PER_PAGE)
        .limit(PER_PAGE)
        .to_a

      # Walk descendants for just this page's roots — a single query per
      # depth level, indexed by parent_id. Replaces the prior O(N²) scan
      # of every loaded question.
      child_by_parent = collect_descendants(page_roots.map(&:id))

      @chains = []
      @standalone = []
      page_roots.each do |root|
        chain = [ root ]
        cur = root
        while (nxt = child_by_parent[cur.id])
          chain << nxt
          cur = nxt
        end
        chain.size > 1 ? (@chains << chain) : (@standalone << root)
      end
    end

    # POST /admin/trivia/generate_riddles — runs the riddle_pack.v1 prompt
    # against the local Claude CLI subscription and inserts the returned
    # batch into the shared trivia_questions table under tag="riddles".
    # Duplicates (same question text, global) are skipped silently.
    def generate_riddles
      count = params[:count].to_i.clamp(1, 30)
      count = 10 if count.zero?
      theme = params[:theme].to_s.strip

      result = Ai::Caller.call(
        slug: "riddle_pack.v1",
        variables: { count: count, theme: theme.presence },
        user: current_user
      )

      if result.error || result.text.blank?
        redirect_to admin_trivium_path("riddles"), alert: "Riddle generation failed: #{result.error.to_s.presence || 'empty response'}" and return
      end

      payload = result.json
      payload = payload["riddles"] if payload.is_a?(Hash) && payload["riddles"].is_a?(Array)

      unless payload.is_a?(Array)
        redirect_to admin_trivium_path("riddles"), alert: "Riddle generation returned non-array JSON." and return
      end

      inserted = skipped = 0
      payload.each do |row|
        next unless row.is_a?(Hash)
        q = row["question"].to_s.strip
        opts = Array(row["options"]).map { |o| o.to_s.strip }.reject(&:blank?)
        idx = row["answer_index"].to_i
        fact = row["fun_fact"].to_s.strip
        next if q.blank? || opts.size < 2 || idx.negative? || idx >= opts.size

        rec = TriviaQuestion.find_or_initialize_by(tag: "riddles", question: q, trip_id: nil)
        if rec.persisted?
          skipped += 1
          next
        end
        rec.assign_attributes(options: opts, answer_index: idx, fun_fact: fact, source: "ai")
        if rec.save
          inserted += 1
        else
          skipped += 1
        end
      end

      redirect_to admin_trivium_path("riddles"),
        notice: "Generated #{inserted} new riddle(s) via Claude CLI subscription (#{skipped} skipped)."
    end

    private

    # Returns a { parent_id => child_question } map covering every descendant
    # reachable from the given root ids. Runs one indexed query per chain
    # depth, so the cost is O(rows_loaded), not O(roots × all_questions).
    def collect_descendants(root_ids)
      return {} if root_ids.empty?
      found = {}
      frontier = root_ids
      until frontier.empty?
        next_level = TriviaQuestion.kept.where(parent_id: frontier).to_a
        break if next_level.empty?
        next_level.each { |q| found[q.parent_id] = q }
        frontier = next_level.map(&:id)
      end
      found
    end
  end
end
