# Wanderply — Marketing Plan

*Prepared as if by the marketing exec. Date: 2026-07-18. Horizon: next 90 days, with a 12-month arc.*

---

## 0. The brutal one-paragraph truth

We have a **strong product and strong technical SEO**, **~0 users**, **a few founder-hours a week**, and **$0 media budget**. Every AI trip build costs real money, so *growth currently costs us money before it makes us any*. This is not a "spend to grow" plan — paid acquisition is off the table until there's a paid tier. This is a **compounding-assets plan**: build things once that keep pulling traffic and converting while we sleep, and make sure the one thing nobody else does is the first thing every visitor hears.

**The single bet:** *Wanderply narrates your road trip like a podcast — every stop, spoken, offline, in the car.* Lead with that. Everything else is proof.

---

## 1. Positioning

### The category
Not "AI trip planner" (crowded: Wanderlog, Layla, Mindtrip, Google). We enter through a **narrower, ownable door**: the **road-trip audio guide that plans itself**.

### Positioning statement
> For **road-trippers and family drivers** who want the trip to feel effortless and *alive*, **Wanderply** is the trip planner that **builds a day-by-day plan and then narrates every stop like a podcast you play on the drive — even with no signal.** Unlike Wanderlog or TripIt (silent lists) or Google (a map, not a companion), Wanderply turns the plan into an experience you *listen to*.

### The three-line message hierarchy (use everywhere, in this order)
1. **Hook (emotional):** "The drive is the trip. We narrate it."
2. **Mechanism (rational):** "Tell us where you're going — get a paced, day-by-day plan with famous en-route stops, then a spoken guide for each one that works offline."
3. **Proof (trust):** free to try, works on your phone, no app-store gate to start (PWA), and it plans around *your* must-dos, budget, and pace.

