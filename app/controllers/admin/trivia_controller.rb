module Admin
  class TriviaController < BaseController
    # Trivia powers the Drive Co-Pilot road-trip game. Questions live in
    # the trivia_questions table — seeded from TriviaPool::SEED_POOL,
    # augmented by AI runs and manual entries.
    def index
      @tags = TriviaQuestion.kept.group(:tag).count.sort_by { |_, c| -c }
      @sources = TriviaQuestion.kept.group(:source).count
      @stats = {
        total:    TriviaQuestion.kept.count,
        global:   TriviaQuestion.kept.global.count,
        trip:     TriviaQuestion.kept.where.not(trip_id: nil).count,
        answered: TriviaResponse.count
      }
    end

    def show
      @tag = params[:id]
      questions = TriviaQuestion.kept.for_tag(@tag).includes(:trip).order(:created_at).to_a
      redirect_to admin_trivia_path, alert: "Unknown category." and return if questions.empty?

      # Walk parent_id links so chained word-problem stories render as one
      # card with the intro + each step in order, instead of looking like
      # disconnected one-offs.
      @chains = []
      @standalone = []
      questions.reject(&:parent_id).each do |root|
        chain = [ root ]
        cur = root
        while (next_step = questions.find { |q| q.parent_id == cur.id })
          chain << next_step
          cur = next_step
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
  end
end
