class QuizQuestion < ApplicationRecord
  scope :for_category, ->(key) { where(category: key.to_s) }

  # The stored payload hashes for a play — `limit` random questions of a deck.
  def self.sample_for_play(key, limit)
    for_category(key).order(Arel.sql("RANDOM()")).limit(limit).pluck(:payload)
  end

  # (Re)generate the bank from reference data via QuizCatalog — one question per
  # source entity per deck. Idempotent: clears and repopulates each category, so
  # re-run after changing seed data (`rake quiz:rebuild` or `db:seed`).
  # Returns the total number of questions written.
  def self.rebuild!(categories: QuizCatalog.keys)
    now = Time.current
    categories.sum do |key|
      questions = QuizCatalog.build(key, count: QuizCatalog.pool_size(key))
      transaction do
        for_category(key).delete_all
        unless questions.empty?
          insert_all(questions.map { |q| { category: key, payload: q, created_at: now, updated_at: now } })
        end
      end
      questions.size
    end
  end
end
