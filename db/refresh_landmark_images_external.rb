# Refreshes RouteLandmark images using external photo APIs (Pexels →
# Unsplash → Pixabay). Falls back to keeping the existing Wikipedia image
# when no provider returns a hit.
#
# We map each landmark back to its state via the curated LANDMARKS array
# in db/seed_landmarks.rb so the search query can be disambiguated
# ("Diamond Head" + "Hawaii" beats just "Diamond Head").
#
# Run modes:
#   bin/rails runner db/refresh_landmark_images_external.rb         # only landmarks currently using wikipedia
#   FORCE=1 bin/rails runner db/refresh_landmark_images_external.rb # refresh every global landmark
#   ONLY=pexels bin/rails runner db/refresh_landmark_images_external.rb
#
# Image attribution and the new source are recorded; the old Wikipedia
# URL stays on the row in `wikipedia_url` so the article link is preserved.

begin
  require "dotenv"
  Dotenv.load(Rails.root.join(".env").to_s)
rescue LoadError
  # dotenv not installed — caller must export vars manually.
end

require_relative "../app/services/landmark_image_finder.rb" unless defined?(LandmarkImageFinder)

# Pull the curated list out of the seed file so we get state info per name
# without re-typing it. The seed file defines LANDMARKS as a top-level
# constant after `module/class` — load it for the side effect.
load Rails.root.join("db/seed_landmarks.rb").to_s if !defined?(LANDMARKS) || LANDMARKS.empty?

FORCE = ENV["FORCE"] == "1"
ONLY = ENV["ONLY"].to_s.split(",").map { |s| s.strip.to_sym }.then { |a| a.empty? ? LandmarkImageFinder::PROVIDERS : a }

# Build a name → state map so the photo-API queries are disambiguated.
STATE_FOR = LANDMARKS.each_with_object({}) { |row, h| h[row[:name].downcase] = row[:state] }.freeze

# Sanity check: at least one provider key must be present, else there's
# nothing to do.
configured = {
  pexels:   ENV["PEXELS_API_KEY"].present?,
  unsplash: ENV["UNSPLASH_ACCESS_KEY"].present?,
  pixabay:  ENV["PIXABAY_API_KEY"].present?
}
unless configured.values.any?
  abort "No API keys set — export at least one of PEXELS_API_KEY / UNSPLASH_ACCESS_KEY / PIXABAY_API_KEY."
end
puts "Configured providers: #{configured.select { |_, v| v }.keys.inspect}"
puts "Trying in order:       #{ONLY.inspect}"
puts ""

# Subset: landmarks whose current image_url points at wikimedia, unless
# FORCE=1.
scope = RouteLandmark.global.kept
scope = scope.where("image_url IS NULL OR image_url LIKE ?", "%upload.wikimedia.org%") unless FORCE
rows = scope.order(:name)

puts "Refreshing #{rows.count} landmark images via external APIs…"
puts ""

stats = Hash.new(0)

rows.find_each.with_index do |row, i|
  state = STATE_FOR[row.name.downcase]
  result = LandmarkImageFinder.call(row.name, state: state, providers: ONLY)

  if result.nil?
    stats[:no_match] += 1
    puts "  [#{i + 1}] miss  #{row.name}" if (i + 1) % 10 == 0 || i < 5
    next
  end

  row.update!(
    image_url: result[:url],
    # Preserve the Wikipedia article link if we already had it.
    wikipedia_url: row.wikipedia_url
  )
  stats[result[:source].to_sym] += 1
  puts "  [#{i + 1}] #{result[:source].ljust(8)} #{row.name}"
end

puts ""
puts "Done. " + stats.map { |k, v| "#{k}=#{v}" }.join(" ")

g = RouteLandmark.global.kept
puts ""
puts "Now by image source:"
puts "  pexels:    #{g.where("image_url LIKE ?", "%images.pexels.com%").count}"
puts "  unsplash:  #{g.where("image_url LIKE ?", "%images.unsplash.com%").count}"
puts "  pixabay:   #{g.where("image_url LIKE ?", "%pixabay.com%").count}"
puts "  wikipedia: #{g.where("image_url LIKE ?", "%wikimedia.org%").count}"
puts "  no image:  #{g.where(image_url: nil).count}"