### What we deliberately do NOT lead with
The 16 trivia decks (they're an acquisition *channel*, not the pitch), the feature laundry list, "AI." AI is table stakes now; the **experience** is the differentiator.

---

## 2. Target segments (ICP)

Ranked by fit to the wedge and to $0 organic distribution.

| # | Segment | Why them | Where they are |
|---|---------|----------|----------------|
| **1** | **US road-trippers** (national parks, coast drives, Route 66 types) | The drive *is* the product; narration + offline is decisive when there's no signal in a canyon | r/roadtrip, r/nationalparks, Pinterest, Google ("X to Y road trip itinerary") |
| **2** | **Family / multi-gen trip organizers** | One person plans for everyone; must-dos, pace, and shared plans matter; kids + trivia decks in the car | Facebook trip-planning groups, Pinterest, parenting/travel blogs |
| **3** | **AllTrails-style outdoorsy planners** | We link trails + trailhead elevation/distance; offline is life-or-death useful | AllTrails-adjacent, r/hiking, r/CampingandHiking |
| **4** | **Trivia/quiz searchers (top-of-funnel, not buyers yet)** | Huge search volume; our free front door; convert a slice into planners | Google ("guess the flag quiz"), Pinterest |

**Primary focus for the next 90 days: Segment 1 (road-trippers).** It's the tightest match to the only differentiator we can't be copied on quickly, and it maps to searchable, evergreen queries.

---

## 3. Channel strategy — compounding assets only

The constraint filter: *does this keep working after I stop touching it?* If no, it's out.

### A. Programmatic + editorial SEO (the engine) — **highest priority**
We already have 130 place pages, blog, schema, sitemap, llms.txt. The gap is **intent-matched landing content** for how people actually search.

- **Route pages** — "The perfect **[Origin] → [Destination]** road trip" (e.g. *San Francisco → Las Vegas*). Each page = the plan preview + en-route stops + "listen to it on the drive" CTA + weather + a sample narration clip. These match the exact evergreen query and show the wedge in the first scroll. **Start with 10 flagship routes**, templated so more are cheap.
- **Quiz decks** — already public + sitemapped. This is our widest crawl surface ("guess the flag quiz" >> "AI trip planner"). Job now: **capture and route** that traffic (see §4 funnel).
- **"Things to do between X and Y" / "stops on the way"** long-tail — we literally compute this. Turn it into indexable content.

**AI-crawler SEO (GEO/AEO):** we have `llms.txt` and AI-tuned robots. Double down — ChatGPT/Perplexity/Claude increasingly *are* the search box for "plan me a trip." Ensure our route + place pages are clean, factual, and citable. This is a compounding moat most competitors ignore.

### B. Pinterest — **second priority, best effort/return for this ICP**
Travel + itineraries + packing lists are Pinterest-native and evergreen (a pin drives traffic for *years*). We already have shareable itinerary/packing artifacts and a strong visual landing language ("travel ephemera"). Turn each flagship route + each packing list into pinnable images that link to the route page. Zero paid, high compounding.

### C. Community seeding (founder's own voice) — **credibility, not scale**
r/roadtrip, r/nationalparks, r/hiking, relevant FB groups. Rules are strict; **do not spam links.** The move: genuinely answer "help me plan X→Y" threads with a real, useful itinerary, and mention the tool honestly where it's allowed. This can't be automated and can't be delegated — it needs the founder's account and voice. Budget it as ~30 min/week, not a growth hack.

### D. Product-as-marketing (built-in loops)
- **Sharing:** trips are shareable by email and plans render offline — every shared trip is an impression. Make the share surface show the brand + a "make your own" CTA.
- **Quiz "share your score"** → social proof + link back.
- **Guest score CTA** at quiz completion (already live) — this is our conversion moment; keep optimizing it.

### E. Explicitly deferred (revisit post-monetization)
Paid ads, influencer/creator deals, PR pushes, newsletter sponsorships. All require budget or hours we don't have, and none compound. Not now.

---

## 4. The funnel — where we're actually leaking

The problem was never traffic quality; it's that **top-of-funnel (quizzes) and bottom-of-funnel (trip builds) aren't connected**, and **we can't see any of it** (analytics inert).

```
CRAWL/SEARCH → Quiz deck / Route page → [engage] → Sign-up CTA → Create trip → Build → Share → Loop
     (free)        (front door)        (peak)      (convert)     (activate)  ($cost)  (viral)
```

**Fix the connective tissue, in order:**
1. **Instrument first (can't optimize blind).** Founder must: create PostHog account → paste key at `/admin/app_settings`; verify wanderply.com in Google Search Console → submit `/sitemap.xml`. **Until these two things happen, nothing else in this plan is measurable and nothing gets indexed.** These are the #1 and #2 tasks.
2. **Route quiz traffic to the wedge.** After a deck, don't just offer sign-up — offer *"Planning a trip? Hear a stop narrated →"* with a 20-second sample. Convert trivia curiosity into a taste of the actual product.
3. **Make the sign-up CTA fire at peak engagement** (deck completion, route-page scroll-depth) — already partially done via `guest: true`.
4. **Activation = first build, not sign-up.** The magic moment is hearing the first narrated stop. Guide new users straight into one flagship pre-built trip they can *listen to immediately* (no build cost, instant wow) before asking them to build their own.

### North-star metric
**Weekly Activated Trips** = trips built *and* whose plan/narration was opened. Sign-ups are vanity; a played narration is the product landing.

### Supporting metrics (the weekly dashboard)
- Organic sessions (Search Console impressions → clicks)
- Quiz → sign-up conversion %
- Sign-up → first-build (activation) %
- Trips shared / viral coefficient
- **Cost per built trip** (watch this like a hawk — see §6)

---

## 5. The 90-day plan (phased, hour-budgeted)

Assume **~4–6 founder hours/week**. Ruthless sequencing.

### Phase 0 — Instrument & index (Week 1) — *~3 hrs, mostly founder clicks*
- [ ] PostHog account + key in `/admin/app_settings`
- [ ] Google Search Console verify + submit sitemap
- [ ] Confirm `TRIP_BUILD_DAILY/MONTHLY_LIMIT` are set sanely **before** any traffic (they gate cost — raise deliberately, not reactively)
- [ ] Baseline snapshot: current impressions, sessions, sign-ups (likely ~0 — that's the point, it's our zero line)

**Gate:** do not drive traffic until analytics + Search Console are live. Blind growth wastes the few hours we have.

### Phase 1 — Build the front doors (Weeks 2–5)
- [ ] Ship **10 flagship route pages** (templated) — pick the 10 most-searched US road-trip corridors (SF→Vegas, LA→Grand Canyon, Denver→Moab, Seattle→Portland, Chicago→Route 66, etc.)
- [ ] Each: plan preview + en-route stops + **embedded 20s sample narration** + weather + "Build your version" CTA
- [ ] Wire **quiz-completion → wedge CTA** (sample narration, not just sign-up)
- [ ] Add **one pre-built, instantly-playable demo trip** as the new-user activation on-ramp

### Phase 2 — Distribution & capture (Weeks 6–9)
- [ ] Pinterest: 10 route pins + packing-list pins, linked to route pages (set up once, pin weekly)
- [ ] Founder community cadence: 1–2 genuine, high-value itinerary answers/week in r/roadtrip etc.
- [ ] "Share your quiz score" + branded share cards for trips
- [ ] First read of PostHog funnel data → fix the biggest leak

### Phase 3 — Monetize & measure (Weeks 10–13)
- [ ] Stand up a **paid tier** (see §6) — even a simple one — so growth stops being a pure cost center
- [ ] Double down on whichever route pages / decks show real organic clicks in Search Console (expand the winners)
- [ ] Publish a "state of the funnel" review; decide what to cut vs. scale for the next quarter

---

## 6. Monetization — the plan is incomplete without this

**This is the strategic risk, not a footnote.** Free product + per-build AI cost means *every success costs us money*, and `BuildQuota` (3/day, 15/month) is a stopgap that also throttles the very growth we want. We cannot run a traffic push into an uncapped, unmonetized cost.

**Recommended model: freemium with the cost-bearing action behind the paywall.**
- **Free:** quizzes (pure SEO magnet, ~$0 to serve), browse pre-built route/demo trips, 1–2 AI builds to taste the wedge.
- **Paid ("Wanderply Pro," target ~$5–9/mo or a per-trip unlock):** unlimited AI builds, full offline narration/podcast export, expense splitting, flight alerts, sharing with more travelers.

The narration/podcast wedge is *also the best paywall* — it's the highest-perceived-value, highest-cost feature. Charge for the thing that's both expensive to make and impossible to copy. **Get at least a minimal paid tier live in Phase 3**; until then, keep quotas tight and lead free users to the zero-cost surfaces (quizzes, pre-built demos).

---

## 7. Weekly operating cadence (fits "a few hours a week")

A repeatable ~4–5 hr week so this survives real life:

- **30 min — Measure:** check PostHog funnel + Search Console. One number to move this week.
- **2 hr — Build one asset:** one new route page, or improve the top-performing existing one.
- **45 min — Distribute:** pin 2–3 route/packing images to Pinterest; queue for the week.
- **30 min — Community:** one genuinely helpful itinerary answer in a relevant subreddit/group.
- **15 min — Cost check:** cost-per-built-trip and quota headroom. Adjust if creeping.

**Cut, don't add:** if a week is short, do Measure + one asset only. Compounding assets forgive skipped weeks; hustle channels don't — which is exactly why we chose these.

---

## 8. Risks & guardrails

| Risk | Guardrail |
|------|-----------|
| Traffic push → runaway AI bill | Quotas set + cost-per-build watched *before* Phase 2; paid tier by Phase 3 |
| Quiz traffic is the wrong audience (never buys) | It's cheap to serve and a crawl/brand surface; treat conversion as bonus, not the plan. Route pages carry the real intent |
| Building assets, not shipping (over-build trap) | Ship 10 *good-enough* route pages, not 1 perfect one. The prior failure mode was over-built product / under-built distribution — don't repeat it |
| Community self-promo backlash | Value-first, links only where allowed, founder's real voice — never automated |
| Big-player copies narration | Move now; deepen it (voices, offline export, personalization) while we're first. It's a hard, unglamorous feature they've skipped for years |
| Founder time evaporates | Cadence degrades gracefully to "measure + one asset"; nothing depends on daily attention |

---

## 9. The 12-month arc (one line each)

- **Q1 (now):** Instrument, ship route pages, connect the funnel, launch a paid tier. *Goal: first real organic sessions + first paying users + a measurable funnel.*
- **Q2:** Scale the winning route/quiz surfaces (50+ route pages), lean into AI-crawler citations, iterate the paywall. *Goal: repeatable organic → activation → revenue loop.*
- **Q3:** App Store / Play Store as a *conversion* surface for engaged web users (not top-of-funnel); deepen narration (voices, richer audio). *Goal: retention + word-of-mouth.*
- **Q4:** Evaluate first paid channel *only if* unit economics (LTV > CAC via the paid tier) finally justify it. *Goal: a growth channel we can actually afford.*

---

### TL;DR for the founder
1. **This week:** PostHog + Search Console. Nothing else counts until these are live.
2. **Lead with the podcast-narrated drive.** It's the only thing nobody else has — say it first, everywhere.
3. **Build route pages + capture quiz traffic** — compounding front doors, zero maintenance.
4. **Launch a paid tier by Phase 3.** Free + per-build cost is a leak we're pouring traffic into.
5. **Run the 4–5 hr/week cadence.** Assets over hustle, because hustle needs hours we don't have.
