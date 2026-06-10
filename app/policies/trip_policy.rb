class TripPolicy < ApplicationPolicy
  def show?
    record.shared_with?(user)
  end

  def create?
    user.present?
  end
  alias_method :new?, :create?

  def update?
    owner?
  end
  alias_method :edit?, :update?

  def destroy?
    owner?
  end

  # Archiving removes a trip from a viewer's dashboard. The owner soft-deletes
  # (discards) the whole trip; a member just leaves it — both are allowed for
  # anyone with access. Restoring/permanently deleting are owner-only.
  def archive?
    record.shared_with?(user)
  end

  def restore?
    owner?
  end
  alias_method :destroy_permanently?, :restore?

  def share?
    owner?
  end

  def rename?
    record.shared_with?(user)
  end

  class Scope < Scope
    def resolve
      scope.kept.joins(:trip_memberships).where(trip_memberships: { user_id: user.id }).distinct
    end
  end

  private

  def owner?
    record.owner_id == user.id
  end
end
