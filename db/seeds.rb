demo = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.name = "Kalyan"
  u.password = "password123"
  u.password_confirmation = "password123"
end

vegas_body = Rails.root.join("docs/TRIP_VEGAS_2026_05.md").read

vegas_trip = Trip.find_or_create_by!(owner: demo, title: "Vegas trip — May 7-10, 2026") do |t|
  t.destination = "Las Vegas, NV"
  t.start_date = Date.new(2026, 5, 7)
  t.end_date = Date.new(2026, 5, 10)
  t.body = vegas_body
  t.pwa_plan_url = "/vegas-trip-4days.html"
  t.pwa_packing_url = "/vegas-packing.html"
end

# Backfill PWA links if the trip already existed before these columns
vegas_trip.update_columns(
  pwa_plan_url: "/vegas-trip-4days.html",
  pwa_packing_url: "/vegas-packing.html"
) if vegas_trip.pwa_plan_url.blank?

[
  { name: "Calico Tanks Trail (Red Rock Canyon)",
    alltrails_url: "https://www.alltrails.com/trail/us/nevada/calico-tanks-trail",
    notes: "2.2 mi out-and-back · moderate · panoramic Strip view from the top." },
  { name: "Hoover Dam Lakeview Overlook",
    alltrails_url: "https://www.alltrails.com/trail/us/nevada/historic-railroad-trail",
    notes: "Historic Railroad Trail · easy · paved with tunnels, good for grandparents." }
].each_with_index do |attrs, i|
  vegas_trip.trails.find_or_create_by!(name: attrs[:name]) do |t|
    t.alltrails_url = attrs[:alltrails_url]
    t.notes = attrs[:notes]
    t.position = i
  end
end

checklist = [
  # ── Before trip (overall prep) ─────────────────────────────────────
  { scope: "before_trip", category: "Documents", title: "Driver's license + primary CDW credit card", person: "Kalyan" },
  { scope: "before_trip", category: "Documents", title: "Hotel + car rental confirmations (PDF on phone)", person: "Kalyan" },
  { scope: "before_trip", category: "Documents", title: "Insurance card", person: "Kalyan" },
  { scope: "before_trip", category: "Hotel",     title: "Swim gear + pool towels", person: "All" },
  { scope: "before_trip", category: "Hotel",     title: "Toiletries kit", person: "Wife" },
  { scope: "before_trip", category: "Parents",   title: "Daily medications (4 days supply)", person: "Parents" },
  { scope: "before_trip", category: "Parents",   title: "Reading glasses", person: "Parents" },
  { scope: "before_trip", category: "Tech",      title: "Phone chargers (USB-C + Lightning)", person: "Kalyan" },
  { scope: "before_trip", category: "Tech",      title: "Backup power bank", person: "Kalyan" },
  { scope: "before_trip", category: "Tech",      title: "Download offline Google Maps for Vegas + Hualapai area", person: "Kalyan" },

  # ── Per day ────────────────────────────────────────────────────────
  { scope: "day", day_label: "Thursday May 7 — Drive in",     title: "Cooler with water + snacks", person: "Wife" },
  { scope: "day", day_label: "Thursday May 7 — Drive in",     title: "Cash for tolls and gas", person: "Kalyan" },
  { scope: "day", day_label: "Thursday May 7 — Drive in",     title: "Sunglasses for everyone", person: nil },
  { scope: "day", day_label: "Thursday May 7 — Drive in",     title: "Costco gas at North Salt Lake before pickup", person: "Kalyan" },
  { scope: "day", day_label: "Friday May 8 — Sphere day",     title: "Cardigans for the venue (68°F inside)", person: "All" },
  { scope: "day", day_label: "Friday May 8 — Sphere day",     title: "Comfortable shoes (lots of walking)", person: "All" },
  { scope: "day", day_label: "Saturday May 9 — Skywalk day",  title: "Earlier wake-up — leave by 7 AM", person: nil },
  { scope: "day", day_label: "Saturday May 9 — Skywalk day",  title: "Lunch snacks (long drive, limited stops)", person: "Wife" },
  { scope: "day", day_label: "Sunday May 10 — Drive home",    title: "Hotel checkout — keys at front desk", person: "Kalyan" },

  # ── Per activity ───────────────────────────────────────────────────
  { scope: "activity", activity_label: "Sphere — Wizard of Oz (Fri 2 PM)",        title: "Screenshot QR tickets in case of no signal", person: "Kalyan" },
  { scope: "activity", activity_label: "Sphere — Wizard of Oz (Fri 2 PM)",        title: "Bathroom stop before the 90-min show", person: "All" },
  { scope: "activity", activity_label: "Sphere — Wizard of Oz (Fri 2 PM)",        title: "No food/drink past security — eat beforehand", person: "All" },
  { scope: "activity", activity_label: "Spy Ninjas HQ (Fri 10 AM)",               title: "Grip socks for the kids' obstacle course", person: "Kids" },
  { scope: "activity", activity_label: "Spy Ninjas HQ (Fri 10 AM)",               title: "Change of clothes (kids will sweat)", person: "Kids" },
  { scope: "activity", activity_label: "Grand Canyon Skywalk (Sat 10 AM)",        title: "Hats with chin straps — windy at the bridge", person: "Kids" },
  { scope: "activity", activity_label: "Grand Canyon Skywalk (Sat 10 AM)",        title: "Dramamine for the kids before the winding road", person: "Kids" },
  { scope: "activity", activity_label: "Grand Canyon Skywalk (Sat 10 AM)",        title: "Lock-up bag for phones (not allowed on bridge)", person: nil },
  { scope: "activity", activity_label: "Bellagio + Forum Shops walk (Fri AM)",    title: "Comfortable walking shoes (parents)", person: "Parents" },
  { scope: "activity", activity_label: "Bellagio + Forum Shops walk (Fri AM)",    title: "Pre-saved Uber payment method", person: "Kalyan" }
]
checklist.each_with_index do |attrs, i|
  vegas_trip.checklist_items.find_or_create_by!(title: attrs[:title]) do |it|
    it.scope          = attrs[:scope]
    it.category       = attrs[:category]
    it.day_label      = attrs[:day_label]
    it.activity_label = attrs[:activity_label]
    it.person         = attrs[:person]
    it.position       = i
    it.packed         = false
  end
end

puts "Seeded: #{demo.email} / password123"
puts "Trips: #{Trip.count}, Trails: #{Trail.count}, Checklist items: #{ChecklistItem.count}"
