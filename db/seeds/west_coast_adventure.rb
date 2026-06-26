# West Coast Adventure — Tom's 7-day RV / travel-trailer loop out of Woods Cross, UT.
# Built from a Word itinerary (Idaho → Oregon → N. California → Nevada → home),
# upgraded with RV logistics and seasonal flags. Idempotent: re-running upserts
# rather than duplicating. Owner is a dedicated tom@example.com demo user.
#
# Run standalone:  bin/rails runner 'load Rails.root.join("db/seeds/west_coast_adventure.rb").to_s'
# Or wire into db/seeds.rb with: require_relative "seeds/west_coast_adventure"

tom = User.find_or_create_by!(email: "tom@example.com") do |u|
  u.name = "Tom"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.home_city = "Woods Cross, UT"
  u.home_lat = 40.871600
  u.home_lng = -111.892200
end

start_date = Date.new(2026, 7, 11)
end_date   = start_date + 6 # Fri, Jul 17, 2026

excitement_pitch =
  "Seven days, one big loop out of Woods Cross: granite spires at City of Rocks, the " \
  "Niagara of the West, Smith Rock's Misery Ridge, the impossibly blue Crater Lake, " \
  "lava-tube caves under Lava Beds, geothermal Lassen, and a string of hidden alpine " \
  "lakes most travelers never find — the Ruby Mountains, Angel Lake, and Tahoe's quiet " \
  "east shore. Towing the trailer the whole way, light-to-moderate hikes each day, and a " \
  "different landscape every morning."

trip = Trip.find_or_create_by!(owner: tom, title: "West Coast Adventure") do |t|
  t.origin          = "Woods Cross, Utah"
  t.destination     = "Idaho · Oregon · Northern California · Nevada loop"
  t.start_date      = start_date
  t.end_date        = end_date
  t.traveler_count  = 2
  t.transport_mode  = "own_car" # RV/trailer — suppresses rental suggestions, adds vehicle-prep items
  t.pace            = "balanced"
  t.budget          = "moderate"
  t.anchor_label    = "Crater Lake National Park"
  t.anchor_lat      = 42.944600
  t.anchor_lng      = -122.109000
  t.excitement_pitch = excitement_pitch
  t.preferences     = <<~PREF.strip
    Towing a travel trailer the whole loop — need trailer-friendly campgrounds, dump
    stations, propane, and pull-through/oversize parking; plan to UNHITCH at each base
    for the steeper trailhead roads. Overnighting at KOAs plus boondocking (Walmart/BLM)
    to keep costs down — book peak-July nights ahead and keep a backup per night.
    Light-to-moderate day hikes only (energy preservation across 7 straight days). Loves
    waterfalls, volcanic/geothermal landscapes, alpine lakes, and hidden gems over crowded
    spots. Photography stops welcome.
  PREF
end

# Keep key fields fresh if the trip pre-existed (idempotent re-seed).
trip.update!(
  excitement_pitch: excitement_pitch,
  build_status: "ready"
)

