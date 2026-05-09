class Person < ApplicationRecord
  # Curated interest tags. Only these are matched against the trivia and
  # playlist pools — keeping the list closed prevents typos.
  INTERESTS = %w[
    math science space animals dinosaurs sports music movies movies_kids
    history geography art food cars books video_games disney superhero
    travel cooking gardening photography
  ].freeze

  belongs_to :trip

  validates :name, presence: true
  validate :interests_in_catalog

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def initials
    name.to_s.split(/\s+/).first(2).map { |w| w[0] }.join.upcase
  end

  def interests_label
    return nil if interests.blank?
    interests.first(3).map { |i| i.tr("_", " ") }.join(" · ")
  end

  private

  def interests_in_catalog
    bad = interests.to_a.reject { |i| INTERESTS.include?(i) }
    errors.add(:interests, "include unknown tags: #{bad.join(', ')}") if bad.any?
  end
end
