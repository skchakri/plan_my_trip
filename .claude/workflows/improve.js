export const meta = {
  name: 'improve',
  description: 'Self-improvement sweep for Plan My Trip: fan out gap/competitor/UX/trend lenses, dedupe + score into a ranked backlog, optionally apply safe fixes on a branch.',
  whenToUse: 'Run via /improve, or the daily autonomous "trip-coach" cron. Produces a ranked improvement backlog; with applyFixes it lands low-risk items on a branch (never main).',
  phases: [
    { title: 'Analyze', detail: 'gap / competitor / UX / trend lenses in parallel (Claude subscription; web research via WebSearch)' },
    { title: 'Score', detail: 'merge, dedupe, rank by impact x (6-effort) x confidence' },
    { title: 'Apply', detail: 'optional: improvement-fixer on safe top items, isolated worktrees, branch only' },
  ],
}

// ---- args (all optional) -------------------------------------------------
// { lenses?: string[], applyFixes?: boolean, maxFindings?: number,
//   maxFixes?: number, focus?: string }
const a = args || {}
const LENS_KEYS = a.lenses && a.lenses.length ? a.lenses
  : ['gap', 'competitor', 'ux', 'trend']
const MAX_FINDINGS = a.maxFindings || 40
const APPLY = a.applyFixes === true
const MAX_FIXES = a.maxFixes || 3
const FOCUS = a.focus ? `\n\nExtra focus for this run: ${a.focus}` : ''
// Model tiering: the four research/audit lenses run on Sonnet — they read code
// and do web research, which Sonnet handles well and which is the bulk of the
// fan-out cost. The Apply fixers (code-writing) keep the default (Opus). Override
// the cheap tier via args.cheapModel.
const CHEAP = (a.cheapModel || 'sonnet').toString()

// ---- structured-output contract every lens returns -----------------------
const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['lens', 'title', 'area', 'problem', 'recommendation',
          'fix_kind', 'impact', 'effort', 'confidence'],
        properties: {
          lens: { type: 'string', enum: ['gap', 'competitor', 'ux', 'trend'] },
          title: { type: 'string' },
          area: { type: 'string', description: 'file:line / route / feature it touches' },
          problem: { type: 'string' },
          evidence: { type: 'string', description: 'proof: grep result, competitor+URL, trend source+URL' },
          recommendation: { type: 'string' },
          fix_kind: { type: 'string', enum: ['copy', 'a11y', 'design', 'config', 'prompt', 'code', 'new-feature', 'data'] },
          impact: { type: 'number', description: '1-5 (5=blocks core flow / huge value)' },
          effort: { type: 'number', description: '1-5 (1=minutes)' },
          confidence: { type: 'number', description: '0-1' },
          refs: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
}

const LENSES = {
  gap: {
    agentType: 'gap-analyst',
    label: 'lens:gap',
    prompt: `Audit Plan My Trip for GAPS — dead-end/unreachable flows, half-built features, missing empty/error/loading/offline states, broken contracts (routes without actions, Turbo targets not in the DOM, policies that lock out offered UI), debt markers, and partial seed data. Read the real code and prove each gap with file:line. Return your full findings list.${FOCUS}`,
  },
  competitor: {
    agentType: 'competitor-scout',
    label: 'lens:competitor',
    prompt: `Research Plan My Trip's competitors on the live web (Wanderlog, TripIt, Roadtrippers, Layla, Mindtrip, Wanderboat, Google Travel, Kayak Trips, Tripadvisor, AllTrails). First inventory what WE already ship (read CLAUDE.md + routes) so you never re-propose it. Build a feature matrix, then propose the top buildable gaps mapped onto our Rails 8/Hotwire stack and Claude-subscription AI. Every competitor claim needs a URL. Return your full findings list.${FOCUS}`,
  },
  ux: {
    agentType: 'ux-auditor',
    label: 'lens:ux',
    prompt: `Audit Plan My Trip's UI/UX against docs/DESIGN_SYSTEM.md and WCAG AA: design-system drift (ad-hoc utility strings vs .btn/.chip), contrast failures (slate-500 text, the ~3.5:1 chip), missing labels/alt/focus, touch targets, responsive behavior, and missing interaction/loading states on async turbo-frames. Static pass over views + Stimulus; screenshot live pages only if a dev server is already up. Return your full findings list.${FOCUS}`,
  },
  trend: {
    agentType: 'trend-scout',
    label: 'lens:trend',
    prompt: `Scout emerging tech we should adopt — new Claude/Anthropic capabilities (verify model IDs via current docs, we use the Claude subscription / claude_cli), travel-tech data sources/APIs, and the Rails 8 / Hotwire / Turbo ecosystem (use context7 for version specifics). For each, propose how to wire it into our actual files/services/prompts. Cite 2025-2026 sources. Return your full findings list.${FOCUS}`,
  },
}

