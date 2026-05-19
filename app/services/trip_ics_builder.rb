class TripIcsBuilder
  PRODID  = "-//Plan My Trip//EN".freeze
  CRLF    = "\r\n".freeze
  TZID    = "Etc/UTC".freeze
  WRAP_AT = 73 # RFC 5545 §3.1: lines SHOULD be wrapped at 75 octets.

  def initialize(trip)
    @trip = trip
  end

  def to_ics
    lines = []
    lines << "BEGIN:VCALENDAR"
    lines << "VERSION:2.0"
    lines << "PRODID:#{PRODID}"
    lines << "METHOD:PUBLISH"
    lines << "X-WR-CALNAME:#{escape_text(@trip.title)}"
    lines << "X-WR-CALDESC:#{escape_text(@trip.destination.to_s)}"
    lines << "X-WR-TIMEZONE:#{TZID}"
    lines.concat(overview_event) if @trip.start_date && @trip.end_date
    @trip.trip_days.includes(:activities).order(:position).each do |day|
      day.activities.order(:position).each do |a|
        lines.concat(activity_event(day, a))
      end
    end
    lines << "END:VCALENDAR"
    fold(lines).join(CRLF) + CRLF
  end

  private

  def overview_event
    [
      "BEGIN:VEVENT",
      "UID:trip-#{@trip.id}@planmytrip",
      "DTSTAMP:#{ics_stamp(@trip.updated_at)}",
      "DTSTART;VALUE=DATE:#{ics_date(@trip.start_date)}",
      # All-day VEVENTs are exclusive on DTEND, so add one day.
      "DTEND;VALUE=DATE:#{ics_date(@trip.end_date + 1)}",
      "SUMMARY:#{escape_text(@trip.title)}",
      ("DESCRIPTION:#{escape_text(@trip.body)}" if @trip.body.present?),
      ("LOCATION:#{escape_text(@trip.destination)}" if @trip.destination.present?),
      "END:VEVENT"
    ].compact
  end

  def activity_event(day, activity)
    start_at = activity_start_at(day, activity)
    end_at   = start_at + 60.minutes # default 1-hour block
    lines = [
      "BEGIN:VEVENT",
      "UID:activity-#{activity.id}@planmytrip",
      "DTSTAMP:#{ics_stamp(activity.updated_at)}",
      "DTSTART:#{ics_datetime(start_at)}",
      "DTEND:#{ics_datetime(end_at)}",
      "SUMMARY:#{escape_text(activity.title)}"
    ]
    location = [ activity.location_name, activity.address ].reject(&:blank?).uniq.join(", ")
    lines << "LOCATION:#{escape_text(location)}" if location.present?
    if activity.latitude.present? && activity.longitude.present?
      lines << "GEO:#{activity.latitude};#{activity.longitude}"
    end
    if activity.notes.present?
      lines << "DESCRIPTION:#{escape_text(activity.notes)}"
    end
    lines << "END:VEVENT"
    lines
  end

  # Activities without an explicit time get bucketed sequentially through
  # the day starting at 9am, so subscribers see them in plan-order.
  def activity_start_at(day, activity)
    base_date = day.date || @trip.start_date || Date.current
    if activity.time_label.present? && (parsed = parse_time(activity.time_label))
      base_date.to_time(:utc).change(hour: parsed[0], min: parsed[1])
    else
      base_date.to_time(:utc).change(hour: 9) + (activity.position.to_i * 90.minutes)
    end
  end

  # Accepts "9am", "14:30", "2:30 PM" — returns [hour, minute] or nil.
  def parse_time(str)
    s = str.to_s.strip.downcase
    if (m = s.match(/\A(\d{1,2}):(\d{2})\s*(am|pm)?\z/))
      h, mn, ap = m[1].to_i, m[2].to_i, m[3]
      h = 0  if ap == "am" && h == 12
      h += 12 if ap == "pm" && h < 12
      [ h % 24, mn ]
    elsif (m = s.match(/\A(\d{1,2})\s*(am|pm)\z/))
      h, ap = m[1].to_i, m[2]
      h = 0  if ap == "am" && h == 12
      h += 12 if ap == "pm" && h < 12
      [ h % 24, 0 ]
    end
  end

  def ics_date(date)     = date.strftime("%Y%m%d")
  def ics_datetime(time) = time.utc.strftime("%Y%m%dT%H%M%SZ")
  def ics_stamp(time)    = (time || Time.current).utc.strftime("%Y%m%dT%H%M%SZ")

  # RFC 5545 §3.3.11: escape backslash, comma, semicolon; newline → \n.
  def escape_text(str)
    str.to_s.gsub("\\", "\\\\").gsub(/\r?\n/, "\\n").gsub(",", "\\,").gsub(";", "\\;")
  end

  # RFC 5545 §3.1: long content lines fold at 75 octets with CRLF + space.
  def fold(lines)
    lines.flat_map do |line|
      next line if line.bytesize <= WRAP_AT
      pieces = []
      while line.bytesize > WRAP_AT
        pieces << line.byteslice(0, WRAP_AT)
        line    = line.byteslice(WRAP_AT, line.bytesize - WRAP_AT)
      end
      pieces << line unless line.empty?
      pieces.each_with_index.map { |p, i| i.zero? ? p : " #{p}" }
    end
  end
end
