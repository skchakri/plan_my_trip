# Thin wrapper around Rails.error so services can opt into structured error
# capture without sprinkling `Rails.error.report` boilerplate everywhere.
#
# Usage in a service:
#
#   ErrorTracker.capture(source: "Ai::Caller", context: { slug: @slug }) do
#     provider.call(rendered)
#   end
#
# - Catches StandardError (NOT Exception — leaves SystemExit / Interrupt alone)
# - Reports via Rails.error.report which routes into AppError via the
#   subscriber initializer
# - Returns the block result on success, the configured `default:` on failure
# - Re-raises if `reraise: true` (default off — swallow silently after report)
module ErrorTracker
  module_function

  def capture(source:, context: {}, default: nil, reraise: false)
    yield
  rescue StandardError => e
    Rails.error.report(
      e,
      handled:  !reraise,
      severity: :error,
      context:  context.merge(source: source),
      source:   source
    )
    raise if reraise
    default
  end

  # Convenience for "I caught it, just want it logged + persisted, no block".
  def report(exception, source:, context: {})
    Rails.error.report(
      exception,
      handled:  true,
      severity: :error,
      context:  context.merge(source: source),
      source:   source
    )
    nil
  end
end
