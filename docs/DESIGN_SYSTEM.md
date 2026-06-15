# Design system

Lightweight, dark-first design tokens for Plan My Trip. The app is Tailwind v4;
these are the conventions to keep new UI consistent. Reusable component classes
live in `app/assets/tailwind/application.css`.

## Buttons

Use the `.btn` base + one size + one variant. Sizes bake in accessible touch
targets (40px default, 48px prominent; compact buttons grow to 44px on touch
devices via a `pointer: coarse` media query).

| Class | Use |
|---|---|
| `.btn .btn-md .btn-primary` | Primary action (amber) — one per view |
| `.btn .btn-md .btn-secondary` | Secondary action (outlined) |
| `.btn .btn-sm .btn-ghost` | Tertiary / inline action |
| `.btn .btn-lg .btn-primary` | Hero / empty-state CTA |

```erb
<%= link_to "Save", path, class: "btn btn-md btn-primary" %>
```

Existing ad-hoc utility strings (`px-3 py-1.5 rounded-lg bg-amber-500 …`) still
work; migrate to `.btn` incrementally when touching a view.

## Badges / chips

`.chip` is the AA-safe neutral chip (`slate-700` / `slate-100`, ≥ 4.5:1). The old
`bg-slate-800/80 text-slate-300` pattern was ~3.5:1 and fails WCAG AA — replace it.

Accent chips stay inline with their semantic color, e.g.
`bg-amber-500/15 text-amber-100 border border-amber-500/40` (owner),
`bg-sky-500/15 text-sky-200 border border-sky-500/30` (editor / info),
`bg-emerald-500/15 text-emerald-300` (success / handled).

## Spacing

Stick to Tailwind's scale; prefer these rhythm steps:
`gap-2` (8px) inside a control, `gap-3` (12px) between controls,
`p-4`/`p-5` card padding, `mt-6` between sections, `gap-6` grid gutters.

## Icons

From `IconsHelper#icon`. Sizes: `w-3.5 h-3.5` (chip/label), `w-4 h-4` (button,
default), `w-5 h-5` (section header), `w-6 h-6`+ (hero / empty state).

## Color

Background `slate-950`; surfaces `slate-900/40` on `slate-800` borders. Accent
amber (`amber-500`/`amber-300`); informational sky; success emerald; danger rose.
Body text `slate-300`/`slate-100`; muted `slate-400` (avoid `slate-500` for text
that must be read).

## Feedback

- Transient confirmations: dispatch a toast — `window.dispatchEvent(new
  CustomEvent("toast", { detail: { type: "notice"|"alert", message } }))` — or set
  a Rails `flash` (rendered into `#toast-stack`).
- Offline: the global `network-status` banner appears automatically; don't claim
  writes work offline.
