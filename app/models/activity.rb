class Activity < ApplicationRecord
  belongs_to :trip_day
  has_one :trip, through: :trip_day

  validates :title, presence: true

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
end
