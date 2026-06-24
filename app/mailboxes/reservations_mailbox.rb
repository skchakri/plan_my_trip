# Ingests a forwarded hotel/flight/car/activity confirmation emailed to a trip's
# per-trip address (trip-<inbox_token>@<domain>). Stays thin: it resolves the
# trip from the token, persists a Reservation shell with the raw body, and hands
# the slow AI extraction to ParseReservationJob — mirroring the BuildTripJob
# async pattern so we never block the ingress request on an LLM call.
class ReservationsMailbox < ApplicationMailbox
  def process
    token = recipient_token
    trip  = token && Trip.kept.find_by(inbox_token: token)

    # Unknown / expired / discarded-trip token → bounce. Don't 500, don't leak.
    return bounced! if trip.nil?

    reservation = trip.reservations.create!(
      status:      "parsing",
      kind:        "other",
      raw_email:   email_body,
      source_from: Array(mail.from).first.to_s.truncate(255)
    )

    ParseReservationJob.perform_later(reservation.id, subject: mail.subject.to_s)
  end

  private

  # Find the trip- prefixed recipient (To/Cc, or the X-Original-To set by most
  # forwarders) and pull the inbox_token out of it.
  def recipient_token
    candidates = Array(mail.recipients)
    candidates += header_addresses("X-Original-To")
    candidates += header_addresses("Delivered-To")
    candidates.each do |addr|
      if (m = addr.to_s.match(/\Atrip-(?<token>[A-Za-z0-9_-]+)@/i))
        return m[:token]
      end
    end
    nil
  end

  def header_addresses(name)
    Array(mail.header[name]).map { |h| h.to_s }
  end

  # Prefer the plain-text part; fall back to a tag-stripped HTML part so HTML-only
  # confirmations (the common case) still parse. Caps length so a giant multipart
  # forward can't blow up the row (Reservation also enforces this on write).
  def email_body
    raw =
      if mail.multipart?
        mail.text_part&.decoded.presence || strip_html(mail.html_part&.decoded)
      else
        mail.decoded
      end
    raw.to_s.truncate(Reservation::MAX_RAW_EMAIL_BYTES)
  end

  def strip_html(html)
    return "" if html.blank?
    ActionController::Base.helpers.strip_tags(html).squish
  end
end
