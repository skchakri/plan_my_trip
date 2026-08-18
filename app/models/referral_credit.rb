# A give-one-get-one build credit minted when a signed-in visitor saves
# someone else's shared trip (PublicTripsController#copy). Both parties earn a
# permanent +1 to their monthly BuildQuota (capped at MAX_PER_USER). Unique
# per (referrer, referee) so re-copying the same friend's trips earns nothing
# extra — the loop rewards *new* people, not repeat clicks.
class ReferralCredit < ApplicationRecord
  MAX_PER_USER = 10

  belongs_to :referrer, class_name: "User"
  belongs_to :referee,  class_name: "User"
  belongs_to :trip, optional: true

  validate :not_self_referral

  # Idempotent. Returns the credit if newly minted, nil if it already existed
  # or was refused (self-referral).
  def self.grant!(referrer:, referee:, trip: nil)
    return nil if referrer.nil? || referee.nil? || referrer.id == referee.id
    return nil if exists?(referrer_id: referrer.id, referee_id: referee.id)

    create!(referrer: referrer, referee: referee, trip: trip)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # Bonus monthly builds a user has earned, from either side of the loop.
  def self.bonus_for(user)
    return 0 if user.nil?
    [ where(referrer_id: user.id).or(where(referee_id: user.id)).count, MAX_PER_USER ].min
  end

  private

  def not_self_referral
    errors.add(:referee, "can't be the referrer") if referrer_id.present? && referrer_id == referee_id
  end
end
