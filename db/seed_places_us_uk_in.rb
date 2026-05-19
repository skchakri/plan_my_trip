# Seeds the global Place catalog with curated destinations across the
# US, UK, and India — distilled from top travel blogs and Instagram-roundup
# posts (May 2026 research). Three tiers per Place::TIERS:
#   iconic     — universally on every "must visit" list
#   well_known — strong secondary destinations
#   underrated — offbeat / Instagram-trending hidden gems
#
# Idempotent: case-insensitive name match scoped to region; existing rows
# only get filled in (we don't overwrite curated description/famous_for).
# Re-run safely. Image backfill via PlaceImageLookup is skipped for rows
# that already have an image_url unless REFRESH_IMAGES=1.
#
# Run:
#   bin/rails runner db/seed_places_us_uk_in.rb
#   REFRESH_IMAGES=1 bin/rails runner db/seed_places_us_uk_in.rb

# rubocop:disable Layout/LineLength, Layout/HashAlignment

PLACES = [
  # ═══════════════════════════════════════════════════════════════
  # 🇺🇸 UNITED STATES
  # ═══════════════════════════════════════════════════════════════

  # ─── ICONIC ─────────────────────────────────────────────────────
  { name: "Grand Canyon National Park",      lat: 36.0544, lng: -112.1401, kind: "natural",    tier: "iconic",     region: "US-AZ", famous_for: "277-mile-long red-rock canyon carved by the Colorado River; South Rim viewpoints and Bright Angel / South Kaibab trails." },
  { name: "Yellowstone National Park",       lat: 44.4280, lng: -110.5885, kind: "natural",    tier: "iconic",     region: "US-WY", famous_for: "Old Faithful, Grand Prismatic Spring, geyser basins, bison herds in Lamar Valley." },
  { name: "Yosemite National Park",          lat: 37.7459, lng: -119.5332, kind: "natural",    tier: "iconic",     region: "US-CA", famous_for: "Half Dome, El Capitan, Yosemite Falls, Tunnel View — Sierra Nevada granite cathedrals." },
  { name: "Zion National Park",              lat: 37.2982, lng: -113.0263, kind: "natural",    tier: "iconic",     region: "US-UT", famous_for: "Angels Landing, The Narrows, towering red sandstone cliffs along the Virgin River." },
  { name: "Niagara Falls",                   lat: 43.0962, lng: -79.0377,  kind: "natural",    tier: "iconic",     region: "US-NY", famous_for: "Thunderous waterfalls on the US/Canada border; Maid of the Mist boat tours." },
  { name: "Statue of Liberty",               lat: 40.6892, lng: -74.0445,  kind: "landmark",   tier: "iconic",     region: "US-NY", famous_for: "Bartholdi's neoclassical icon on Liberty Island; ferry from Battery Park." },
  { name: "Golden Gate Bridge",              lat: 37.8199, lng: -122.4783, kind: "landmark",   tier: "iconic",     region: "US-CA", famous_for: "International Orange suspension bridge over the Golden Gate strait." },
  { name: "Times Square",                    lat: 40.7580, lng: -73.9855,  kind: "landmark",   tier: "iconic",     region: "US-NY", famous_for: "Neon-clad commercial intersection in Midtown Manhattan, the 'Crossroads of the World.'" },
  { name: "Central Park",                    lat: 40.7829, lng: -73.9654,  kind: "park",       tier: "iconic",     region: "US-NY", famous_for: "843-acre urban park designed by Olmsted & Vaux — Bow Bridge, Bethesda Terrace, The Mall." },
  { name: "Hollywood Sign",                  lat: 34.1341, lng: -118.3215, kind: "landmark",   tier: "iconic",     region: "US-CA", famous_for: "1923 sign on Mount Lee, the symbol of the American film industry." },
  { name: "Las Vegas Strip",                 lat: 36.1147, lng: -115.1728, kind: "landmark",   tier: "iconic",     region: "US-NV", famous_for: "4.2-mile boulevard of mega-resorts, fountains, neon and themed casinos." },
  { name: "Walt Disney World Resort",        lat: 28.3852, lng: -81.5639,  kind: "landmark",   tier: "iconic",     region: "US-FL", famous_for: "Four theme parks, two water parks, Disney Springs — Florida's largest tourism draw." },
  { name: "Mount Rushmore National Memorial", lat: 43.8791, lng: -103.4591, kind: "landmark",  tier: "iconic",     region: "US-SD", famous_for: "60-foot granite portraits of Washington, Jefferson, Lincoln and Roosevelt in the Black Hills." },

  # ─── WELL-KNOWN ─────────────────────────────────────────────────
  { name: "Big Sur",                         lat: 36.2704, lng: -121.8081, kind: "natural",    tier: "well_known", region: "US-CA", famous_for: "70-mile rugged Pacific coastline along Highway 1 — Bixby Bridge, McWay Falls, redwood forests." },
  { name: "Carmel-by-the-Sea",               lat: 36.5552, lng: -121.9233, kind: "town",       tier: "well_known", region: "US-CA", famous_for: "Fairy-tale storybook cottages, white-sand beach, art galleries along Ocean Avenue." },
  { name: "Hearst Castle",                   lat: 35.6852, lng: -121.1681, kind: "historic",   tier: "well_known", region: "US-CA", famous_for: "Hilltop Mediterranean Revival mansion built by William Randolph Hearst, completed 1947." },
  { name: "Monterey Bay",                    lat: 36.6177, lng: -121.9166, kind: "city",       tier: "well_known", region: "US-CA", famous_for: "Cannery Row, Monterey Bay Aquarium, sea otters and 17-Mile Drive." },
  { name: "Santa Barbara",                   lat: 34.4208, lng: -119.6982, kind: "city",       tier: "well_known", region: "US-CA", famous_for: "Spanish Colonial 'American Riviera' — wineries, mission, Stearns Wharf." },
  { name: "Charleston",                      lat: 32.7765, lng: -79.9311,  kind: "city",       tier: "well_known", region: "US-SC", famous_for: "Cobblestone streets, pastel Rainbow Row, antebellum mansions, Lowcountry cuisine." },
  { name: "Savannah Historic District",      lat: 32.0809, lng: -81.0912,  kind: "historic",   tier: "well_known", region: "US-GA", famous_for: "Spanish-moss-draped oaks, 22 garden squares, Forsyth Park fountain." },
  { name: "Philadelphia",                    lat: 39.9526, lng: -75.1652,  kind: "city",       tier: "well_known", region: "US-PA", famous_for: "Independence Hall, Liberty Bell, focal city for the US 250th anniversary in 2026." },
  { name: "New Orleans French Quarter",      lat: 29.9584, lng: -90.0644,  kind: "historic",   tier: "well_known", region: "US-LA", famous_for: "Bourbon Street, French/Spanish Creole architecture, jazz, beignets at Café du Monde." },
  { name: "Nashville",                       lat: 36.1627, lng: -86.7816,  kind: "city",       tier: "well_known", region: "US-TN", famous_for: "Music City — Grand Ole Opry, Country Music Hall of Fame, honky-tonks on Broadway." },
  { name: "Austin",                          lat: 30.2672, lng: -97.7431,  kind: "city",       tier: "well_known", region: "US-TX", famous_for: "Live music capital, SXSW, food trucks, Lady Bird Lake, BBQ at Franklin's." },
  { name: "Sedona",                          lat: 34.8697, lng: -111.7610, kind: "town",       tier: "well_known", region: "US-AZ", famous_for: "Red-rock buttes (Cathedral Rock, Bell Rock), energy vortexes, Slide Rock State Park." },
  { name: "Lake Tahoe",                      lat: 39.0968, lng: -120.0324, kind: "natural",    tier: "well_known", region: "US-CA", famous_for: "Cobalt-blue alpine lake straddling CA/NV — Emerald Bay, skiing at Heavenly and Palisades." },
  { name: "Acadia National Park",            lat: 44.3386, lng: -68.2733,  kind: "natural",    tier: "well_known", region: "US-ME", famous_for: "Cadillac Mountain (first US sunrise), Park Loop Road, Jordan Pond, granite Atlantic coast." },
  { name: "Glacier National Park",           lat: 48.7596, lng: -113.7870, kind: "natural",    tier: "well_known", region: "US-MT", famous_for: "Going-to-the-Sun Road, Logan Pass, glacier-carved peaks, Lake McDonald." },

  # ─── UNDERRATED / IG-TRENDING ───────────────────────────────────
  { name: "Antelope Canyon",                 lat: 36.8619, lng: -111.3743, kind: "geological", tier: "underrated", region: "US-AZ", famous_for: "Navajo-land slot canyon — swirling sandstone walls and light beams; tribal-guide access only." },
  { name: "Horseshoe Bend",                  lat: 36.8791, lng: -111.5104, kind: "viewpoint",  tier: "underrated", region: "US-AZ", famous_for: "1,000-ft cliff overlooking the Colorado River's horseshoe-shaped meander near Page." },
  { name: "Bonneville Salt Flats",           lat: 40.7672, lng: -113.9220, kind: "natural",    tier: "underrated", region: "US-UT", famous_for: "30,000-acre dazzling white salt pan — land-speed-record runs and surreal minimalist photos." },
  { name: "Nā Pali Coast State Park",        lat: 22.1370, lng: -159.6534, kind: "natural",    tier: "underrated", region: "US-HI", famous_for: "17-mile remote Kauai coastline of 4,000-ft sea cliffs — accessible only by boat, helicopter or Kalalau Trail." },
  { name: "Wynwood Walls",                   lat: 25.8013, lng: -80.1994,  kind: "landmark",   tier: "underrated", region: "US-FL", famous_for: "Outdoor street-art museum in Miami's Wynwood district — rotating murals by international artists." },
  { name: "Mesa Arch",                       lat: 38.3879, lng: -109.8688, kind: "viewpoint",  tier: "underrated", region: "US-UT", famous_for: "Canyonlands cliff-edge arch glowing orange at sunrise — one of the most-photographed sunrises in the West." },
  { name: "Multnomah Falls",                 lat: 45.5760, lng: -122.1158, kind: "natural",    tier: "underrated", region: "US-OR", famous_for: "620-ft two-tiered waterfall on the Columbia River Gorge, with the photogenic Benson Footbridge." },
  { name: "White Sands National Park",       lat: 32.7872, lng: -106.3257, kind: "natural",    tier: "underrated", region: "US-NM", famous_for: "275 sq mi of pure white gypsum dunes — sledding, sunset hikes, surreal photographs." },

  # ═══════════════════════════════════════════════════════════════
  # 🇬🇧 UNITED KINGDOM
  # ═══════════════════════════════════════════════════════════════

  # ─── ICONIC ─────────────────────────────────────────────────────
  { name: "Edinburgh Castle",                lat: 55.9486, lng: -3.1999,   kind: "historic",   tier: "iconic",     region: "GB-SCT", famous_for: "12th-century fortress atop Castle Rock — #1 most-Instagrammed Scottish spot, the Stone of Destiny and crown jewels." },
  { name: "Tower of London",                 lat: 51.5081, lng: -0.0759,   kind: "historic",   tier: "iconic",     region: "GB-ENG", famous_for: "1066 Norman fortress on the Thames — Crown Jewels, Yeoman Warders, the ravens." },
  { name: "Big Ben & Westminster",           lat: 51.5007, lng: -0.1246,   kind: "landmark",   tier: "iconic",     region: "GB-ENG", famous_for: "Elizabeth Tower clock on the Palace of Westminster — the silhouette of London." },
  { name: "Buckingham Palace",               lat: 51.5014, lng: -0.1419,   kind: "landmark",   tier: "iconic",     region: "GB-ENG", famous_for: "Royal residence — Changing of the Guard, State Rooms open in summer." },
  { name: "Stonehenge",                      lat: 51.1789, lng: -1.8262,   kind: "historic",   tier: "iconic",     region: "GB-ENG", famous_for: "Neolithic stone circle on Salisbury Plain, c. 2500 BCE — UNESCO World Heritage Site." },
  { name: "Tower Bridge",                    lat: 51.5055, lng: -0.0754,   kind: "landmark",   tier: "iconic",     region: "GB-ENG", famous_for: "1894 Victorian bascule bridge over the Thames with twin Gothic towers." },
  { name: "Loch Ness",                       lat: 57.3229, lng: -4.4244,   kind: "natural",    tier: "iconic",     region: "GB-SCT", famous_for: "23-mile freshwater loch — Urquhart Castle ruins and the cryptid 'Nessie' legend." },
  { name: "Loch Lomond",                     lat: 56.0815, lng: -4.6206,   kind: "natural",    tier: "iconic",     region: "GB-SCT", famous_for: "Largest freshwater loch in Britain by area — Trossachs hills, 30+ islands, lochside villages." },
  { name: "Glencoe",                         lat: 56.6859, lng: -5.1019,   kind: "natural",    tier: "iconic",     region: "GB-SCT", famous_for: "Steep-sided volcanic glen in Lochaber — used in Harry Potter, Skyfall and Outlander." },
  { name: "Isle of Skye",                    lat: 57.2735, lng: -6.2156,   kind: "natural",    tier: "iconic",     region: "GB-SCT", famous_for: "Inner Hebrides island — Old Man of Storr, Fairy Pools, Quiraing, Neist Point." },
  { name: "Lake District",                   lat: 54.4609, lng: -3.0886,   kind: "natural",    tier: "iconic",     region: "GB-ENG", famous_for: "Cumbria fells and 16 ribbon-lakes — Windermere, Derwentwater, Wordsworth's Dove Cottage." },

  # ─── WELL-KNOWN ─────────────────────────────────────────────────
  { name: "Castle Combe",                    lat: 51.4912, lng: -2.2299,   kind: "town",       tier: "well_known", region: "GB-ENG", famous_for: "Cotswold honey-stone village often called 'the prettiest village in England' — Doctor Dolittle filming location." },
  { name: "Bibury",                          lat: 51.7588, lng: -1.8332,   kind: "town",       tier: "well_known", region: "GB-ENG", famous_for: "17th-century Arlington Row weavers' cottages — William Morris called it 'the most beautiful village.'" },
  { name: "Bourton-on-the-Water",            lat: 51.8851, lng: -1.7556,   kind: "town",       tier: "well_known", region: "GB-ENG", famous_for: "'Venice of the Cotswolds' — five low stone bridges over the River Windrush." },
  { name: "Bath",                            lat: 51.3811, lng: -2.3590,   kind: "city",       tier: "well_known", region: "GB-ENG", famous_for: "Georgian honey-stone city — Roman Baths, Royal Crescent, Bath Abbey, Jane Austen Centre." },
  { name: "York",                            lat: 53.9590, lng: -1.0815,   kind: "city",       tier: "well_known", region: "GB-ENG", famous_for: "Medieval walled city — The Shambles, York Minster, Roman/Viking layers." },
  { name: "Oxford",                          lat: 51.7548, lng: -1.2544,   kind: "city",       tier: "well_known", region: "GB-ENG", famous_for: "Dreaming spires — 38 university colleges, Bodleian Library, Christ Church (Harry Potter)." },
  { name: "Cambridge",                       lat: 52.2053, lng: 0.1218,    kind: "city",       tier: "well_known", region: "GB-ENG", famous_for: "Punting on the Cam, King's College Chapel, Fitzwilliam Museum, the Backs." },
  { name: "Cairngorms National Park",        lat: 57.0833, lng: -3.6667,   kind: "park",       tier: "well_known", region: "GB-SCT", famous_for: "Largest UK national park — five of Britain's six highest peaks, ancient Caledonian pine forest." },
  { name: "Snowdonia (Eryri) National Park", lat: 53.0685, lng: -3.9000,   kind: "park",       tier: "well_known", region: "GB-WLS", famous_for: "Yr Wyddfa (Snowdon, 1,085 m) — highest peak in Wales, Welsh slate landscapes, Portmeirion-adjacent." },
  { name: "Giant's Causeway",                lat: 55.2408, lng: -6.5114,   kind: "geological", tier: "well_known", region: "GB-NIR", famous_for: "40,000 hexagonal basalt columns on the Antrim coast — UNESCO site, formed by Paleogene volcanic activity." },
  { name: "Pembrokeshire Coast",             lat: 51.8819, lng: -5.0716,   kind: "natural",    tier: "well_known", region: "GB-WLS", famous_for: "Only fully coastal UK national park — 186-mile Coast Path, puffins on Skomer Island." },
  { name: "Victoria Street, Edinburgh",      lat: 55.9482, lng: -3.1936,   kind: "landmark",   tier: "well_known", region: "GB-SCT", famous_for: "Curved cobbled street of colourful shopfronts — the inspiration for Diagon Alley." },
  { name: "Dean Village, Edinburgh",         lat: 55.9527, lng: -3.2154,   kind: "landmark",   tier: "well_known", region: "GB-SCT", famous_for: "Pink-stone former milling village on the Water of Leith — fairytale turrets minutes from Princes Street." },
  { name: "Arthur's Seat",                   lat: 55.9442, lng: -3.1619,   kind: "viewpoint",  tier: "well_known", region: "GB-SCT", famous_for: "251-m extinct-volcano peak in Holyrood Park — panorama of the entire city of Edinburgh." },

  # ─── UNDERRATED / HIDDEN GEMS ───────────────────────────────────
  { name: "Ross Back Sands",                 lat: 55.6473, lng: -1.8158,   kind: "beach",      tier: "underrated", region: "GB-ENG", famous_for: "5 km of empty white sand on the Northumberland coast — view of Lindisfarne and Bamburgh Castle, 1.5 km walk-in access only." },
  { name: "Holy Island of Lindisfarne",      lat: 55.6792, lng: -1.8014,   kind: "historic",   tier: "underrated", region: "GB-ENG", famous_for: "Tidal-causeway island — 7th-century Lindisfarne Priory, 16th-century castle, only accessible at low tide." },
  { name: "Shell Grotto, Margate",           lat: 51.3856, lng: 1.3814,    kind: "historic",   tier: "underrated", region: "GB-ENG", famous_for: "Mysterious underground passages covered in 4.6 million shell mosaics — discovered 1835, origin unknown." },
  { name: "Skipton Castle",                  lat: 53.9636, lng: -2.0193,   kind: "historic",   tier: "underrated", region: "GB-ENG", famous_for: "900-year-old fully-roofed medieval Yorkshire castle — one of the best-preserved in England." },
  { name: "Portmeirion",                     lat: 52.9136, lng: -4.0972,   kind: "landmark",   tier: "underrated", region: "GB-WLS", famous_for: "Italianate folly village on the Dwyryd Estuary — built 1925–1973 by Clough Williams-Ellis." },
  { name: "St. Ninian's Isle",               lat: 59.9716, lng: -1.3489,   kind: "beach",      tier: "underrated", region: "GB-SCT", famous_for: "Largest active tombolo in Britain — a 500-m sandy causeway between Shetland Mainland and an islet, turquoise water." },
  { name: "Three Cliffs Bay",                lat: 51.5772, lng: -4.1099,   kind: "beach",      tier: "underrated", region: "GB-WLS", famous_for: "Gower Peninsula bay with three limestone tors stepping into the sea — frequent 'best UK beach' winner." },
  { name: "Rhossili Bay",                    lat: 51.5703, lng: -4.2950,   kind: "beach",      tier: "underrated", region: "GB-WLS", famous_for: "3-mile sweep of golden sand backed by Rhossili Down — Worm's Head tidal islet at the south end." },
  { name: "Fort William",                    lat: 56.8198, lng: -5.1052,   kind: "town",       tier: "underrated", region: "GB-SCT", famous_for: "Gateway to Ben Nevis (UK's highest peak) and Glencoe — terminus of the West Highland Way." },
  { name: "Old Man of Storr",                lat: 57.5067, lng: -6.1832,   kind: "geological", tier: "underrated", region: "GB-SCT", famous_for: "165-ft basalt pinnacle on the Trotternish ridge, Isle of Skye — one of Scotland's most-photographed landmarks." },
  { name: "Fairy Pools, Skye",               lat: 57.2493, lng: -6.2700,   kind: "natural",    tier: "underrated", region: "GB-SCT", famous_for: "Series of clear blue plunge pools and waterfalls on the River Brittle below the Black Cuillin." },

  # ═══════════════════════════════════════════════════════════════
  # 🇮🇳 INDIA
  # ═══════════════════════════════════════════════════════════════

  # ─── ICONIC ─────────────────────────────────────────────────────
  { name: "Taj Mahal",                       lat: 27.1751, lng: 78.0421,   kind: "historic",   tier: "iconic",     region: "IN-UP", famous_for: "Ivory-white Mughal mausoleum built by Shah Jahan for Mumtaz Mahal, completed 1653 — UNESCO World Heritage." },
  { name: "Hawa Mahal",                      lat: 26.9239, lng: 75.8267,   kind: "historic",   tier: "iconic",     region: "IN-RJ", famous_for: "'Palace of Winds' — five-story pink-sandstone honeycomb façade of 953 jharokha windows in Jaipur." },
  { name: "Amber Fort",                      lat: 26.9855, lng: 75.8513,   kind: "historic",   tier: "iconic",     region: "IN-RJ", famous_for: "Hilltop Rajput fort overlooking Maota Lake — Sheesh Mahal mirror palace, elephant rides up the ramp." },
  { name: "City Palace, Udaipur",            lat: 24.5764, lng: 73.6835,   kind: "historic",   tier: "iconic",     region: "IN-RJ", famous_for: "400-year-old palace complex of marble courtyards, peacock mosaics, and balconies over Lake Pichola." },
  { name: "Lake Pichola",                    lat: 24.5759, lng: 73.6755,   kind: "natural",    tier: "iconic",     region: "IN-RJ", famous_for: "Artificial lake studded with Jag Niwas (Lake Palace hotel) and Jag Mandir island palaces." },
  { name: "Mehrangarh Fort",                 lat: 26.2978, lng: 73.0193,   kind: "historic",   tier: "iconic",     region: "IN-RJ", famous_for: "400-ft cliff-top fort over Jodhpur's blue city — one of India's largest, intact and museum-curated." },
  { name: "Varanasi Ghats",                  lat: 25.3010, lng: 83.0103,   kind: "historic",   tier: "iconic",     region: "IN-UP", famous_for: "88 riverfront ghats along the Ganga — Dashashwamedh Ganga Aarti, cremation ghats at Manikarnika." },
  { name: "Red Fort",                        lat: 28.6562, lng: 77.2410,   kind: "historic",   tier: "iconic",     region: "IN-DL", famous_for: "1648 Mughal red-sandstone citadel — site of India's Independence Day prime-ministerial address." },
  { name: "Qutub Minar",                     lat: 28.5245, lng: 77.1855,   kind: "historic",   tier: "iconic",     region: "IN-DL", famous_for: "73-m tapered minaret, completed 1220 — tallest brick minaret in the world, UNESCO site." },
  { name: "Gateway of India",                lat: 18.9220, lng: 72.8347,   kind: "landmark",   tier: "iconic",     region: "IN-MH", famous_for: "1924 basalt triumphal arch on Mumbai's Apollo Bunder waterfront — Indo-Saracenic style." },
  { name: "Kerala Backwaters (Alleppey)",    lat: 9.4981,  lng: 76.3388,   kind: "natural",    tier: "iconic",     region: "IN-KL", famous_for: "900-km network of lagoons, canals and lakes — overnight stay on traditional kettuvallam houseboats." },
  { name: "Pangong Tso",                     lat: 33.7570, lng: 78.6500,   kind: "natural",    tier: "iconic",     region: "IN-LA", famous_for: "134-km Himalayan endorheic lake at 4,225 m — colour shifts between deep blue, turquoise and grey." },
  { name: "Goa Beaches",                     lat: 15.2993, lng: 74.1240,   kind: "beach",      tier: "iconic",     region: "IN-GA", famous_for: "Portuguese-Goan beach state — Anjuna, Baga, Palolem, shacks and trance scene." },

  # ─── WELL-KNOWN / 2026 TRENDING ─────────────────────────────────
  { name: "Spiti Valley",                    lat: 32.2461, lng: 78.0349,   kind: "natural",    tier: "well_known", region: "IN-HP", famous_for: "Cold-desert Himalayan valley at 3,800+ m — Key Monastery, Chandratal Lake; just opened for 2026 season." },
  { name: "Srinagar — Dal Lake",             lat: 34.1183, lng: 74.8910,   kind: "natural",    tier: "well_known", region: "IN-JK", famous_for: "Shikara boat rides, floating Mughal-era shikara gardens, Tulip Garden peak bloom in April." },
  { name: "Gulmarg",                         lat: 34.0500, lng: 74.3800,   kind: "town",       tier: "well_known", region: "IN-JK", famous_for: "Himalayan ski town at 2,650 m — Gulmarg Gondola, one of the world's highest cable cars." },
  { name: "Yumthang Valley",                 lat: 27.8278, lng: 88.6985,   kind: "natural",    tier: "well_known", region: "IN-SK", famous_for: "'Valley of Flowers' in North Sikkim — rhododendron peak in April, hot springs, alpine meadows." },
  { name: "Tsomgo Lake",                     lat: 27.3744, lng: 88.7625,   kind: "natural",    tier: "well_known", region: "IN-SK", famous_for: "Glacial high-altitude lake at 3,753 m near the India–China border — frozen Dec–Mar, yak rides." },
  { name: "Rumtek Monastery",                lat: 27.2876, lng: 88.5613,   kind: "historic",   tier: "well_known", region: "IN-SK", famous_for: "Seat of the Karmapa lineage of Tibetan Buddhism — golden stupa, monk debates, Kanchenjunga view." },
  { name: "Coorg (Madikeri)",                lat: 12.4244, lng: 75.7382,   kind: "natural",    tier: "well_known", region: "IN-KA", famous_for: "Western Ghats coffee-estate hills — Abbey Falls, Raja's Seat sunset point, homestays among plantations." },
  { name: "Hampi",                           lat: 15.3350, lng: 76.4600,   kind: "historic",   tier: "well_known", region: "IN-KA", famous_for: "Ruins of 14th-century Vijayanagara Empire capital — Virupaksha Temple, boulder landscapes, UNESCO site." },
  { name: "Munnar",                          lat: 10.0889, lng: 77.0595,   kind: "town",       tier: "well_known", region: "IN-KL", famous_for: "South India hill station at 1,600 m — rolling tea plantations, Eravikulam NP, Mattupetty Dam." },
  { name: "Havelock Island (Swaraj Dweep)",  lat: 11.9930, lng: 92.9863,   kind: "beach",      tier: "well_known", region: "IN-AN", famous_for: "Radhanagar Beach (Asia's best-rated beach), turquoise water, scuba over the Andaman reef." },
  { name: "Darjeeling",                      lat: 27.0410, lng: 88.2663,   kind: "town",       tier: "well_known", region: "IN-WB", famous_for: "Himalayan tea-estate hill station — Darjeeling Himalayan Railway (UNESCO), Tiger Hill sunrise over Kanchenjunga." },
  { name: "Rishikesh",                       lat: 30.0869, lng: 78.2676,   kind: "town",       tier: "well_known", region: "IN-UT", famous_for: "'Yoga capital of the world' on the Ganga — Laxman Jhula suspension bridge, Beatles ashram, river rafting." },
  { name: "Marine Drive, Mumbai",            lat: 18.9438, lng: 72.8231,   kind: "landmark",   tier: "well_known", region: "IN-MH", famous_for: "3.6-km C-curved promenade along the Arabian Sea — the 'Queen's Necklace' of streetlights at night." },
  { name: "Mysore Palace",                   lat: 12.3052, lng: 76.6552,   kind: "historic",   tier: "well_known", region: "IN-KA", famous_for: "Indo-Saracenic Wodeyar palace lit by 97,000 bulbs every Sunday evening — Dasara festival centerpiece." },

  # ─── UNDERRATED / IG-TRENDING OFFBEAT ───────────────────────────
  { name: "Cherrapunji Living Root Bridges", lat: 25.2702, lng: 91.7323,   kind: "natural",    tier: "underrated", region: "IN-ML", famous_for: "Khasi-tribe-trained rubber-tree roots woven into living bridges — Nongriat double-decker is most famous." },
  { name: "Dawki (Umngot River)",            lat: 25.1849, lng: 92.0207,   kind: "natural",    tier: "underrated", region: "IN-ML", famous_for: "Crystal-clear river on the Bangladesh border — boats appear to float in mid-air over the visible riverbed." },
  { name: "Mawlynnong",                      lat: 25.2008, lng: 91.9100,   kind: "town",       tier: "underrated", region: "IN-ML", famous_for: "'Cleanest village in Asia' — bamboo sky-walk, balancing rock, living-root bridge nearby." },
  { name: "Kasol",                           lat: 32.0094, lng: 77.3146,   kind: "town",       tier: "underrated", region: "IN-HP", famous_for: "Parvati Valley backpacker hub — Israeli cafes, riverside trekking base for Kheerganga and Tosh." },
  { name: "Tosh",                            lat: 32.0500, lng: 77.4500,   kind: "town",       tier: "underrated", region: "IN-HP", famous_for: "Last motorable village of Parvati Valley at 2,400 m — snow-peak views, slow café culture." },
  { name: "Gurez Valley",                    lat: 34.6328, lng: 74.8347,   kind: "natural",    tier: "underrated", region: "IN-JK", famous_for: "Remote Himalayan valley near LoC — Habba Khatoon peak, Dard-Shin tribal villages, opened to tourists 2007." },
  { name: "Shoja",                           lat: 31.5550, lng: 77.3417,   kind: "town",       tier: "underrated", region: "IN-HP", famous_for: "Quiet Seraj-valley village in Banjar — Jalori Pass, Serolsar Lake, Great Himalayan NP gateway." },
  { name: "Chopta",                          lat: 30.4974, lng: 79.0780,   kind: "natural",    tier: "underrated", region: "IN-UT", famous_for: "'Mini Switzerland of Uttarakhand' at 2,680 m — Tungnath (world's highest Shiva temple) and Chandrashila." },
  { name: "Mechuka",                         lat: 28.6149, lng: 94.1280,   kind: "town",       tier: "underrated", region: "IN-AR", famous_for: "Arunachal frontier valley near McMahon Line — 400-year-old Samten Yongcha monastery, Yargyap Chu river." },
  { name: "Bhandardara",                     lat: 19.5430, lng: 73.7530,   kind: "natural",    tier: "underrated", region: "IN-MH", famous_for: "Sahyadri hill station — Arthur Lake, Wilson Dam, Mt Kalsubai (highest peak in Maharashtra)." },
  { name: "Mandu",                           lat: 22.3640, lng: 75.3941,   kind: "historic",   tier: "underrated", region: "IN-MP", famous_for: "Afghan-architecture ruined city on the Vindhya plateau — Jahaz Mahal, Rupmati's Pavilion, monsoon magic." },
  { name: "Maravanthe Beach",                lat: 13.7088, lng: 74.6390,   kind: "beach",      tier: "underrated", region: "IN-KA", famous_for: "Unique Karnataka beach with the Arabian Sea on one side of the highway and Souparnika River on the other." },
  { name: "Key Monastery",                   lat: 32.2987, lng: 78.0123,   kind: "historic",   tier: "underrated", region: "IN-HP", famous_for: "1,000-year-old Tibetan Buddhist gompa stacked on a 4,166-m hill — largest monastery in Spiti." },
  { name: "Bir-Billing",                     lat: 32.0440, lng: 76.7250,   kind: "town",       tier: "underrated", region: "IN-HP", famous_for: "World's second-highest paragliding take-off — Tibetan colony, Deer Park Institute, Dharamkot offshoot." }
].freeze

