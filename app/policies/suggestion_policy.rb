class SuggestionPolicy < ApplicationPolicy
  def create? = active? && trip_member?
  def vote?   = active? && trip_member?
  def destroy? = active? && (own? || trip_owner?)

  private

  def active?
    record.trip&.kept?
  end

  def trip_member?
    record.trip&.shared_with?(user)
  end

  def own?
    record.author_id == user&.id
  end

  def trip_owner?
    record.trip&.owner_id == user&.id
  end
end