# ── Days + activities ────────────────────────────────────────────────────────
# famous_for = the "why stop here"; notes = the upgrade/logistics tips.
days = [
  {
    label: "Day 1", accent: "blue", theme: "scenic", date: start_date,
    title: "Day 1 — Utah to Idaho",
    summary: "Big opening drive (~7.5h) from Woods Cross into southern Idaho — granite towers at " \
             "City of Rocks, the Niagara of the West, and a walk behind Perrine Coulee — finishing in " \
             "Boise. Start by 7:00 AM to keep margin on the longest driving day.",
    activities: [
      { time_label: "7:00 AM", title: "Depart Woods Cross, UT", group_label: "drive",
        location_name: "Woods Cross, UT", address: "Woods Cross, UT",
        latitude: 40.871600, longitude: -111.892200,
        famous_for: "I-15 N → Burley → ID-77/ID-36 toward Almo.",
        notes: "Leave at 7 (an hour earlier than the original) — it's the longest driving day. Top off fuel before Snowville." },
      { time_label: "11:00 AM", title: "City of Rocks National Reserve", group_label: "park",
        location_name: "City of Rocks National Reserve", address: "Almo, ID 83312",
        latitude: 42.081400, longitude: -113.713600,
        famous_for: "Tom's requested destination — enormous granite domes rising out of the valley; a world-class climbing area.",
        notes: "Paved to the reserve; some interior roads are gravel. Scenic drive + short walks among the formations. ~40 min." },
      { time_label: "1:45 PM", title: "Lunch — Twin Falls, ID", group_label: "lunch",
        location_name: "Twin Falls, ID", address: "Twin Falls, ID",
        latitude: 42.555800, longitude: -114.470100,
        famous_for: "Fuel + lunch on the Snake River plateau.",
        notes: "Refuel here — long stretch ahead to Boise." },
      { time_label: "2:45 PM", title: "Shoshone Falls", group_label: "viewpoint",
        location_name: "Shoshone Falls Park", address: "Shoshone Falls, Twin Falls, ID",
        latitude: 42.592800, longitude: -114.400600,
        famous_for: "The \"Niagara of the West\" — 212 ft, taller than Niagara.",
        notes: "$5/vehicle day-use. Heads up: flow is often LOW by mid-July (upstream irrigation) — it's a torrent in spring, sometimes a trickle in summer. Steep park road; fine for a truck." },
      { time_label: "3:30 PM", title: "Perrine Coulee Falls", group_label: "viewpoint",
        location_name: "Perrine Coulee Falls", address: "Canyon Springs Rd, Twin Falls, ID",
        latitude: 42.596900, longitude: -114.486100,
        famous_for: "Hidden 200-ft falls in the Snake River Canyon you can walk behind.",
        notes: "Small pullout on Canyon Springs Rd. Short, slightly slick path behind the falls. Same low-flow caveat as Shoshone." },
      { time_label: "6:15 PM", title: "Overnight — Boise, ID", group_label: "lodging",
        location_name: "Boise / Meridian, ID", address: "Meridian, ID",
        latitude: 43.615000, longitude: -116.202300,
        famous_for: "Boise Meridian KOA Journey — full hookups, pull-through sites.",
        notes: "BOOK AHEAD for mid-July. Backups: Mountain View RV Park, or boondock (call the store first — many Walmarts no longer allow overnight)." }
    ]
  },
  {
    label: "Day 2", accent: "gold", theme: "hiking", date: start_date + 1,
    title: "Day 2 — Oregon: Smith Rock",
    summary: "First real hiking day — Smith Rock's Misery Ridge high above the Crooked River, then the " \
             "97-ft Tumalo Falls, overnight in Bend (~5.5h driving).",
    activities: [
      { time_label: "7:30 AM", title: "Depart Boise, ID", group_label: "drive",
        location_name: "Boise, ID", address: "Boise, ID",
        latitude: 43.615000, longitude: -116.202300,
        famous_for: "I-84 W through eastern Oregon → US-20 W toward Bend.",
        notes: "High-desert morning drive. Fuel in Ontario or Burns Junction." },
      { time_label: "12:45 PM", title: "Smith Rock State Park — Misery Ridge", group_label: "hike",
        location_name: "Smith Rock State Park", address: "Terrebonne, OR 97760",
        latitude: 44.364900, longitude: -121.138700,
        famous_for: "Birthplace of American sport climbing — volcanic canyon walls over the Crooked River. The signature hike of the trip.",
        notes: "Misery Ridge + River Trail loop ≈ 3.6 mi, steep & exposed. It BAKES on a July afternoon with no shade — carry 3L water each, sun protection. Trailer parking is tight: park in the main day-use lot or unhitch in Terrebonne." },
      { time_label: "4:45 PM", title: "Tumalo Falls", group_label: "viewpoint",
        location_name: "Tumalo Falls", address: "Tumalo Falls, Bend, OR",
        latitude: 44.031900, longitude: -121.567200,
        famous_for: "Beautiful 97-ft waterfall — an easy reward after Smith Rock.",
        notes: "Last ~2.5 mi is gravel FR-4601 (fine for a truck, NOT for the trailer) — drop the trailer in Bend first. Short walk to the overlook." },
      { time_label: "6:00 PM", title: "Overnight — Bend, OR", group_label: "lodging",
        location_name: "Bend, OR", address: "Bend, OR",
        latitude: 44.058200, longitude: -121.315300,
        famous_for: "Bend/Sisters Garden RV Resort — hookups, easy access.",
        notes: "Peak-season town — book ahead. Bend Walmart has historically allowed overnight but confirm; great breweries if you want a night out." }
    ]
  },
  {
    label: "Day 3", accent: "teal", theme: "volcanic", date: start_date + 2,
    title: "Day 3 — Crater Lake",
    summary: "Volcano day — Paulina Peak over Newberry's giant caldera, then the impossibly blue Crater " \
             "Lake and Watchman Peak, down to Klamath Falls (~5h).",
    activities: [
      { time_label: "8:00 AM", title: "Depart Bend, OR", group_label: "drive",
        location_name: "Bend, OR", address: "Bend, OR",
        latitude: 44.058200, longitude: -121.315300,
        famous_for: "US-97 S into central Oregon's volcanic country.",
        notes: "Short hop to Newberry — get there early before the summit road gets busy." },
      { time_label: "8:45 AM", title: "Newberry NVM — Paulina Peak", group_label: "hike",
        location_name: "Paulina Peak, Newberry National Volcanic Monument", address: "La Pine, OR 97739",
        latitude: 43.688900, longitude: -121.256600,
        famous_for: "Panorama over one of the largest calderas in the Pacific Northwest — lava flows, twin crater lakes.",
        notes: "IMPORTANT: the last ~3 mi to the summit is a steep, narrow gravel road where trailers aren't advised. Drop the trailer at the Paulina Lake day-use area and drive up, or hike the trail. NW Forest Pass / day fee." },
      { time_label: "12:30 PM", title: "Crater Lake NP — Watchman Peak + Rim Village", group_label: "hike",
        location_name: "Crater Lake National Park (West Rim)", address: "Crater Lake, OR 97604",
        latitude: 42.944600, longitude: -122.168900,
        famous_for: "Deepest lake in the U.S. (1,943 ft), in a caldera left by Mt. Mazama ~7,700 years ago. Watchman Peak (1.7 mi) has the best full-lake panorama.",
        notes: "Use the America the Beautiful pass here. CHECK NPS before you go — Rim Drive is under multi-year construction and segments close. Watchman's West-Rim lot is paved but fills midday; arrive early if you can. Superb stargazing if you linger." },
      { time_label: "6:45 PM", title: "Overnight — Klamath Falls, OR", group_label: "lodging",
        location_name: "Klamath Falls, OR", address: "Klamath Falls, OR",
        latitude: 42.224900, longitude: -121.781700,
        famous_for: "Klamath Falls KOA Journey — full hookups.",
        notes: "Book ahead. Quiet town; good launchpad for the California leg." }
    ]
  },
  {
    label: "Day 4", accent: "emerald", theme: "variety", date: start_date + 3,
    title: "Day 4 — N. California: caves, falls & Shasta",
    summary: "Best-variety day — lava-tube caves at Lava Beds, the spring-fed Burney Falls, and an alpine " \
             "hike to Heart Lake under Mt. Shasta (~5h).",
    activities: [
      { time_label: "8:00 AM", title: "Depart Klamath Falls, OR", group_label: "drive",
        location_name: "Klamath Falls, OR", address: "Klamath Falls, OR",
        latitude: 42.224900, longitude: -121.781700,
        famous_for: "US-97 S → CA-161/CA-139 into California's volcanic country.",
        notes: "Pass Lower Klamath / Tule Lake refuges — birdlife if you want a quick pull-off." },
      { time_label: "9:00 AM", title: "Lava Beds National Monument", group_label: "park",
        location_name: "Lava Beds National Monument", address: "Tulelake, CA 96134",
        latitude: 41.714100, longitude: -121.510300,
        famous_for: "700+ lava-tube caves from ancient eruptions — an underground world unlike anything else on the trip.",
        notes: "Stop at the visitor center first: FREE cave permit + a quick white-nose (bat) gear screening — no clothing/gear that's touched another cave. Bring headlamps + spare batteries per person. Mushpot is lit & easiest; Sentinel & Skull are great. Pass covers entry." },
      { time_label: "1:00 PM", title: "McArthur-Burney Falls State Park", group_label: "hike",
        location_name: "McArthur-Burney Falls Memorial State Park", address: "Burney, CA 96013",
        latitude: 41.011900, longitude: -121.651900,
        famous_for: "129-ft falls fed by springs that pour straight through the rock face — flows full even when summer has dried everything else.",
        notes: "Burney Falls Loop ≈ 1.1 mi, easy. State-park day-use fee (NOT covered by the NPS pass — bring a card/cash)." },
      { time_label: "3:30 PM", title: "Mount Shasta — Heart Lake", group_label: "hike",
        location_name: "Heart Lake Trail (Castle Lake)", address: "Mount Shasta, CA 96067",
        latitude: 41.229400, longitude: -122.383800,
        famous_for: "Alpine tarn that perfectly frames 14,179-ft Mt. Shasta — one of the best mountain views in California.",
        notes: "Good news: Heart Lake from Castle Lake is ~3 mi RT (shorter than the 4–5 mi estimate) — easier to fit after a full day. The Castle Lake road is narrow/winding — UNHITCH in Mt. Shasta city first." },
      { time_label: "Evening", title: "Overnight — Mount Shasta, CA", group_label: "lodging",
        location_name: "Mount Shasta City, CA", address: "Mount Shasta, CA",
        latitude: 41.309900, longitude: -122.310600,
        famous_for: "Mount Shasta KOA Holiday — hookups, trailer-friendly.",
        notes: "Book ahead. Mountain-town dinner options in town." }
    ]
  },
  {
    label: "Day 5", accent: "violet", theme: "sierra", date: start_date + 4,
    title: "Day 5 — Lassen & Lake Tahoe",
    summary: "Sierra day — geothermal Bumpass Hell in Lassen, then Tahoe's quiet east shore at Spooner " \
             "Lake (a trailer-friendly swap for Eagle Falls), overnight Reno (~6h).",
    activities: [
      { time_label: "8:00 AM", title: "Depart Mount Shasta, CA", group_label: "drive",
        location_name: "Mount Shasta, CA", address: "Mount Shasta, CA",
        latitude: 41.309900, longitude: -122.310600,
        famous_for: "I-5 S briefly, then CA-89 S into the Lassen region.",
        notes: "Fuel before turning onto 89 — services thin out." },
      { time_label: "9:30 AM", title: "Lassen Volcanic NP — Bumpass Hell", group_label: "hike",
        location_name: "Bumpass Hell Trailhead, Lassen Volcanic NP", address: "Mineral, CA 96063",
        latitude: 40.457600, longitude: -121.400600,
        famous_for: "Lassen's largest hydrothermal basin — fumaroles, boiling springs and mudpots, often compared to Yellowstone.",
        notes: "≈ 3 mi RT, moderate. Pass covers entry. STAY ON THE BOARDWALK — the ground is scalding and unstable. High elevation (~8,200 ft) — pace it." },
      { time_label: "3:30 PM", title: "Lake Tahoe — Spooner Lake", group_label: "hike",
        location_name: "Spooner Lake (Lake Tahoe Nevada State Park)", address: "Glenbrook, NV 89413",
        latitude: 39.106300, longitude: -119.917000,
        famous_for: "Aspen-ringed lake on Tahoe's quiet east shore — gentle, gorgeous, and uncrowded.",
        notes: "SWAPPED IN for Eagle Falls/Emerald Bay, whose tiny lot and narrow Hwy-89 can't take a rig towing all day. Spooner has a large US-50/NV-28 lot that fits a trailer. ≈ 2.5 mi easy loop. NV state-park fee." },
      { time_label: "5:00 PM", title: "Sand Harbor viewpoint (optional)", group_label: "viewpoint",
        location_name: "Sand Harbor, NV-28", address: "Incline Village, NV 89451",
        latitude: 39.201700, longitude: -119.930600,
        famous_for: "The iconic boulder-strewn turquoise east shore, on the way north toward Reno.",
        notes: "Quick photo stop from the NV-28 pullouts — the main lot fills fast in summer, so don't count on parking the rig inside." },
      { time_label: "6:30 PM", title: "Overnight — Reno, NV", group_label: "lodging",
        location_name: "Reno, NV", address: "Reno, NV",
        latitude: 39.529600, longitude: -119.813800,
        famous_for: "Reno-area RV park — full hookups before the desert legs.",
        notes: "Book ahead — many Reno Walmarts prohibit overnight. Try Reno KOA at Boomtown or Gold Ranch RV. Big fuel-up for the I-80 stretch tomorrow." }
    ]
  },
  {
    label: "Day 6", accent: "rose", theme: "alpine", date: start_date + 5,
    title: "Day 6 — Nevada's Ruby Mountains",
    summary: "Hidden Nevada — I-80 east to the Ruby Mountains and a glacier-lake hike to Island Lake, " \
             "overnight Elko (~5h). Fuel + download offline maps before the canyon.",
    activities: [
      { time_label: "8:00 AM", title: "Depart Reno, NV", group_label: "drive",
        location_name: "Reno, NV", address: "Reno, NV",
        latitude: 39.529600, longitude: -119.813800,
        famous_for: "I-80 E across northern Nevada (~4h of high desert).",
        notes: "Long, empty stretch. Fuel at Winnemucca/Battle Mountain; cell is spotty." },
      { time_label: "12:00 PM", title: "Lamoille Canyon — Island Lake", group_label: "hike",
        location_name: "Island Lake Trail (Road's End)", address: "Lamoille, NV 89828",
        latitude: 40.607600, longitude: -115.347500,
        famous_for: "The \"Swiss Alps of Nevada\" — a glacier-carved canyon in the Ruby Mountains few travelers ever associate with NV. Arguably the best remaining hike of the trip.",
        notes: "≈ 3.6 mi RT, moderate, with wildflowers in summer. The upper canyon road is narrow/winding — unhitch in Lamoille (or at a lower pullout). FUEL in Elko/Spring Creek + download offline maps first: no services in the canyon, poor cell." },
      { time_label: "4:30 PM", title: "Overnight — Elko, NV", group_label: "lodging",
        location_name: "Elko, NV", address: "Elko, NV",
        latitude: 40.832400, longitude: -115.763100,
        famous_for: "Elko RV park — hookups, easy I-80 access.",
        notes: "Book ahead. Optional add-on below if you still have energy." },
      { time_label: "Optional", title: "California Trail Interpretive Center", group_label: "historic",
        location_name: "California Trail Interpretive Center", address: "Elko, NV 89801",
        latitude: 40.754800, longitude: -115.943000,
        famous_for: "Free museum on the pioneer wagon migration through Nevada — a nice change of pace.",
        notes: "Closes ~5 PM — only if you arrive with time/energy to spare." }
    ]
  },
  {
    label: "Day 7", accent: "gold", theme: "return", date: end_date,
    title: "Day 7 — Angel Lake & home",
    summary: "Relaxed finish — the Angel Lake byway above Wells for one last alpine lake, then the easy " \
             "run home to Woods Cross (~5.5–6h). Ends on a hidden gem, not just 'driving home.'",
    activities: [
      { time_label: "8:30 AM", title: "Depart Elko, NV", group_label: "drive",
        location_name: "Elko, NV", address: "Elko, NV",
        latitude: 40.832400, longitude: -115.763100,
        famous_for: "I-80 E toward Wells (~50 min). Relaxed start.",
        notes: "Fuel in Wells at the base of the byway." },
      { time_label: "9:30 AM", title: "Angel Lake Scenic Byway + light hike", group_label: "hike",
        location_name: "Angel Lake", address: "Wells, NV 89835",
        latitude: 41.038400, longitude: -115.036400,
        famous_for: "A 12-mi paved byway climbs the East Humboldt Range to an alpine cirque lake most I-80 travelers never know exists — the perfect final hidden gem.",
        notes: "Day-use fee. Smith Lake via Angel Lake ≈ 2.5 mi light hike (~90 min), or just stroll the shore. Cool mountain air, great photos." },
      { time_label: "Lunch", title: "Lunch — Wells / Wendover / Park City", group_label: "lunch",
        location_name: "En route, I-80 / Park City", address: "Park City, UT",
        latitude: 40.646100, longitude: -111.498000,
        famous_for: "Fuel + lunch break on the run home.",
        notes: "Wendover (state line) or Park City both work depending on timing." },
      { time_label: "3:00 PM", title: "Home — Woods Cross, UT", group_label: "drive",
        location_name: "Woods Cross, UT", address: "Woods Cross, UT",
        latitude: 40.871600, longitude: -111.892200,
        famous_for: "Loop complete — falls, volcanoes, caves, and alpine lakes in one week.",
        notes: "Unload, dump/flush tanks, and rest. Trip done." }
    ]
  }
]

