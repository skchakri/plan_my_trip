module HighlightsHelper
  # Maps a Highlight#category (the wizard's VIBES vocabulary) to a
  # Tailwind gradient + Lucide icon. Used for the image-less fallback
  # on highlight cards (admin sandbox + wizard highlights step).
  #
  # All gradient classes are written as literal strings so Tailwind's
  # JIT compiles them.
  CATEGORY_VISUAL = {
    "adventure"   => { gradient: "from-rose-700 to-stone-950",    icon: :mountain },
    "nature"      => { gradient: "from-emerald-800 to-slate-950", icon: :map_pin },
    "scenic"      => { gradient: "from-sky-700 to-slate-950",     icon: :map_pin },
    "history"     => { gradient: "from-stone-700 to-stone-950",   icon: :sparkles },
    "cultural"    => { gradient: "from-violet-800 to-slate-950",  icon: :sparkles },
    "photography" => { gradient: "from-indigo-800 to-slate-950",  icon: :camera },
    "food"        => { gradient: "from-amber-800 to-stone-950",   icon: :sparkles },
    "family"      => { gradient: "from-teal-700 to-slate-950",    icon: :users },
    "relaxing"    => { gradient: "from-cyan-800 to-slate-950",    icon: :map_pin },
    "shopping"    => { gradient: "from-pink-800 to-slate-950",    icon: :sparkles },
    "nightlife"   => { gradient: "from-fuchsia-800 to-slate-950", icon: :sparkles }
  }.freeze

  DEFAULT_VISUAL = { gradient: "from-slate-700 to-slate-950", icon: :map_pin }.freeze

  def highlight_visual_for(category)
    CATEGORY_VISUAL[category.to_s.downcase] || DEFAULT_VISUAL
  end
end
