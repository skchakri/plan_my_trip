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
  # PWA links are relative paths, which the http(s)-only XSS validation rejects
  # on create — they're set just below via update_columns (skips validation).
  t.excitement_pitch = "Four days, six people, three icons of the American West: a 16K-pixel dome that wraps you in The Wizard of Oz, a glass bridge cantilevered over the Grand Canyon, and the most over-the-top Strip in America. Heat, lights, fountains, and a 900-mile minivan adventure tying it all together."
end

# Backfill PWA links + excitement pitch if the trip pre-existed
vegas_trip.update_columns(
  pwa_plan_url: "/vegas-trip-4days.html",
  pwa_packing_url: "/vegas-packing.html"
) if vegas_trip.pwa_plan_url.blank?

vegas_trip.update_column(:excitement_pitch,
  "Four days, six people, three icons of the American West: a 16K-pixel dome that wraps you in The Wizard of Oz, a glass bridge cantilevered over the Grand Canyon, and the most over-the-top Strip in America. Heat, lights, fountains, and a 900-mile minivan adventure tying it all together."
) if vegas_trip.excitement_pitch.blank?

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
        latitude: 40.8487, longitude: -111.9069,
        photo_url: "https://images.unsplash.com/photo-1507608616759-54f48f0af0ee?w=800&q=80",
        notes: "Pack the cooler, top off Costco gas at 1818 N Redwood Rd before pickup." },
      { time_label: "3:30 PM",  title: "Lunch + gas — Arshel's Café",
        location_name: "Arshel's Café, Beaver UT", address: "711 N Main St, Beaver, UT 84713",
        latitude: 38.2769, longitude: -112.6388,
        photo_url: "https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800&q=80",
        notes: "Halfway point. Clean restrooms + diner food. 30 min stop." },
      { time_label: "7:30 PM",  title: "Arrive in Vegas — check in + Smith's grocery run",
        location_name: "Smith's Food and Drug",      address: "2540 S Maryland Pkwy, Las Vegas, NV 89109",
        latitude: 36.1311, longitude: -115.1378,
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
        latitude: 36.1444, longitude: -115.2825,
        photo_url: "https://images.unsplash.com/photo-1577896851231-70ef18881754?w=800&q=80",
        notes: "Action Pass, ~2 hr. Mini-Ninja section for younger kids." },
      { time_label: "10:30 AM", title: "Bellagio Conservatory (Group B)", group_label: "Group B — You + parents",
        location_name: "Bellagio Conservatory & Botanical Gardens", address: "3600 S Las Vegas Blvd, Las Vegas, NV 89109",
        latitude: 36.1126, longitude: -115.1767,
        photo_url: "https://images.unsplash.com/photo-1581351721010-8cf859cb14a4?w=800&q=80",
        notes: "Free, indoor, fully accessible. Plan ~1 hour. Slow gentle walk for the parents to ease into the day." },
      { time_label: "11:45 AM", title: "Forum Shops at Caesars (Group B)", group_label: "Group B — You + parents",
        location_name: "Forum Shops at Caesars Palace", address: "3500 S Las Vegas Blvd, Las Vegas, NV 89109",
        latitude: 36.1162, longitude: -115.1747,
        photo_url: "https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=800&q=80",
        notes: "Roman architecture, AC, free fountain shows. If parents' knees ache — Uber the 5-min hop instead of walking." },
      { time_label: "12:30 PM", title: "Lunch at Eataly — Park MGM (Group B)", group_label: "Group B — You + parents",
        location_name: "Eataly Las Vegas", address: "3770 S Las Vegas Blvd, Las Vegas, NV 89109",
        latitude: 36.1027, longitude: -115.1761,
        photo_url: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80",
        notes: "Italian food market under one roof — many veg options. Saravanaa Bhavan on Maryland Pkwy is the South Indian alternative." },
      { time_label: "1:30 PM",  title: "Regroup at Sphere",
        location_name: "Sphere", address: "255 Sands Ave, Las Vegas, NV 89169",
        latitude: 36.1217, longitude: -115.1685,
        photo_url: "https://images.unsplash.com/photo-1542204625-ca960325cc62?w=800&q=80",
        notes: "Meet at the LED orb on the south side. 15-20 min security takes a while on weekend matinees." },
      { time_label: "2:00 PM",  title: "Sphere — Wizard of Oz (Fri 2 PM)",
        location_name: "Sphere", address: "255 Sands Ave, Las Vegas, NV 89169",
        latitude: 36.1217, longitude: -115.1685,
        photo_url: "https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=800&q=80",
        notes: "90 min show. Venue is 68°F — bring cardigans. Phones allowed but no filming during immersive segments." },
      { time_label: "Evening",  title: "Pool + Bellagio fountains",
        location_name: "Bellagio Fountains", address: "3600 S Las Vegas Blvd, Las Vegas, NV 89109",
        latitude: 36.1126, longitude: -115.1759,
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
        latitude: 36.1311, longitude: -115.1378,
        photo_url: "https://images.unsplash.com/photo-1517991104123-1d56a6e81ed9?w=800&q=80",
        notes: "Beat the heat. Cooler with breakfast in the car so the kids eat on the road." },
      { time_label: "7:45 AM",  title: "Pat Tillman Bridge photo stop (Hoover Dam)",
        location_name: "Mike O'Callaghan–Pat Tillman Memorial Bridge", address: "Boulder City, NV 89005",
        latitude: 36.0166, longitude: -114.7372,
        photo_url: "https://images.unsplash.com/photo-1474044159687-1ee9f3a51722?w=800&q=80",
        notes: "Free pedestrian walkway with the iconic Hoover Dam view. 10-min stop, no need to do the full dam tour." },
      { time_label: "10:00 AM", title: "Grand Canyon Skywalk (Sat 10 AM)",
        location_name: "Grand Canyon West — Eagle Point", address: "Diamond Bar Rd, Peach Springs, AZ 86434",
        latitude: 35.9892, longitude: -113.8101,
        photo_url: "https://images.unsplash.com/photo-1474044159687-1ee9f3a51722?w=800&q=80",
        notes: "All Access pass: Skywalk + zipline + Sky View lunch + shuttle to Eagle/Guano/Hualapai Ranch. **Phones not allowed on the Skywalk** — buy the digital photo pack ($69) or have one person stay off-bridge to shoot." },
      { time_label: "1:00 PM",  title: "Lunch at Sky View Restaurant",
        location_name: "Sky View Restaurant — Eagle Point", address: "Diamond Bar Rd, Peach Springs, AZ 86434",
        latitude: 35.9892, longitude: -113.8101,
        photo_url: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80",
        notes: "Included with the All Access pass. Buffet-style with canyon view." },
      { time_label: "5:30 PM",  title: "Back at the hotel",
        location_name: "Hotel", address: "3906 Maryland Ave, Las Vegas, NV 89121",
        latitude: 36.1311, longitude: -115.1378,
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
        latitude: 36.1311, longitude: -115.1378,
        photo_url: "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800&q=80",
        notes: "Drop keys at the front desk. Grab grocery leftovers for the drive." },
      { time_label: "11:00 AM", title: "Lunch in St. George — Black Bear Diner",
        location_name: "Black Bear Diner",   address: "1245 S Main St, St. George, UT 84770",
        latitude: 37.0894, longitude: -113.5803,
        photo_url: "https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800&q=80",
        notes: "Veg alternative on the same block: India Palace at 393 E St. George Blvd." },
      { time_label: "6:00 PM",  title: "Home",
        location_name: "Home", address: "North Salt Lake, UT",
        latitude: 40.8487, longitude: -111.9069,
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
    activity = day.activities.find_or_create_by!(title: a[:title]) do |act|
      act.time_label    = a[:time_label]
      act.location_name = a[:location_name]
      act.address       = a[:address]
      act.photo_url     = a[:photo_url]
      act.notes         = a[:notes]
      act.group_label   = a[:group_label]
      act.position      = i
    end
    # Backfill lat/lng on already-seeded rows so existing dev DBs pick up the
    # offline-map thumbnails without a re-seed.
    if a[:latitude] && a[:longitude] && (activity.latitude.nil? || activity.longitude.nil?)
      activity.update!(latitude: a[:latitude], longitude: a[:longitude])
    end
  end
end

people = [
  { name: "Kalyan",  age: 42,  interests: %w[travel cars history geography] },
  { name: "Sneha",   age: 41,  interests: %w[food art photography movies] },
  { name: "Aarav",   age: 11,  interests: %w[math space superhero video_games] },
  { name: "Diya",    age: 8,   interests: %w[disney animals dinosaurs movies_kids] },
  { name: "Mom",     age: 68,  interests: %w[cooking gardening movies books] },
  { name: "Dad",     age: 70,  interests: %w[history sports cars geography] }
]
people.each_with_index do |attrs, i|
  vegas_trip.people.find_or_create_by!(name: attrs[:name]) do |p|
    p.age       = attrs[:age]
    p.interests = attrs[:interests]
    p.position  = i
  end
end

famous_for = {
  "Sphere — Wizard of Oz (Fri 2 PM)"         => "The world's largest spherical structure — 366 ft tall, with a 16K-resolution interior LED screen that wraps the entire venue. The Wizard of Oz reimagining premiered in 2025 with new generative AI scenes.",
  "Bellagio Conservatory (Group B)"           => "A 14,000 sq ft botanical garden inside the Bellagio with seasonal displays that change five times a year. Free to walk through, and one of the few quiet escapes on the Strip.",
  "Forum Shops at Caesars (Group B)"          => "A high-end mall styled as ancient Rome, with a painted sky that shifts from dawn to dusk every hour. Home to the talking-statue Fall of Atlantis show.",
  "Spy Ninjas HQ (Group A)"                   => "A massive entertainment park inspired by the Spy Ninjas YouTube series — obstacle courses, ziplines, axe throwing, and an arcade. One of the highest-rated kid attractions in Vegas.",
  "Pat Tillman Bridge photo stop (Hoover Dam)" => "The Mike O'Callaghan–Pat Tillman Memorial Bridge, the second-highest bridge in the US — 890 ft above the Colorado River with a postcard view of Hoover Dam below.",
  "Grand Canyon Skywalk (Sat 10 AM)"          => "A horseshoe-shaped glass bridge that extends 70 feet beyond the canyon rim, 4,000 ft above the Colorado River. Engineered to hold 70 fully loaded 747s — and built on Hualapai tribal land.",
  "Sky View Restaurant"                       => "Buffet-style dining on the canyon edge at Eagle Point — included with the Hualapai Legacy Gold pass.",
  "Bellagio Fountains (evening)"              => "1,200 fountains synchronized to music, dancing 460 feet into the air. Free shows every 15 minutes after 8 PM.",
  "Pool + Bellagio fountains"                 => "1,200 fountains synchronized to music, dancing 460 feet into the air. Free shows every 15 minutes after 8 PM.",
  "Eataly — Park MGM (Group B)"               => "Italian celebrity-chef food hall with 7+ counter restaurants under one roof. The Vegas outpost is the largest Eataly in the US.",
  "Lunch at Eataly — Park MGM (Group B)"      => "Italian celebrity-chef food hall with 7+ counter restaurants under one roof. The Vegas outpost is the largest Eataly in the US."
}
Activity.find_each do |a|
  next unless famous_for[a.title].present?
  a.update!(famous_for: famous_for[a.title]) if a.famous_for.blank?
end

# Rich tour-guide narration. Written to be spoken aloud by the "guide"
# voice in the podcast-mode reading flow — short, punchy sentences,
# proper nouns and dates that listeners can latch onto, and a hook at
# the front so it doesn't open with a number.
guide_scripts = {
  "Sphere — Wizard of Oz (Fri 2 PM)" => <<~SCRIPT.strip,
    You're about to step inside the largest spherical building on Earth. The Sphere stands 366 feet tall and 516 feet wide — that's bigger than the Statue of Liberty, wrapped in a curve. It opened in September 2023, just east of the Strip, and cost about 2.3 billion dollars to build. Inside, the screen wraps almost all the way around you. It's 160,000 square feet of LED at 16K resolution — the highest-resolution display ever built. The Wizard of Oz reimagining you're about to see uses generative AI to extend every original 1939 frame into the full curved view. So when Dorothy looks out at Kansas, you see Kansas. When she steps into Oz, you're standing in Oz. The sound system has 167,000 speakers, and the seats vibrate with the score. Pro tip: the higher rows feel the wraparound effect more strongly than the floor.
  SCRIPT
  "Bellagio Conservatory (Group B)" => <<~SCRIPT.strip,
    The Bellagio Conservatory is one of the best-kept free secrets in Las Vegas. It's a 14,000 square foot botanical garden tucked just past the lobby, and it's been open since the hotel itself debuted in 1998. The displays change five times a year — for spring, summer, fall, the holidays, and Lunar New Year. A team of more than 120 horticulturalists builds each one from scratch, working through the night so the changeover is invisible to guests. Many of the centerpiece sculptures are mechanized — giant flowers that bloom on a timer, butterflies that move, water features built around real living plants. Look up: that 50-foot ceiling is hand-blown glass by Dale Chihuly, the same artist who did the lobby's Fiori di Como. It's free, it's quiet, and it's a beautiful way to start the day before the Strip wakes up.
  SCRIPT
  "Forum Shops at Caesars (Group B)" => <<~SCRIPT.strip,
    The Forum Shops opened in 1992 and are still one of the highest-grossing malls per square foot in the world. The whole place is themed as ancient Rome — marble columns, fountains, and statues — and the ceiling is painted to look like the Mediterranean sky. Watch it for a few minutes and you'll see it cycle from dawn to dusk on a one-hour loop, the whole thing painted by hand when the mall was built. Don't miss the Fall of Atlantis fountain near the back — animatronic statues of Atlas and his children come to life every hour, with fire and water effects. Kids love it, parents either love it or laugh at it. There's also a spiral escalator here, one of only a handful in the world. And if your feet are tired, the Cheesecake Factory just past the entrance has the original soaring two-story Roman dining room.
  SCRIPT
  "Spy Ninjas HQ (Group A)" => <<~SCRIPT.strip,
    Spy Ninjas HQ opened in 2022, built around the Spy Ninjas YouTube series — Chad Wild Clay and Vy Qwaint's channel that has over 30 million subscribers. The facility is around 30,000 square feet and was designed by the cast themselves. The kids will go through five training rooms — laser maze, ninja obstacle course, axe throwing, escape rooms, and a final mission. Each one earns them a colored belt, and they get a real Spy Ninjas dog tag at the end. The arcade is included with admission, so let them burn off the rest of the energy there. The whole place is built for ages five through fifteen, and they make a point of pacing it so siblings of different ages can stay together. Tip: book the early time slot — the lighting and music are full intensity, and it gets loud later in the day.
  SCRIPT
  "Pat Tillman Bridge photo stop (Hoover Dam)" => <<~SCRIPT.strip,
    What you're looking at is two engineering marvels stacked on top of each other. Down in the canyon is Hoover Dam — built between 1931 and 1936, during the Great Depression, when the country desperately needed jobs. It's 726 feet tall, made from 4.4 million cubic yards of concrete, and at the time it was finished it was the tallest dam in the world. It tamed the Colorado River, created Lake Mead, and brought reliable electricity and water to seven states. Ninety-six workers died building it. Above it is the Mike O'Callaghan–Pat Tillman Memorial Bridge, finished in 2010 to take traffic off the dam itself. It's the second-highest bridge in the United States — 890 feet above the river. It's named for two Arizonans: Mike O'Callaghan, a former Nevada governor, and Pat Tillman, the NFL player who left a multi-million-dollar contract after 9/11 to enlist as an Army Ranger, and was killed in Afghanistan in 2004. The walkway over the bridge gives you the only safe view of the dam from the front. Step out, take a minute, and look at what people built here.
  SCRIPT
  "Grand Canyon Skywalk (Sat 10 AM)" => <<~SCRIPT.strip,
    The Skywalk opened on March 20th, 2007, on the rim of the Grand Canyon at Eagle Point. It's a horseshoe-shaped glass bridge that extends 70 feet out over the canyon — and the floor beneath your feet is four inches of clear, layered glass. Below that is 4,000 feet of nothing. It was engineered to hold 70 fully loaded Boeing 747s, and to flex without breaking through an 8-magnitude earthquake from 50 miles away. This is Hualapai land — the Hualapai Tribe, whose name means "people of the tall pines," own and operate the entire site. The Skywalk was their idea, championed by tribal businessman David Jin, as a way to create lasting jobs on the reservation. You'll be asked to leave phones and cameras in a locker before you step onto the bridge — it's not about secrecy, it's about not dropping a phone four thousand feet onto a national treasure. Hualapai photographers will take pictures for you. Take your shoes off if it's allowed — the booties they hand you are quieter, and the whole thing feels less surreal in socks.
  SCRIPT
  "Sky View Restaurant" => <<~SCRIPT.strip,
    Sky View sits right on the canyon rim at Eagle Point, with floor-to-ceiling windows that look out at the same view you just walked over. It's buffet-style and it's included if you bought the Hualapai Legacy Gold pass. The food is comfort-style with a Native American twist — fry bread is the thing to try if you've never had it. It's a quick lunch, but the seats by the windows are first-come-first-served, so move with intent.
  SCRIPT
  "Lunch at Eataly — Park MGM (Group B)" => <<~SCRIPT.strip,
    Eataly was founded in Turin, Italy in 2007 by Oscar Farinetti, with the idea that high-quality Italian food should be both eaten and bought in the same place. The Vegas location, inside Park MGM, is the largest Eataly in the United States — about 40,000 square feet. Inside there are seven sit-down counters: pasta, pizza, seafood, butcher, salumi, fresh mozzarella made on the spot, and a gelato bar. The trick is to split up — get pasta from one counter, pizza from another, and meet at a table. The mozzarella di bufala is flown in from Naples three times a week. The pizza is wood-fired Neapolitan style. And if you're a coffee person, the espresso bar by the front uses Lavazza beans pulled the way they do it in Milan — quick, hot, and small.
  SCRIPT
  "Bellagio Fountains (evening)" => <<~SCRIPT.strip,
    The Bellagio Fountains have been running since the hotel opened in 1998. There are over 1,200 individual fountains in an eight-and-a-half-acre lake, and they shoot water up to 460 feet in the air — taller than the original Bellagio tower itself. They're choreographed to a rotating playlist of about 35 songs, from Sinatra to opera to Whitney Houston to Tiësto. After 8 PM the shows run every 15 minutes; before 8, every 30. Best viewing spots: the curved railing right in front of the hotel, the bridge to Bally's, or — if you want a quieter view — the upper terrace at the Eiffel Tower restaurant across the street. The fountains are free. They've been one of the most-watched outdoor performances on Earth for over 25 years.
  SCRIPT
  "Pool + Bellagio fountains" => <<~SCRIPT.strip,
    The Bellagio Fountains have been running since the hotel opened in 1998. Over 1,200 fountains in an eight-and-a-half-acre lake, shooting water up to 460 feet in the air — taller than the original Bellagio tower itself. They're choreographed to a rotating playlist, about 35 songs, from Sinatra to opera to Whitney Houston. After 8 PM the shows run every 15 minutes. Watch from the railing in front of the hotel, or the bridge over to Bally's. They're free, and they've been one of the most-watched outdoor performances on Earth for more than 25 years.
  SCRIPT
  "Regroup at Sphere" => <<~SCRIPT.strip,
    Quick logistics break. The Sphere is at the Venetian, just east of the Strip across Sands Avenue. The walk from the Venetian's parking is about ten minutes through an indoor connector, so plan extra time. Bathrooms are on every level of the venue, but the lines after the show are long — go before. And the venue has timed entry, so once everyone's regrouped, head straight to the doors.
  SCRIPT
  "Lunch + gas — Arshel's Café" => <<~SCRIPT.strip,
    Arshel's Café has been on the corner of Beaver, Utah since 1973. It's a roadside diner, family-run, and one of the last classic stops on the I-15 corridor between Salt Lake and Vegas. The chicken-fried steak is what they're known for, and the homemade scones are the size of your face. Beaver itself is a small town founded in 1856 by Mormon pioneers — Butch Cassidy was born here in 1866. Quick stop: gas, food, stretch, and back on the road.
  SCRIPT
  "Lunch in St. George — Black Bear Diner" => <<~SCRIPT.strip,
    Black Bear Diner started as a single roadside spot in Mount Shasta, California in 1995, and now there are over 150 of them across the West. The St. George location is a popular last-stop on the way north out of the Mojave. The portions are huge — a half-order is usually plenty. The cinnamon roll French toast is a road-trip classic. Quick stop: eat, fuel up if needed, and we're back on I-15 toward home.
  SCRIPT
  "Arrive in Vegas — check in + Smith's grocery run" => <<~SCRIPT.strip
    Welcome to Las Vegas. The valley you're driving into has been inhabited for at least ten thousand years — the name "Las Vegas" is Spanish for "the meadows," and it was given to the area in 1829 by a Mexican scout named Rafael Rivera who found freshwater springs here. The city itself was founded on May 15th, 1905, when railroad land was auctioned off near today's Fremont Street. After check-in, the closest Smith's grocery is about a five-minute drive. Stock up on water, breakfast stuff, snacks for the kids, and anything you'd rather not pay strip prices for.
  SCRIPT
}
Activity.find_each do |a|
  script = guide_scripts[a.title]
  next if script.blank?
  a.update!(guide_script: script) if a.guide_script.blank?
end

puts "Seeded: #{demo.email} / password123"
puts "Trips: #{Trip.count}, Trails: #{Trail.count}, Checklist items: #{ChecklistItem.count}, Days: #{TripDay.count}, Activities: #{Activity.count}, Travelers: #{Person.count}"

puts "\nSeeding Travel Trivia reference data…"
load Rails.root.join("db/seeds/geography.rb").to_s
load Rails.root.join("db/seeds/brands.rb").to_s

puts "Building the quiz question bank…"
puts "Quiz questions: #{QuizQuestion.rebuild!}"

# Drive Co-Pilot trivia pool — without this a fresh install leaves TriviaQuestion
# empty and TriviaPool falls back to its hardcoded 2-question GENERIC list.
# seed loads the standalone questions; seed_chains loads the multi-step
# word-problem chains that TriviaPool.pick_for biases toward — without them
# the co-pilot still falls back to the GENERIC pool. Both tasks are idempotent.
puts "\nSeeding Drive Co-Pilot trivia pool…"
require "rake"
Rails.application.load_tasks unless Rake::Task.task_defined?("trivia:seed")
Rake::Task["trivia:seed"].invoke
Rake::Task["trivia:seed_chains"].invoke
puts "Trivia questions: #{TriviaQuestion.where(trip_id: nil).count} " \
     "(#{TriviaQuestion.where(trip_id: nil).where.not(chain_intro: nil).count} chains)"

puts "\nSeeding AI prompts…"
load Rails.root.join("db/seed_ai_prompts.rb").to_s

# Lift any settings still living in ENV (.env) into the AppSetting store so the
# admin UI becomes the source of truth. Idempotent: only fills keys with an ENV
# value and no DB row yet.
imported = AppSetting.import_from_env!
puts "AppSettings imported from ENV: #{imported.any? ? imported.join(', ') : 'none'}"

if (admin = User.find_by(email: "skchakri@gmail.com"))
  admin.update_column(:admin, true) unless admin.admin?
  puts "Admin user: #{admin.email}"
else
  puts "(skchakri@gmail.com not registered yet — sign up then re-run db:seed to be promoted to admin.)"
end