days.each_with_index do |day_data, day_idx|
  day = trip.trip_days.find_or_create_by!(label: day_data[:label]) do |d|
    d.date     = day_data[:date]
    d.title    = day_data[:title]
    d.theme    = day_data[:theme]
    d.accent   = day_data[:accent]
    d.summary  = day_data[:summary]
    d.position = day_idx
  end
  # Keep summary/title fresh on re-seed.
  day.update!(title: day_data[:title], theme: day_data[:theme], accent: day_data[:accent], summary: day_data[:summary])

  day_data[:activities].each_with_index do |a, i|
    activity = day.activities.find_or_create_by!(title: a[:title]) do |act|
      act.time_label    = a[:time_label]
      act.location_name = a[:location_name]
      act.address       = a[:address]
      act.latitude      = a[:latitude]
      act.longitude     = a[:longitude]
      act.famous_for    = a[:famous_for]
      act.notes         = a[:notes]
      act.group_label   = a[:group_label]
      act.position      = i
    end
    activity.update!(
      time_label: a[:time_label], location_name: a[:location_name], address: a[:address],
      latitude: a[:latitude], longitude: a[:longitude], famous_for: a[:famous_for],
      notes: a[:notes], group_label: a[:group_label], position: i
    )
  end
end

# ── Trails (each hike, linked to its verified AllTrails page) ─────────────────
trails = [
  { name: "Misery Ridge & River Trail (Smith Rock)",
    alltrails_url: "https://www.alltrails.com/trail/us/oregon/misery-ridge-and-river-trail--2",
    notes: "Day 2 · ≈3.6 mi loop · hard · Crooked River canyon + Monkey Face. Hot & exposed — 3L water each." },
  { name: "Paulina Peak Trail (Newberry)",
    alltrails_url: "https://www.alltrails.com/trail/us/oregon/paulina-peak-trail",
    notes: "Day 3 · caldera-rim panorama. Summit road's last ~3 mi is steep gravel — drop the trailer at Paulina Lake." },
  { name: "The Watchman Peak Trail (Crater Lake)",
    alltrails_url: "https://www.alltrails.com/trail/us/oregon/the-watchman-peak-trail",
    notes: "Day 3 · ≈1.7 mi · moderate · best full-lake panorama; West Rim, paved trailhead lot." },
  { name: "Burney Falls Loop",
    alltrails_url: "https://www.alltrails.com/trail/us/california/burney-falls-loop-trail",
    notes: "Day 4 · ≈1.1 mi easy loop to the base of the spring-fed 129-ft falls." },
  { name: "Heart Lake Trail from Castle Lake (Mt. Shasta)",
    alltrails_url: "https://www.alltrails.com/trail/us/california/heart-lake-trail-from-castle-lake",
    notes: "Day 4 · ≈3 mi RT · moderate · alpine tarn framing Mt. Shasta. Unhitch in town — Castle Lake road is narrow." },
  { name: "Bumpass Hell Trail (Lassen)",
    alltrails_url: "https://www.alltrails.com/trail/us/california/bumpass-hell",
    notes: "Day 5 · ≈3 mi RT · moderate · fumaroles & mudpots; stay on the boardwalk." },
  { name: "Spooner Lake Trail (Tahoe east shore)",
    alltrails_url: "https://www.alltrails.com/trail/us/nevada/spooner-lake-trail",
    notes: "Day 5 · ≈2.5 mi easy loop · rig-friendly US-50 lot — swapped in for Eagle Falls/Emerald Bay (no trailer access)." },
  { name: "Island Lake Trail (Lamoille Canyon)",
    alltrails_url: "https://www.alltrails.com/trail/us/nevada/island-lake-trail",
    notes: "Day 6 · ≈3.6 mi RT · moderate · glacial alpine lake in the Ruby Mountains." },
  { name: "Smith Lake via Angel Lake Trail (Wells)",
    alltrails_url: "https://www.alltrails.com/trail/us/nevada/smith-lake-via-angel-lake-trail",
    notes: "Day 7 · ≈2.5 mi · moderate · light final hike above Angel Lake." }
]
trails.each_with_index do |attrs, i|
  trip.trails.find_or_create_by!(name: attrs[:name]) do |t|
    t.alltrails_url = attrs[:alltrails_url]
    t.notes         = attrs[:notes]
    t.position      = i
  end
