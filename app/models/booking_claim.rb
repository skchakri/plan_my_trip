class BookingClaim < ApplicationRecord
  KINDS = %w[cars stays flights activities].freeze
  KIND_LABELS = {
    "cars"       => "Cars",
    "stays"      => "Stays",
    "flights"    => "Flights",
    "activities" => "Activities"
  }.freeze
  MAX_DOC_BYTES = 20.megabytes

  belongs_to :trip
  has_many_attached :documents do |attachable|
    attachable.variant :preview, resize_to_limit: [ 800, 800 ]
  end

  validates :kind, inclusion: { in: KINDS }
  validates :kind, uniqueness: { scope: :trip_id }
  validate  :documents_within_size

  def kind_label
    KIND_LABELS[kind] || kind.humanize
  end

  private

  def documents_within_size
    documents.each do |doc|
      next unless doc.byte_size && doc.byte_size > MAX_DOC_BYTES
      errors.add(:documents, "#{doc.filename} is #{ActiveSupport::NumberHelper.number_to_human_size(doc.byte_size)}, max is #{ActiveSupport::NumberHelper.number_to_human_size(MAX_DOC_BYTES)}")
    end
  end
end
