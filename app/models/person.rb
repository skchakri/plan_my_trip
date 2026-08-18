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
      interests = Array(p.interests).map { |i| i.to_s.strip }.reject(&:blank?)
      # Latest NON-EMPTY list wins: a newer row saved without interests
      # (e.g. the wizard was submitted before chips loaded) must not wipe
      # what we already know about this person.
      acc[key] = interests if interests.any? || !acc.key?(key)
    end
  end

  # Returns [{ name:, age:, interests: }, ...] — one entry per unique
  # traveler name across all kept trips owned by `user`. Most recent row
  # per name wins, so its age + interests become the pre-fill when the
  # user clicks a suggestion card in the wizard — except that an empty
  # interests list never overrides a remembered one.
  def self.known_travelers_for(user)
    return [] unless user
    by_name = {}
    joins(:trip)
      .where(trips: { owner_id: user.id, discarded_at: nil })
      .order(:updated_at)
      .each do |p|
        name = p.name.to_s.strip
        key = name.downcase
        next if key.blank?
        interests = Array(p.interests).map { |i| i.to_s.strip }.reject(&:blank?)
        prev = by_name[key]
        by_name[key] = {
          name: name,
          age: p.age.presence || prev&.dig(:age),
          # Keep the most recent non-empty interests (see known_interests_for).
          interests: interests.any? ? interests : Array(prev&.dig(:interests))
        }
      end
    by_name.values.sort_by { |h| h[:name].downcase }
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
