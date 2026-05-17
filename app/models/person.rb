class Person < ApplicationRecord
  belongs_to :trip
  has_many :trivia_responses, dependent: :destroy

  validates :name, presence: true

  before_validation :compact_interests

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  # Returns { "kalyan" => ["sports","art",...], "mani" => [...] } from all
  # kept-trip Person rows owned by `user`. Used to pre-fill interests when
  # the user adds the same traveler to a future trip — most recent wins.
  def self.known_interests_for(user)
    return {} unless user
    joins(:trip)
      .where(trips: { owner_id: user.id, discarded_at: nil })
      .order(:updated_at)
      .each_with_object({}) do |p, acc|
      key = p.name.to_s.downcase.strip
      next if key.blank?
      acc[key] = Array(p.interests)
    end
  end

  def initials
    name.to_s.split(/\s+/).first(2).map { |w| w[0] }.join.upcase
  end

  def interests_label
    return nil if interests.blank?
    interests.first(3).map { |i| i.tr("_", " ") }.join(" · ")
  end

  private

  def compact_interests
    self.interests = Array(interests).map { |i| i.to_s.strip }.reject(&:blank?).uniq
  end
end
