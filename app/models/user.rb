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

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :owned_trips, class_name: "Trip", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :trip_memberships, dependent: :destroy
  has_many :trips, through: :trip_memberships

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
end
