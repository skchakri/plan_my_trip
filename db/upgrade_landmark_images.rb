# Upgrades existing global RouteLandmark image_urls from Wikipedia's default
# 330px thumbnails to 1280px renders. Pure URL rewrite — no API calls, no
# AI usage. Also re-fetches images for the ~19 landmarks that originally
# came back without one.
#
# Run with:
#   bin/rails runner db/upgrade_landmark_images.rb
#   REFRESH_ALL=1 bin/rails runner db/upgrade_landmark_images.rb
#     (also re-queries Wikipedia for the ones already at 1280+)

require "net/http"
require "uri"
require "json"

USER_AGENT = "PlanMyTrip/1.0 (https://planmytrip.app; mailto:hello@planmytrip.app)".freeze
HERO_IMAGE_WIDTH = 1280
REFRESH_ALL = ENV["REFRESH_ALL"] == "1"

def upgrade_thumb(url, width)
  return nil if url.blank?
  return nil unless url.include?("/thumb/") && url =~ %r{/\d+px-[^/]+\.\w+\z}
  url.sub(%r{/\d+px-([^/]+)\z}, "/#{width}px-\\1")
end

def current_size(url)
  url[/\/(\d+)px-/, 1]&.to_i
end

def wiki_summary(title)
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

def opensearch_title(query)
  uri = URI("https://en.wikipedia.org/w/api.php")
  uri.query = URI.encode_www_form(action: "opensearch", search: query, limit: 1, namespace: 0, format: "json")
  req = Net::HTTP::Get.new(uri); req["User-Agent"] = USER_AGENT
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) { |h| h.request(req) }
  return nil unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)[1]&.first
rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError
  nil
end

# Wikipedia pageimages API — returns the article's lead image at the requested
# size in one round trip. Use this for landmarks whose summary endpoint
# returned no thumbnail at all (typically because the article lives at a
# disambiguated title like "Diamond Head, Hawaii").
def pageimages_lead(title, width)
  encoded = URI.encode_www_form_component(title)
  uri = URI("https://en.wikipedia.org/w/api.php?action=query&prop=pageimages|info&pithumbsize=#{width}&inprop=url&titles=#{encoded}&format=json&redirects=1")
  req = Net::HTTP::Get.new(uri); req["User-Agent"] = USER_AGENT
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) { |h| h.request(req) }
  return [ nil, nil ] unless res.is_a?(Net::HTTPSuccess)
  pages = JSON.parse(res.body).dig("query", "pages") || {}
  page = pages.values.first
  return [ nil, nil ] unless page
  [ page.dig("thumbnail", "source"), page["fullurl"] ]
rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError
  [ nil, nil ]
end

def resolve_fresh(name)
  data = wiki_summary(name)
  if data.nil?
    title = opensearch_title(name)
    data = wiki_summary(title) if title && !title.casecmp?(name)
  end
  if data
    thumb = data.dig("thumbnail", "source")
    upgraded = upgrade_thumb(thumb, HERO_IMAGE_WIDTH)
    page_url = data.dig("content_urls", "desktop", "page")
    return [ upgraded || data.dig("originalimage", "source") || thumb, page_url ]
  end

  # Summary endpoint had nothing — try the pageimages query API directly with
  # name variants like "Diamond Head, Hawaii".
  pageimages_lead(name, HERO_IMAGE_WIDTH)
end

rows = RouteLandmark.global.kept.order(:name)
puts "Scanning #{rows.count} global landmarks…"

upgraded = filled = unchanged = failed = 0

rows.find_each do |row|
  if row.image_url.blank?
    img, wiki = resolve_fresh(row.name)
    if img.present?
      row.update!(image_url: img, wikipedia_url: row.wikipedia_url.presence || wiki)
      filled += 1
      puts "  fill   #{row.name.ljust(50)} #{current_size(img) || '?'}px"
    else
      failed += 1
      puts "  miss   #{row.name}"
    end
    next
  end

  cur = current_size(row.image_url)
  if cur && cur >= HERO_IMAGE_WIDTH && !REFRESH_ALL
    unchanged += 1
    next
  end

  new_url = upgrade_thumb(row.image_url, HERO_IMAGE_WIDTH)
  if new_url && new_url != row.image_url
    row.update!(image_url: new_url)
    upgraded += 1
    puts "  upgrade #{row.name.ljust(49)} #{cur}px → #{HERO_IMAGE_WIDTH}px"
  elsif REFRESH_ALL
    img, _ = resolve_fresh(row.name)
    if img.present? && img != row.image_url
      row.update!(image_url: img)
      upgraded += 1
      puts "  refresh #{row.name.ljust(49)} new URL"
    else
      unchanged += 1
    end
  else
    unchanged += 1
  end
end

puts ""
puts "Done. upgraded=#{upgraded} filled=#{filled} unchanged=#{unchanged} failed=#{failed}"
puts "All global landmarks: #{RouteLandmark.global.kept.count}"
puts "With images:          #{RouteLandmark.global.kept.where.not(image_url: nil).count}"
