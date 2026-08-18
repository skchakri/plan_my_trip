# Curated road-trip guides rendered at /road-trips/:slug. Hand-authored (no AI),
# idempotent upsert by slug. Loaded by db/seeds.rb. Founders edit these in
# /admin/road_trips after seeding.
road_trips = [
  {
    slug: "san-francisco-to-las-vegas",
    origin: "San Francisco", destination: "Las Vegas",
    title: "San Francisco to Las Vegas Road Trip",
    tagline: "570 miles from the Golden Gate to the neon — canyons, Route 66 ghost towns, and the Mojave in between.",
    hero_image_url: "https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=1600&q=80",
    distance_label: "~570 miles", drive_time_label: "~9 hours (direct)", suggested_days: 4,
    best_season: "Spring & fall (the Mojave is brutal in midsummer)",
    transport_mode: "own_car",
    destination_lat: 36.1699, destination_lng: -115.1398,
    seo_description: "The complete San Francisco to Las Vegas road trip guide: the best route, famous stops (Yosemite, Route 66, the Mojave), a day-by-day plan, weather, and FAQs.",
    intro: <<~MD,
      The drive from San Francisco to Las Vegas is one of the great American road trips — and how you route it changes the whole trip. The fast way (I-5 to CA-58) covers 570 miles in about nine hours; the memorable way threads Yosemite's high country, the old Route 66 towns of the Mojave, and a ghost town or two before the Strip lights up the horizon.

      This guide lays out the classic stops, a relaxed four-day plan, and what to expect at each one. When you're ready, let Wanderply build your version — it plans the days around *your* pace and must-dos, then narrates every stop like a podcast for the drive.
    MD
    stops: [
      { name: "Yosemite National Park", tag: "Detour", blurb: "Worth the detour if Tioga Pass is open (roughly June–October): granite walls, waterfalls, and Glacier Point. Adds a day but it's the trip's crown jewel." },
      { name: "Bakersfield", tag: "Overnight / food", blurb: "The Central Valley's country-music town and a natural first-night stop. Great basque food and a good base before the climb into the mountains." },
      { name: "Tehachapi Loop", tag: "Roadside", blurb: "A famous railroad spiral where a mile-long train crosses over itself. A quick, free photo stop as you climb out of the valley." },
      { name: "Barstow & Route 66", tag: "Route 66", blurb: "Mother Road murals, the Route 66 Mother Road Museum, and classic neon. The gateway to the Mojave." },
      { name: "Calico Ghost Town", tag: "Ghost town", blurb: "A restored 1880s silver-mining town in the hills above Barstow — mine tours, wooden boardwalks, and desert views." },
      { name: "Mojave National Preserve", tag: "Nature", blurb: "Singing sand dunes, Joshua tree forests, and lava tubes — a quieter, wilder alternative to the interstate straight-shot." },
      { name: "Las Vegas", tag: "Destination", blurb: "The Strip, the Sphere, world-class dining, and a base for day trips to Hoover Dam and the Grand Canyon's West Rim." }
    ],
    itinerary: [
      { day: 1, title: "SF → Yosemite high country", summary: "Leave the Bay early, climb into the Sierra, and overnight near the park (or Bakersfield if you're skipping Yosemite)." },
      { day: 2, title: "Down to the Mojave", summary: "Descend through Tehachapi to Barstow. Walk Route 66, tour Calico Ghost Town, overnight in Barstow." },
      { day: 3, title: "Mojave to the Strip", summary: "Detour into Mojave National Preserve, then roll into Vegas by evening. Check in, hit the fountains." },
      { day: 4, title: "Vegas day", summary: "Sphere, a Strip walk, and a day-trip option to Hoover Dam or Red Rock Canyon." }
    ],
    faqs: [
      { q: "How long is the drive from San Francisco to Las Vegas?", a: "About 570 miles and 9 hours non-stop via I-5 and CA-58. With stops and a Yosemite detour, plan on 3–4 days." },
      { q: "What's the best route?", a: "The fastest is I-5 south to CA-58 east through Bakersfield and Barstow. The most scenic adds Yosemite (when Tioga Pass is open) or the eastern Sierra via US-395." },
      { q: "When is the best time to make this drive?", a: "Spring and fall. The Mojave Desert stretch is dangerously hot in July and August; Yosemite's high passes are closed in winter." },
      { q: "Is it worth stopping, or should I just drive straight through?", a: "The stops are the trip. Calico Ghost Town, Route 66 in Barstow, and Mojave National Preserve turn a long haul into a real adventure." }
    ]
  },
  {
    slug: "los-angeles-to-grand-canyon",
    origin: "Los Angeles", destination: "Grand Canyon",
    title: "Los Angeles to Grand Canyon Road Trip",
    tagline: "490 miles of Route 66 nostalgia — burros, ghost towns, and one of the seven natural wonders of the world.",
    hero_image_url: "https://images.unsplash.com/photo-1474044159687-1ee9f3a51722?w=1600&q=80",
    distance_label: "~490 miles", drive_time_label: "~7.5 hours", suggested_days: 3,
    best_season: "Spring & fall (South Rim is open year-round)",
    transport_mode: "own_car",
    destination_lat: 36.0544, destination_lng: -112.1401,
    seo_description: "Los Angeles to Grand Canyon road trip guide: the Route 66 route, the best stops (Oatman, Seligman, Williams), a 3-day plan, weather, and FAQs.",
    intro: <<~MD,
      From Los Angeles to the Grand Canyon's South Rim is about 490 miles — and almost all of it traces the old Route 66. This is the Mother Road at its most photogenic: burros wandering the streets of Oatman, the roadside kitsch of Seligman, and the pine-forest gateway town of Williams before the canyon opens up in front of you.

      Below is the classic route, a three-day plan, and the stops that make it. Let Wanderply build a version around your dates and crew — and narrate every stop for the drive.
    MD
    stops: [
      { name: "Barstow", tag: "Route 66", blurb: "The first big Route 66 town east of LA — murals, the Mother Road Museum, and a good coffee-and-gas reset before Arizona." },
      { name: "Oatman, AZ", tag: "Ghost town", blurb: "A former gold-mining town where wild burros roam the main street looking for treats. Old West gunfight shows and a genuinely wild mountain road in." },
      { name: "Kingman", tag: "Route 66", blurb: "The 'Heart of Route 66' — a classic diner scene and the Route 66 Museum. A natural overnight or lunch stop." },
      { name: "Seligman, AZ", tag: "Route 66", blurb: "The town that inspired Pixar's Cars — every storefront is Mother Road nostalgia. Don't skip the Snow Cap Drive-In." },
      { name: "Williams, AZ", tag: "Gateway town", blurb: "The last Route 66 town bypassed by the interstate and the southern gateway to the canyon. Pine forest, a vintage railway, and the turnoff to the South Rim." },
      { name: "Grand Canyon South Rim", tag: "Destination", blurb: "Mather Point, the Rim Trail, Desert View Watchtower, and sunset at Hopi Point. One of the seven natural wonders of the world." }
    ],
    itinerary: [
      { day: 1, title: "LA → Kingman", summary: "Roll out of LA, cross the Mojave, and pick up Route 66. Detour to Oatman for the burros, overnight in Kingman." },
      { day: 2, title: "Route 66 to the Rim", summary: "Seligman's roadside Americana, lunch in Williams, then up to the South Rim for sunset at Mather or Hopi Point." },
      { day: 3, title: "Canyon day", summary: "Sunrise on the Rim Trail, Desert View Watchtower, and a short leg down the South Kaibab Trail if you're up for it." }
    ],
    faqs: [
      { q: "How far is the Grand Canyon from Los Angeles?", a: "About 490 miles to the South Rim — roughly 7.5 hours of driving. Most people make it a 2–3 day trip." },
      { q: "Which Grand Canyon rim is closest to LA?", a: "The South Rim (open all year) is the classic destination via Williams. The West Rim / Skywalk on Hualapai land is closer but a different experience." },
      { q: "Is Route 66 worth following?", a: "Absolutely — Oatman, Kingman, and Seligman are the highlight reel of the surviving Mother Road and turn a highway drive into the trip itself." },
      { q: "When is the best time to go?", a: "Spring and fall for mild temperatures. The South Rim sits at 7,000 feet and can snow in winter; summer is hot and crowded." }
    ]
  },
  {
    slug: "salt-lake-city-to-las-vegas",
    origin: "Salt Lake City", destination: "Las Vegas",
    title: "Salt Lake City to Las Vegas Road Trip",
    tagline: "420 miles down I-15 — red-rock canyons, a national park detour, and the Strip at the finish line.",
    hero_image_url: "https://images.unsplash.com/photo-1526772662000-3f88f10405ff?w=1600&q=80",
    distance_label: "~420 miles", drive_time_label: "~6 hours", suggested_days: 3,
    best_season: "Spring & fall (Zion is glorious, summer is hot)",
    transport_mode: "own_car",
    destination_lat: 36.1699, destination_lng: -115.1398,
    seo_description: "Salt Lake City to Las Vegas road trip guide: the I-15 route, the best stops (Zion, St. George, the Virgin River Gorge), a 3-day plan, weather, and FAQs.",
    intro: <<~MD,
      Salt Lake City to Las Vegas is a straight shot down I-15 — about 420 miles and six hours — but it passes some of the most spectacular red rock in the country. With a half-day to spare, Zion National Park is right off the highway, and the drive itself saves the best for last: the Virgin River Gorge, one of the most beautiful stretches of interstate in America.

      Here's the route, the stops, and a three-day plan. Wanderply can build your version and narrate every stop — including the famous ones on the way into Vegas.
    MD
    stops: [
      { name: "Provo & the Wasatch Front", tag: "Scenic", blurb: "The mountains stay with you for the first hour south of Salt Lake — a dramatic sendoff along the Wasatch Front." },
      { name: "Beaver, UT", tag: "Food / gas", blurb: "The classic halfway stop. Arshel's Café has served road-trippers since 1973 — chicken-fried steak and scones the size of your face." },
      { name: "Zion National Park", tag: "Detour", blurb: "Just off I-15 near St. George: the Narrows, Angels Landing, and the shuttle up Zion Canyon. The best detour on the drive." },
      { name: "St. George, UT", tag: "Overnight", blurb: "Utah's warm-weather corner and a great base for Zion or Snow Canyon. A natural overnight before the final push." },
      { name: "Virgin River Gorge", tag: "Scenic drive", blurb: "A jaw-dropping 20-mile canyon stretch of I-15 through the northwest tip of Arizona — one of the most scenic interstates ever built." },
      { name: "Las Vegas", tag: "Destination", blurb: "The Sphere, the Strip, and a base for the Grand Canyon Skywalk and Hoover Dam. Neon after all that red rock." }
    ],
    itinerary: [
      { day: 1, title: "SLC → St. George", summary: "South down I-15 with a lunch stop in Beaver. Overnight in St. George, gateway to Zion." },
      { day: 2, title: "Zion, then the Gorge", summary: "A morning in Zion Canyon, then the stunning drive through the Virgin River Gorge into Nevada. Vegas by evening." },
      { day: 3, title: "Vegas day", summary: "The Sphere, a Strip walk, and a day-trip option to Hoover Dam or the Grand Canyon Skywalk." }
    ],
    faqs: [
      { q: "How long is the drive from Salt Lake City to Las Vegas?", a: "About 420 miles and 6 hours non-stop down I-15. With a Zion detour, make it a 2–3 day trip." },
      { q: "Can I visit a national park on the way?", a: "Yes — Zion National Park is just off I-15 near St. George and is the standout detour. Bryce Canyon and the Grand Canyon are both within reach with an extra day." },
      { q: "What's the most scenic part of the drive?", a: "The Virgin River Gorge — a 20-mile canyon stretch of I-15 through the corner of Arizona that's regularly called one of the most beautiful interstates in the country." },
      { q: "When is the best time to make this drive?", a: "Spring and fall. Summer is very hot in St. George and Vegas; winter is fine on I-15 but Zion's high trails can be icy." }
    ]
  },
  {
    slug: "denver-to-moab",
    origin: "Denver", destination: "Moab",
    title: "Denver to Moab Road Trip",
    tagline: "350 miles over the Rockies and down into red-rock country — canyons, wine, and Arches at the end.",
    hero_image_url: "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=1600&q=80",
    distance_label: "~350 miles", drive_time_label: "~5.5 hours", suggested_days: 3,
    best_season: "Spring & fall (Arches is hot in summer, I-70 snowy in winter)",
    transport_mode: "own_car",
    destination_lat: 38.5733, destination_lng: -109.5498,
    seo_description: "Denver to Moab road trip guide: the I-70 route over the Rockies, stops (Glenwood Canyon, Colorado National Monument), a 3-day plan, weather, and FAQs.",
    intro: <<~MD,
      The drive from Denver to Moab is a study in contrasts: you start in the Mile High City, climb over the Continental Divide through the heart of the Rockies, and end in the red-rock desert at the doorstep of Arches and Canyonlands. It's about 350 miles on I-70 and UT-128 — and the road itself, through Glenwood Canyon, is one of the engineering marvels of the interstate system.

      Here's the route, the best stops, and a three-day plan. Let Wanderply build your version and narrate every stop for the drive over the mountains.
    MD
    stops: [
      { name: "Glenwood Springs", tag: "Hot springs", blurb: "Home to the world's largest hot-springs pool and the mouth of Glenwood Canyon. A perfect first-night soak after the mountain crossing." },
      { name: "Glenwood Canyon", tag: "Scenic drive", blurb: "A 12-mile stretch where I-70 threads a sheer canyon on stacked viaducts alongside the Colorado River — a genuine feat of road engineering." },
      { name: "Grand Junction & wine country", tag: "Food / wine", blurb: "Colorado's wine country in the Grand Valley — tasting rooms, orchards, and the last real town before Utah." },
      { name: "Colorado National Monument", tag: "Nature", blurb: "Sheer red-rock canyons and the Rim Rock Drive just outside Grand Junction — a stunning, underrated warm-up for Moab." },
      { name: "Fisher Towers (UT-128)", tag: "Scenic drive", blurb: "Skip the interstate for the last leg and follow the Colorado River on UT-128 past the soaring Fisher Towers into Moab." },
      { name: "Moab / Arches National Park", tag: "Destination", blurb: "Delicate Arch, Balanced Rock, and Canyonlands next door. The red-rock adventure capital of the Southwest." }
    ],
    itinerary: [
      { day: 1, title: "Denver → Glenwood Springs", summary: "Climb over the Divide on I-70, through Vail and Glenwood Canyon. Soak in the hot springs and overnight." },
      { day: 2, title: "Wine country to red rock", summary: "Grand Junction wineries and Colorado National Monument, then the scenic UT-128 river road into Moab." },
      { day: 3, title: "Arches day", summary: "Sunrise at Delicate Arch, the Windows section, and an afternoon in Canyonlands' Island in the Sky." }
    ],
    faqs: [
      { q: "How long is the drive from Denver to Moab?", a: "About 350 miles and 5.5 hours via I-70. With stops in Glenwood Springs and Grand Junction, it's an easy 2–3 day trip." },
      { q: "Is the drive over the Rockies difficult?", a: "I-70 is a well-maintained interstate, but it crosses high mountain passes. In winter, carry chains and check conditions — the Eisenhower Tunnel sits above 11,000 feet." },
      { q: "What's the best scenic stop?", a: "Glenwood Canyon for the engineering and the river, and Colorado National Monument for a red-rock preview of Moab. Take UT-128 for the final leg." },
      { q: "Do I need a reservation for Arches National Park?", a: "During peak season (spring through fall) Arches uses a timed-entry reservation system for daytime entry. Book ahead or enter early morning / late afternoon." }
    ]
  },
  {
    slug: "seattle-to-portland",
    origin: "Seattle", destination: "Portland",
    title: "Seattle to Portland Road Trip",
    tagline: "175 miles down I-5 — but the volcanoes, waterfalls, and coffee stops are the whole point.",
    hero_image_url: "https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=1600&q=80",
    distance_label: "~175 miles", drive_time_label: "~3 hours (direct)", suggested_days: 2,
    best_season: "Summer & early fall (clear volcano views, dry trails)",
    transport_mode: "own_car",
    destination_lat: 45.5152, destination_lng: -122.6784,
    seo_description: "Seattle to Portland road trip guide: the I-5 route plus the great detours (Mount Rainier, Mount St. Helens), a 2-day plan, weather, and FAQs.",
    intro: <<~MD,
      Seattle to Portland is only about 175 miles — three hours if you never leave I-5. But that's the trap: the best of the Pacific Northwest is a short detour off the highway. Two active volcanoes, old-growth forest, waterfalls, and some of the best coffee and beer in the country all sit within easy reach of the drive.

      Here's the route, the detours worth taking, and a relaxed two-day plan. Wanderply can build your version around your interests and narrate every stop for the road.
    MD
    stops: [
      { name: "Tacoma", tag: "City stop", blurb: "The Museum of Glass and a waterfront revival make Tacoma a quick, worthwhile stop just south of Seattle." },
      { name: "Mount Rainier National Park", tag: "Detour", blurb: "The Northwest's iconic volcano — Paradise wildflower meadows, waterfalls, and old-growth forest. The best detour of the trip on a clear day." },
      { name: "Olympia", tag: "State capital", blurb: "Washington's compact capital, with the domed Capitol building and a good farmers' market. An easy lunch stop." },
      { name: "Mount St. Helens", tag: "Detour", blurb: "The volcano that erupted in 1980 — the Johnston Ridge Observatory looks straight into the crater and tells one of geology's great stories." },
      { name: "Columbia River / Vancouver, WA", tag: "Scenic", blurb: "Cross the mighty Columbia River into Oregon — the gateway to Portland and, just east, the Columbia River Gorge waterfalls." },
      { name: "Portland", tag: "Destination", blurb: "Food carts, Powell's City of Books, Forest Park, and a base for the Columbia Gorge and Mount Hood. Keep it weird." }
    ],
    itinerary: [
      { day: 1, title: "Seattle → Mount Rainier → Olympia", summary: "South to Tacoma, then up to Paradise at Mount Rainier for the meadows and views. Overnight near Olympia." },
      { day: 2, title: "St. Helens to Portland", summary: "Detour to the Mount St. Helens crater viewpoint, cross the Columbia, and arrive in Portland for dinner and Powell's." }
    ],
    faqs: [
      { q: "How long is the drive from Seattle to Portland?", a: "About 175 miles and 3 hours non-stop on I-5. With detours to Mount Rainier and Mount St. Helens it's a full, rewarding 2 days." },
      { q: "What are the best stops between Seattle and Portland?", a: "Mount Rainier and Mount St. Helens are the headliners. Tacoma's Museum of Glass and Olympia's Capitol make good shorter breaks." },
      { q: "When is the best time to make this drive?", a: "Summer and early fall, when the skies are clearest for volcano views and the high mountain roads at Rainier are fully open." },
      { q: "Can I see both volcanoes in one trip?", a: "Yes, with two days. Mount Rainier is an eastern detour from Tacoma; Mount St. Helens is reached from Castle Rock further south — both are off I-5." }
    ]
  }
]

road_trips.each_with_index do |attrs, i|
  rec = RoadTrip.find_or_initialize_by(slug: attrs[:slug])
  rec.assign_attributes(attrs.merge(status: "published", position: i))
  rec.save!
end

puts "Road trips: #{RoadTrip.count} total (#{RoadTrip.published.count} published)"
