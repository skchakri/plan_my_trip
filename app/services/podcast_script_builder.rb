# Builds a host + guide dialogue script for the reading-mode podcast.
# Pure presentation: takes plain Activity / TripDay / Trip data and emits an
# array of {voice:, text:, rate:, pitch:, pause_after_ms:} lines per scene.
#
# Two voices: HOST (warm, conversational, slightly faster) and GUIDE
# (factual, slightly slower for clarity). The reading-mode JS controller
# resolves these to the closest available SpeechSynthesisVoice on the device.
class PodcastScriptBuilder
  HOST  = "host".freeze
  GUIDE = "guide".freeze

  def initialize(trip:, days:, viewer_name: nil)
    @trip = trip
    @days = days
    @viewer = viewer_name
    @people = trip.respond_to?(:people) ? trip.people.ordered.to_a : []
  end

  # Returns an array of scene hashes, each carrying a :lines array.
  def build
    scenes = []
    scenes << intro_scene if @trip.excitement_pitch.present? || @people.any?

    @days.each_with_index do |day, di|
      next_day = @days[di + 1]
      scenes << day_intro_scene(day, di + 1, total: @days.size)
      day.activities.each_with_index do |activity, ai|
        next_in_day = day.activities[ai + 1]
        next_overall = next_in_day || (next_day && next_day.activities.first) || nil
        scenes << activity_scene(activity, day: day, day_index: di + 1, next_activity: next_overall)
      end
    end

    scenes << outro_scene
    scenes
  end

  private

  # ── Scene builders ────────────────────────────────────────────────────

  def intro_scene
    names = @people.map(&:name)
    greeting =
      if names.any?
        "Hey #{join_names(names)} — welcome aboard."
      else
        "Hey there — welcome to the show."
      end

    title = @trip.title.to_s

    lines = []
    lines << host(greeting, pause: 200)
    lines << host("This is your Plan My Trip podcast — a little tour through what's coming over the next few days.", pause: 300)

    if @trip.excitement_pitch.present?
      lines << host("Here's the pitch.", pause: 150)
      lines << guide(@trip.excitement_pitch, rate: 0.95, pause: 350)
    end

    lines << host("Ready? Let's go.", rate: 1.05, pause: 400)

    {
      type: "intro",
      eyebrow: "Episode 1",
      title: title.presence || "Welcome",
      text: "Welcome aboard. #{@trip.excitement_pitch}",
      photo: nil,
      tiles: [],
      lines: lines
    }
  end

  def day_intro_scene(day, day_num, total:)
    weekday = day.date&.strftime("%A") || day.title
    theme   = day.theme.presence

    lines = []
    lines << host("Day #{day_num} of #{total}.", pause: 200)
    lines << host("It's #{weekday}#{theme ? " — and the theme is #{theme}." : '.'}", pause: 250)
    if day.summary.present?
      lines << guide(day.summary, rate: 0.95, pause: 300)
    end
    if day.activities.any?
      preview = day.activities.first(3).map(&:title).map { |t| strip_parens(t) }.join(" · ")
      lines << host("On the docket: #{preview}#{day.activities.size > 3 ? ', and more' : ''}.", pause: 350)
    end
    lines << host("Let's break it down.", pause: 250)

    {
      type: "day",
      eyebrow: "Day #{day_num}#{theme ? " · #{theme}" : ''}",
      title: day.title,
      text: [ day.summary, day.activities.map { |a| "#{a.time_label} #{a.title}" }.join(", then ") ].compact.reject(&:blank?).join(". "),
      photo: nil, tiles: [],
      lines: lines
    }
  end

  def activity_scene(activity, day:, day_index:, next_activity: nil)
    map = activity.respond_to?(:map_tiles) ? activity.map_tiles : nil

    title_clean = strip_parens(activity.title)
    location    = activity.location_name.presence
    time_label  = activity.time_label.presence
    famous      = activity.famous_for.presence
    note_blurb  = first_sentence(activity.notes.to_s.gsub(/[*_`#>]/, " "))
    group_label = activity.group_label.presence

    lines = []

    # Hook
    hook = pick(ACTIVITY_HOOKS, activity.id) % { title: title_clean }
    lines << host(hook, pause: 200)

    # Setup — time, group, place
    setup_bits = []
    setup_bits << time_label if time_label
    setup_bits << "for #{group_label.sub(/^Group [AB] — /, '')}" if group_label
    setup_bits << "we're stopping at #{location}" if location && location != title_clean
    setup_bits << "we're heading to #{title_clean}" if setup_bits.empty?
    setup_phrase = setup_bits.join(", ")
    lines << guide(capitalize_first(setup_phrase) + ".", rate: 0.95, pause: 220)

    # Owner-authored tour-guide script wins when present — chunked into
    # bite-sized sentences with host reactions woven in for podcast cadence.
    if activity.guide_script.present?
      lines << host(pick(WHY_CARE_HOOKS, activity.id), pause: 150)
      chunks = guide_chunks(activity.guide_script, max_per_chunk: 2)
      chunks.each_with_index do |chunk, ci|
        lines << guide(chunk, rate: 0.92, pause: 280)
        # Sprinkle a host reaction roughly every 2 chunks so it doesn't
        # feel like a monologue. Pick deterministically from REACTIONS.
        if ci.even? && ci != chunks.length - 1
          lines << host(pick(REACTIONS, "#{activity.id}-#{ci}"), rate: 1.05, pitch: 1.05, pause: 220)
        end
      end
    elsif famous
      # Fallback when no rich script: famous_for + reaction.
      lines << host(pick(WHY_CARE_HOOKS, activity.id), pause: 150)
      lines << guide(famous, rate: 0.92, pause: 350)
      lines << host(pick(REACTIONS, activity.id), rate: 1.05, pitch: 1.05, pause: 280)
    end

    # Practical color from notes — only when nothing in the rich script
    # already covered it.
    if note_blurb && activity.guide_script.blank? && (famous.nil? || !overlaps?(famous, note_blurb))
      lines << guide(note_blurb, rate: 0.95, pause: 280)
    end

    # Outro tease
    if next_activity
      tease = pick(COMING_UP_HOOKS, activity.id) % { next: strip_parens(next_activity.title) }
      lines << host(tease, pause: 350)
    end

    {
      type: "activity",
      eyebrow: "Day #{day_index}#{time_label ? " · #{time_label}" : ''}",
      title: activity.title,
      location: location,
      address: activity.address,
      photo: activity.photo_url.presence,
      tiles: map ? map[:tiles] : [],
      pin_x_pct: map ? map[:pin_x_pct].round(2) : 50,
      pin_y_pct: map ? map[:pin_y_pct].round(2) : 50,
      maps_link: activity.respond_to?(:maps_link) ? activity.maps_link : nil,
      text: [ location, famous, activity.notes.to_s.gsub(/[*_`]/, " ") ].compact.reject(&:blank?).join(". "),
      lines: lines
    }
  end

  def outro_scene
    names = @people.map(&:name)
    closing =
      if names.any?
        "That's the trip, #{join_names(names)}."
      else
        "And that's the trip."
      end

    {
      type: "outro",
      eyebrow: "Wrap-up",
      title: "Safe travels.",
      text: "Have an amazing time.",
      photo: nil, tiles: [],
      lines: [
        host(closing, pause: 250),
        host("Have a blast out there. Drive safe, take pictures, and enjoy every stop.", pause: 350),
        host("This has been Plan My Trip. See you on the road.", rate: 0.95, pause: 200)
      ]
    }
  end

  # ── Templates ─────────────────────────────────────────────────────────

  ACTIVITY_HOOKS = [
    "Up next — %{title}.",
    "All right, here's a good one. %{title}.",
    "Now picture this: %{title}.",
    "Coming up — %{title}.",
    "Time for %{title}.",
    "Get ready for %{title}.",
    "Brace yourself — %{title}.",
    "Here's a personal favorite — %{title}.",
    "And now — %{title}."
  ].freeze

  WHY_CARE_HOOKS = [
    "Here's why this one's special.",
    "Quick story.",
    "Fun fact.",
    "Why does it matter?",
    "Here's the cool part.",
    "Stick with me on this one.",
    "Listen to this."
  ].freeze

  REACTIONS = [
    "That's wild.",
    "Love that.",
    "Worth the trip just for this.",
    "How cool is that?",
    "Whoa.",
    "Right? Incredible.",
    "Nice.",
    "Tell me that's not amazing."
  ].freeze

  COMING_UP_HOOKS = [
    "Coming up next, %{next}.",
    "Right after this — %{next}.",
    "Then we're off to %{next}.",
    "Stick around for %{next}.",
    "And then? %{next}."
  ].freeze

  # ── Helpers ───────────────────────────────────────────────────────────

  def host(text, rate: 1.05, pitch: 1.0, pause: 200)
    { voice: HOST, text: text.to_s, rate: rate, pitch: pitch, pause_after_ms: pause }
  end

  def guide(text, rate: 0.95, pitch: 0.95, pause: 250)
    { voice: GUIDE, text: text.to_s, rate: rate, pitch: pitch, pause_after_ms: pause }
  end

  # Stable pick from a list, keyed off any hashable thing — same scene
  # produces the same line every time so the script feels designed,
  # not random.
  def pick(arr, key)
    arr[key.to_s.bytes.sum % arr.length]
  end

  def strip_parens(s)
    s.to_s.sub(/\s*\([^)]*\)\s*\z/, "").strip
  end

  # Chunk a multi-sentence script into ~max_per_chunk-sentence groups
  # so the guide doesn't deliver one long monologue.
  def guide_chunks(text, max_per_chunk: 2)
    return [] if text.blank?
    sentences = text.strip.split(/(?<=[.!?])\s+/).reject(&:blank?)
    sentences.each_slice(max_per_chunk).map { |group| group.join(" ") }
  end

  def first_sentence(text)
    return nil if text.blank?
    s = text.strip.split(/(?<=[.!?])\s+/, 2).first
    s = s.to_s.gsub(/\s+/, " ").strip
    s.empty? ? nil : s
  end

  def overlaps?(a, b)
    return false if a.blank? || b.blank?
    a_words = a.downcase.scan(/[a-z]+/).first(8)
    b_words = b.downcase.scan(/[a-z]+/).first(8)
    (a_words & b_words).size >= 4
  end

  def capitalize_first(str)
    return str if str.blank?
    str[0].upcase + str[1..]
  end

  def join_names(arr)
    case arr.size
    when 0 then ""
    when 1 then arr.first
    when 2 then arr.join(" and ")
    else arr[0..-2].join(", ") + ", and " + arr.last
    end
  end
end
