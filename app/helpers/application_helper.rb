module ApplicationHelper
  # Whether to surface the per-trip forwarding-address panel. The inbound-mail
  # ingress (SES receipt rule / Mailgun route / etc.) is an infra prerequisite;
  # until an operator wires it and flips INBOUND_EMAIL_ENABLED, showing the
  # "forward confirmations here" affordance in production would be a dead end.
  # Development/test always show it — the Action Mailbox conductor works locally.
  def inbound_email_enabled?
    return true unless Rails.env.production?
    ActiveModel::Type::Boolean.new.cast(AppSetting.get("INBOUND_EMAIL_ENABLED"))
  end

  # Extra input classes when a model attribute has validation errors, so the
  # offending field is highlighted in place (not just listed at the top).
  def input_error_classes(model, attr)
    return "" unless model.respond_to?(:errors) && model.errors[attr].present?
    " border-rose-400 ring-2 ring-rose-500/30"
  end

  # Inline, field-level error message rendered right under the input.
  def field_errors(model, attr)
    return if model.blank? || !model.respond_to?(:errors)
    msgs = model.errors[attr]
    return if msgs.blank?
    tag.p(msgs.to_sentence, class: "mt-1.5 text-xs text-rose-300", role: "alert")
  end

  # Multi-stop "navigate this day" Google Maps directions deep link, built from
  # the day's activities that have coordinates (falling back to a street
  # address). The last stop is the destination, the rest are ordered waypoints;
  # the origin is left to Maps ("your location"). Opens the native Maps app on
  # mobile. Returns nil when the day has nothing routable. Capped at 10 stops —
  # the Maps URL scheme handles ~9 waypoints + a destination reliably.
  def day_directions_url(day)
    points = day.activities.filter_map do |a|
      if a.latitude.present? && a.longitude.present?
        "#{a.latitude},#{a.longitude}"
      elsif a.respond_to?(:address) && a.address.present?
        a.address
      end
    end.first(10)
    return if points.empty?

    url = +"https://www.google.com/maps/dir/?api=1&travelmode=driving"
    url << "&destination=#{CGI.escape(points.last)}"
    url << "&waypoints=#{points[0...-1].map { |p| CGI.escape(p) }.join('|')}" if points.size > 1
    url
  end

  # Google Maps web/app deep link centred on the trip's area at a zoom that
  # frames all the stops. Used for the "Download in Google Maps" hand-off:
  # a website can't trigger Google's offline-map download, but it can open
  # Maps on the right region so the user taps "Download offline map" there.
  # `pins` is an array of hashes carrying :lat/:lng (or "lat"/"lng").
  def google_maps_area_url(pins)
    pts = Array(pins).filter_map do |p|
      lat = p[:lat] || p["lat"]
      lng = p[:lng] || p["lng"]
      [ lat.to_f, lng.to_f ] if lat && lng
    end
    return if pts.empty?

    lats = pts.map(&:first)
    lngs = pts.map(&:last)
    center_lat = (lats.min + lats.max) / 2.0
    center_lng = (lngs.min + lngs.max) / 2.0
    span = [ lats.max - lats.min, lngs.max - lngs.min ].max
    zoom =
      case span
      when 0...0.05  then 12
      when 0.05...0.2 then 11
      when 0.2...0.5 then 10
      when 0.5...1   then 9
      when 1...2     then 8
      when 2...5     then 7
      when 5...10    then 6
      else 5
      end
    "https://www.google.com/maps/@#{center_lat.round(4)},#{center_lng.round(4)},#{zoom}z"
  end
end
