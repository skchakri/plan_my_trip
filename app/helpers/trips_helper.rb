module TripsHelper
  # Human-readable one-line description of a concierge-proposed edit, for the
  # Apply card. `edit` is a sanitized hash (string keys) from
  # TripAgent#converse — action + the fields that action uses.
  def concierge_edit_label(edit)
    day = edit["day_number"]
    case edit["action"]
    when "add_activity"
      bits = [ %(Add “#{edit['title']}”) ]
      bits << "at #{edit['time_label']}" if edit["time_label"].present?
      bits << "(#{edit['location_name']})" if edit["location_name"].present?
      "#{bits.join(' ')} to day #{day}"
    when "remove_activity"
      %(Remove “#{edit['activity_title']}” from day #{day})
    when "move_activity"
      %(Move “#{edit['activity_title']}” #{edit['direction']} on day #{day})
    when "update_day_title"
      %(Rename day #{day} to “#{edit['title']}”)
    else
      "Edit day #{day}"
    end
  end
end
