module AnalyticsHelper
  # Product analytics is opt-in: it exists only when a POSTHOG_API_KEY is set at
  # /admin/app_settings.
  #
  # Both the tracking snippet (layouts/_analytics) and the disclosure on the
  # privacy page read this same predicate, on purpose — the policy then can't
  # drift from what the app actually does, in either direction: no undisclosed
  # tracking, and no claiming to track when we don't.
  def analytics_enabled?
    AppSetting.get("POSTHOG_API_KEY").present?
  end

  def analytics_key
    AppSetting.get("POSTHOG_API_KEY").presence
  end

  def analytics_host
    AppSetting.get("POSTHOG_HOST").presence || "https://us.i.posthog.com"
  end

  # Google Search Console HTML-tag verification token, set at
  # /admin/app_settings. Blank until the founder pastes it, so no tag renders.
  def google_site_verification
    AppSetting.get("GOOGLE_SITE_VERIFICATION").presence
  end
end
