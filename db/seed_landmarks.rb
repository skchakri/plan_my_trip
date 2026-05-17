# Seeds the global RouteLandmark catalog (trip_id: nil) with marquee
# Utah-and-surrounding-states landmarks. Each row gets:
#   * curated name / coords / kind / state (this file)
#   * AI-generated 2-3 sentence narration (Ai::Caller, landmark_narration.v1)
#   * Wikipedia thumbnail + article URL (en.wikipedia REST API)
#
# Idempotent: re-running upserts by (name, trip_id IS NULL). Existing rows
# keep their AI-generated narration unless --refresh is passed via the env
# var REFRESH=1 (in which case we re-call AI and re-fetch Wikipedia).
#
# Run with:
#   bin/rails runner db/seed_landmarks.rb
#   REFRESH=1 bin/rails runner db/seed_landmarks.rb

require "net/http"
require "uri"
require "json"

USER_AGENT = "PlanMyTrip/1.0 (https://planmytrip.app; mailto:hello@planmytrip.app)".freeze
REFRESH = ENV["REFRESH"] == "1"

LANDMARKS = [
  # ─── Alabama ─────────────────────────────────────────────────────
  { name: "USS Alabama Battleship Memorial Park",     lat: 30.6818, lng: -88.0143, kind: "historic",    state: "Alabama" },
  { name: "Cheaha State Park",                        lat: 33.4860, lng: -85.8089, kind: "natural",     state: "Alabama" },
  { name: "16th Street Baptist Church",               lat: 33.5160, lng: -86.8146, kind: "historic",    state: "Alabama" },
  { name: "Bellingrath Gardens and Home",             lat: 30.5535, lng: -88.0913, kind: "cultural",    state: "Alabama" },

  # ─── Alaska ──────────────────────────────────────────────────────
  { name: "Denali",                                   lat: 63.0692, lng: -151.0070, kind: "natural",    state: "Alaska" },
  { name: "Glacier Bay National Park",                lat: 58.4554, lng: -135.8946, kind: "natural",    state: "Alaska" },
  { name: "Mendenhall Glacier",                       lat: 58.4419, lng: -134.5450, kind: "natural",    state: "Alaska" },
  { name: "Kenai Fjords National Park",               lat: 59.9221, lng: -149.6515, kind: "natural",    state: "Alaska" },

  # ─── Arizona · Grand Canyon, slot canyons, Sedona ────────────────
  { name: "Grand Canyon — South Rim",                 lat: 36.0544, lng: -112.1401, kind: "geological",  state: "Arizona" },
  { name: "Monument Valley Navajo Tribal Park",       lat: 36.9980, lng: -110.0985, kind: "tribal",      state: "Arizona" },
  { name: "Antelope Canyon",                          lat: 36.8619, lng: -111.3743, kind: "geological",  state: "Arizona" },
  { name: "Horseshoe Bend",                           lat: 36.8791, lng: -111.5104, kind: "scenic",      state: "Arizona" },
  { name: "Glen Canyon Dam",                          lat: 36.9367, lng: -111.4844, kind: "engineering", state: "Arizona" },
  { name: "Cathedral Rock, Sedona",                   lat: 34.8208, lng: -111.7867, kind: "geological",  state: "Arizona" },
  { name: "Meteor Crater",                            lat: 35.0277, lng: -111.0227, kind: "geological",  state: "Arizona" },
  { name: "Petrified Forest National Park",           lat: 34.9099, lng: -109.8068, kind: "natural",     state: "Arizona" },
  { name: "Saguaro National Park",                    lat: 32.2967, lng: -111.1660, kind: "natural",     state: "Arizona" },
  { name: "Tombstone Historic District",              lat: 31.7128, lng: -110.0676, kind: "ghost_town", state: "Arizona" },

  # ─── Arkansas ────────────────────────────────────────────────────
  { name: "Hot Springs National Park",                lat: 34.5117, lng: -93.0537, kind: "historic",    state: "Arkansas" },
  { name: "Buffalo National River",                   lat: 36.0167, lng: -92.7000, kind: "natural",     state: "Arkansas" },
  { name: "Crystal Bridges Museum of American Art",   lat: 36.3826, lng: -94.2034, kind: "cultural",    state: "Arkansas" },
  { name: "Little Rock Central High School",          lat: 34.7355, lng: -92.2944, kind: "historic",    state: "Arkansas" },

  # ─── California ──────────────────────────────────────────────────
  { name: "Yosemite National Park",                   lat: 37.7459, lng: -119.5332, kind: "natural",    state: "California" },
  { name: "Golden Gate Bridge",                       lat: 37.8199, lng: -122.4783, kind: "engineering", state: "California" },
  { name: "Sequoia National Park",                    lat: 36.5816, lng: -118.7517, kind: "natural",    state: "California" },
  { name: "Joshua Tree National Park",                lat: 33.8734, lng: -115.9010, kind: "natural",    state: "California" },
  { name: "Hollywood Sign",                           lat: 34.1341, lng: -118.3215, kind: "historic",   state: "California" },
  { name: "Bixby Creek Bridge",                       lat: 36.3712, lng: -121.9027, kind: "engineering", state: "California" },
  { name: "Death Valley National Park",               lat: 36.5054, lng: -117.0794, kind: "natural",    state: "California" },

  # ─── Colorado · Cliff dwellings, sand dunes, peaks ───────────────
  { name: "Mesa Verde — Cliff Palace",                lat: 37.1672, lng: -108.4737, kind: "cultural",    state: "Colorado" },
  { name: "Maroon Bells",                             lat: 39.0708, lng: -106.9890, kind: "scenic",      state: "Colorado" },
  { name: "Garden of the Gods",                       lat: 38.8784, lng: -104.8697, kind: "geological",  state: "Colorado" },
  { name: "Great Sand Dunes National Park",           lat: 37.7916, lng: -105.5943, kind: "natural",     state: "Colorado" },
  { name: "Pikes Peak",                               lat: 38.8409, lng: -105.0442, kind: "pass_summit", state: "Colorado" },
  { name: "Black Canyon of the Gunnison",             lat: 38.5751, lng: -107.7416, kind: "geological",  state: "Colorado" },
  { name: "Red Mountain Pass",                        lat: 37.8961, lng: -107.7126, kind: "pass_summit", state: "Colorado" },
  { name: "Rocky Mountain National Park",             lat: 40.3428, lng: -105.6836, kind: "natural",    state: "Colorado" },

  # ─── Connecticut ─────────────────────────────────────────────────
  { name: "Mark Twain House",                         lat: 41.7670, lng: -72.7016, kind: "historic",    state: "Connecticut" },
  { name: "Yale University",                          lat: 41.3083, lng: -72.9279, kind: "cultural",    state: "Connecticut" },
  { name: "Mystic Seaport Museum",                    lat: 41.3719, lng: -71.9645, kind: "historic",    state: "Connecticut" },

  # ─── Delaware ────────────────────────────────────────────────────
  { name: "Cape Henlopen State Park",                 lat: 38.7868, lng: -75.0894, kind: "natural",     state: "Delaware" },
  { name: "Hagley Museum and Library",                lat: 39.7710, lng: -75.5736, kind: "historic",    state: "Delaware" },
  { name: "Rehoboth Beach Boardwalk",                 lat: 38.7204, lng: -75.0760, kind: "historic",    state: "Delaware" },

  # ─── Florida ─────────────────────────────────────────────────────
  { name: "Everglades National Park",                 lat: 25.2866, lng: -80.8987, kind: "natural",     state: "Florida" },
  { name: "Kennedy Space Center",                     lat: 28.5729, lng: -80.6490, kind: "engineering", state: "Florida" },
  { name: "St. Augustine Historic District",          lat: 29.8946, lng: -81.3145, kind: "historic",    state: "Florida" },
  { name: "Walt Disney World Magic Kingdom",          lat: 28.4178, lng: -81.5812, kind: "cultural",    state: "Florida" },
  { name: "Miami Beach Architectural District",       lat: 25.7800, lng: -80.1310, kind: "historic",    state: "Florida" },

  # ─── Georgia ─────────────────────────────────────────────────────
  { name: "Stone Mountain",                           lat: 33.8053, lng: -84.1452, kind: "geological",  state: "Georgia" },
  { name: "Martin Luther King Jr. National Historical Park", lat: 33.7565, lng: -84.3719, kind: "historic", state: "Georgia" },
  { name: "Savannah Historic District",               lat: 32.0809, lng: -81.0912, kind: "historic",    state: "Georgia" },
  { name: "Okefenokee Swamp",                         lat: 30.7400, lng: -82.1500, kind: "natural",     state: "Georgia" },

  # ─── Hawaii ──────────────────────────────────────────────────────
  { name: "Diamond Head",                             lat: 21.2620, lng: -157.8053, kind: "geological", state: "Hawaii" },
  { name: "Pearl Harbor National Memorial",           lat: 21.3640, lng: -157.9498, kind: "historic",   state: "Hawaii" },
  { name: "Hawaiʻi Volcanoes National Park",          lat: 19.4194, lng: -155.2885, kind: "geological", state: "Hawaii" },
  { name: "Waimea Canyon",                            lat: 22.0727, lng: -159.6614, kind: "geological", state: "Hawaii" },
  { name: "Nā Pali Coast State Wilderness Park",      lat: 22.1671, lng: -159.6500, kind: "scenic",     state: "Hawaii" },

  # ─── Idaho ───────────────────────────────────────────────────────
  { name: "Craters of the Moon National Monument",    lat: 43.4166, lng: -113.5170, kind: "geological",  state: "Idaho" },
  { name: "Shoshone Falls",                           lat: 42.5946, lng: -114.4014, kind: "natural",     state: "Idaho" },
  { name: "Sawtooth National Recreation Area",        lat: 44.1428, lng: -114.9281, kind: "natural",    state: "Idaho" },
  { name: "Hells Canyon",                             lat: 45.2728, lng: -116.7569, kind: "geological", state: "Idaho" },

  # ─── Illinois ────────────────────────────────────────────────────
  { name: "Willis Tower",                             lat: 41.8789, lng: -87.6359, kind: "engineering", state: "Illinois" },
  { name: "Cloud Gate",                               lat: 41.8827, lng: -87.6233, kind: "cultural",    state: "Illinois" },
  { name: "Lincoln Home National Historic Site",      lat: 39.7975, lng: -89.6469, kind: "historic",    state: "Illinois" },
  { name: "Wrigley Field",                            lat: 41.9484, lng: -87.6553, kind: "historic",    state: "Illinois" },

  # ─── Indiana ─────────────────────────────────────────────────────
  { name: "Indianapolis Motor Speedway",              lat: 39.7950, lng: -86.2347, kind: "cultural",    state: "Indiana" },
  { name: "Indiana Dunes National Park",              lat: 41.6533, lng: -87.0524, kind: "natural",     state: "Indiana" },
  { name: "Conner Prairie",                           lat: 39.9728, lng: -86.0617, kind: "historic",    state: "Indiana" },

  # ─── Iowa ────────────────────────────────────────────────────────
  { name: "Field of Dreams Movie Site",               lat: 42.4990, lng: -91.0658, kind: "cultural",    state: "Iowa" },
  { name: "Effigy Mounds National Monument",          lat: 43.0902, lng: -91.1893, kind: "cultural",    state: "Iowa" },
  { name: "John Wayne Birthplace and Museum",         lat: 41.3408, lng: -94.0144, kind: "historic",    state: "Iowa" },

  # ─── Kansas ──────────────────────────────────────────────────────
  { name: "Tallgrass Prairie National Preserve",      lat: 38.4407, lng: -96.5572, kind: "natural",     state: "Kansas" },
  { name: "Monument Rocks",                           lat: 38.7905, lng: -100.7635, kind: "geological", state: "Kansas" },
  { name: "Dwight D. Eisenhower Presidential Library", lat: 38.9189, lng: -97.2275, kind: "historic",   state: "Kansas" },

  # ─── Kentucky ────────────────────────────────────────────────────
  { name: "Mammoth Cave National Park",               lat: 37.1862, lng: -86.1003, kind: "geological",  state: "Kentucky" },
  { name: "Churchill Downs",                          lat: 38.2042, lng: -85.7691, kind: "cultural",    state: "Kentucky" },
  { name: "Cumberland Falls State Resort Park",       lat: 36.8378, lng: -84.3431, kind: "natural",     state: "Kentucky" },

  # ─── Louisiana ───────────────────────────────────────────────────
  { name: "French Quarter",                           lat: 29.9577, lng: -90.0640, kind: "historic",    state: "Louisiana" },
  { name: "Oak Alley Plantation",                     lat: 30.0061, lng: -90.7770, kind: "historic",    state: "Louisiana" },
  { name: "Atchafalaya Basin",                        lat: 30.4350, lng: -91.5500, kind: "natural",     state: "Louisiana" },

  # ─── Maine ───────────────────────────────────────────────────────
  { name: "Acadia National Park",                     lat: 44.3528, lng: -68.2243, kind: "natural",     state: "Maine" },
  { name: "Portland Head Light",                      lat: 43.6233, lng: -70.2076, kind: "historic",    state: "Maine" },
  { name: "Bar Harbor",                               lat: 44.3876, lng: -68.2039, kind: "cultural",    state: "Maine" },
  { name: "West Quoddy Head Light",                   lat: 44.8156, lng: -66.9505, kind: "historic",    state: "Maine" },

  # ─── Maryland ────────────────────────────────────────────────────
  { name: "Fort McHenry",                             lat: 39.2632, lng: -76.5806, kind: "historic",    state: "Maryland" },
  { name: "Antietam National Battlefield",            lat: 39.4720, lng: -77.7427, kind: "battlefield", state: "Maryland" },
  { name: "Assateague Island National Seashore",      lat: 38.0625, lng: -75.2057, kind: "natural",     state: "Maryland" },
  { name: "Baltimore Inner Harbor",                   lat: 39.2861, lng: -76.6080, kind: "historic",    state: "Maryland" },

  # ─── Massachusetts ───────────────────────────────────────────────
  { name: "Freedom Trail",                            lat: 42.3601, lng: -71.0589, kind: "historic",    state: "Massachusetts" },
  { name: "Cape Cod National Seashore",               lat: 41.8576, lng: -69.9712, kind: "natural",     state: "Massachusetts" },
  { name: "Plymouth Rock",                            lat: 41.9583, lng: -70.6620, kind: "historic",    state: "Massachusetts" },
  { name: "Walden Pond",                              lat: 42.4391, lng: -71.3357, kind: "cultural",    state: "Massachusetts" },
  { name: "Fenway Park",                              lat: 42.3467, lng: -71.0972, kind: "historic",    state: "Massachusetts" },

  # ─── Michigan ────────────────────────────────────────────────────
  { name: "Mackinac Bridge",                          lat: 45.8170, lng: -84.7278, kind: "engineering", state: "Michigan" },
  { name: "Sleeping Bear Dunes National Lakeshore",   lat: 44.8821, lng: -86.0593, kind: "natural",     state: "Michigan" },
  { name: "Pictured Rocks National Lakeshore",        lat: 46.5663, lng: -86.4502, kind: "natural",     state: "Michigan" },
  { name: "The Henry Ford",                           lat: 42.3018, lng: -83.2342, kind: "cultural",    state: "Michigan" },

  # ─── Minnesota ───────────────────────────────────────────────────
  { name: "Voyageurs National Park",                  lat: 48.4839, lng: -92.8389, kind: "natural",     state: "Minnesota" },
  { name: "Mall of America",                          lat: 44.8548, lng: -93.2422, kind: "cultural",    state: "Minnesota" },
  { name: "Split Rock Lighthouse",                    lat: 47.2003, lng: -91.3669, kind: "historic",    state: "Minnesota" },
  { name: "Itasca State Park",                        lat: 47.2197, lng: -95.2069, kind: "natural",     state: "Minnesota" },

  # ─── Mississippi ─────────────────────────────────────────────────
  { name: "Vicksburg National Military Park",         lat: 32.3478, lng: -90.8480, kind: "battlefield", state: "Mississippi" },
  { name: "Natchez Trace Parkway",                    lat: 32.5570, lng: -90.2148, kind: "historic",    state: "Mississippi" },
  { name: "Beauvoir",                                 lat: 30.3849, lng: -88.9436, kind: "historic",    state: "Mississippi" },

  # ─── Missouri ────────────────────────────────────────────────────
  { name: "Gateway Arch",                             lat: 38.6247, lng: -90.1848, kind: "engineering", state: "Missouri" },
  { name: "Mark Twain Boyhood Home & Museum",         lat: 39.7100, lng: -91.3593, kind: "historic",    state: "Missouri" },
  { name: "Branson",                                  lat: 36.6437, lng: -93.2185, kind: "cultural",    state: "Missouri" },

  # ─── Montana ─────────────────────────────────────────────────────
  { name: "Glacier National Park",                    lat: 48.7596, lng: -113.7870, kind: "natural",    state: "Montana" },
  { name: "Going-to-the-Sun Road",                    lat: 48.6967, lng: -113.7180, kind: "scenic",     state: "Montana" },
  { name: "Little Bighorn Battlefield National Monument", lat: 45.5710, lng: -107.4310, kind: "battlefield", state: "Montana" },
  { name: "Beartooth Highway",                        lat: 45.0247, lng: -109.3978, kind: "scenic",     state: "Montana" },

  # ─── Nebraska ────────────────────────────────────────────────────
  { name: "Chimney Rock National Historic Site",      lat: 41.7037, lng: -103.3458, kind: "geological", state: "Nebraska" },
  { name: "Scotts Bluff National Monument",           lat: 41.8312, lng: -103.7113, kind: "geological", state: "Nebraska" },
  { name: "Carhenge",                                 lat: 42.1421, lng: -102.8585, kind: "cultural",   state: "Nebraska" },

  # ─── Nevada ──────────────────────────────────────────────────────
  { name: "Valley of Fire State Park",                lat: 36.4308, lng: -114.5187, kind: "geological",  state: "Nevada" },
  { name: "Red Rock Canyon National Conservation Area", lat: 36.1316, lng: -115.4267, kind: "geological", state: "Nevada" },
  { name: "Hoover Dam",                               lat: 36.0162, lng: -114.7377, kind: "engineering", state: "Nevada" },
  { name: "Lake Tahoe",                               lat: 39.0968, lng: -120.0324, kind: "natural",    state: "Nevada" },
  { name: "Great Basin National Park",                lat: 38.9833, lng: -114.3000, kind: "natural",    state: "Nevada" },

  # ─── New Hampshire ───────────────────────────────────────────────
  { name: "Mount Washington",                         lat: 44.2705, lng: -71.3033, kind: "pass_summit", state: "New Hampshire" },
  { name: "Franconia Notch State Park",               lat: 44.1614, lng: -71.6840, kind: "geological",  state: "New Hampshire" },
  { name: "Lake Winnipesaukee",                       lat: 43.6066, lng: -71.3270, kind: "natural",     state: "New Hampshire" },

  # ─── New Jersey ──────────────────────────────────────────────────
  { name: "Ellis Island",                             lat: 40.6987, lng: -74.0394, kind: "historic",    state: "New Jersey" },
  { name: "Cape May Historic District",               lat: 38.9362, lng: -74.9060, kind: "historic",    state: "New Jersey" },
  { name: "Atlantic City Boardwalk",                  lat: 39.3543, lng: -74.4377, kind: "historic",    state: "New Jersey" },

  # ─── New Mexico ──────────────────────────────────────────────────
  { name: "White Sands National Park",                lat: 32.7872, lng: -106.3257, kind: "natural",     state: "New Mexico" },
  { name: "Carlsbad Caverns National Park",           lat: 32.1234, lng: -104.5876, kind: "geological",  state: "New Mexico" },
  { name: "Taos Pueblo",                              lat: 36.4380, lng: -105.5453, kind: "cultural",    state: "New Mexico" },
  { name: "Bandelier National Monument",              lat: 35.7780, lng: -106.2706, kind: "cultural",   state: "New Mexico" },
  { name: "Chaco Culture National Historical Park",   lat: 36.0339, lng: -107.9573, kind: "cultural",   state: "New Mexico" },

  # ─── New York ────────────────────────────────────────────────────
  { name: "Statue of Liberty",                        lat: 40.6892, lng: -74.0445, kind: "historic",    state: "New York" },
  { name: "Niagara Falls",                            lat: 43.0843, lng: -79.0683, kind: "natural",     state: "New York" },
  { name: "Central Park",                             lat: 40.7829, lng: -73.9654, kind: "cultural",    state: "New York" },
  { name: "Empire State Building",                    lat: 40.7484, lng: -73.9857, kind: "engineering", state: "New York" },
  { name: "Mount Marcy",                              lat: 44.1129, lng: -73.9230, kind: "pass_summit", state: "New York" },
  { name: "Brooklyn Bridge",                          lat: 40.7061, lng: -73.9969, kind: "engineering", state: "New York" },

  # ─── North Carolina ──────────────────────────────────────────────
  { name: "Blue Ridge Parkway",                       lat: 36.0775, lng: -81.8267, kind: "scenic",      state: "North Carolina" },
  { name: "Great Smoky Mountains National Park",      lat: 35.5628, lng: -83.4983, kind: "natural",     state: "North Carolina" },
  { name: "Wright Brothers National Memorial",        lat: 36.0146, lng: -75.6724, kind: "historic",    state: "North Carolina" },
  { name: "Biltmore Estate",                          lat: 35.5407, lng: -82.5524, kind: "historic",    state: "North Carolina" },
  { name: "Cape Hatteras Lighthouse",                 lat: 35.2503, lng: -75.5288, kind: "historic",    state: "North Carolina" },

  # ─── North Dakota ────────────────────────────────────────────────
  { name: "Theodore Roosevelt National Park",         lat: 46.9790, lng: -103.5388, kind: "natural",    state: "North Dakota" },
  { name: "Knife River Indian Villages National Historic Site", lat: 47.3414, lng: -101.3839, kind: "cultural", state: "North Dakota" },
  { name: "International Peace Garden",               lat: 49.0009, lng: -100.0540, kind: "cultural",   state: "North Dakota" },

  # ─── Ohio ────────────────────────────────────────────────────────
  { name: "Rock and Roll Hall of Fame",               lat: 41.5085, lng: -81.6953, kind: "cultural",    state: "Ohio" },
  { name: "Hocking Hills State Park",                 lat: 39.4319, lng: -82.5371, kind: "natural",     state: "Ohio" },
  { name: "Cuyahoga Valley National Park",            lat: 41.2808, lng: -81.5678, kind: "natural",     state: "Ohio" },
  { name: "Pro Football Hall of Fame",                lat: 40.8210, lng: -81.3759, kind: "cultural",    state: "Ohio" },

  # ─── Oklahoma ────────────────────────────────────────────────────
  { name: "Oklahoma City National Memorial",          lat: 35.4729, lng: -97.5170, kind: "historic",    state: "Oklahoma" },
  { name: "Wichita Mountains Wildlife Refuge",        lat: 34.7375, lng: -98.7142, kind: "natural",     state: "Oklahoma" },
  { name: "Tallgrass Prairie Preserve",               lat: 36.8377, lng: -96.4226, kind: "natural",     state: "Oklahoma" },

  # ─── Oregon ──────────────────────────────────────────────────────
  { name: "Crater Lake National Park",                lat: 42.9446, lng: -122.1090, kind: "geological", state: "Oregon" },
  { name: "Multnomah Falls",                          lat: 45.5762, lng: -122.1158, kind: "natural",    state: "Oregon" },
  { name: "Mount Hood",                               lat: 45.3735, lng: -121.6960, kind: "natural",    state: "Oregon" },
  { name: "Cannon Beach",                             lat: 45.8829, lng: -123.9685, kind: "scenic",     state: "Oregon" },
  { name: "John Day Fossil Beds National Monument",   lat: 44.6531, lng: -120.2625, kind: "geological", state: "Oregon" },

  # ─── Pennsylvania ────────────────────────────────────────────────
  { name: "Independence Hall",                        lat: 39.9489, lng: -75.1500, kind: "historic",    state: "Pennsylvania" },
  { name: "Gettysburg National Military Park",        lat: 39.8118, lng: -77.2253, kind: "battlefield", state: "Pennsylvania" },
  { name: "Fallingwater",                             lat: 39.9061, lng: -79.4684, kind: "cultural",    state: "Pennsylvania" },
  { name: "Liberty Bell",                             lat: 39.9496, lng: -75.1503, kind: "historic",    state: "Pennsylvania" },

  # ─── Rhode Island ────────────────────────────────────────────────
  { name: "The Breakers",                             lat: 41.4690, lng: -71.2980, kind: "historic",    state: "Rhode Island" },
  { name: "Cliff Walk",                               lat: 41.4818, lng: -71.2920, kind: "scenic",      state: "Rhode Island" },
  { name: "WaterFire Providence",                     lat: 41.8240, lng: -71.4128, kind: "cultural",    state: "Rhode Island" },

  # ─── South Carolina ──────────────────────────────────────────────
  { name: "Charleston Historic District",             lat: 32.7710, lng: -79.9305, kind: "historic",    state: "South Carolina" },
  { name: "Fort Sumter National Monument",            lat: 32.7522, lng: -79.8748, kind: "battlefield", state: "South Carolina" },
  { name: "Magnolia Plantation and Gardens",          lat: 32.8783, lng: -80.0820, kind: "historic",    state: "South Carolina" },
  { name: "Hilton Head Island",                       lat: 32.1896, lng: -80.7499, kind: "natural",     state: "South Carolina" },

  # ─── South Dakota ────────────────────────────────────────────────
  { name: "Mount Rushmore National Memorial",         lat: 43.8791, lng: -103.4591, kind: "cultural",   state: "South Dakota" },
  { name: "Badlands National Park",                   lat: 43.8554, lng: -101.9777, kind: "geological", state: "South Dakota" },
  { name: "Custer State Park",                        lat: 43.7596, lng: -103.4127, kind: "natural",    state: "South Dakota" },
  { name: "Crazy Horse Memorial",                     lat: 43.8364, lng: -103.6243, kind: "cultural",   state: "South Dakota" },
  { name: "Wind Cave National Park",                  lat: 43.5567, lng: -103.4791, kind: "geological", state: "South Dakota" },

  # ─── Tennessee ───────────────────────────────────────────────────
  { name: "Cades Cove",                               lat: 35.6116, lng: -83.7820, kind: "natural",     state: "Tennessee" },
  { name: "Graceland",                                lat: 35.0466, lng: -90.0227, kind: "cultural",    state: "Tennessee" },
  { name: "Grand Ole Opry",                           lat: 36.2068, lng: -86.6921, kind: "cultural",    state: "Tennessee" },
  { name: "Lookout Mountain",                         lat: 35.0035, lng: -85.3441, kind: "scenic",      state: "Tennessee" },

  # ─── Texas ───────────────────────────────────────────────────────
  { name: "The Alamo",                                lat: 29.4260, lng: -98.4861, kind: "historic",    state: "Texas" },
  { name: "Big Bend National Park",                   lat: 29.1275, lng: -103.2425, kind: "natural",    state: "Texas" },
  { name: "Space Center Houston",                     lat: 29.5519, lng: -95.0975, kind: "cultural",    state: "Texas" },
  { name: "Palo Duro Canyon State Park",              lat: 34.9824, lng: -101.6595, kind: "geological", state: "Texas" },
  { name: "Hamilton Pool Preserve",                   lat: 30.3429, lng: -98.1248, kind: "natural",     state: "Texas" },
  { name: "Cadillac Ranch",                           lat: 35.1872, lng: -101.9870, kind: "cultural",   state: "Texas" },

  # ─── Utah · The Mighty 5 + iconic spots ──────────────────────────
  { name: "Zion National Park",                       lat: 37.2982, lng: -113.0263, kind: "natural",     state: "Utah" },
  { name: "Bryce Canyon National Park",               lat: 37.5930, lng: -112.1871, kind: "geological",  state: "Utah" },
  { name: "Arches National Park",                     lat: 38.7331, lng: -109.5925, kind: "geological",  state: "Utah" },
  { name: "Canyonlands National Park",                lat: 38.3269, lng: -109.8783, kind: "geological",  state: "Utah" },
  { name: "Capitol Reef National Park",               lat: 38.3669, lng: -111.2615, kind: "geological",  state: "Utah" },
  { name: "Delicate Arch",                            lat: 38.7436, lng: -109.4993, kind: "geological",  state: "Utah" },
  { name: "Mesa Arch",                                lat: 38.3884, lng: -109.8687, kind: "scenic",      state: "Utah" },
  { name: "Goblin Valley State Park",                 lat: 38.5728, lng: -110.7113, kind: "geological",  state: "Utah" },
  { name: "Dead Horse Point State Park",              lat: 38.4783, lng: -109.7414, kind: "scenic",      state: "Utah" },
  { name: "Bonneville Salt Flats",                    lat: 40.7593, lng: -113.8869, kind: "natural",     state: "Utah" },
  { name: "Spiral Jetty",                             lat: 41.4376, lng: -112.6688, kind: "cultural",    state: "Utah" },
  { name: "Salt Lake Temple",                         lat: 40.7707, lng: -111.8911, kind: "historic",    state: "Utah" },
  { name: "Park City Main Street Historic District",  lat: 40.6461, lng: -111.4988, kind: "historic",    state: "Utah" },
  { name: "Natural Bridges National Monument",        lat: 37.6105, lng: -110.0078, kind: "geological",  state: "Utah" },
  { name: "Cedar Breaks National Monument",           lat: 37.6383, lng: -112.8447, kind: "geological",  state: "Utah" },

  # ─── Vermont ─────────────────────────────────────────────────────
  { name: "Stowe Mountain Resort",                    lat: 44.5305, lng: -72.7814, kind: "natural",     state: "Vermont" },
  { name: "Quechee Gorge",                            lat: 43.6403, lng: -72.4112, kind: "geological",  state: "Vermont" },
  { name: "Ben & Jerry's Factory",                    lat: 44.3536, lng: -72.7479, kind: "cultural",    state: "Vermont" },

  # ─── Virginia ────────────────────────────────────────────────────
  { name: "Shenandoah National Park",                 lat: 38.5300, lng: -78.3500, kind: "natural",     state: "Virginia" },
  { name: "Colonial Williamsburg",                    lat: 37.2707, lng: -76.7075, kind: "historic",    state: "Virginia" },
  { name: "Monticello",                               lat: 38.0093, lng: -78.4538, kind: "historic",    state: "Virginia" },
  { name: "Arlington National Cemetery",              lat: 38.8783, lng: -77.0687, kind: "historic",    state: "Virginia" },
  { name: "Natural Bridge of Virginia",               lat: 37.6304, lng: -79.5436, kind: "geological",  state: "Virginia" },

  # ─── Washington ──────────────────────────────────────────────────
  { name: "Mount Rainier",                            lat: 46.8523, lng: -121.7603, kind: "natural",    state: "Washington" },
  { name: "Olympic National Park",                    lat: 47.8606, lng: -123.9351, kind: "natural",    state: "Washington" },
  { name: "Pike Place Market",                        lat: 47.6097, lng: -122.3422, kind: "cultural",   state: "Washington" },
  { name: "Space Needle",                             lat: 47.6205, lng: -122.3493, kind: "engineering", state: "Washington" },
  { name: "North Cascades National Park",             lat: 48.7718, lng: -121.2985, kind: "natural",    state: "Washington" },

  # ─── Washington, D.C. (federal district, listed with neighbors) ──
  { name: "Lincoln Memorial",                         lat: 38.8893, lng: -77.0502, kind: "historic",    state: "Washington, D.C." },
  { name: "Washington Monument",                      lat: 38.8895, lng: -77.0353, kind: "historic",    state: "Washington, D.C." },
  { name: "United States Capitol",                    lat: 38.8899, lng: -77.0091, kind: "historic",    state: "Washington, D.C." },

  # ─── West Virginia ───────────────────────────────────────────────
  { name: "New River Gorge National Park and Preserve", lat: 38.0668, lng: -81.0660, kind: "geological", state: "West Virginia" },
  { name: "Harpers Ferry National Historical Park",   lat: 39.3243, lng: -77.7397, kind: "historic",    state: "West Virginia" },
  { name: "Seneca Rocks",                             lat: 38.8336, lng: -79.3717, kind: "geological",  state: "West Virginia" },
  { name: "Blackwater Falls State Park",              lat: 39.1131, lng: -79.4861, kind: "natural",     state: "West Virginia" },

  # ─── Wisconsin ───────────────────────────────────────────────────
  { name: "Wisconsin Dells",                          lat: 43.6275, lng: -89.7710, kind: "geological",  state: "Wisconsin" },
  { name: "Apostle Islands National Lakeshore",       lat: 46.9628, lng: -90.6589, kind: "natural",     state: "Wisconsin" },
  { name: "House on the Rock",                        lat: 43.0986, lng: -90.1361, kind: "cultural",    state: "Wisconsin" },
  { name: "Door County",                              lat: 44.9266, lng: -87.1697, kind: "natural",     state: "Wisconsin" },

  # ─── Wyoming · Yellowstone, Tetons, Devils Tower ─────────────────
  { name: "Old Faithful Geyser",                      lat: 44.4605, lng: -110.8281, kind: "geological",  state: "Wyoming" },
  { name: "Grand Prismatic Spring",                   lat: 44.5251, lng: -110.8383, kind: "geological",  state: "Wyoming" },
  { name: "Grand Teton",                              lat: 43.7412, lng: -110.8024, kind: "natural",     state: "Wyoming" },
  { name: "Devils Tower National Monument",           lat: 44.5902, lng: -104.7148, kind: "geological",  state: "Wyoming" },
  { name: "Jackson Hole Town Square",                 lat: 43.4799, lng: -110.7624, kind: "historic",    state: "Wyoming" },
  { name: "Hot Springs State Park",                   lat: 43.6541, lng: -108.2095, kind: "geological",  state: "Wyoming" },
  { name: "Buffalo Bill Center of the West",          lat: 44.5266, lng: -109.0707, kind: "historic",    state: "Wyoming" },
  # Yellowstone interior — beyond Old Faithful & Grand Prismatic.
  { name: "Mammoth Hot Springs",                      lat: 44.9778, lng: -110.6995, kind: "geological",  state: "Wyoming" },
  { name: "Yellowstone Lake",                         lat: 44.4280, lng: -110.3640, kind: "natural",     state: "Wyoming" },
  { name: "Grand Canyon of the Yellowstone",          lat: 44.7203, lng: -110.4965, kind: "geological",  state: "Wyoming" },
  { name: "Norris Geyser Basin",                      lat: 44.7264, lng: -110.7034, kind: "geological",  state: "Wyoming" },
  { name: "Lamar Valley",                             lat: 44.9133, lng: -110.2333, kind: "natural",     state: "Wyoming" },
  # Tetons / Jackson — fill in the iconic side-trip stops.
  { name: "Jenny Lake",                               lat: 43.7681, lng: -110.7193, kind: "natural",     state: "Wyoming" },
  { name: "Mormon Row Historic District",             lat: 43.6736, lng: -110.6661, kind: "historic",    state: "Wyoming" },
  { name: "Snake River Overlook",                     lat: 43.6494, lng: -110.5878, kind: "scenic",      state: "Wyoming" },
  # Trails West / Oregon-trail Wyoming — overlooked but historically huge.
  { name: "Fossil Butte National Monument",           lat: 41.8639, lng: -110.7691, kind: "geological",  state: "Wyoming" },
  { name: "Medicine Wheel National Historic Landmark", lat: 44.8262, lng: -107.9217, kind: "tribal",     state: "Wyoming" },
  { name: "Independence Rock State Historic Site",    lat: 42.4942, lng: -107.1297, kind: "historic",    state: "Wyoming" },
  { name: "Fort Laramie National Historic Site",      lat: 42.2056, lng: -104.5575, kind: "historic",    state: "Wyoming" },
  { name: "Sinks Canyon State Park",                  lat: 42.7475, lng: -108.8136, kind: "geological",  state: "Wyoming" }
].freeze

