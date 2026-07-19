class SupportTicketPolicy < ApplicationPolicy
  def index?  = user.present?
  def create? = user.present?
  def show?   = owner?
  def reply?  = owner?

  private

  def owner?
    record.user_id == user&.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.kept.where(user_id: user.id)
    end
  end
end
