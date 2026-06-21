# Trip Coach — self-improvement system

An autonomous-capable loop that keeps making **Plan My Trip** better: it reads the
app, watches competitors and emerging tech, audits the UI, ranks what to do next,
and (optionally) lands the safe fixes on a branch for review. Everything runs on
the **Claude subscription** — no metered API keys are touched.

## Parts

| Piece | Path | Role |
|---|---|---|
| `/improve` skill | `.claude/skills/improve/SKILL.md` | Entry point: runs the workflow, writes the report, files myjira tasks |
| `improve` workflow | `.claude/workflows/improve.js` | Fans the lenses out in parallel, dedupes, scores, optional fix phase |
| **gap-analyst** | `.claude/agents/gap-analyst.md` | Finds dead-ends / half-built features / missing states (reads code) |
| **competitor-scout** | `.claude/agents/competitor-scout.md` | Feature-vs-us matrix + buildable gaps (live web) |
| **ux-auditor** | `.claude/agents/ux-auditor.md` | Design-system + WCAG AA audit (views + Stimulus, optional screenshots) |
| **trend-scout** | `.claude/agents/trend-scout.md` | Emerging AI / travel-tech / Rails-Hotwire → "apply it here" |
| **improvement-fixer** | `.claude/agents/improvement-fixer.md` | Lands ONE vetted low-risk fix on a branch (never main) |
| Reports | `docs/improvements/REPORT-<date>.md` | The ranked backlog, one per run — the diff over time is the signal |

Each lens agent is independently runnable: `@gap-analyst find dead ends in the
trip wizard`, `@competitor-scout how do we compare to Wanderlog?`, etc. The
existing `@ai-prompt-tuner` covers AI-prompt quality (run it manually — it spends
API tokens, so it's deliberately *not* in the auto loop).

## Scoring

`score = impact × (6 − effort) × confidence` — high impact, low effort, high
confidence floats to the top. Findings are deduped by normalized title+area.

## Usage

```bash
/improve                      # full sweep → ranked report + myjira tasks
/improve --lenses gap,ux      # fast, no web research
/improve --focus "the trip wizard"
/improve --apply              # also land the safest top items on a branch
@gap-analyst ...              # run a single lens directly
@improvement-fixer apply #3   # land one specific finding
```

## Autonomy tiers (why it's safe to run unattended)

The product is still maturing, so autonomy is **deliberately capped at analysis**:

- **Tier 0 — Observe (default, what the daily cron does).** Read-only on the
  codebase. Produces the ranked report + files myjira tasks. Zero risk: it never
  edits app code, never touches `main`, never spends metered API tokens.
- **Tier 1 — Propose-and-stage (`--apply`).** `improvement-fixer` lands only
  low-blast-radius items (copy, a11y, design, config, prompt-instruction, tiny
  code) on a **branch**, runs lint/tests, commits — and stops. A human reviews
  and merges. Refuses migrations, auth/policy, deps, refactors, new features.
- **Tier 2 — Auto-PR (manual opt-in, later).** Flip the cron to `--apply` and
  add a `gh pr create --draft` step once you trust Tier 1's output.

Promotion is your call: start at Tier 0, watch a few reports, then enable `--apply`
when the suggestions are consistently good.

## Daily autonomous run

Tier 0 runs daily at **6:53 AM local**. Two ways to drive it, by how unattended
you need it:

**A. In-session cron (set up now, job `be1ddeb2`).** Created via Claude Code's
`CronCreate`. Convenient, subscription + local myjira + local repo all reachable.
**Caveats:** it only fires while a Claude Code session is alive and idle, and
recurring jobs **auto-expire after 7 days** — so re-arm it weekly (just ask, or
re-run the cron line). Inspect/cancel with `CronList` / `CronDelete` (or
`/schedule`). Good for the "I'm actively developing this most days" phase.

**B. OS-level cron for true unattended runs (when you want it to fire even with
no session open).** Use the headless Claude CLI on a real system cron — survives
reboots, no 7-day expiry, still on your subscription + localhost myjira:

```cron
# crontab -e  — daily 6:53am Trip Coach sweep, read-only (Tier 0)
53 6 * * * cd /home/kalyan/platform/skchakri/plan_my_trip && \
  claude -p "/improve" >> log/trip_coach.log 2>&1
```

A cloud `/schedule` routine is the third option but **loses localhost myjira and
`claude_cli`**, so it's not recommended while those are dependencies.

Switch any of these to weekly (`53 6 * * 1`) or turn them off once the backlog
stabilizes and you move to on-demand — that was always the plan.

## What this loop intentionally can't see yet

There is **no product analytics** in the app (no Ahoy/PostHog/Mixpanel), so the
loop reasons from code + competitors + trends, not from *where real users drop
off*. Adding lightweight self-hosted analytics (Ahoy fits the Rails 8 / Postgres
stack) is the single highest-leverage upgrade to make this loop data-driven — at
which point a fifth "funnel-analyst" lens becomes worthwhile.
