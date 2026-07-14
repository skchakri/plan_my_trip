require "cgi"

# Exports a trip's mapped stops as KML — the "save my trip points into
# Google Maps" hand-off. Google gives websites no way to inject pins into
# the Maps app or trigger an offline download, but Google **My Maps**
# (mymaps.google.com → Create a map → Import) accepts a KML file and the
# result shows up in the Google Maps app under Saved → Maps, every stop
# included, and plays nice with offline areas.
#
# Layout: one <Folder> per trip day (My Maps renders folders as toggleable
# layers) holding a <Placemark> per geocoded activity, plus a final folder
# of en-route landmarks. Activities without coordinates are skipped — a
# pin with no location is noise. NOTE: KML coordinates are "lng,lat".
#
#   TripKmlBuilder.new(trip).to_kml  # => String (KML XML)
class TripKmlBuilder
  def initialize(trip)
    @trip = trip
  end

  def to_kml
    <<~KML
      <?xml version="1.0" encoding="UTF-8"?>
      <kml xmlns="http://www.opengis.net/kml/2.2">
      <Document>
      <name>#{esc(@trip.title)}</name>
      <description>#{esc(document_description)}</description>
      #{day_folders}#{landmark_folder}</Document>
      </kml>
    KML
  end

  private

  def esc(text)
    CGI.escapeHTML(text.to_s)
  end

  def document_description
    [ @trip.destination.presence,
      (@trip.start_date && @trip.end_date ? "#{@trip.start_date} – #{@trip.end_date}" : nil),
      "Exported from Wanderply" ].compact.join(" · ")
  end

  def day_folders
    @trip.trip_days.includes(:activities).order(:position).filter_map { |day|
      marks = day.activities.order(:position).filter_map { |a| activity_placemark(a) }
      next if marks.empty?
      folder(day_name(day), marks)
    }.join
  end

  def day_name(day)
    [ "Day #{day.position}", day.title.presence ].compact.join(" — ")
  end

  def activity_placemark(activity)
    return nil if activity.latitude.blank? || activity.longitude.blank?
    detail = [ activity.time_label.presence,
               (activity.location_name.presence if activity.location_name != activity.title),
               activity.address.presence ].compact.join(" · ")
    placemark(
      name: activity.title,
      description: [ detail.presence, activity.famous_for.presence ].compact.join("\n"),
      lat: activity.latitude, lng: activity.longitude
    )
  end

  def landmark_folder
    marks = @trip.route_landmarks.filter_map do |l|
      next if l.latitude.blank? || l.longitude.blank?
      placemark(name: l.name, description: l.kind.to_s.presence, lat: l.latitude, lng: l.longitude)
    end
    marks.empty? ? "" : folder("En-route landmarks", marks)
  end

  def folder(name, placemarks)
    "<Folder>\n<name>#{esc(name)}</name>\n#{placemarks.join}</Folder>\n"
  end

  def placemark(name:, description:, lat:, lng:)
    desc = description.to_s.strip
    <<~XML
      <Placemark>
      <name>#{esc(name)}</name>
      #{desc.present? ? "<description>#{esc(desc)}</description>\n" : ""}<Point><coordinates>#{lng.to_f},#{lat.to_f}</coordinates></Point>
      </Placemark>
    XML
  end
end
