class ApplicationJob < ActiveJob::Base
  # Retry transient infrastructure errors with exponential backoff before giving up.
  retry_on ActiveRecord::Deadlocked,        wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout,                wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout,                wait: :polynomially_longer, attempts: 3
  retry_on Errno::ECONNRESET,               wait: :polynomially_longer, attempts: 3

  # Job's record was deleted between enqueue and execution — drop the job
  # rather than retry forever.
  discard_on ActiveJob::DeserializationError

  # Catch-all: any uncaught exception reaches Rails.error so it surfaces
  # wherever the host has subscribed (logs, AppError, Sentry, etc).
  # Re-raise so Solid Queue marks the job failed and the configured retry
  # policy applies.
  rescue_from(StandardError) do |error|
    Rails.error.report(
      error,
      severity: :error,
      context:  {
        job:        self.class.name,
        queue:      queue_name,
        job_id:     job_id,
        executions: executions,
        arguments:  arguments
      },
      handled: false
    )
    raise
  end
end
