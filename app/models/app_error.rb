# Lightweight error capture. Anything that calls `Rails.error.report(...)`
# (controllers, jobs, services) lands here via ErrorTrackerSubscriber.
#
# Aggregated by fingerprint = SHA256(class + truncated message + source).
# Same error repeated 100 times → one row, occurrences_count=100. Resolve
# from the admin UI to ack — auto-reopens on next occurrence.
class AppError < ApplicationRecord
  SEVERITIES = %w[low medium high critical].freeze
  MESSAGE_TRUNCATE = 200

  validates :error_class, :message, :fingerprint, presence: true
  validates :fingerprint, uniqueness: true
  validates :severity, inclusion: { in: SEVERITIES }

  scope :unresolved, -> { where(resolved: false) }
  scope :recent,     -> { order(last_occurred_at: :desc) }

  def self.track(exception, context: {}, source: nil)
    fp = fingerprint_for(exception, source)
    record = find_or_initialize_by(fingerprint: fp)

    if record.new_record?
      record.assign_attributes(
        error_class:       exception.class.name,
        message:           exception.message.to_s.truncate(MESSAGE_TRUNCATE * 4),
        backtrace:         Array(exception.backtrace).first(20).join("\n"),
        first_occurred_at: Time.current,
        last_occurred_at:  Time.current,
        context:           sanitize(context),
        source:            source,
        severity:          "low"
      )
      record.save!
    else
      AppError.where(id: record.id).update_all(
        occurrences_count: record.occurrences_count + 1,
        last_occurred_at:  Time.current,
        context:           sanitize(context),
        resolved:          false,
        resolved_at:       nil,
        updated_at:        Time.current
      )
      record.reload
      record.recalculate_severity!
    end

    record
  rescue ActiveRecord::RecordNotUnique
    retry
  rescue StandardError => e
    Rails.logger.error("[AppError] tracker itself failed: #{e.class}: #{e.message}")
    nil
  end

  def self.fingerprint_for(exception, source)
    Digest::SHA256.hexdigest(
      [
        exception.class.name,
        exception.message.to_s.truncate(MESSAGE_TRUNCATE),
        source.to_s
      ].join("|")
    )
  end

  def self.sanitize(context)
    return {} if context.blank?
    h = context.respond_to?(:to_unsafe_h) ? context.to_unsafe_h : context.to_h
    h.deep_stringify_keys.deep_transform_values do |v|
      case v
      when String, Numeric, TrueClass, FalseClass, NilClass then v
      when Array, Hash then v
      else v.to_s.truncate(500)
      end
    end
  rescue StandardError
    {}
  end

  def recalculate_severity!
    new_severity = case occurrences_count
                   when 0..5    then "low"
                   when 6..20   then "medium"
                   when 21..100 then "high"
                   else              "critical"
                   end
    update_columns(severity: new_severity) if severity != new_severity
  end

  def resolve!
    update!(resolved: true, resolved_at: Time.current)
  end

  def short_fingerprint
    fingerprint&.first(8)
  end
end