end

# ── RV / trailer checklist ───────────────────────────────────────────────────
checklist = [
  # Passes & reservations
  { scope: "before_trip", category: "Passes & Reservations", title: "America the Beautiful annual pass ($80) — covers Crater Lake, Lassen & Lava Beds" },
  { scope: "before_trip", category: "Passes & Reservations", title: "Confirm all 6 nightly RV/KOA reservations (Boise, Bend, Klamath Falls, Mt Shasta, Reno, Elko)" },
  { scope: "before_trip", category: "Passes & Reservations", title: "Backup boondock list per night (Campendium / iOverlander) — many Walmarts now ban overnight" },
  { scope: "before_trip", category: "Passes & Reservations", title: "Cash/card for state-park day-use fees (Burney Falls, Spooner Lake, Angel Lake)" },
  # Documents
  { scope: "before_trip", category: "Documents", title: "Driver's license + truck registration & insurance", person: "Tom" },
  { scope: "before_trip", category: "Documents", title: "Trailer registration & insurance", person: "Tom" },
  { scope: "before_trip", category: "Documents", title: "Roadside assistance card (Good Sam / AAA RV)" },
  # Trailer & tow
  { scope: "before_trip", category: "Trailer & Tow", title: "Tire pressure + tread on truck, trailer & spare" },
  { scope: "before_trip", category: "Trailer & Tow", title: "Test trailer brakes + breakaway cable" },
  { scope: "before_trip", category: "Trailer & Tow", title: "Grease hitch; check ball/coupler + weight-distribution/sway bars" },
  { scope: "before_trip", category: "Trailer & Tow", title: "Verify all trailer lights (brake / turn / running)" },
  { scope: "before_trip", category: "Trailer & Tow", title: "Wheel chocks + leveling blocks" },
  # Camp setup
  { scope: "before_trip", category: "Camp Setup", title: "Fresh-water hose + inline filter" },
  { scope: "before_trip", category: "Camp Setup", title: "Sewer hose + dump gloves (note dump-station locations)" },
  { scope: "before_trip", category: "Camp Setup", title: "30/50A power adapter + surge protector" },
  { scope: "before_trip", category: "Camp Setup", title: "Propane tanks full (×2)" },
  { scope: "before_trip", category: "Camp Setup", title: "Stabilizer jacks, camp chairs, outdoor mat" },
  # Hiking & outdoors
  { scope: "before_trip", category: "Hiking & Outdoors", title: "Headlamps + spare batteries per person (Lava Beds caves)" },
  { scope: "before_trip", category: "Hiking & Outdoors", title: "3L water bladders per person (desert + exposed hikes)" },
  { scope: "before_trip", category: "Hiking & Outdoors", title: "Sun hats, SPF 50, sunglasses; layers for cold alpine mornings" },
  { scope: "before_trip", category: "Hiking & Outdoors", title: "Trekking poles + broken-in hiking boots" },
  { scope: "before_trip", category: "Hiking & Outdoors", title: "Offline maps downloaded (AllTrails / Gaia) for dead zones" },
  { scope: "before_trip", category: "Hiking & Outdoors", title: "First-aid kit + bug spray" },
  # Kitchen & supplies
  { scope: "before_trip", category: "Kitchen & Supplies", title: "Groceries + cooler restock for 7 days" },
  { scope: "before_trip", category: "Kitchen & Supplies", title: "Refillable water jugs (top off before desert legs)" },
  { scope: "before_trip", category: "Kitchen & Supplies", title: "Portable jump pack + 12V tire inflator" },

  # Day-scoped reminders (day_label must match the TripDay labels above)
  { scope: "day", day_label: "Day 1", title: "Buy Shoshone Falls day-use ($5/vehicle) — and temper expectations: flow is often low by mid-July" },
  { scope: "day", day_label: "Day 2", title: "Drop the trailer in Bend before the gravel Tumalo Falls road" },
  { scope: "day", day_label: "Day 3", title: "Check Crater Lake Rim Drive construction status (nps.gov) before arriving" },
  { scope: "day", day_label: "Day 3", title: "Drop the trailer at Paulina Lake before the Paulina Peak summit road" },
  { scope: "day", day_label: "Day 4", title: "Get the free cave permit + headlamp/white-nose screening at Lava Beds visitor center" },
  { scope: "day", day_label: "Day 4", title: "Unhitch in Mt Shasta city before the Castle Lake road" },
  { scope: "day", day_label: "Day 6", title: "Fuel up + download offline maps in Elko before Lamoille Canyon (no services, poor cell)" },
  { scope: "day", day_label: "Day 6", title: "Unhitch in Lamoille before the upper canyon road" }
]
checklist.each_with_index do |attrs, i|
  trip.checklist_items.find_or_create_by!(scope: attrs[:scope], title: attrs[:title]) do |it|
    it.category       = attrs[:category]
    it.day_label      = attrs[:day_label]
    it.person         = attrs[:person]
    it.position       = i
  end
