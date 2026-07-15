# frozen_string_literal: true

# Caps how many AI-built trips one account can start in a rolling window.
#
# Every wizard / day-trip build fans out real paid AI calls (trip_structure.v1,
# then one activity_narration.v1 per stop — dozens on a long trip), so an
# uncapped account is an uncapped bill. Rack::Attack throttles anonymous
# traffic at the door by IP; this throttles by *account* once someone is
# through it, which is the side the spend actually lives on.
#
# Counted against `owned_trips` rather than `Trip.kept` on purpose: discarding a
# trip must not refund quota, or delete-and-rebuild loops around the cap.
#
# Limits resolve through AppSetting so they're retunable at /admin/app_settings
# with no redeploy. A blank or non-positive limit disables that window.
class BuildQuota
  DAILY_KEY   = "TRIP_BUILD_DAILY_LIMIT"
  MONTHLY_KEY = "TRIP_BUILD_MONTHLY_LIMIT"

  DAILY_DEFAULT   = "3"
  MONTHLY_DEFAULT = "15"

  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Admins are exempt so operator testing and seeding never trip the cap.
  def exempt?
    user.nil? || user.admin?
  end

  def exceeded?
    return false if exempt?

    daily_exceeded? || monthly_exceeded?
  end

  def daily_exceeded?
    limit = self.class.limit(DAILY_KEY, DAILY_DEFAULT)
    limit.positive? && builds_since(24.hours.ago) >= limit
  end

  def monthly_exceeded?
    limit = self.class.limit(MONTHLY_KEY, MONTHLY_DEFAULT)
    limit.positive? && builds_since(30.days.ago) >= limit
  end

  # Copy for the flash when a build is refused. Names the window that actually
  # tripped so the traveler knows whether to wait a day or a month.
  def message
    if daily_exceeded?
      limit = self.class.limit(DAILY_KEY, DAILY_DEFAULT)
      "You've built #{limit} #{'plan'.pluralize(limit)} in the last 24 hours — that's the daily limit while " \
        "Wanderply is free. Your existing trips are untouched, and you can build again tomorrow."
    else
      limit = self.class.limit(MONTHLY_KEY, MONTHLY_DEFAULT)
      "You've built #{limit} #{'plan'.pluralize(limit)} this month — that's the monthly limit while " \
        "Wanderply is free. Your existing trips are untouched."
    end
  end

  def self.limit(key, fallback)
    AppSetting.get(key).presence.to_s.strip.then { |v| v.presence || fallback }.to_i
  rescue StandardError
    fallback.to_i
  end

  private

  def builds_since(time)
    user.owned_trips.where(created_at: time..).count
  end
end
