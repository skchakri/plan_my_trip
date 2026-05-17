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
        "Hey #{join_names(names)} — buckle up, because this one's going to be good."
      else
        "Hey there — strap in. You're going to love this."
      end

    title = @trip.title.to_s

    lines = []
    lines << host(greeting, rate: 1.1, pitch: 1.05, pause: 200)
    lines << host("This is your Plan My Trip podcast — your personal tour guide for the next few days.", rate: 1.08, pause: 250)

    if @trip.excitement_pitch.present?
      lines << host("Now listen — here's why this trip is special.", rate: 1.08, pitch: 1.05, pause: 180)
      lines << guide(@trip.excitement_pitch, rate: 0.95, pause: 350)
      lines << host("Yeah. That's what we're talking about.", rate: 1.1, pitch: 1.1, pause: 250)
    end

    lines << host("Ready? Here we go.", rate: 1.15, pitch: 1.08, pause: 400)

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

    # A punchy day-level pitch — different framing per ordinal so each day
    # has its own energy instead of "Day N of total" each time.
    opener = pick(DAY_OPENERS, "#{day.id}-opener") % { num: day_num, total: total, weekday: weekday }
    theme_line =
      if theme
        pick(THEME_FRAMINGS, "#{day.id}-theme") % { theme: theme }
      else
        nil
      end

    lines = []
    lines << host(opener, rate: 1.1, pitch: 1.05, pause: 200)
    lines << host(theme_line, rate: 1.08, pitch: 1.05, pause: 220) if theme_line
    if day.summary.present?
      lines << guide(day.summary, rate: 0.95, pause: 300)
    end
    if day.activities.any?
      preview = day.activities.first(3).map(&:title).map { |t| strip_parens(t) }.join(", ")
      lines << host("Today: #{preview}#{day.activities.size > 3 ? ', and more.' : '.'}", rate: 1.08, pause: 280)
      headliner_activity = pick_headliner(day.activities)
      if headliner_activity
        headliner = strip_parens(headliner_activity.title)
        lines << host(pick(DAY_HYPE, "#{day.id}-hype") % { headliner: headliner }, rate: 1.12, pitch: 1.08, pause: 350)
      end
    end
    lines << host(pick(DAY_TRANSITIONS, "#{day.id}-trans"), rate: 1.1, pause: 250)

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
        "And that's the trip, #{join_names(names)}. What a ride."
      else
        "And that — is the trip. What a ride."
      end

    {
      type: "outro",
      eyebrow: "Wrap-up",
      title: "Safe travels.",
      text: "Have an amazing time.",
      photo: nil, tiles: [],
      lines: [
        host(closing, rate: 1.1, pitch: 1.05, pause: 220),
        host("Eat the food. Take the pictures. Soak it in. This one's going to stick with you.", rate: 1.08, pause: 320),
        host("Drive safe. Hug the people you're with. And have the time of your life.", rate: 1.05, pause: 320),
        host("This has been Plan My Trip. See you on the road.", rate: 0.98, pitch: 0.98, pause: 200)
      ]
    }
  end

  # ── Templates ─────────────────────────────────────────────────────────

  ACTIVITY_HOOKS = [
    "Now THIS — %{title}.",
    "All right, this is the one. %{title}.",
    "Picture it. %{title}.",
    "Hold on to your hat — %{title}.",
    "Big one coming up. %{title}.",
    "Get ready — %{title}.",
    "Brace yourself. %{title}.",
    "Personal favorite — %{title}. You're going to love this.",
    "And here we go — %{title}.",
    "This next one — %{title}. Trust me on this.",
    "Stop everything. %{title}."
  ].freeze

  WHY_CARE_HOOKS = [
    "Here's why this one's a banger.",
    "Quick story — and it's a good one.",
    "Fun fact, and you'll want to remember this.",
    "OK, listen up.",
    "Here's the magic.",
    "Stick with me — this is the good part.",
    "You won't believe this.",
    "Here's what makes this special.",
    "Lean in. Here it is."
  ].freeze

  REACTIONS = [
    "That's wild, right?",
    "Love. That.",
    "Worth the trip just for this one.",
    "How cool is that?",
    "Whoa.",
    "Right? Incredible.",
    "I mean, come on.",
    "Tell me that's not amazing.",
    "Goosebumps.",
    "You're going to LOVE this.",
    "That's the kind of thing you remember forever."
  ].freeze

  COMING_UP_HOOKS = [
    "Coming up next — %{next}. And it's gonna be good.",
    "Right after this? %{next}.",
    "Then we're heading straight to %{next}.",
    "Stick around — %{next} is up.",
    "And then? %{next}. You're not going to want to miss it.",
    "Next stop: %{next}.",
    "Hold that thought — %{next} is on deck."
  ].freeze

  DAY_OPENERS = [
    "Day %{num}. %{weekday}. Let's go.",
    "All right — Day %{num} of %{total}. Here's where it gets good.",
    "Day %{num}, %{weekday}. Big day ahead.",
    "It's %{weekday}. Day %{num}. And we are READY.",
    "Welcome to Day %{num}. %{weekday}, and it's a good one."
  ].freeze

  THEME_FRAMINGS = [
    "Today's vibe? %{theme}.",
    "The theme of the day — %{theme}.",
    "One word for today: %{theme}.",
    "Today is all about %{theme}.",
    "If today had a tagline, it'd be %{theme}."
  ].freeze

  DAY_HYPE = [
    "If you take nothing else from today — %{headliner}. That alone is worth it.",
    "%{headliner} alone justifies the whole day.",
    "The thing you're going to be telling people about? %{headliner}.",
    "Mark my words: %{headliner} is going to be the highlight.",
    "If today only delivered one moment — let it be %{headliner}."
  ].freeze

  DAY_TRANSITIONS = [
    "Let's get into it.",
    "Let's break it down, stop by stop.",
    "Here's how it unfolds.",
    "All right — first up.",
    "Let's walk through it."
  ].freeze

  # ── Helpers ───────────────────────────────────────────────────────────

  # Slightly hotter defaults — tour-guide energy by default. Callers can
  # still pass explicit rate/pitch for specific lines.
  def host(text, rate: 1.08, pitch: 1.02, pause: 180)
    { voice: HOST, text: text.to_s, rate: rate, pitch: pitch, pause_after_ms: pause }
  end

  def guide(text, rate: 0.97, pitch: 0.95, pause: 240)
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

  # Best candidate for the "today's headliner" hype line. Skips logistics
  # stops (Depart / Pack up / Drive home etc.) and prefers activities that
  # carry a famous_for blurb — the ones actually worth pitching.
  LOGISTICS_RE = /\A(depart|pack up|check out|back at|home|arrive|drive home)/i
  def pick_headliner(activities)
    list = activities.to_a
    real = list.reject { |a| LOGISTICS_RE.match?(a.title.to_s) }
    pool = real.any? ? real : list
    pool.find { |a| a.famous_for.present? } || pool.first
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