def wikipedia_summary(title)
  encoded = URI.encode_www_form_component(title.to_s.tr(" ", "_"))
  uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
  req = Net::HTTP::Get.new(uri)
  req["User-Agent"] = USER_AGENT
  req["Accept"] = "application/json"
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) { |h| h.request(req) }
  return nil unless res.is_a?(Net::HTTPSuccess)
  json = JSON.parse(res.body)
  return nil if json["type"] == "disambiguation"
  json
rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError
  nil
end

def opensearch_resolve(query)
  uri = URI("https://en.wikipedia.org/w/api.php")
  uri.query = URI.encode_www_form(action: "opensearch", search: query, limit: 1, namespace: 0, format: "json")
  req = Net::HTTP::Get.new(uri)
  req["User-Agent"] = USER_AGENT
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) { |h| h.request(req) }
  return nil unless res.is_a?(Net::HTTPSuccess)
  title = JSON.parse(res.body)[1]&.first
  return nil if title.blank? || title.casecmp?(query.to_s)
  wikipedia_summary(title)
rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError
  nil
end

def wiki_for(name)
  data = wikipedia_summary(name) || opensearch_resolve(name)
  return [ nil, nil ] unless data.is_a?(Hash)
  [
    best_image_url(data),
    data.dig("content_urls", "desktop", "page")
  ]
