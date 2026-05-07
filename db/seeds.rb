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
  { scope: "activity", activity_label: "Spy Ninjas HQ (Group A)",                 title: "Grip socks for the kids' obstacle course", person: "Kids" },
  { scope: "activity", activity_label: "Spy Ninjas HQ (Group A)",                 title: "Change of clothes (kids will sweat)", person: "Kids" },
  { scope: "activity", activity_label: "Grand Canyon Skywalk (Sat 10 AM)",        title: "Hats with chin straps — windy at the bridge", person: "Kids" },
  { scope: "activity", activity_label: "Grand Canyon Skywalk (Sat 10 AM)",        title: "Dramamine for the kids before the winding road", person: "Kids" },
  { scope: "activity", activity_label: "Grand Canyon Skywalk (Sat 10 AM)",        title: "Lock-up bag for phones (not allowed on bridge)", person: nil },
  { scope: "activity", activity_label: "Bellagio Conservatory (Group B)",         title: "Comfortable walking shoes (parents)", person: "Parents" },
  { scope: "activity", activity_label: "Bellagio Conservatory (Group B)",         title: "Pre-saved Uber payment method", person: "Kalyan" }
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

vegas_days = [
  {
    label:   "Thursday May 7 — Drive in",
    date:    Date.new(2026, 5, 7),
    title:   "Drive in",
    theme:   "arrive",
    accent:  "blue",
    summary: "12:30 PM departure from North Salt Lake. ~6 hours via I-15 with a lunch stop in Beaver. Vegas by 7 PM.",
    activities: [
      { time_label: "12:30 PM", title: "Depart North Salt Lake",
        location_name: "Home", address: "3906 Maryland Ave, Las Vegas, NV 89121",
        photo_url: "https://images.unsplash.com/photo-1507608616759-54f48f0af0ee?w=800&q=80",
        notes: "Pack the cooler, top off Costco gas at 1818 N Redwood Rd before pickup." },
      { time_label: "3:30 PM",  title: "Lunch + gas — Arshel's Café",
        location_name: "Arshel's Café, Beaver UT", address: "711 N Main St, Beaver, UT 84713",
        photo_url: "https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800&q=80",
        notes: "Halfway point. Clean restrooms + diner food. 30 min stop." },
      { time_label: "7:30 PM",  title: "Arrive in Vegas — check in + Smith's grocery run",
        location_name: "Smith's Food and Drug",      address: "2540 S Maryland Pkwy, Las Vegas, NV 89109",
        photo_url: "https://images.unsplash.com/photo-1606406054219-619c4c2e2100?w=800&q=80",
        notes: "Stock the kitchen for 3 days of breakfasts + snacks. Pool / unwind, early bed." }
    ]
  },
  {
    label:   "Friday May 8 — Sphere day",
    date:    Date.new(2026, 5, 8),
    title:   "Sphere day",
    theme:   "main event",
    accent:  "gold",
    summary: "Split morning — wife and kids go to Spy Ninjas; you take the parents to a slow Strip walk. Both groups regroup at Sphere for the 2 PM show.",
    activities: [
      { time_label: "10:00 AM", title: "Spy Ninjas HQ (Group A)", group_label: "Group A — Wife + kids",
        location_name: "Spy Ninjas HQ", address: "7980 W Sahara Ave, Las Vegas, NV 89117",
        photo_url: "https://images.unsplash.com/photo-1577896851231-70ef18881754?w=800&q=80",
        notes: "Action Pass, ~2 hr. Mini-Ninja section for younger kids." },
      { time_label: "10:30 AM", title: "Bellagio Conservatory (Group B)", group_label: "Group B — You + parents",
        location_name: "Bellagio Conservatory & Botanical Gardens", address: "3600 S Las Vegas Blvd, Las Vegas, NV 89109",
        photo_url: "https://images.unsplash.com/photo-1581351721010-8cf859cb14a4?w=800&q=80",
        notes: "Free, indoor, fully accessible. Plan ~1 hour. Slow gentle walk for the parents to ease into the day." },
      { time_label: "11:45 AM", title: "Forum Shops at Caesars (Group B)", group_label: "Group B — You + parents",
        location_name: "Forum Shops at Caesars Palace", address: "3500 S Las Vegas Blvd, Las Vegas, NV 89109",
        photo_url: "https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=800&q=80",
        notes: "Roman architecture, AC, free fountain shows. If parents' knees ache — Uber the 5-min hop instead of walking." },
      { time_label: "12:30 PM", title: "Lunch at Eataly — Park MGM (Group B)", group_label: "Group B — You + parents",
        location_name: "Eataly Las Vegas", address: "3770 S Las Vegas Blvd, Las Vegas, NV 89109",
        photo_url: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80",
        notes: "Italian food market under one roof — many veg options. Saravanaa Bhavan on Maryland Pkwy is the South Indian alternative." },
      { time_label: "1:30 PM",  title: "Regroup at Sphere",
        location_name: "Sphere", address: "255 Sands Ave, Las Vegas, NV 89169",
        photo_url: "https://images.unsplash.com/photo-1542204625-ca960325cc62?w=800&q=80",
        notes: "Meet at the LED orb on the south side. 15-20 min security takes a while on weekend matinees." },
      { time_label: "2:00 PM",  title: "Sphere — Wizard of Oz (Fri 2 PM)",
        location_name: "Sphere", address: "255 Sands Ave, Las Vegas, NV 89169",
        photo_url: "https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=800&q=80",
        notes: "90 min show. Venue is 68°F — bring cardigans. Phones allowed but no filming during immersive segments." },
      { time_label: "Evening",  title: "Pool + Bellagio fountains",
        location_name: "Bellagio Fountains", address: "3600 S Las Vegas Blvd, Las Vegas, NV 89109",
        photo_url: "https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=800&q=80",
        notes: "Free fountain shows every 15 min after 8 PM. Casual stroll to wind down — kids love this." }
    ]
  },
  {
    label:   "Saturday May 9 — Skywalk day",
    date:    Date.new(2026, 5, 9),
    title:   "Skywalk day",
    theme:   "adventure",
    accent:  "teal",
    summary: "7 AM departure for the Grand Canyon Skywalk. ~2.5 hr drive. Photo stop at the Pat Tillman bridge above Hoover Dam on the way.",
    activities: [
      { time_label: "7:00 AM",  title: "Depart for Skywalk",
        location_name: "Hotel", address: "3906 Maryland Ave, Las Vegas, NV 89121",
        photo_url: "https://images.unsplash.com/photo-1517991104123-1d56a6e81ed9?w=800&q=80",
        notes: "Beat the heat. Cooler with breakfast in the car so the kids eat on the road." },
      { time_label: "7:45 AM",  title: "Pat Tillman Bridge photo stop (Hoover Dam)",
        location_name: "Mike O'Callaghan–Pat Tillman Memorial Bridge", address: "Boulder City, NV 89005",
        photo_url: "https://images.unsplash.com/photo-1474044159687-1ee9f3a51722?w=800&q=80",
        notes: "Free pedestrian walkway with the iconic Hoover Dam view. 10-min stop, no need to do the full dam tour." },
      { time_label: "10:00 AM", title: "Grand Canyon Skywalk (Sat 10 AM)",
        location_name: "Grand Canyon West — Eagle Point", address: "Diamond Bar Rd, Peach Springs, AZ 86434",
        photo_url: "https://images.unsplash.com/photo-1474044159687-1ee9f3a51722?w=800&q=80",
        notes: "All Access pass: Skywalk + zipline + Sky View lunch + shuttle to Eagle/Guano/Hualapai Ranch. **Phones not allowed on the Skywalk** — buy the digital photo pack ($69) or have one person stay off-bridge to shoot." },
      { time_label: "1:00 PM",  title: "Lunch at Sky View Restaurant",
        location_name: "Sky View Restaurant — Eagle Point", address: "Diamond Bar Rd, Peach Springs, AZ 86434",
        photo_url: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80",
        notes: "Included with the All Access pass. Buffet-style with canyon view." },
      { time_label: "5:30 PM",  title: "Back at the hotel",
        location_name: "Hotel", address: "3906 Maryland Ave, Las Vegas, NV 89121",
        photo_url: "https://images.unsplash.com/photo-1496417263034-38ec4f0b665a?w=800&q=80",
        notes: "Pool, easy dinner, early bed. 10+ hours of car/walking total — grandparents will be fried." }
    ]
  },
  {
    label:   "Sunday May 10 — Drive home",
    date:    Date.new(2026, 5, 10),
    title:   "Drive home",
    theme:   "return",
    accent:  "pink",
    summary: "Pack up by 9, lunch in St. George around 11, home by 6 PM.",
    activities: [
      { time_label: "9:00 AM",  title: "Pack up + check out",
        location_name: "Hotel",        address: "3906 Maryland Ave, Las Vegas, NV 89121",
        photo_url: "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800&q=80",
        notes: "Drop keys at the front desk. Grab grocery leftovers for the drive." },
      { time_label: "11:00 AM", title: "Lunch in St. George — Black Bear Diner",
        location_name: "Black Bear Diner",   address: "1245 S Main St, St. George, UT 84770",
        photo_url: "https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800&q=80",
        notes: "Veg alternative on the same block: India Palace at 393 E St. George Blvd." },
      { time_label: "6:00 PM",  title: "Home",
        location_name: "Home", address: "North Salt Lake, UT",
        photo_url: "https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&q=80",
        notes: "Unload, laundry, sleep. Trip done." }
    ]
  }
]

vegas_days.each_with_index do |day_data, day_idx|
  day = vegas_trip.trip_days.find_or_create_by!(label: day_data[:label]) do |d|
    d.date     = day_data[:date]
    d.title    = day_data[:title]
    d.theme    = day_data[:theme]
    d.accent   = day_data[:accent]
    d.summary  = day_data[:summary]
    d.position = day_idx
  end

  day_data[:activities].each_with_index do |a, i|
    day.activities.find_or_create_by!(title: a[:title]) do |act|
      act.time_label    = a[:time_label]
      act.location_name = a[:location_name]
      act.address       = a[:address]
      act.photo_url     = a[:photo_url]
      act.notes         = a[:notes]
      act.group_label   = a[:group_label]
      act.position      = i
    end
  end
end

puts "Seeded: #{demo.email} / password123"
puts "Trips: #{Trip.count}, Trails: #{Trail.count}, Checklist items: #{ChecklistItem.count}, Days: #{TripDay.count}, Activities: #{Activity.count}"
