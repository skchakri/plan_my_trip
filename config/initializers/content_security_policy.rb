# Be sure to restart your server when you modify this file.

# Application-wide Content-Security-Policy — the backstop against XSS given the
# app's user-supplied URLs and html_safe helper output.
#
# External origins in use:
#   fonts.googleapis.com / fonts.gstatic.com  — Inter + Fraunces webfonts
#   img-src https:                            — flagcdn.com, cdn.simpleicons.org,
#                                               Pexels/Unsplash/Pixabay place photos,
#                                               tile.openstreetmap.org map tiles
#   ws/wss                                    — ActionCable (turbo_stream_from)
#   *.posthog.com                             — product analytics, and only when
#                                               POSTHOG_API_KEY is set (see
#                                               layouts/_analytics). Allow-listing
#                                               a host loads nothing by itself, and
#                                               the alternative — reading AppSetting
#                                               here — would touch the DB at boot
#                                               and break assets:precompile.
#
# Inline <script> tags (layout SW registration, copilot player) carry the
# per-session nonce; importmap tags pick the nonce up automatically. Inline
# styles stay on unsafe-inline (style="" attributes everywhere) — style
# injection is far lower risk than script injection.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self, "https://*.posthog.com"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :https, :data, :blob
    # connect-src also governs fetch() calls inside the service worker (it
    # inherits this policy), so every cross-origin host the SW caches —
    # map tiles, quiz flag/logo CDNs, webfonts — must be listed here.
    policy.connect_src :self, :ws, :wss,
                       "https://tile.openstreetmap.org", "https://*.tile.openstreetmap.org",
                       "https://flagcdn.com", "https://cdn.simpleicons.org",
                       "https://fonts.googleapis.com", "https://fonts.gstatic.com",
                       "https://*.posthog.com"
    policy.object_src  :none
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :self
  end

  # Per-session nonce for the few inline <script> blocks (random fallback —
  # session.id is nil until the session cookie exists, and an empty nonce
  # would block every inline script on a first visit). Directive list is
  # script-only on purpose — adding style-src here would disable the
  # unsafe-inline above and break every style="" attribute.
  config.content_security_policy_nonce_generator =
    ->(request) { request.session.id.to_s.presence || SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # web-console injects un-nonced inline scripts on exception pages, so don't
  # enforce locally — report-only still logs violations to the browser console.
  config.content_security_policy_report_only = true if Rails.env.development?
end
