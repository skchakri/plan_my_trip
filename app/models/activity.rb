class Activity < ApplicationRecord
  MAX_DOCUMENT_BYTES = 15.megabytes

  belongs_to :trip_day
  has_one :trip, through: :trip_day

  has_many_attached :documents do |attachable|
    attachable.variant :preview, resize_to_limit: [ 600, 600 ]
  end

  validates :title, presence: true
  validate :documents_within_size_limit

  def maps_link
    return maps_url if maps_url.present?
    return nil if address.blank?
    "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(address)}&travelmode=driving"
  end

  def uber_link
    return uber_url if uber_url.present?
    return nil if address.blank?
    "https://m.uber.com/ul/?action=setPickup&pickup=my_location&dropoff%5Bformatted_address%5D=#{CGI.escape(address)}"
  end

  def checklist_items
    trip.checklist_items.where(scope: "activity", activity_label: title)
  end

  def packed_count
    checklist_items.where(packed: true).count
  end

  private

  def documents_within_size_limit
    documents.each do |doc|
      next unless doc.byte_size && doc.byte_size > MAX_DOCUMENT_BYTES
      errors.add(:documents, "#{doc.filename} is #{ActiveSupport::NumberHelper.number_to_human_size(doc.byte_size)}, max is #{ActiveSupport::NumberHelper.number_to_human_size(MAX_DOCUMENT_BYTES)}")
    end
  end
end
