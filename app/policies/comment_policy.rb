class CommentPolicy < ApplicationPolicy
  # Anyone with access to the trip can read comments.
  def index?  = trip_member?
  def create? = trip_member?
  def show?   = trip_member?

  # Only the comment author can edit or delete; trip owner can also delete
  # for moderation.
  def update?  = own_comment?
  def destroy? = own_comment? || trip_owner?

  private

  def trip_member?
    record.respond_to?(:trip) ? record.trip&.shared_with?(user) : false
  end

  def own_comment?
    record.author_id == user&.id
  end

  def trip_owner?
    record.trip&.owner_id == user&.id
  end
end
