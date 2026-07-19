class User < ApplicationRecord
  # Catalog of supported discount/loyalty memberships. Used by the booking
  # link partial to badge "member rate" links and to surface real recurring
  # discounts (no scraped promo codes).
  MEMBERSHIPS = {
    costco:              { label: "Costco",              category: :wholesale },
    aaa:                 { label: "AAA",                 category: :wholesale },
    aarp:                { label: "AARP",                category: :wholesale },
    hilton_honors:       { label: "Hilton Honors",       category: :hotel },
    marriott_bonvoy:     { label: "Marriott Bonvoy",     category: :hotel },
    hyatt_world:         { label: "World of Hyatt",      category: :hotel },
    ihg_one:             { label: "IHG One Rewards",     category: :hotel },
    best_western:        { label: "Best Western Rewards", category: :hotel },
    booking_genius:      { label: "Booking.com Genius",  category: :hotel },
    hotels_rewards:      { label: "Hotels.com Rewards",  category: :hotel },
    aadvantage:          { label: "AAdvantage",          category: :airline },
    delta_skymiles:      { label: "Delta SkyMiles",      category: :airline },
    united_mileageplus:  { label: "United MileagePlus",  category: :airline },
    southwest_rapid:     { label: "Southwest Rapid Rewards", category: :airline },
    chase_sapphire:      { label: "Chase Sapphire",      category: :card },
    amex_platinum:       { label: "Amex Platinum",       category: :card },
    capital_one_venture: { label: "Capital One Venture", category: :card }
  }.freeze

  # Interest tags surfaced on the day-trip wizard and used as Claude vibes
  # when ranking nearby ideas. Each value is a (label, emoji, vibes) triple
  # — vibes feed DestinationHighlights::VIBES so day-trip and multi-day
  # ranking share the same downstream vocabulary.
  DAY_TRIP_INTERESTS = [
    { key: "hiking",      label: "Hiking & trails",        emoji: "🥾", vibes: %w[adventure nature] },
    { key: "scenic",      label: "Scenic drives & overlooks", emoji: "🚗", vibes: %w[scenic photography nature] },
    { key: "family",      label: "Family-friendly",        emoji: "👨‍👩‍👧", vibes: %w[family relaxing] },
    { key: "food",        label: "Food & breweries",       emoji: "🍴", vibes: %w[food nightlife] },
    { key: "history",     label: "History & museums",      emoji: "🏛️", vibes: %w[cultural history] },
    { key: "water",       label: "Lakes & swimming",       emoji: "🏊", vibes: %w[relaxing nature] },
    { key: "wildlife",    label: "Wildlife & nature",      emoji: "🦌", vibes: %w[nature photography] },
    { key: "photography", label: "Photography spots",      emoji: "📷", vibes: %w[photography scenic] },
    { key: "shopping",    label: "Shopping & markets",     emoji: "🛍️", vibes: %w[shopping food] }
  ].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :owned_trips, class_name: "Trip", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :trip_memberships, dependent: :destroy
  has_many :trips, through: :trip_memberships
  has_many :notifications_received, class_name: "Notification", foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient
  has_many :quiz_attempts, dependent: :destroy
  has_many :support_tickets, dependent: :destroy

  # Form-friendly bridge for the daily-digest opt-out. The DB column is a
  # nullable timestamp (so we can know *when* the user opted out), but the
  # account page just shows a checkbox: 1 = receive digest, 0 = opt out.
  def receive_digest
    digest_optout_at.blank?
  end

  def receive_digest=(value)
    truthy = ActiveModel::Type::Boolean.new.cast(value)
    self.digest_optout_at = truthy ? nil : (digest_optout_at || Time.current)
  end

  validates :name, presence: true

  def display_name
    name.presence || email.split("@").first
  end

  def has_membership?(key)
    discount_memberships.to_h[key.to_s] == true
  end

  def memberships_in(category)
    MEMBERSHIPS.select { |k, v| v[:category] == category && has_membership?(k) }.keys
  end

  # Coerce form values ("1"/"0") into booleans before persisting jsonb.
  def discount_memberships=(value)
    return super(value) unless value.is_a?(Hash) || value.respond_to?(:to_unsafe_h)
    hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value
    cast = ActiveModel::Type::Boolean.new
    super(hash.each_with_object({}) { |(k, v), h| h[k.to_s] = cast.cast(v) })
  end

  def home_base?
    home_lat.present? && home_lng.present?
  end

  def home_label
    home_city.presence || (home_base? ? "#{home_lat.to_f.round(3)}, #{home_lng.to_f.round(3)}" : nil)
  end

  def default_interests=(value)
    super(Array(value).map { |i| i.to_s.strip }.reject(&:blank?).uniq)
  end
end
