# frozen_string_literal: true

# Off-request IndexNow submission (see IndexNow). Enqueued when a BlogPost or
# RoadTrip becomes public. Cheap, idempotent, safe to retry.
class IndexNowPingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(urls)
    IndexNow.submit(urls)
  end
end