end

# ── Markdown body (itinerary derived the app's way, + upgrade/logistics notes) ─
structure = {
  "excitement_pitch" => excitement_pitch,
  "days" => days.map do |d|
    {
      "title"   => d[:title],
      "date"    => d[:date].iso8601,
      "summary" => d[:summary],
      "activities" => d[:activities].map do |a|
        { "title" => a[:title], "time_label" => a[:time_label],
          "famous_for" => a[:famous_for], "notes" => a[:notes] }
      end
    }
  end
}
itinerary_md = MarkdownItinerary.from_structure(structure, destination: trip.destination, people: [ { name: "Tom" } ])

glance = <<~MD
  ## Trip at a glance

  | Day | Route | Driving |
  | --- | --- | --- |
  | Sat Jul 11 | Woods Cross → City of Rocks → Twin Falls → Boise | ~7.5h |
  | Sun Jul 12 | Boise → Smith Rock → Tumalo Falls → Bend | ~5.5h |
  | Mon Jul 13 | Bend → Paulina Peak → Crater Lake → Klamath Falls | ~5h |
  | Tue Jul 14 | Klamath Falls → Lava Beds → Burney Falls → Mt Shasta | ~5h |
  | Wed Jul 15 | Mt Shasta → Lassen → Lake Tahoe → Reno | ~6h |
  | Thu Jul 16 | Reno → Lamoille Canyon → Elko | ~5h |
  | Fri Jul 17 | Elko → Angel Lake → Woods Cross | ~5.5–6h |