// ===========================================================================
phase('Analyze')
log(`Running ${LENS_KEYS.length} improvement lenses: ${LENS_KEYS.join(', ')}`)

const lensResults = await parallel(
  LENS_KEYS.map((key) => () => {
    const L = LENSES[key]
    if (!L) return Promise.resolve(null)
    return agent(L.prompt, {
      agentType: L.agentType,
      label: L.label,
      phase: 'Analyze',
      schema: FINDINGS_SCHEMA,
      model: CHEAP,
    })
  })
)

// ---- merge + dedupe + score ----------------------------------------------
phase('Score')
const raw = lensResults
  .filter(Boolean)
  .flatMap((r) => (r && Array.isArray(r.findings) ? r.findings : []))

const score = (f) => {
  const impact = Number(f.impact) || 0
  const effort = Math.min(5, Math.max(1, Number(f.effort) || 3))
  const conf = Number(f.confidence)
  const c = isNaN(conf) ? 0.6 : Math.min(1, Math.max(0, conf))
  return +(impact * (6 - effort) * c).toFixed(2) // higher = do sooner
}

// dedupe by normalized title+area; keep the higher-scoring duplicate
const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().slice(0, 80)
const byKey = new Map()
for (const f of raw) {
  const key = `${norm(f.title)}::${norm(f.area)}`
  const withScore = { ...f, score: score(f) }
  const prev = byKey.get(key)
  if (!prev || withScore.score > prev.score) byKey.set(key, withScore)
}

const ranked = Array.from(byKey.values())
  .sort((x, y) => y.score - x.score)
  .slice(0, MAX_FINDINGS)

log(`Collected ${raw.length} findings -> ${ranked.length} ranked after dedupe.`)

// ---- optional: apply the safest top items on a branch --------------------
let applied = []
if (APPLY) {
  const SAFE_KINDS = new Set(['copy', 'a11y', 'design', 'config', 'prompt'])
  const candidates = ranked
    .filter((f) => f.confidence >= 0.8 && f.effort <= 2 &&
      (SAFE_KINDS.has(f.fix_kind) || (f.fix_kind === 'code' && f.effort <= 2)))
    .slice(0, MAX_FIXES)

  if (candidates.length) {
    phase('Apply')
    log(`Applying ${candidates.length} low-risk fixes on branches (never main).`)
    applied = await parallel(
      candidates.map((f) => () =>
        agent(
          `Apply EXACTLY this one pre-vetted improvement and nothing else.\n\n` +
          `Title: ${f.title}\nArea: ${f.area}\nProblem: ${f.problem}\n` +
          `Recommendation: ${f.recommendation}\nfix_kind: ${f.fix_kind}\n\n` +
          `Honor your safety gate: if it's not genuinely low-risk, return status "deferred". ` +
          `Work on a branch, verify with lint/tests, commit, do NOT push or open a PR.`,
          {
            agentType: 'improvement-fixer',
            label: `fix:${norm(f.title).slice(0, 24)}`,
            phase: 'Apply',
            isolation: 'worktree',
          }
        ).then((res) => ({ finding: f, result: res }))
      )
    )
    applied = applied.filter(Boolean)
  }
}

// ---- return the backlog; the /improve skill writes the report + myjira ----
return {
  summary: {
    lenses: LENS_KEYS,
    rawCount: raw.length,
    rankedCount: ranked.length,
    appliedCount: applied.length,
    applyFixes: APPLY,
  },
  ranked,
  applied,
}
