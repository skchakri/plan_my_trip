module PlacesHelper
  KM_TO_MILES = 0.621371

  # km is the internal unit (AI prompts, search radius, storage); the UI
  # surfaces miles for US users. Pass an Integer/Float in km, get a short
  # display string like "25 mi" or "12.3 mi" (one decimal under 10).
  def km_to_miles(km, precision: nil)
    return nil if km.blank?
    miles = km.to_f * KM_TO_MILES
    precision ||= (miles < 10 ? 1 : 0)
    format("%.#{precision}f", miles)
  end

  TIER_STYLES = {
    "must-see" => {
      label: "Must-see",
      classes: "bg-amber-500/20 border-amber-500/50 text-amber-100",
      icon: :trophy
    },
    "worth-it" => {
      label: "Worth it",
      classes: "bg-emerald-500/15 border-emerald-500/40 text-emerald-200",
      icon: :sparkles
    },
    "bonus" => {
      label: "Bonus",
      classes: "bg-slate-800/80 border-slate-700 text-slate-300",
      icon: :plus
    }
  }.freeze

  # Renders a "#3 · ★ 4.2" chip used at the top-left of every place card.
  # `item` is a Highlight or Idea (PlaceRanker-stamped) — falls back to
  # nil when used on a raw Place without rank.
  def place_rank_chip(item)
    rank   = item.respond_to?(:rank)   ? item.rank   : nil
    rating = item.respond_to?(:rating) ? item.rating : nil
    real   = item.respond_to?(:has_real_rating?) && item.has_real_rating?
    return "".html_safe unless rank || rating

    rank_html = if rank
      %(<span class="font-semibold tabular-nums">##{rank}</span>)
    end
    rating_html = if rating
      stroke = real ? "text-amber-300" : "text-slate-400"
      %(<span class="inline-flex items-center gap-0.5 #{stroke}">) +
        icon(:star, class: "w-3 h-3 fill-current") +
        %(<span class="tabular-nums font-medium">#{format("%.1f", rating)}</span>) +
        %(</span>)
    end
    %(<span class="inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-[11px] bg-slate-950/75 backdrop-blur-sm border border-slate-700/70 text-slate-100">#{rank_html}#{rating_html}</span>).html_safe
  end

  # Tier ribbon (Must-see / Worth it / Bonus). Returns "" if no tier.
  def place_tier_badge(item, size: :sm)
    tier = item.respond_to?(:tier) ? item.tier : nil
    style = TIER_STYLES[tier]
    return "".html_safe unless style
    pad = size == :sm ? "px-2 py-0.5 text-[10px]" : "px-2.5 py-1 text-xs"
    icon_html = icon(style[:icon], class: "w-3 h-3")
    %(<span class="inline-flex items-center gap-1 rounded-full #{pad} uppercase tracking-widest font-semibold border #{style[:classes]}">#{icon_html}<span>#{style[:label]}</span></span>).html_safe
  end

  # 5-star row (filled / half / empty). Used on the place page next to
  # the average rating.
  def star_row(rating, klass: "w-4 h-4")
    rating = rating.to_f
    full   = rating.floor
    half   = (rating - full) >= 0.25 && (rating - full) < 0.75
    full  += 1 if (rating - full) >= 0.75
    out = ""
    5.times do |i|
      cls = if i < full
        "text-amber-400"
      elsif i == full && half
        "text-amber-400/60"
      else
        "text-slate-700"
      end
      out += %(<span class="#{cls}">) + icon(:star, class: "#{klass} fill-current") + %(</span>)
    end
    out.html_safe
  end

  # "4.2 · 12 reviews" caption — collapses to "No ratings yet" when empty.
  def rating_caption(rating, count)
    if count.to_i.zero?
      %(<span class="text-slate-400">No ratings yet</span>).html_safe
    else
      %(<span class="text-slate-200 font-semibold">#{format("%.1f", rating.to_f)}</span> <span class="text-slate-400">· #{pluralize(count.to_i, "review")}</span>).html_safe
    end
  end
end
