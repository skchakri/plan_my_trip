class QuizAttempt < ApplicationRecord
  belongs_to :user

  validates :category, presence: true, inclusion: { in: QuizCatalog.keys }
  validates :score, :total, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate  :score_within_total

  scope :for_category, ->(key) { where(category: key.to_s) }

  def percentage
    return 0 if total.to_i.zero?
    (score * 100.0 / total).round
  end

  private

  def score_within_total
    return if total.blank? || score.blank?
    errors.add(:score, "can't exceed total") if score > total
  end
end
