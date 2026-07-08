class ReservationPolicy < ApplicationPolicy
  # Owners and editors may remove a parsed reservation. Plain members see it
  # (via the trip page) but can't delete it. Blocked entirely on a discarded
  # trip — mirrors the active-trip guard used across the trip-scoped policies.
  def destroy?
    active_trip? && record.trip.editable_by?(user)
  end
  alias_method :update?, :destroy?
  alias_method :retry?, :destroy?

  private

  def active_trip?
    record.trip.present? && !record.trip.discarded?
  end
end
