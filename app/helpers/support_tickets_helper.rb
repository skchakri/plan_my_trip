module SupportTicketsHelper
  # (label, tailwind badge classes) for a ticket status. `escalated` reads as
  # "in review" to the user — they don't need the internal escalation wording.
  STATUS_BADGES = {
    "open"        => [ "Awaiting reply", "bg-amber-500/15 text-amber-200 border-amber-500/30" ],
    "ai_answered" => [ "Answered",       "bg-emerald-500/15 text-emerald-200 border-emerald-500/30" ],
    "escalated"   => [ "In review",      "bg-sky-500/15 text-sky-200 border-sky-500/30" ],
    "resolved"    => [ "Resolved",       "bg-slate-700/60 text-slate-300 border-slate-600" ],
    "closed"      => [ "Closed",         "bg-slate-700/60 text-slate-400 border-slate-600" ]
  }.freeze

  def support_status_badge(status)
    label, classes = STATUS_BADGES.fetch(status, [ status.titleize, "bg-slate-700 text-slate-300 border-slate-600" ])
    tag.span(label, class: "inline-flex items-center text-[11px] px-2 py-0.5 rounded-full border font-semibold #{classes}")
  end

  # Admin view shows the raw internal status wording.
  def support_admin_status_label(status)
    { "escalated" => "Escalated · needs you", "ai_answered" => "AI answered" }.fetch(status, status.titleize)
  end

  # Speaker label + bubble colour for a thread message. From the admin's
  # perspective the "user" role is the customer, not "You".
  def support_message_meta(message, admin: false)
    case message.role
    when "user"      then [ admin ? (message.author&.display_name || "Customer") : "You", "bg-slate-800/70 border-slate-700" ]
    when "assistant" then [ "Wanderply (AI)", "bg-amber-500/10 border-amber-500/25" ]
    when "admin"     then [ "Wanderply team", "bg-emerald-500/10 border-emerald-500/25" ]
    else [ message.role.titleize, "bg-slate-800 border-slate-700" ]
    end
  end
end
