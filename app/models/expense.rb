class Expense < ApplicationRecord
  include Discard::Model

  # A handful of common currencies for the picker; any ISO code is accepted.
  CURRENCIES = %w[USD EUR GBP CAD AUD MXN JPY INR].freeze

  belongs_to :trip
  belongs_to :paid_by, class_name: "Person", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :description, presence: true, length: { maximum: 200 }
  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
  validates :currency, presence: true, length: { is: 3 }

  before_validation { self.currency = currency.to_s.upcase.presence || "USD" }
  before_validation :compact_split

  scope :ordered, -> { order(incurred_on: :desc, created_at: :desc) }

  # Dollars in / out for the form + display.
  def amount = amount_cents.to_i / 100.0

  def amount=(value)
    self.amount_cents = (value.to_s.gsub(/[^0-9.\-]/, "").to_f * 100).round
  end

  # Person ids this expense is split across, defaulting to every current
  # traveler when left unset. Filtered to travelers that still exist.
  def split_person_ids(all_person_ids)
    ids = Array(split_between).map(&:to_s) & all_person_ids.map(&:to_s)
    ids.presence || all_person_ids.map(&:to_s)
  end

  private

  def compact_split
    self.split_between = Array(split_between).map(&:to_s).reject(&:blank?).uniq
  end
end
