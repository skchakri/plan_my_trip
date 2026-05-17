# Re-resolves the 20 global landmarks whose Wikipedia summary endpoint
# returned nothing on the first seed pass. Almost all are name-disambiguation
# issues — "Diamond Head" matches a disambiguation page, but "Diamond Head,
# Hawaii" goes straight to the article we want.
#
# Run with:
#   bin/rails runner db/fix_landmark_image_misses.rb

require "net/http"
require "uri"
require "json"

USER_AGENT = "PlanMyTrip/1.0 (https://planmytrip.app; mailto:hello@planmytrip.app)".freeze
HERO_IMAGE_WIDTH = 1280

# name -> [ wikipedia title candidates to try, in order ]
ALIASES = {
  "Horseshoe Bend"                            => [ "Horseshoe Bend (Arizona)" ],
  "Cathedral Rock, Sedona"                    => [ "Cathedral Rock (Arizona)" ],
  "Mesa Verde — Cliff Palace"                 => [ "Cliff Palace", "Mesa Verde National Park" ],
  "Jackson Hole Town Square"                  => [ "Jackson, Wyoming", "Jackson Hole" ],
  "Field of Dreams Movie Site"                => [ "Field of Dreams", "Dyersville, Iowa" ],
  "Rehoboth Beach Boardwalk"                  => [ "Rehoboth Beach, Delaware" ],
  "St. Augustine Historic District"           => [ "St. Augustine, Florida" ],
  "Savannah Historic District"                => [ "Savannah Historic District (Georgia)", "Savannah, Georgia" ],
  "Diamond Head"                              => [ "Diamond Head, Hawaii" ],
  "Nā Pali Coast State Wilderness Park"       => [ "Nā Pali Coast State Park", "Na Pali Coast State Park" ],
  "John Wayne Birthplace and Museum"          => [ "John Wayne Birthplace Museum", "Winterset, Iowa" ],
  "Monument Rocks"                            => [ "Monument Rocks (Kansas)" ],
  "Beauvoir"                                  => [ "Beauvoir (Biloxi, Mississippi)" ],
  "Branson"                                   => [ "Branson, Missouri" ],
  "Glacier National Park"                     => [ "Glacier National Park (U.S.)" ],
  "Cliff Walk"                                => [ "Cliff Walk (Newport)" ],
  "Magnolia Plantation and Gardens"           => [ "Magnolia Plantation and Gardens (South Carolina)" ],
  "Ben & Jerry's Factory"                     => [ "Ben & Jerry's", "Waterbury, Vermont" ],
  "Wisconsin Dells"                           => [ "Wisconsin Dells, Wisconsin" ],
  "Natural Bridge of Virginia"                => [ "Natural Bridge (Virginia)" ]
}.freeze

def upgrade_thumb(url, width)
  return nil if url.blank?
  return nil unless url.include?("/thumb/") && url =~ %r{/\d+px-[^/]+\.\w+\z}
  url.sub(%r{/\d+px-([^/]+)\z}, "/#{width}px-\\1")
end

def wiki_summary(title)
  encoded = URI.encode_www_form_component(title.to_s.tr(" ", "_"))
  uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
  req = Net::HTTP::Get.new(uri); req["User-Agent"] = USER_AGENT; req["Accept"] = "application/json"
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) { |h| h.request(req) }
  return nil unless res.is_a?(Net::HTTPSuccess)
  json = JSON.parse(res.body)
  return nil if json["type"] == "disambiguation"
  json
rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError
  nil
end

def best_url(data)
  thumb = data.dig("thumbnail", "source")
  orig  = data.dig("originalimage", "source")
  upgraded = upgrade_thumb(thumb, HERO_IMAGE_WIDTH)
  upgraded || orig || thumb
end

filled = still_missing = 0

ALIASES.each do |name, candidates|
  row = RouteLandmark.global.kept.find_by("LOWER(name) = ?", name.downcase)
  unless row
    puts "  no-row #{name}"
    next
  end
  if row.image_url.present?
    puts "  ok     #{name} (already has image)"
    next
  end

  resolved = candidates.lazy.filter_map { |c| wiki_summary(c) }.first
  if resolved
    img = best_url(resolved)
    wiki = resolved.dig("content_urls", "desktop", "page")
    row.update!(image_url: img, wikipedia_url: row.wikipedia_url.presence || wiki)
    filled += 1
    puts "  fill   #{name.ljust(45)} → #{candidates.first}"
  else
    still_missing += 1
    puts "  miss   #{name}"
  end
end

puts ""
puts "Done. filled=#{filled} still_missing=#{still_missing}"
total = RouteLandmark.global.kept.count
with_img = RouteLandmark.global.kept.where.not(image_url: nil).count
puts "Image coverage now: #{with_img}/#{total} (#{(100.0 * with_img / total).round(1)}%)"
