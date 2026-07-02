---
name: improve
description: >-
  Run the Wanderply self-improvement sweep ("Trip Coach"): fan out the
  gap / competitor / UX / trend lens agents, score them into one ranked backlog,
  write a dated markdown report under docs/improvements/, and push the top items
  to myjira. Use when the user says "/improve", "run a self-improvement sweep",
  "what should we work on next?", "find gaps and improvements", or for the daily
  autonomous Trip-Coach run. Everything runs on the Claude subscription.
---

# /improve — Wanderply self-improvement sweep

You are running the **Trip Coach** loop. It analyzes the app through four lenses,
ranks the findings, persists a backlog, and files the top items in myjira. By
default it is **read-only on the codebase** — it suggests, you decide.

## 0. Parse arguments (`$ARGUMENTS`)

- `--lenses gap,ux` → run only those (default: all four — gap, competitor, ux, trend)
- `--focus "<text>"` → bias every lens toward an area (e.g. `--focus "the trip wizard"`)
- `--apply` → also let `improvement-fixer` land the safest top items on a branch
  (never main; default OFF — keep off while the product is immature)
- `--max N` → cap the backlog size (default 40)
- `--no-myjira` → write the report but skip filing tasks

## 1. Run the orchestrator workflow

Call the **Workflow** tool (this skill authorizes it) with the predefined
`improve` workflow, passing parsed args:

```
Workflow({ name: "improve", args: { lenses, focus, applyFixes, maxFindings } })
```

It returns `{ summary, ranked: [findings…], applied: [...] }`. Each finding has:
`lens, title, area, problem, evidence, recommendation, fix_kind, impact, effort,
confidence, refs, score`. **Do not re-run the lenses yourself** — the workflow
already fanned them out in parallel on the subscription.

If the workflow can't be invoked in this context, fall back to spawning the four
agents yourself via the Agent tool **in one message** (`gap-analyst`,
`competitor-scout`, `ux-auditor`, `trend-scout`), then dedupe/score by
`impact × (6 − effort) × confidence` exactly as the workflow does.

## 2. Write the dated report

Get the date: `date +%F` (and `date +%H%M` only if a report for today already
exists — then suffix it). Write `docs/improvements/REPORT-<YYYY-MM-DD>.md`:

```markdown
# Trip Coach — improvement backlog · <YYYY-MM-DD>

_Lenses: <list> · <rawCount> raw → <rankedCount> ranked · subscription run_

## Top priorities (do next)
<the top 8, as a table: # | Title | Lens | Impact | Effort | Conf | Score | Area>

## Findings by lens
### 🕳️ Gaps  /  🏁 Competitors  /  🎨 UX  /  🚀 Trends
For each finding (highest score first):
- **<title>** · `area` · impact N · effort N · conf 0.x · **fix_kind**
  - Problem: …
  - Recommendation: …
  - Evidence / refs: … (URLs for competitor/trend items)

## Applied this run (if --apply)
<branch name · finding · status applied/deferred · verification result>

## Notes
- Carry-over: link the previous report and mark which items are still open.
```

Keep the previous reports — the diff over time IS the improvement signal. Glob
`docs/improvements/REPORT-*.md` for the prior one and add a one-line carry-over.

## 3. File the top items in myjira (unless `--no-myjira`)

For the **top 8** findings, invoke the **`myjira-report-gap`** skill once per
finding (project: the Wanderply project; type: enhancement for new-feature/
trend, gap for gap/ux, bug if it's a defect). Title = the finding title; body =
problem + recommendation + area + score + refs. Best-effort dedupe: before
filing, note titles already filed by a recent run (mention if you skip dupes).
If myjira (http://localhost:1200) is unreachable, say so and skip — never block
the report on it.

## 4. Report back to the user (concise)

Lead with the **top 3–5 things to do next** (title + why + impact/effort), the
report path, how many myjira items you filed, and — if `--apply` ran — which
branches are ready for review. Offer the obvious next step:
"`@improvement-fixer apply #N`" for a specific item, or `/improve --apply` to let
it land the safe ones itself.

## Guardrails

- **Subscription only.** The lenses use WebSearch/WebFetch + code reading — no
  metered API keys. Don't invoke `ai-prompt-tuner` here (it spends API tokens by
  running prompts); recommend it as a manual deep-dive instead.
- **Never push to main, never auto-merge.** `--apply` only commits to a branch.
- **Cost awareness.** A full sweep spawns 4+ research agents. For a quick check,
  suggest `--lenses gap,ux` (no web research). Mention the scope you ran.
