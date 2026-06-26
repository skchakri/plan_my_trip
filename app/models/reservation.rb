class Reservation < ApplicationRecord
  include Discard::Model

  # Reservation kinds we parse out of a forwarded confirmation email. "other"
  # is the catch-all for anything the extractor couldn't confidently classify.
  KINDS = %w[stay flight car activity rail other].freeze
  KIND_LABELS = {
    "stay"     => "Stay",
    "flight"   => "Flight",
    "car"      => "Car rental",
    "activity" => "Activity",
    "rail"     => "Rail",
    "other"    => "Reservation"
  }.freeze
  KIND_ICONS = {
    "stay"     => :bed,
    "flight"   => :plane,
    "car"      => :car,
    "activity" => :ticket,
    "rail"     => :train,
    "other"    => :mail
  }.freeze

  # Maps a parsed reservation kind onto the BookingClaim "handled" kinds so a
  # forwarded confirmation collapses the matching "Book this trip" card.
  BOOKING_KIND = {
    "stay"     => "stays",
    "flight"   => "flights",
    "car"      => "cars",
    "activity" => "activities"
  }.freeze

  STATUSES = %w[parsing parsed failed].freeze

  # Hard cap on stored raw email so a giant multipart forward can't bloat the row.
  MAX_RAW_EMAIL_BYTES = 64.kilobytes

  belongs_to :trip
  belongs_to :trip_day, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  before_validation :truncate_raw_email

  scope :ordered, -> { order(Arel.sql("start_at IS NULL"), start_at: :asc, created_at: :asc) }
  scope :parsing, -> { where(status: "parsing") }
  scope :parsed,  -> { where(status: "parsed") }
  scope :failed,  -> { where(status: "failed") }

  def kind_label
    KIND_LABELS[kind] || kind.to_s.humanize
  end

  def kind_icon
    KIND_ICONS[kind] || :mail
  end

  def booking_kind
    BOOKING_KIND[kind]
  end

  def parsing?
    status == "parsing"
  end

  def parsed?
    status == "parsed"
  end

  def failed?
    status == "failed"
  end

  # Short one-line headline for list rows: the AI title, else the vendor, else
  # the humanized kind. Always returns something renderable.
  def headline
    title.presence || vendor.presence || kind_label
  end

  private

  def truncate_raw_email
    return if raw_email.blank?
    return if raw_email.bytesize <= MAX_RAW_EMAIL_BYTES
    self.raw_email = raw_email.byteslice(0, MAX_RAW_EMAIL_BYTES).scrub
  end
end
