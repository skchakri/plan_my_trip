# Routes every `Rails.error.report(...)` call into AppError.track so the
# whole app shares a single capture path. Controllers, jobs, services that
# already call Rails.error.report get persisted automatically.

Rails.application.config.after_initialize do
  # Guard on the table existing, but tolerate the DB being unreachable at boot
  # (e.g. `assets:precompile` during the Docker image build has no database).
  table_ready =
    begin
      ActiveRecord::Base.connection.data_source_exists?("app_errors")
    rescue StandardError
      false
    end
  next unless table_ready

  Rails.error.subscribe(Class.new do
    def report(exception, handled:, severity:, context:, source: nil)
      # Skip ActionController routing/404 noise — handled by the router.
      return if exception.is_a?(ActionController::RoutingError)
      return if exception.is_a?(ActiveRecord::RecordNotFound) && severity == :info

      AppError.track(
        exception,
        context: context.merge(handled: handled, reporter_severity: severity),
        source:  source || context[:source] || context[:job] || context[:controller]
      )
    rescue StandardError => e
      Rails.logger.warn("[ErrorTrackerSubscriber] #{e.class}: #{e.message}")
    end
  end.new)
end
