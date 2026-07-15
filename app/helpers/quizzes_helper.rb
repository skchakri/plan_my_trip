module QuizzesHelper
  # Per-category accent class sets. Written as full literal class strings so the
  # Tailwind v4 scanner (which reads helpers/**/*.rb) compiles every variant.
  QUIZ_ACCENTS = {
    "amber" => {
      tile:  "bg-amber-500/10 text-amber-300 ring-1 ring-amber-500/20",
      hover: "hover:border-amber-500/50 hover:shadow-amber-500/10",
      badge: "bg-amber-500/10 text-amber-200 border border-amber-500/30",
      bar:   "bg-gradient-to-r from-amber-400 to-amber-500",
      text:  "text-amber-300",
      dot:   "bg-amber-400",
      glow:  "from-amber-500/15"
    },
    "sky" => {
      tile:  "bg-sky-500/10 text-sky-300 ring-1 ring-sky-500/20",
      hover: "hover:border-sky-500/50 hover:shadow-sky-500/10",
      badge: "bg-sky-500/10 text-sky-200 border border-sky-500/30",
      bar:   "bg-gradient-to-r from-sky-400 to-sky-500",
      text:  "text-sky-300",
      dot:   "bg-sky-400",
      glow:  "from-sky-500/15"
    },
    "rose" => {
      tile:  "bg-rose-500/10 text-rose-300 ring-1 ring-rose-500/20",
      hover: "hover:border-rose-500/50 hover:shadow-rose-500/10",
      badge: "bg-rose-500/10 text-rose-200 border border-rose-500/30",
      bar:   "bg-gradient-to-r from-rose-400 to-rose-500",
      text:  "text-rose-300",
      dot:   "bg-rose-400",
      glow:  "from-rose-500/15"
    },
    "violet" => {
      tile:  "bg-violet-500/10 text-violet-300 ring-1 ring-violet-500/20",
      hover: "hover:border-violet-500/50 hover:shadow-violet-500/10",
      badge: "bg-violet-500/10 text-violet-200 border border-violet-500/30",
      bar:   "bg-gradient-to-r from-violet-400 to-violet-500",
      text:  "text-violet-300",
      dot:   "bg-violet-400",
      glow:  "from-violet-500/15"
    },
    "emerald" => {
      tile:  "bg-emerald-500/10 text-emerald-300 ring-1 ring-emerald-500/20",
      hover: "hover:border-emerald-500/50 hover:shadow-emerald-500/10",
      badge: "bg-emerald-500/10 text-emerald-200 border border-emerald-500/30",
      bar:   "bg-gradient-to-r from-emerald-400 to-emerald-500",
      text:  "text-emerald-300",
      dot:   "bg-emerald-400",
      glow:  "from-emerald-500/15"
    },
    "teal" => {
      tile:  "bg-teal-500/10 text-teal-300 ring-1 ring-teal-500/20",
      hover: "hover:border-teal-500/50 hover:shadow-teal-500/10",
      badge: "bg-teal-500/10 text-teal-200 border border-teal-500/30",
      bar:   "bg-gradient-to-r from-teal-400 to-teal-500",
      text:  "text-teal-300",
      dot:   "bg-teal-400",
      glow:  "from-teal-500/15"
    },
    "indigo" => {
      tile:  "bg-indigo-500/10 text-indigo-300 ring-1 ring-indigo-500/20",
      hover: "hover:border-indigo-500/50 hover:shadow-indigo-500/10",
      badge: "bg-indigo-500/10 text-indigo-200 border border-indigo-500/30",
      bar:   "bg-gradient-to-r from-indigo-400 to-indigo-500",
      text:  "text-indigo-300",
      dot:   "bg-indigo-400",
      glow:  "from-indigo-500/15"
    },
    "cyan" => {
      tile:  "bg-cyan-500/10 text-cyan-300 ring-1 ring-cyan-500/20",
      hover: "hover:border-cyan-500/50 hover:shadow-cyan-500/10",
      badge: "bg-cyan-500/10 text-cyan-200 border border-cyan-500/30",
      bar:   "bg-gradient-to-r from-cyan-400 to-cyan-500",
      text:  "text-cyan-300",
      dot:   "bg-cyan-400",
      glow:  "from-cyan-500/15"
    },
    "fuchsia" => {
      tile:  "bg-fuchsia-500/10 text-fuchsia-300 ring-1 ring-fuchsia-500/20",
      hover: "hover:border-fuchsia-500/50 hover:shadow-fuchsia-500/10",
      badge: "bg-fuchsia-500/10 text-fuchsia-200 border border-fuchsia-500/30",
      bar:   "bg-gradient-to-r from-fuchsia-400 to-fuchsia-500",
      text:  "text-fuchsia-300",
      dot:   "bg-fuchsia-400",
      glow:  "from-fuchsia-500/15"
    },
    "orange" => {
      tile:  "bg-orange-500/10 text-orange-300 ring-1 ring-orange-500/20",
      hover: "hover:border-orange-500/50 hover:shadow-orange-500/10",
      badge: "bg-orange-500/10 text-orange-200 border border-orange-500/30",
      bar:   "bg-gradient-to-r from-orange-400 to-orange-500",
      text:  "text-orange-300",
      dot:   "bg-orange-400",
      glow:  "from-orange-500/15"
    },
    "red" => {
      tile:  "bg-red-500/10 text-red-300 ring-1 ring-red-500/20",
      hover: "hover:border-red-500/50 hover:shadow-red-500/10",
      badge: "bg-red-500/10 text-red-200 border border-red-500/30",
      bar:   "bg-gradient-to-r from-red-400 to-red-500",
      text:  "text-red-300",
      dot:   "bg-red-400",
      glow:  "from-red-500/15"
    },
    "lime" => {
      tile:  "bg-lime-500/10 text-lime-300 ring-1 ring-lime-500/20",
      hover: "hover:border-lime-500/50 hover:shadow-lime-500/10",
      badge: "bg-lime-500/10 text-lime-200 border border-lime-500/30",
      bar:   "bg-gradient-to-r from-lime-400 to-lime-500",
      text:  "text-lime-300",
      dot:   "bg-lime-400",
      glow:  "from-lime-500/15"
    },
    "blue" => {
      tile:  "bg-blue-500/10 text-blue-300 ring-1 ring-blue-500/20",
      hover: "hover:border-blue-500/50 hover:shadow-blue-500/10",
      badge: "bg-blue-500/10 text-blue-200 border border-blue-500/30",
      bar:   "bg-gradient-to-r from-blue-400 to-blue-500",
      text:  "text-blue-300",
      dot:   "bg-blue-400",
      glow:  "from-blue-500/15"
    },
    "zinc" => {
      tile:  "bg-zinc-500/10 text-zinc-300 ring-1 ring-zinc-500/20",
      hover: "hover:border-zinc-500/50 hover:shadow-zinc-500/10",
      badge: "bg-zinc-500/10 text-zinc-200 border border-zinc-500/30",
      bar:   "bg-gradient-to-r from-zinc-400 to-zinc-500",
      text:  "text-zinc-300",
      dot:   "bg-zinc-400",
      glow:  "from-zinc-500/15"
    },
    "yellow" => {
      tile:  "bg-yellow-500/10 text-yellow-300 ring-1 ring-yellow-500/20",
      hover: "hover:border-yellow-500/50 hover:shadow-yellow-500/10",
      badge: "bg-yellow-500/10 text-yellow-200 border border-yellow-500/30",
      bar:   "bg-gradient-to-r from-yellow-400 to-yellow-500",
      text:  "text-yellow-300",
      dot:   "bg-yellow-400",
      glow:  "from-yellow-500/15"
    },
    "pink" => {
      tile:  "bg-pink-500/10 text-pink-300 ring-1 ring-pink-500/20",
      hover: "hover:border-pink-500/50 hover:shadow-pink-500/10",
      badge: "bg-pink-500/10 text-pink-200 border border-pink-500/30",
      bar:   "bg-gradient-to-r from-pink-400 to-pink-500",
      text:  "text-pink-300",
      dot:   "bg-pink-400",
      glow:  "from-pink-500/15"
    }
  }.freeze

  def quiz_accent(name)
    QUIZ_ACCENTS.fetch(name.to_s, QUIZ_ACCENTS.fetch("amber"))
  end

  # SEO title for a deck page. Leads with the deck name + "Quiz" because that's
  # the literal shape of the search ("world capitals quiz"), not the brand —
  # nobody searches for us yet. Brand trails for SERP recognition.
  def quiz_seo_title(category)
    name = category.title
    name = "#{name} Quiz" unless name.match?(/\bquiz\b/i)
    "#{name} · Free Online Trivia · Wanderply"
  end

  # Meta description: the deck's own tagline, then the deck size and the fact
  # it's free and login-free — the two things that decide the click.
  def quiz_seo_description(category)
    "#{category.tagline} #{QuizCatalog::DEFAULT_COUNT} questions, instant scoring, " \
      "no sign-up needed. One of #{QuizCatalog.keys.size} free travel trivia decks on Wanderply."
  end

  # schema.org/Quiz so answer engines and rich results can read the deck for
  # what it is. Kept minimal and honest — questions are sampled per play, so we
  # describe the deck, not a fixed question set.
  def quiz_jsonld(category)
    {
      "@context" => "https://schema.org",
      "@type" => "Quiz",
      "name" => quiz_seo_title(category),
      "description" => quiz_seo_description(category),
      "url" => quiz_url(category.key),
      "educationalLevel" => "beginner",
      "isAccessibleForFree" => true,
      "learningResourceType" => "Quiz",
      "about" => { "@type" => "Thing", "name" => category.title },
      "publisher" => { "@type" => "Organization", "name" => "Wanderply", "url" => root_url }
    }.to_json
  end
end