end

# Wikipedia's REST summary returns a 330px thumbnail and the full original.
# 330px looks pixelated when used as a hero image; full original can be 5MB+.
# Sweet spot: rewrite the thumbnail URL to request 1280px — Wikimedia renders
# any size on the fly and serves them off the same CDN.
HERO_IMAGE_WIDTH = 1280

def best_image_url(data)
  thumb = data.dig("thumbnail", "source")
  orig  = data.dig("originalimage", "source")

  upgraded = upgrade_wikipedia_thumb(thumb, HERO_IMAGE_WIDTH)
  return upgraded if upgraded

  # No /thumb/ URL to rewrite — use the original if reasonable, else the small thumb.
  orig_w = data.dig("originalimage", "width").to_i
  return orig if orig && orig_w.positive? && orig_w <= 2500
  thumb || orig
end

def upgrade_wikipedia_thumb(url, width)
  return nil if url.blank?
  return nil unless url.include?("/thumb/") && url =~ %r{/\d+px-[^/]+\.\w+\z}
  url.sub(%r{/\d+px-([^/]+)\z}, "/#{width}px-\\1")
end

def narrate(name, state, kind)
  result = Ai::Caller.call(
    slug: "landmark_narration.v1",
    variables: { name: name, location: state, kind: kind }
  )
  parsed = result.json
  text = parsed.is_a?(Hash) ? parsed["narration"].to_s.strip : result.text.to_s.strip
  text.presence
