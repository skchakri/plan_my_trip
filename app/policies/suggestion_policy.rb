class SuggestionPolicy < ApplicationPolicy
  def create? = trip_member?
  def vote?   = trip_member?
  def destroy? = own? || trip_owner?

  private

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
