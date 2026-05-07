# Generates pre-populated search URLs for hotels, cars, flights, and
# activities based on a Trip. Member-aware: when the viewing user has
# certain loyalty memberships, those provider links are badged as
# "Member rate" so they sort to the top of each section.
#
# All URLs hit public, documented search forms. No affiliate IDs are
# attached — if/when you sign up for affiliate programs, append your tag
# in the per-provider builders below.
class BookingLinks
  Link = Struct.new(:provider, :url, :badge, :note, keyword_init: true)

  def initialize(trip, viewer: nil)
    @trip = trip
    @viewer = viewer
  end

  def hotels
    return [] if destination.blank?
    out = []
    out << Link.new(provider: "Booking.com", url: booking_com_hotels,
                    badge: viewer_has?(:booking_genius) ? "Genius rate auto-applied" : nil,
                    note: "10% Genius discount kicks in after 2 stays — free")
    out << Link.new(provider: "Hotels.com", url: hotels_com,
                    badge: viewer_has?(:hotels_rewards) ? "1 free night per 10 stamps" : nil)
    out << Link.new(provider: "Expedia", url: expedia_hotels)
    out << Link.new(provider: "Kayak", url: kayak_hotels,
                    note: "Aggregator — compare prices across sites")
    out << Link.new(provider: "Hilton (direct)", url: hilton_search,
                    badge: viewer_has?(:hilton_honors) ? "Honors Discount Rate (member)" : nil,
                    note: "Honors members get up to 20% off the Best Flexible Rate")
    out << Link.new(provider: "Marriott (direct)", url: marriott_search,
                    badge: viewer_has?(:marriott_bonvoy) ? "Member Rate (5-15% off)" : nil)
    out << Link.new(provider: "Hyatt (direct)", url: hyatt_search,
                    badge: viewer_has?(:hyatt_world) ? "Member Rate" : nil)
    out << Link.new(provider: "IHG (direct)", url: ihg_search,
                    badge: viewer_has?(:ihg_one) ? "Member Rate" : nil)
    if viewer_has?(:costco)
      out << Link.new(provider: "Costco Travel", url: "https://www.costcotravel.com/Hotels",
                      badge: "Member rate", note: "Often beats published rates; 2% Executive reward")
    end
    sort_member_first(out)
  end

  def cars
    return [] if destination.blank?
    out = []
    out << Link.new(provider: "Kayak Cars", url: kayak_cars,
                    note: "Aggregator — compare across rental brands")
    out << Link.new(provider: "AutoSlash", url: "https://www.autoslash.com/",
                    note: "Free price tracking — auto-rebooks if your rate drops")
    if viewer_has?(:costco)
      out << Link.new(provider: "Costco Travel Cars", url: "https://www.costcotravel.com/Rental-Cars",
                      badge: "Member rate", note: "Frequently the cheapest minivan/SUV booking; free additional driver")
    end
    out << Link.new(provider: "Hertz", url: "https://www.hertz.com/")
    out << Link.new(provider: "Enterprise", url: "https://www.enterprise.com/")
    out << Link.new(provider: "Turo", url: turo_search,
                    note: "Peer-to-peer — sometimes cheaper, sometimes not")
    sort_member_first(out)
  end

  def flights
    return [] if destination.blank?
    out = []
    out << Link.new(provider: "Google Flights", url: google_flights,
                    note: "Best aggregator — calendar view shows cheapest dates")
    out << Link.new(provider: "Kayak Flights", url: kayak_flights)
    out << Link.new(provider: "Skyscanner", url: skyscanner_flights)
    if viewer_has?(:southwest_rapid)
      out << Link.new(provider: "Southwest", url: "https://www.southwest.com/air/booking/",
                      badge: "Member", note: "Two free checked bags · no change fees")
    end
    out
  end

  def activities
    return [] if destination.blank?
    [
      Link.new(provider: "GetYourGuide", url: getyourguide,
               note: "Free cancellation up to 24h on most tours"),
      Link.new(provider: "Viator", url: viator),
      Link.new(provider: "Tiqets", url: tiqets, note: "Skip-the-line tickets for museums + attractions"),
      Link.new(provider: "Klook", url: klook, note: "Strong in Asia + activities + transfers")
    ]
  end

  # Card travel portals — a real way to stack points (often 5x) and
  # access Hotel Collection / Fine Hotels & Resorts perks.
  def card_portals
    out = []
    out << Link.new(provider: "Chase Travel", url: "https://travel.chase.com/",
                    note: "5x on hotels, 10x on cars when booked through portal") if viewer_has?(:chase_sapphire)
    out << Link.new(provider: "Amex Travel (FHR)", url: "https://travel.americanexpress.com/",
                    note: "Fine Hotels & Resorts: $100 credit + 4 PM checkout + breakfast on Plat") if viewer_has?(:amex_platinum)
    out << Link.new(provider: "Capital One Travel", url: "https://travel.capitalone.com/",
                    note: "Price prediction, freeze-the-fare, 10x miles on hotels/cars") if viewer_has?(:capital_one_venture)
    out
  end

  # Discounts that always apply — no codes needed, just real recurring offers.
  # Returned as plain hashes for the partial to render as bullet points.
  def discount_tips
    tips = []
    tips << { title: "Hilton Honors Discount Rate", body: "Free Honors signup gives ~10–20% off Best Flexible Rate at most properties." } if viewer_has?(:hilton_honors)
    tips << { title: "Marriott Bonvoy Member Rate", body: "Free Bonvoy signup gives 5–15% off Best Available Rate." } if viewer_has?(:marriott_bonvoy)
    tips << { title: "Hyatt Member Rate", body: "World of Hyatt members see member rates on most direct bookings." } if viewer_has?(:hyatt_world)
    tips << { title: "IHG One Rewards", body: "Members get IHG Rewards rate + free room upgrades when available." } if viewer_has?(:ihg_one)
    tips << { title: "Booking.com Genius (auto)", body: "After 2 completed stays, you get 10% off + free breakfast at participating properties — automatic, no code." }
    tips << { title: "Costco Travel for cars", body: "Costco rates are frequently the cheapest published rate, with free additional driver and no young-driver fees over 25." } if viewer_has?(:costco)
    tips << { title: "AAA discount at booking", body: "Many hotels offer 5–10% off the AAA rate. Apply at the chain's site, not OTAs." } if viewer_has?(:aaa)
    tips << { title: "AARP rate (50+)", body: "Wyndham, Hilton, Best Western honor AARP. Stacks with senior bookings." } if viewer_has?(:aarp)
    tips << { title: "Best Price Guarantee", body: "Hilton, Marriott, Hyatt, IHG all match a lower price found on a third-party site within 24 hours of booking — submit a claim and they'll match + add a small bonus." }
    tips << { title: "AutoSlash for car rentals", body: "Forward your rental confirmation; AutoSlash watches the price and auto-rebooks at lower rates until pickup. Free." }
    tips
  end

  private

  attr_reader :trip, :viewer

  def viewer_has?(key)
    viewer&.has_membership?(key) || false
  end

  def sort_member_first(links)
    links.partition { |l| l.badge.to_s.match?(/member|honors|genius/i) }.flatten
  end

  def destination
    @destination ||= trip.destination.to_s.strip
  end

  def origin
    @origin ||= trip.origin.to_s.strip
  end

  def adults
    trip.traveler_count.to_i.clamp(1, 30)
  end

  def start_iso = trip.start_date&.iso8601
  def end_iso   = trip.end_date&.iso8601
  def start_us  = trip.start_date&.strftime("%m/%d/%Y")
  def end_us    = trip.end_date&.strftime("%m/%d/%Y")

  # ── Hotel URLs ────────────────────────────────────────────────────────
  def booking_com_hotels
    "https://www.booking.com/searchresults.html?#{q(ss: destination, checkin: start_iso, checkout: end_iso, group_adults: adults)}"
  end

  def hotels_com
    "https://www.hotels.com/Hotel-Search?#{q(destination: destination, startDate: start_iso, endDate: end_iso, adults: adults)}"
  end

  def expedia_hotels
    "https://www.expedia.com/Hotel-Search?#{q(destination: destination, startDate: start_iso, endDate: end_iso, adults: adults)}"
  end

  def kayak_hotels
    base = "https://www.kayak.com/hotels"
    parts = [ base, encode_path(destination) ]
    parts << start_iso if start_iso
    parts << end_iso if end_iso
    parts << "#{adults}adults"
    parts.join("/")
  end

  def hilton_search
    "https://www.hilton.com/en/search/?#{q(query: destination, arrivalDate: start_iso, departureDate: end_iso, numAdults: adults)}"
  end

  def marriott_search
    "https://www.marriott.com/search/findHotels.mi?#{q('destinationAddress.destination' => destination, fromDate: start_us, toDate: end_us, numberOfAdults: adults)}"
  end

  def hyatt_search
    "https://www.hyatt.com/search?#{q(location: destination, checkinDate: start_iso, checkoutDate: end_iso, adults: adults)}"
  end

  def ihg_search
    "https://www.ihg.com/hotels/us/en/find-hotels/hotel/list?#{q(qDest: destination, qCiD: trip.start_date&.day, qCiMy: trip.start_date&.strftime('%-m%Y'), qCoD: trip.end_date&.day, qCoMy: trip.end_date&.strftime('%-m%Y'), qAdlt: adults)}"
  end

  # ── Car URLs ──────────────────────────────────────────────────────────
  def kayak_cars
    base = "https://www.kayak.com/cars"
    parts = [ base, encode_path(destination) ]
    parts << start_iso if start_iso
    parts << end_iso if end_iso
    parts.join("/")
  end

  def turo_search
    "https://turo.com/us/en/search?#{q(country: 'US', defaultZoomLevel: 7, location: destination, region: 'US', startDate: start_iso, endDate: end_iso)}"
  end

  # ── Flight URLs ───────────────────────────────────────────────────────
  def google_flights
    parts = [ "Flights" ]
    parts << "from #{origin}" if origin.present?
    parts << "to #{destination}"
    parts << "on #{start_iso}" if start_iso
    parts << "through #{end_iso}" if end_iso
    "https://www.google.com/travel/flights?#{q(q: parts.join(' '))}"
  end

  def kayak_flights
    base = "https://www.kayak.com/flights"
    if origin.present?
      "#{base}/#{encode_path(origin)}-#{encode_path(destination)}/#{start_iso}#{end_iso ? "/#{end_iso}" : ''}"
    else
      "#{base}?#{q(searchOrigin: '', searchDestination: destination, departureDate: start_iso, returnDate: end_iso)}"
    end
  end

  def skyscanner_flights
    "https://www.skyscanner.com/transport/flights/?#{q(adultsv2: adults, cabinclass: 'economy')}"
  end

  # ── Activity URLs ─────────────────────────────────────────────────────
  def getyourguide
    "https://www.getyourguide.com/s/?#{q(q: destination, date_from: start_iso, date_to: end_iso)}"
  end

  def viator
    "https://www.viator.com/searchResults/all?#{q(text: destination)}"
  end

  def tiqets
    "https://www.tiqets.com/en/search?#{q(query: destination)}"
  end

  def klook
    "https://www.klook.com/en-US/search/result/?#{q(query: destination)}"
  end

  # ── helpers ───────────────────────────────────────────────────────────
  def q(hash)
    hash.compact.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
  end

  def encode_path(str)
    CGI.escape(str.to_s).gsub("+", "%20")
  end
end
