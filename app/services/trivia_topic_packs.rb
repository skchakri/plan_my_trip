# Hand-curated multi-step chained question packs, one or more per interest
# tag. Used by the `trivia:seed_topic_packs` rake task to expand the pool
# beyond the original seed/chains. Each pack is one chain — a coherent
# mini-story that walks the player through a topic step by step.
#
# Data lives in db/trivia_topic_packs.yml. Shape (per tag → array of packs):
#   { difficulty:, intro:, steps: [{ q:, options:, answer:, fun_fact: }, ...] }
#
# Reload the file with `TriviaTopicPacks.reload!` after editing in dev.
module TriviaTopicPacks
  DATA_FILE = Rails.root.join("db", "trivia_topic_packs.yml")

  class << self
    def packs
      @packs ||= load_packs
    end

    def reload!
      @packs = nil
      packs
    end

    private

    def load_packs
      raw = YAML.safe_load_file(DATA_FILE, permitted_classes: [], aliases: false)
      raw.transform_values do |list|
        Array(list).map do |pack|
          {
            difficulty: pack["difficulty"].to_s,
            intro:      pack["intro"].to_s,
            steps:      Array(pack["steps"]).map { |s| symbolize_step(s) }
          }
        end
      end.freeze
    end

    def symbolize_step(step)
      {
        q:        step["q"].to_s,
        options:  Array(step["options"]).map(&:to_s),
        answer:   step["answer"].to_i,
        fun_fact: step["fun_fact"].to_s
      }
    end
  end

  # Backwards-compatible constant for existing callers.
  PACKS = packs
end
