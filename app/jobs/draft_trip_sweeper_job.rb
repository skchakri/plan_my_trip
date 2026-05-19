# Deletes wizard drafts that have aged past expires_at. Scheduled from
# config/recurring.yml. Drafts are cheap (one jsonb column per user) but
# we don't want zombie state lingering forever after someone abandons
# the wizard.
class DraftTripSweeperJob < ApplicationJob
  queue_as :default

  def perform
    DraftTrip.expired.delete_all
  end
end
