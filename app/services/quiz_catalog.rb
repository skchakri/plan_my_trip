# Registry + question builder for the standalone general-knowledge quizzes
# ("Travel Trivia"). Categories are defined here in code; the answer pool comes
# from curated seed data (Country / UsState). Questions are generated fresh on
# each play from a random sample, so a quiz never feels memorized.
#
# build(key) returns an array of plain hashes the front-end grades client-side:
#   { prompt:, image_url:, flag_thumb:, options: [4 strings], answer_index: }
module QuizCatalog
  Category = Struct.new(:key, :title, :tagline, :short, :icon, :accent, :emoji, :note, keyword_init: true) do
    def to_param = key
  end

  # When leader_name was last hand-verified. Surfaced in the UI so "current
  # leader" answers stay honest as governments change.
  LEADERS_AS_OF = "August 2026"

  CATEGORIES = [
    Category.new(
      key: "countries_capitals",
      title: "World Capitals",
      tagline: "Match each country to the city that runs it.",
      short: "Capitals",
      icon: :globe, accent: "amber", emoji: "🌍"
    ),
    Category.new(
      key: "us_states_capitals",
      title: "U.S. State Capitals",
      tagline: "All fifty states and their capital cities.",
      short: "State capitals",
      icon: :landmark, accent: "sky", emoji: "🏛️"
    ),
    Category.new(
      key: "flags_countries",
      title: "Guess the Flag",
      tagline: "Name the nation from its colors alone.",
      short: "Flags",
      icon: :flag, accent: "rose", emoji: "🚩"
    ),
    Category.new(
      key: "world_leaders",
      title: "World Leaders",
      tagline: "Presidents, prime ministers & monarchs by country.",
      short: "Leaders",
      icon: :crown, accent: "violet", emoji: "👑",
      note: "Leaders current as of #{LEADERS_AS_OF}."
    ),
    Category.new(
      key: "currencies_countries",
      title: "World Currencies",
      tagline: "What does each country keep in its wallet?",
      short: "Currencies",
      icon: :coins, accent: "emerald", emoji: "💱"
    ),
    Category.new(
      key: "landmarks_countries",
      title: "Famous Landmarks",
      tagline: "Place the world's icons on the map.",
      short: "Landmarks",
      icon: :map_pin, accent: "teal", emoji: "🗺️"
    ),
    Category.new(
      key: "languages_countries",
      title: "World Languages",
      tagline: "What do the locals speak?",
      short: "Languages",
      icon: :languages, accent: "indigo", emoji: "🗣️"
    ),
    Category.new(
      key: "calling_codes_countries",
      title: "Dialing Codes",
      tagline: "Phone home — match the country to its +code.",
      short: "Dialing codes",
      icon: :phone, accent: "cyan", emoji: "☎️"
    ),
    Category.new(
      key: "tlds_countries",
      title: "Internet Domains",
      tagline: "Whose web address is that? (.de, .ch, .za …)",
      short: "Domains",
      icon: :link, accent: "fuchsia", emoji: "🌐"
    ),
    Category.new(
      key: "continents_countries",
      title: "Continents",
      tagline: "Place every country on the right continent.",
      short: "Continents",
      icon: :map, accent: "orange", emoji: "🧭"
    ),
    Category.new(
      key: "anthems_countries",
      title: "National Anthems",
      tagline: "Name that tune — anthems of the world.",
      short: "Anthems",
      icon: :music, accent: "red", emoji: "🎵"
    ),
    Category.new(
      key: "national_birds_countries",
      title: "National Birds",
      tagline: "Which feathered icon represents each nation?",
      short: "National birds",
      icon: :bird, accent: "lime", emoji: "🦤"
    ),
    Category.new(
      key: "national_sports_countries",
      title: "National Sports",
      tagline: "The games each nation is known for.",
      short: "National sports",
      icon: :trophy, accent: "blue", emoji: "🏅",
      note: "Official where one exists; otherwise the sport the country is most associated with."
    ),
    Category.new(
      key: "car_logos",
      title: "Car Logos",
      tagline: "Name the marque from its badge.",
      short: "Car logos",
      icon: :car, accent: "zinc", emoji: "🚗"
    ),
    Category.new(
      key: "airline_logos",
      title: "Airline Logos",
      tagline: "Spot the airline from its logo.",
      short: "Airline logos",
      icon: :plane, accent: "yellow", emoji: "✈️"
    ),
    Category.new(
      key: "famous_brands",
      title: "Famous Brands",
      tagline: "Four logos, one brand — pick the right mark.",
      short: "Famous brands",
      icon: :tag, accent: "pink", emoji: "🏷️"
    )
  ].freeze

  CONTINENTS = [ "Africa", "Asia", "Europe", "North America", "South America", "Oceania" ].freeze

  DEFAULT_COUNT = 10
  OPTION_COUNT  = 4

  module_function

  def all  = CATEGORIES
  def keys = CATEGORIES.map(&:key)
  def find(key) = CATEGORIES.find { |c| c.key == key.to_s }

  # How many questions a category can currently field (0 = unavailable).
  def pool_size(key)
    case key.to_s
    when "countries_capitals", "flags_countries" then Country.count
    when "us_states_capitals"                    then UsState.count
    when "world_leaders"                         then Country.with_leader.count
    when "currencies_countries"                  then Country.with_currency.count
    when "landmarks_countries"                   then Landmark.count
    when "languages_countries"                   then Country.with_language.count
    when "calling_codes_countries"               then Country.with_calling_code.count
    when "tlds_countries", "continents_countries" then Country.count
    when "anthems_countries"                     then Country.with_anthem.count
    when "national_birds_countries"              then Country.with_national_bird.count
    when "national_sports_countries"             then Country.with_national_sport.count
    when "car_logos"                             then Brand.for_category("car").count
    when "airline_logos"                         then Brand.for_category("airline").count
    when "famous_brands"                         then Brand.for_category("brand").count
    else 0
    end
  end

  def available?(key) = pool_size(key) >= OPTION_COUNT

  def build(key, count: DEFAULT_COUNT)
    case key.to_s
    when "countries_capitals"    then countries_capitals(count)
    when "us_states_capitals"    then us_states_capitals(count)
    when "flags_countries"       then flags_countries(count)
    when "world_leaders"         then world_leaders(count)
    when "currencies_countries"  then currencies_countries(count)
    when "landmarks_countries"   then landmarks_countries(count)
    when "languages_countries"   then languages_countries(count)
    when "calling_codes_countries" then calling_codes_countries(count)
    when "tlds_countries"        then tlds_countries(count)
    when "continents_countries"  then continents_countries(count)
    when "anthems_countries"     then anthems_countries(count)
    when "national_birds_countries"  then national_birds_countries(count)
    when "national_sports_countries" then national_sports_countries(count)
    when "car_logos"             then logo_deck("car", count, "Which car brand does this logo belong to?")
    when "airline_logos"         then logo_deck("airline", count, "Which airline does this logo belong to?")
    when "famous_brands"         then brand_image_deck(count)
    else []
    end
  end

  # ── builders ───────────────────────────────────────────────────────

  def countries_capitals(count)
    rows = Country.all.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.capital, distractors(rows, c, :capital, group: :continent))
      { prompt: "What is the capital of #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def us_states_capitals(count)
    rows = UsState.all.to_a
    sample(rows, count).map do |s|
      options, idx = mc(s.capital, distractors(rows, s, :capital))
      { prompt: "What is the capital of #{s.name}?", options: options, answer_index: idx }
    end
  end

  def flags_countries(count)
    rows = Country.all.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.name, distractors(rows, c, :name, group: :continent))
      { prompt: "Which country flies this flag?", image_url: c.flag_url(width: 320),
        options: options, answer_index: idx }
    end
  end

  def world_leaders(count)
    rows = Country.with_leader.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.leader_name, distractors(rows, c, :leader_name, group: :leader_title))
      { prompt: "Who is the #{c.leader_title.downcase} of #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def currencies_countries(count)
    rows = Country.with_currency.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.currency_name, distractors(rows, c, :currency_name, group: :continent))
      { prompt: "What is the official currency of #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def landmarks_countries(count)
    countries = Country.all.to_a
    sample(Landmark.all.to_a, count).map do |l|
      near, far = countries.partition { |c| c.continent == l.continent }
      wrong = pick_distinct((near.shuffle + far.shuffle).map(&:name), l.country)
      options, idx = mc(l.country, wrong)
      { prompt: "Which country is home to #{l.name}?", options: options, answer_index: idx }
    end
  end

  def languages_countries(count)
    rows = Country.with_language.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.primary_language, distractors(rows, c, :primary_language, group: :continent))
      { prompt: "What is the main language spoken in #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def calling_codes_countries(count)
    rows = Country.with_calling_code.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.calling_code, distractors(rows, c, :calling_code, group: :continent))
      { prompt: "What is the international dialing code for #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def tlds_countries(count)
    rows = Country.all.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.name, distractors(rows, c, :name, group: :continent))
      { prompt: "Which country owns the #{c.tld} internet domain?", options: options, answer_index: idx }
    end
  end

  def continents_countries(count)
    rows = Country.all.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.continent, sample(CONTINENTS - [ c.continent ], OPTION_COUNT - 1))
      { prompt: "On which continent is #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def anthems_countries(count)
    rows = Country.with_anthem.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.national_anthem, distractors(rows, c, :national_anthem, group: :continent))
      { prompt: "Which song is the national anthem of #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def national_birds_countries(count)
    rows = Country.with_national_bird.to_a
    sample(rows, count).map do |c|
      options, idx = mc(c.national_bird, distractors(rows, c, :national_bird, group: :continent))
      { prompt: "What is the national bird of #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  def national_sports_countries(count)
    rows = Country.with_national_sport.to_a
    # No continent grouping — sport isn't continent-correlated, so a global
    # spread of distractors plays better.
    sample(rows, count).map do |c|
      options, idx = mc(c.national_sport, distractors(rows, c, :national_sport))
      { prompt: "Which sport is most associated with #{c.name}?", flag_thumb: c.flag_url(width: 80),
        options: options, answer_index: idx }
    end
  end

  # Shared by the car / airline logo decks: show a logo, pick the brand. The
  # `logo: true` flag tells the player to render it on a light card (logos can
  # be any colour). Distractors are other brands in the same category.
  def logo_deck(category, count, prompt)
    rows = Brand.for_category(category).to_a
    sample(rows, count).map do |b|
      options, idx = mc(b.name, distractors(rows, b, :name))
      { prompt: prompt, image_url: b.logo_url, logo: true, options: options, answer_index: idx }
    end
  end

  # The flipped "famous brands" twist: name a brand, show FOUR logos, pick the
  # right one. Options are images (`option_images`); `option_labels` carry the
  # brand names for accessibility + the results recap.
  def brand_image_deck(count)
    rows = Brand.for_category("brand").to_a
    sample(rows, count).map do |b|
      pool = ([ b ] + sample(rows - [ b ], OPTION_COUNT - 1)).shuffle
      {
        prompt: "Which of these is the #{b.name} logo?",
        option_images: pool.map(&:logo_url),
        option_labels: pool.map(&:name),
        answer_index: pool.index(b)
      }
    end
  end

  # ── helpers ────────────────────────────────────────────────────────

  def sample(rows, count)
    rows.shuffle.first([ count, rows.size ].min)
  end

  # Shuffle the correct answer in with its distractors; return [options, index].
  def mc(correct, distractors)
    opts = ([ correct ] + distractors).shuffle
    [ opts, opts.index(correct) ]
  end

  # Pick OPTION_COUNT-1 distinct, plausible wrong answers for `subject` drawn
  # from `pool`. Prefers rows sharing `group` (same continent / same office) so
  # the distractors are believable, then falls back to the wider pool. Dedupes
  # by display value so options never repeat.
  def distractors(pool, subject, attr, group: nil)
    correct = subject.public_send(attr)
    others  = pool.reject { |r| r.id == subject.id }
    near, far =
      if group
        others.partition { |r| r.public_send(group) == subject.public_send(group) }
      else
        [ others, [] ]
      end
    pick_distinct((near.shuffle + far.shuffle).map { |r| r.public_send(attr) }, correct)
  end

  # Take the first OPTION_COUNT-1 values that are present, distinct, and not the
  # correct answer — so options never repeat (e.g. several Euro countries).
  def pick_distinct(values, correct)
    out = []
    values.each do |v|
      next if v.blank? || v == correct || out.include?(v)
      out << v
      break if out.size >= OPTION_COUNT - 1
    end
    out
  end
end