# rubocop:enable Layout/LineLength, Layout/HashAlignment

REFRESH_IMAGES = ENV["REFRESH_IMAGES"] == "1"

puts "Seeding #{PLACES.size} Place rows across US / UK / India…"

created = updated = image_set = image_missing = 0

PLACES.each_with_index do |row, i|
  # Idempotent: case-insensitive name match within the same region.
  # (Region-scoped because "Castle" / "Fort" type names are duplicate-prone.)
  place = Place.where(region: row[:region]).find_by("LOWER(name) = ?", row[:name].downcase)

  if place.nil?
    place = Place.new(name: row[:name], region: row[:region])
    place.canonical_name = row[:name]
    created += 1
  else
    updated += 1
  end

  # Only fill curated fields when blank — don't overwrite manual edits.
  place.kind        = row[:kind]       if place.kind.blank?
  place.tier        = row[:tier]       if place.tier.blank?
  place.latitude    = row[:lat]        if place.latitude.blank?
  place.longitude   = row[:lng]        if place.longitude.blank?
  place.famous_for  = row[:famous_for] if place.famous_for.blank?
  place.verified    = true
  place.save!

  # Image backfill — PlaceImageLookup tries direct Wikipedia, opensearch,
  # Wikipedia geosearch, then Wikimedia Commons geosearch.
  if place.image_url.blank? || REFRESH_IMAGES
    img = PlaceImageLookup.call(place.name, lat: place.latitude, lng: place.longitude)
    if img.present?
      place.update!(image_url: img, image_source: "wikipedia")
      image_set += 1
    else
      image_missing += 1
    end
  end

  print "." if ((i + 1) % 10).zero?
end

puts
puts "Done."
puts "  created:       #{created}"
puts "  updated:       #{updated}"
puts "  images set:    #{image_set}"
puts "  images missed: #{image_missing}"
