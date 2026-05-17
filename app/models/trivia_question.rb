class TriviaQuestion < ApplicationRecord
  include Discard::Model

  SOURCES = %w[seed ai manual].freeze

  belongs_to :trip, optional: true
  belongs_to :parent, class_name: "TriviaQuestion", optional: true
  has_one  :follow_up, class_name: "TriviaQuestion", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :trivia_responses, dependent: :destroy

  validates :tag, :question, presence: true
  validates :answer_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :source, inclusion: { in: SOURCES }
  validate  :options_well_formed

  scope :global,      -> { where(trip_id: nil) }
  scope :for_tag,     ->(tag) { where(tag: tag.to_s) }
  scope :chain_roots, -> { where(parent_id: nil) }

  def chain?
    parent_id.present? || follow_up.present?
  end

  # 1-based step number within its chain. Walks parent links.
  def chain_position
    pos = 1
    cur = self
    while cur.parent_id
      pos += 1
      cur = cur.parent
    end
    pos
  end

  def chain_length
    cur = self
    cur = cur.parent while cur.parent_id
    len = 1
    len += 1 while (cur = cur.follow_up)
    len
  end

  def correct_option
    Array(options)[answer_index]
  end

  private

  def options_well_formed
    arr = Array(options)
    errors.add(:options, "must have at least 2 entries") if arr.size < 2
    errors.add(:answer_index, "out of range for options") if answer_index.present? && answer_index >= arr.size
  end
end