MD

upgrades = <<~MD
  ## Smart upgrades baked in

  - **Unhitch strategy for the steep trailhead roads** — Paulina Peak's summit road, the Castle Lake road (Heart Lake), Tumalo Falls' gravel, and Lamoille Canyon's upper road are all narrow/steep. Drop the trailer at the overnight or a lower pullout and day-trip in the truck.
  - **Tahoe swapped to Spooner Lake** — Eagle Falls/Emerald Bay's tiny lot and narrow Hwy-89 can't take a rig towed all day; Spooner has a large US-50 lot and an easy 2.5-mi loop, with an optional Sand Harbor photo stop en route to Reno.
  - **Buy the America the Beautiful pass ($80)** — it covers Crater Lake **+** Lassen **+** Lava Beds and pays for itself.
  - **Book RV nights ahead** — mid-July is peak; many Walmarts no longer allow overnight (especially Bend & Reno). Keep a backup per night.
  - **Shoshone & Perrine Coulee run low by mid-July** — spectacular in spring, often modest in late summer (upstream irrigation). Set expectations.
  - **Heavy days flagged** — Day 1 (~7.5h) starts at 7:00 AM for margin; Day 4 (caves + falls + Shasta) is full — Heart Lake is mercifully ~3 mi, not 4–5.
  - **Smith Rock heat** — Misery Ridge bakes on a July afternoon with no shade; carry 3L water each and sun protection.
  - **Lava Beds prep** — free cave permit + headlamps + bat white-nose gear screening at the visitor center first.
  - **Nevada fuel & cell** — fuel at every chance Days 6–7 and pre-download offline maps; Lamoille, Angel Lake and Lava Beds are dead zones.
MD

trip.update!(body: [ itinerary_md, glance, upgrades ].join("\n\n").strip)

puts "✅ West Coast Adventure seeded for #{tom.email}"
puts "   trip_id=#{trip.id}"
puts "   days=#{trip.trip_days.count} activities=#{Activity.joins(:trip_day).where(trip_days: { trip_id: trip.id }).count} " \
     "trails=#{trip.trails.count} checklist=#{trip.checklist_items.count}"