end

puts "Seeding #{LANDMARKS.size} global landmarks…"
created = updated = skipped = 0

LANDMARKS.each_with_index do |row, i|
  existing = RouteLandmark.where(trip_id: nil).find_by("LOWER(name) = ?", row[:name].downcase)

  if existing && !REFRESH
    skipped += 1
    puts "  [#{i + 1}/#{LANDMARKS.size}] skip   #{row[:name]} (exists)"
    next
  end

  narration = narrate(row[:name], row[:state], row[:kind])
  if narration.blank?
    warn "  [#{i + 1}/#{LANDMARKS.size}] fail   #{row[:name]} — no narration from AI"
    next
  end

  image_url, wiki_url = wiki_for(row[:name])

  attrs = {
    name: row[:name],
    kind: row[:kind],
    latitude: row[:lat],
    longitude: row[:lng],
    narration: narration,
    image_url: image_url,
    wikipedia_url: wiki_url,
    source: "seed",
    position: i
  }

  if existing
    existing.update!(attrs)
    updated += 1
    puts "  [#{i + 1}/#{LANDMARKS.size}] update #{row[:name]} (#{row[:state]})"
  else
    RouteLandmark.create!(attrs.merge(trip_id: nil))
    created += 1
    puts "  [#{i + 1}/#{LANDMARKS.size}] new    #{row[:name]} (#{row[:state]})"
  end
end

puts ""
puts "Done. created=#{created} updated=#{updated} skipped=#{skipped}"
