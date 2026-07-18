class TripTemplate
  # Curated starter trips offered to new users on /trips when they have zero
  # trips of their own. Stored as plain Ruby (no DB) — these are content,
  # not user data, and live in the codebase so PRs review them.
  # Hero images go through the same-origin /place_image resolver (stock-photo
  # lookup + cache) — hotlinked Wikimedia thumbs proved to be link-rot magnets.
  TEMPLATES = {
    "utah-parks" => {
      title:        "Utah Mighty 5 — A 7-Night Road Trip",
      destination:  "Utah, USA",
      origin:       "Las Vegas, NV",
      body:         "## Day 1 — Vegas to Zion\n## Day 2 — Zion canyons\n## Day 3 — Bryce sunrise\n## Day 4 — Scenic Byway 12 to Capitol Reef\n## Day 5 — Hanksville to Moab\n## Day 6 — Arches\n## Day 7 — Canyonlands & home",
      tagline:      "Five national parks, one unforgettable loop. Sandstone, slot canyons, dark skies.",
      duration_days: 8,
      hero_image_url: "/place_image?q=Bryce+Canyon+National+Park",
      vibe: %w[nature scenic adventure]
    },
    "pnw-loop" => {
      title:        "Pacific Northwest — Mountains, Coast & Coffee",
      destination:  "Washington & Oregon, USA",
      origin:       "Seattle, WA",
      body:         "## Day 1 — Seattle\n## Day 2 — Olympic peninsula\n## Day 3 — Hood Canal & ferry to Bainbridge\n## Day 4 — Mount Rainier\n## Day 5 — Columbia River Gorge\n## Day 6 — Cannon Beach\n## Day 7 — Portland\n## Day 8 — Home",
      tagline:      "Old-growth forests, basalt waterfalls, and a coffee on every corner.",
      duration_days: 8,
      hero_image_url: "/place_image?q=Mount+Rainier+National+Park",
      vibe: %w[nature scenic relaxing]
    },
    "beach-weekend" => {
      title:        "Beach Weekend — A 3-Day Reset",
      destination:  "Outer Banks, NC",
      origin:       "Raleigh, NC",
      body:         "## Friday — Drive + check in\n## Saturday — Sunrise walk, Bodie Lighthouse, oysters\n## Sunday — Pancakes, packing, drive home",
      tagline:      "Short drive, big air. A three-day reset on the Atlantic.",
      duration_days: 3,
      hero_image_url: "/place_image?q=Bodie+Island+Lighthouse+Outer+Banks",
      vibe: %w[relaxing family]
    }
  }.freeze

  attr_reader :key, :data

  def initialize(key)
    @key = key.to_s
    @data = TEMPLATES.fetch(@key) { raise ActiveRecord::RecordNotFound, "Unknown template: #{key}" }
  end

  def self.all
    TEMPLATES.map { |k, _| new(k) }
  end

  def title         = data[:title]
  def destination   = data[:destination]
  def origin        = data[:origin]
  def tagline       = data[:tagline]
  def duration_days = data[:duration_days]
  def hero_image_url = data[:hero_image_url]
  def vibe          = data[:vibe]

  # Materialise the template into a real Trip owned by `user`, starting
  # `start_date` days from now. The trip lives in the user's account
  # from here forward — fully editable, indistinguishable from a
  # hand-built trip.
  def build_for(user, start_date: nil)
    start = (start_date || Date.current + 14).to_date
    trip = user.owned_trips.create!(
      title:       data[:title],
      destination: data[:destination],
      origin:      data[:origin],
      body:        data[:body],
      start_date:  start,
      end_date:    start + duration_days - 1
    )
    seed_trip_days(trip, start)
    trip
  end

  private

  def seed_trip_days(trip, start)
    accent_palette = %w[blue gold teal pink violet emerald rose]
    headings = day_headings
    duration_days.times do |i|
      trip.trip_days.create!(
        label:    "day-#{i + 1}",
        # Carry the template's own day headings (e.g. "Vegas to Zion") onto the
        # day cards. Without this, the Plan page — which is day/activity-driven,
        # not body-driven — renders blank "Day 1" cards and the itinerary is
        # buried in the collapsed markdown notes, so a fresh template looks empty.
        title:    headings[i] || "Day #{i + 1}",
        accent:   accent_palette[i % accent_palette.size],
        position: i + 1,
        date:     start + i
      )
    end
  end

  # The descriptive part of each "## Day 1 — Vegas to Zion" (or
  # "## Friday — Drive + check in") heading in the template body, in order.
  # The leading "Day N —" / weekday prefix is stripped since the card already
  # shows a day number; anything without a recognizable prefix is kept whole.
  def day_headings
    data[:body].to_s.lines.filter_map do |line|
      next unless line.start_with?("## ")

      heading = line.delete_prefix("## ").strip
      heading.sub(/\A(?:Day\s*\d+|Mon(?:day)?|Tue(?:sday)?|Wed(?:nesday)?|Thu(?:rsday)?|Fri(?:day)?|Sat(?:urday)?|Sun(?:day)?)\s*[—–-]\s*/i, "").presence || heading
    end
  end
end
