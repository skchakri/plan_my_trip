# Affiliate program identifiers, loaded from ENV. Read by
# BookingLinks to attach affiliate params to outbound provider URLs.
#
# Each value is optional — if blank, the corresponding provider link
# falls back to a plain search URL. So signing up with one network at
# a time is fine; you don't need every key set.
#
# Networks worth signing up with (one-time, free):
#   * Travelpayouts — single account covers Booking.com, Hotels.com,
#     Kayak, Skyscanner, GetYourGuide, Viator, Tiqets, AutoSlash, Turo.
#     Their tag goes in AFFILIATE_TRAVELPAYOUTS_MARKER (used as the
#     `marker` query param Skyscanner / Travelpayouts wraps recognise).
#   * Booking.com Affiliate Partner Program — direct, pays per stay.
#     Tag goes in AFFILIATE_BOOKING_COM_AID.
#   * GetYourGuide Partner Hub — direct, pays per booking.
#     Tag goes in AFFILIATE_GETYOURGUIDE_PARTNER_ID.
#   * Viator Affiliate Program — direct (was Awin).
#     Tag goes in AFFILIATE_VIATOR_PID.
Rails.application.config.x.affiliates = ActiveSupport::OrderedOptions.new.tap do |a|
  a.booking_com_aid          = ENV["AFFILIATE_BOOKING_COM_AID"].presence
  a.booking_com_label        = ENV["AFFILIATE_BOOKING_COM_LABEL"].presence || "plan_my_trip"
  a.getyourguide_partner_id  = ENV["AFFILIATE_GETYOURGUIDE_PARTNER_ID"].presence
  a.viator_pid               = ENV["AFFILIATE_VIATOR_PID"].presence
  a.viator_mcid              = ENV["AFFILIATE_VIATOR_MCID"].presence || "42383"
  a.skyscanner_associateid   = ENV["AFFILIATE_SKYSCANNER_ASSOCIATEID"].presence
  a.travelpayouts_marker     = ENV["AFFILIATE_TRAVELPAYOUTS_MARKER"].presence
end
