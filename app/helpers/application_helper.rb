module ApplicationHelper
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
end
