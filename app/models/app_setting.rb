# Admin-editable key/value store for all the app's external settings (API keys,
# affiliate IDs, paths) so an operator manages them at /admin/app_settings
# instead of editing .env / Rails credentials and redeploying.
#
# Values are encrypted at rest with ActiveSupport::MessageEncryptor (key derived
# from secret_key_base — no separate AR-encryption keys to provision). Only the
# `key` + ciphertext live in the DB; human-facing metadata is in REGISTRY.
#
# Resolution order for any key (AppSetting.get):
#   1. DB override entered in the admin UI
#   2. ENV (.env / process env)        ← legacy fallback; import_from_env! lifts these into the DB
#   3. the registry default (if any)
class AppSetting < ApplicationRecord
  ENCRYPT_PURPOSE = "app_settings.value.v1".freeze
  CACHE_PREFIX = "app_setting/v1".freeze
  CACHE_TTL = 5.minutes

  # secret: mask the value in the admin UI (API keys). Non-secret settings
  # (affiliate IDs, CLI path) render as a normal prefilled text field.
  Definition = Struct.new(
    :key, :label, :category, :description, :placeholder, :secret, :default,
    keyword_init: true
  )

  # The catalog the admin page renders. Add a row to expose a new setting —
  # no schema change needed.
  REGISTRY = [
    # ── AI providers ──
    Definition.new(key: "ANTHROPIC_API_KEY", label: "Anthropic API key", category: "AI providers", secret: true,
      description: "Claude Messages API (provider: anthropic). Not needed for claude_cli, which uses the local subscription.", placeholder: "sk-ant-…"),
    Definition.new(key: "OPENAI_API_KEY", label: "OpenAI API key", category: "AI providers", secret: true,
      description: "OpenAI chat + image generation (provider: openai).", placeholder: "sk-…"),
    Definition.new(key: "PERPLEXITY_API_KEY", label: "Perplexity API key", category: "AI providers", secret: true,
      description: "Sonar models power day-trip NearbyIdeas (provider: perplexity). perplexity.ai/settings/api — needs API credits.", placeholder: "pplx-…"),
    # NOTE: CLAUDE_CLI_PATH is intentionally NOT here — it's a path to an
    # executable, so making it web-editable would be an RCE vector. It stays an
    # ENV/deploy-only setting (see Ai::ClaudeCliProvider).

    # ── Place data ──
    Definition.new(key: "GOOGLE_PLACES_API_KEY", label: "Google Places API key", category: "Place data", secret: true,
      description: "When set, Places::Geocoder uses Google Places Text Search for coordinate lookups (better POI matching, no 1-req/sec cap). Blank → free OpenStreetMap Nominatim. console.cloud.google.com → enable Places API.", placeholder: "AIza…"),

    # ── Travel data ──
    Definition.new(key: "EIA_API_KEY", label: "EIA gas-price API key", category: "Travel data", secret: true,
      description: "Free U.S. Energy Information Administration API (api.eia.gov/register) — current gas price for RoadTripEstimator's fuel estimate. Blank → a hardcoded national-average price is used.", placeholder: nil),

    # ── Image search ──
    Definition.new(key: "PEXELS_API_KEY", label: "Pexels API key", category: "Image search", secret: true,
      description: "Photo source for LandmarkImageFinder / place hero images.", placeholder: nil),
    Definition.new(key: "UNSPLASH_ACCESS_KEY", label: "Unsplash access key", category: "Image search", secret: true,
      description: "Photo source for LandmarkImageFinder / place hero images.", placeholder: nil),
    Definition.new(key: "PIXABAY_API_KEY", label: "Pixabay API key", category: "Image search", secret: true,
      description: "Photo source for LandmarkImageFinder / place hero images.", placeholder: nil),

    # ── Affiliate programs (BookingLinks) ──
    Definition.new(key: "AFFILIATE_BOOKING_COM_AID", label: "Booking.com AID", category: "Affiliate programs", secret: false,
      description: "Booking.com Affiliate Partner Program ID. Blank → plain search URLs.", placeholder: nil),
    Definition.new(key: "AFFILIATE_BOOKING_COM_LABEL", label: "Booking.com label", category: "Affiliate programs", secret: false,
      description: "Tracking label prefix for Booking.com links.", placeholder: nil, default: "plan_my_trip"),
    Definition.new(key: "AFFILIATE_GETYOURGUIDE_PARTNER_ID", label: "GetYourGuide partner ID", category: "Affiliate programs", secret: false,
      description: "GetYourGuide Partner Hub ID.", placeholder: nil),
    Definition.new(key: "AFFILIATE_VIATOR_PID", label: "Viator PID", category: "Affiliate programs", secret: false,
      description: "Viator Affiliate Program partner ID.", placeholder: nil),
    Definition.new(key: "AFFILIATE_VIATOR_MCID", label: "Viator MCID", category: "Affiliate programs", secret: false,
      description: "Viator media channel ID.", placeholder: nil, default: "42383"),
    Definition.new(key: "AFFILIATE_SKYSCANNER_ASSOCIATEID", label: "Skyscanner associate ID", category: "Affiliate programs", secret: false,
      description: "Direct Skyscanner partnership ID (rare — most go via Travelpayouts).", placeholder: nil),
    Definition.new(key: "AFFILIATE_TRAVELPAYOUTS_MARKER", label: "Travelpayouts marker", category: "Affiliate programs", secret: false,
      description: "Travelpayouts marker — one account covers Skyscanner + many others.", placeholder: nil)
  ].freeze

  KEYS = REGISTRY.map(&:key).freeze
  CATEGORIES = REGISTRY.map(&:category).uniq.freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }

  after_commit :bust_cache

  scope :ordered, -> { order(:key) }

  # Resolved value: DB override → ENV → registry default. Cached so the AI hot
  # path doesn't hit the DB per call; busted on write. Tolerates a missing
  # table (e.g. before migrate) by falling back to ENV/default.
  def self.get(key)
    key = key.to_s
    Rails.cache.fetch(cache_key(key), expires_in: CACHE_TTL) do
      db = begin
        find_by(key: key)&.value
      rescue ActiveRecord::StatementInvalid
        nil
      end
      db.presence || ENV[key].presence || definition(key)&.default
    end
  end

  def self.cache_key(key)
    "#{CACHE_PREFIX}/#{key}"
  end

  def self.definition(key)
    REGISTRY.find { |d| d.key == key.to_s }
  end

  # Upsert a value; blank deletes any override (reverting to ENV/default).
  def self.set(key, raw)
    rec = find_or_initialize_by(key: key.to_s)
    if raw.to_s.strip.empty?
      rec.destroy if rec.persisted?
      return nil
    end
    rec.value = raw
    rec.save!
    rec
  end

  # One-time lift of existing settings into the DB so the admin UI becomes the
  # source of truth. Reads both the process ENV and the .env FILE (foreman/
  # dotenv loads .env at boot, but `rails runner`/seeds don't, so we parse it
  # directly). Only fills keys that have a value and no DB row yet — idempotent,
  # safe to re-run (and to call from seeds). Returns imported keys.
  def self.import_from_env!
    source = env_sources
    imported = []
    REGISTRY.each do |d|
      raw = source[d.key].presence
      next if raw.blank?
      next if exists?(key: d.key)
      set(d.key, raw)
      imported << d.key
    end
    imported
  end

  # Merged settings source: the .env file overlaid by the live process ENV
  # (process ENV wins). Tolerates a missing file or absent dotenv gem.
  def self.env_sources
    file = {}
    begin
      require "dotenv"
      path = Rails.root.join(".env")
      file = Dotenv.parse(path.to_s) if File.exist?(path)
    rescue LoadError, StandardError
      file = {}
    end
    file.merge(ENV.to_h)
  end

  def value
    return nil if encrypted_value.blank?
    self.class.encryptor.decrypt_and_verify(encrypted_value)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def value=(raw)
    self.encrypted_value =
      raw.to_s.strip.empty? ? nil : self.class.encryptor.encrypt_and_sign(raw.to_s.strip)
  end

  def set?
    encrypted_value.present?
  end

  # last 4 chars only — enough to recognise a key, never the whole secret.
  def masked_hint
    v = value
    v.blank? ? nil : "••••#{v[-4..]}"
  end

  def self.encryptor
    @encryptor ||= begin
      len = ActiveSupport::MessageEncryptor.key_len
      key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
                                       .generate_key(ENCRYPT_PURPOSE, len)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end

  private

  def bust_cache
    Rails.cache.delete(self.class.cache_key(key))
  end
end
