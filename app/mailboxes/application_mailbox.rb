class ApplicationMailbox < ActionMailbox::Base
  # Per-trip forwarding addresses: trip-<inbox_token>@<INBOUND_EMAIL_DOMAIN>.
  # Anything matching the trip- prefix routes to the reservations mailbox; the
  # mailbox itself bounces unknown/expired tokens so we never leak trips.
  routing(/\Atrip-(?<token>[A-Za-z0-9_-]+)@/i => :reservations)
end
