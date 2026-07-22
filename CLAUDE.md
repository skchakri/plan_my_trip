# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Wanderply (wanderply.com) — a trip-planning app: users sign up, create trips,
share with other users by email, rename a trip just for themselves, and link
AllTrails trails into the plan. Built as a Rails 8 + Hotwire web app with optional
Hotwire Native iOS and Android shells (web is the source of truth). The Rails
application module is still named `PlanMyTrip` (internal identifier — renaming it
is a risky, no-user-value refactor, so it's intentionally left as-is).

## Stack

- **Web**: Rails 8.1, PostgreSQL (UUID PKs), Devise auth, Pundit authz,
  Discard soft-delete, Hotwire (Turbo + Stimulus), Tailwind CSS, Redcarpet
  for trip body markdown, Solid Queue / Solid Cache.
- **Native shells**: thin Hotwire Native wrappers around the same web URLs.
  iOS uses `hotwire-native-ios` (Swift / Xcode 15+). Android uses
  `dev.hotwire:core` (Kotlin / Android Studio + JDK 17).

## Layout

```
plan_my_trip/
├── app/                      # Rails app (controllers, models, views, policies)
├── config/                   # Routes, database.yml, devise/initializers
├── db/                       # Migrations + seeds (Vegas trip + 2 trails)
├── public/
│   ├── configurations/
│   │   ├── ios.json          # Hotwire Native path config — iOS
│   │   └── android.json      # Hotwire Native path config — Android
│   ├── vegas-trip-4days.html # Static PWA — pre-Rails artifact, kept live
│   ├── vegas-packing.html    # Static PWA — packing list
│   └── trips.html            # Static index of the PWAs
├── docs/
│   ├── STRATEGY.md           # Trip-planning heuristics (constraint-first, etc.)
│   └── TRIP_VEGAS_2026_05.md # Vegas itinerary in markdown — also seeded as a Trip
├── ios/                      # Hotwire Native iOS shell (Swift) — see ios/README.md
└── android/                  # Hotwire Native Android shell (Kotlin) — see android/README.md
```

## Commands

```bash
PORT=3010 bin/dev                # Dev server on port 3010 (port 3000 reserved)
bin/rails db:create db:migrate db:seed
bin/rails console
bin/rubocop                       # Lint
bin/brakeman --no-pager           # Security scan
bin/ci                            # Full CI pipeline (see below)
```

Demo login (after `db:seed`): `demo@example.com / password123`.

## Tests

Minitest (Rails default — no RSpec), under `test/`, mirroring `app/`
(`test/services`, `test/jobs`, `test/models`, ...). Fixtures in `test/fixtures`.

```bash
bin/rails test                              # Full suite (parallelized by CPU)
bin/rails test test/services/foo_test.rb    # One file
bin/rails test test/services/foo_test.rb:42 # One test by line number
```

**No-network AI seam:** tests never hit a live provider. `ActiveSupport::TestCase#with_fake_ai(body)`
(defined in `test/test_helper.rb`) swaps `Ai::Caller.call` for a fake returning a
canned `Ai::Result`, then restores it. Wrap any code that calls an AI provider in
it — pass a String or a Hash (auto-`to_json`'d). Don't reach for `minitest/mock`'s
`#stub` (dropped); use this seam.

**`bin/ci` does NOT run the test suite** — it runs `bin/setup`, RuboCop, the
Slate-contrast guard (`bin/check-slate-contrast`), bundler-audit, importmap audit,
and Brakeman (see `config/ci.rb`). Run `bin/rails test` separately.

## Database

Hosted on the shared `dev_datastack` Postgres (localhost:5432, root/password).
Don't stand up another Postgres locally for this app. See workspace
`~/CLAUDE.md` for full connection details.

## Models

- **User** (Devise) — `name`, `email`, `alltrails_pro` boolean (self-declared),
  `discount_memberships` jsonb (per-program booleans — see `User::MEMBERSHIPS`).
- **Trip** — `owner` (User), `title`, `destination`, `origin`,
  `start_date`, `end_date`, `traveler_count`, `body` (markdown),
  `pwa_plan_url`, `pwa_packing_url`, `discarded_at`. Owner via `owner_id`.
  Planning levers fed to the itinerary builder: `pace` (relaxed/balanced/
  packed), `budget` (shoestring/moderate/comfortable/luxury), `preferences`
  (free-form: dietary, accessibility, must-dos, avoids), `transport_mode`
  (own_car/rental/flying/mixed, labels in `TRANSPORT_MODE_LABELS`), and
  `must_includes` (jsonb array, capped at `MUST_INCLUDES_MAX`=12 —
  traveler-mandated anchors like "Disneyland — 2 days"; trip_structure.v1
  schedules every one honoring stated durations, and for drive modes + origin
  plans famous en-route stops as timed activities). Wizard step 1 collects
  both and mirrors them in a live right-rail summary
  (`wizard_summary_controller.js`, aria-live-safe diffed writes); the
  highlights step pre-selects + badges fuzzy-matched cards ("Disney" →
  "Disneyland Park", first visit only, saved selections never overridden) and
  lists unmatched favourites in an "Already in your plan" strip. Async build
  lifecycle: `build_status` (building/ready/failed, default ready), `build_error`.
- **TripMembership** — join between Trip and User with `role` (owner/member)
  and `custom_title` (per-user title override). Created automatically for
  the owner on Trip creation; created by `TripSharesController#create` for
  invitees.
- **TripInvitation** — pending invite for an unregistered email. Magic-link
  token; `accepted_at`/`declined_at`/`discarded_at`.
- **Trail** — belongs_to Trip, with `name`, `alltrails_url` (validated to
  `alltrails.com`), `notes`, `position`. Nested-attribute editing via the
  Trip form.
- **ChecklistItem** — belongs_to Trip, with `title`, `category`,
  `person`, `position`, `packed`. Used by the in-app checklist page at
  `/trips/:id/checklist` with Turbo Stream toggles.
- **Brand** — `name`, `category` ("car"/"airline"/"brand"), `slug`. Powers the
  logo decks; `Brand#logo_url` builds a Simple Icons URL
  (`cdn.simpleicons.org/<slug>`, free, no key, colored SVG mark). No binaries
  stored. Probe new slugs with curl before adding — Simple Icons removes many
  brands for trademark.
- **Country** / **UsState** / **Landmark** — curated reference data for Travel
  Trivia. One `Country` row carries many facts (`capital`, `iso2`, `continent`,
  `leader_title`/`leader_name`, `currency_name`, `primary_language`,
  `calling_code`, plus national `_anthem`/`_animal`/`_bird`/`_flower`/`_sport`/
  `_motto`/`_dish`); `Country#flag_url` builds flagcdn.com URLs from `iso2`,
  `Country#tld` derives the ccTLD, and `Country#fact_rows` is the ordered
  (label, value, icon) list the Country Explorer renders. `Landmark`
  (`name`, `country`, `continent`) powers the landmarks deck. See
  `## Travel Trivia`.
- **QuizAttempt** — belongs_to User; one row per finished quiz round
  (`category`, `score`, `total`). Drives per-category personal bests.

## In-app Plan + Checklist routes

- `GET /trips/:id/plan` — full-page mobile-optimized markdown render of
  the trip body. Cached by the service worker once visited.
- `GET /trips/:id/checklist` — sectioned checklist with progress bar +
  inline add form. Each row toggles via Turbo Stream
  (`POST /trips/:id/checklist_items/:id` with `packed=true|false`).

## Travel Trivia (general-knowledge quizzes)

A standalone quiz section at `/quizzes` — distinct from the trip-scoped
`TriviaQuestion` game played by travelers during a trip. Sixteen multiple-choice
decks: **World Capitals**, **U.S. State Capitals**, **Guess the Flag**,
**World Leaders**, **World Currencies**, **Famous Landmarks**, **World
Languages**, **Dialing Codes**, **Internet Domains** (ccTLD → country),
**Continents**, **National Anthems**, **National Birds**, **National Sports**,
**Car Logos**, **Airline Logos**, and **Famous Brands**. Adding a deck = a new
`QuizCatalog` category + builder (+ an accent in `QuizzesHelper::QUIZ_ACCENTS`);
most builders pull distractors from the same table grouped by continent, while
the landmark/TLD builders draw country-name distractors from `Country`.

**Questions are pre-generated and stored.** `QuizCatalog` is the *generator*;
`QuizQuestion` (table `quiz_questions`, `category` + JSONB `payload`) is the
stored bank — one row per source entity per deck (~1,500 rows). `QuizQuestion.rebuild!`
clears and regenerates from reference data via `QuizCatalog.build(key, count:
pool_size)`; run it with `rake quiz:rebuild` or `db:seed` **after changing any
reference data** (countries/brands/etc.), else the bank is stale. `show` serves
`QuizQuestion.sample_for_play(key, 10)` (random rows' payloads) — no on-the-fly
generation. `payload` is format-agnostic so text/single-image/four-image decks
all store identically.

**Offline (PWA).** The service worker (`app/views/pwa/service-worker.js`, bump
`VERSION` to roll out) caches `/quizzes*` pages (network-first) and the flag/logo
CDNs `flagcdn.com` + `cdn.simpleicons.org` (cache-first, immutable). A "Save all
decks for offline" control on the quiz index (`offline_quizzes_controller.js`)
fetches `GET /quizzes/offline` (deck-page URLs + all flag/logo image URLs) and
posts a `PRECACHE_QUIZ` message so the SW pre-downloads everything — all 16 decks
then play with no connection.

**Two question formats.** Most decks are *text options* (`options: [..]`). The
car/airline logo decks set `image_url` + `logo: true` (a single logo on a light
card → text options). **Famous Brands** is the flipped *image-options* twist:
the prompt names a brand and the four options are logos — the builder emits
`option_images: [..]` + `option_labels: [..]` (labels for a11y + recap) and the
player renders a 2×2 grid of tappable logo cards. The Stimulus controller
branches on `Array.isArray(q.option_images)`. The TLD deck needs no stored data (`Country#tld`
derives from `iso2`, except the UK's `.uk`); continents reuses the `continent`
column. A `Category` may carry a `note:` (e.g. the leaders "as of #{LEADERS_AS_OF}"
and the national-sports "official where one exists" caveats) shown under the deck title.

**Country Explorer** (`GET /quizzes/explore`, `QuizzesController#explore`) — a
country picker (a `<select>` that auto-navigates via the `auto-submit` Stimulus
controller, `?c=<iso2>`) renders a fact-sheet of *all* a country's national data
from `Country#fact_rows`. Defaults to the US. Route is declared **before**
`quizzes/:category` so `explore` isn't read as a deck key. Linked from the
quizzes index banner and the account dropdown.

- **`QuizCatalog` (`app/services/quiz_catalog.rb`)** — the deck registry (code,
  not DB) + question builder. `CATEGORIES` defines each deck's metadata
  (title/tagline/icon/accent). `build(key, count: 10)` generates fresh questions
  on every play from a random sample of the seed data, so a round never feels
  memorized. Distractors prefer the same continent (capitals/flags) or same
  office (leaders) for plausibility, then fall back to the wider pool; options
  are deduped by display value. Returns plain hashes:
  `{ prompt:, image_url:, flag_thumb:, options: [4], answer_index: }`.
- **Seed data** lives in `db/seeds/geography.rb` (loaded by `db:seed`):
  ~176 countries (170 dialing codes, 136 currencies, 128 languages, 45 anthems,
  35 leaders, 33 national birds, 26 national sports) + 50 states + ~48 landmarks.
  National symbols (`NATIONAL_SYMBOLS`) are filled only where confidently known
  so partially-populated countries degrade gracefully in the Explorer. Logo-deck
  brands live in `db/seeds/brands.rb` (~37 cars, ~28 airlines, ~55 famous
  brands) — slugs verified against Simple Icons (brands removed there for trademark, e.g. Mercedes-Benz,
  are simply omitted). `leader_name` is hand-curated as of
  `QuizCatalog::LEADERS_AS_OF` (surfaced in the leaders deck UI); re-running the
  seed refreshes leaders in place (idempotent upsert on `iso2` / `abbreviation`).
- **`QuizzesController`** — `index` (deck grid + personal bests), `show`
  (renders the player), `record` (`POST /quizzes/:category/attempts`, persists a
  `QuizAttempt`). No Pundit policy — these are global reference quizzes.
  **Playing is public and must stay that way**: `index`/`show`/`explore`/
  `offline` skip `authenticate_user!`, are listed in `sitemap.xml`, and each deck
  carries its own title/description/canonical + `schema.org/Quiz`
  (`QuizzesHelper#quiz_seo_*`). The decks are the app's widest organic-search
  surface — people search "guess the flag quiz" far more than "AI trip planner" —
  so a login wall here hides ~1,500 ready-made questions from crawlers and
  first-time visitors. `record` is public too but answers guests
  `{ ok: false, guest: true }` (never a 401, which the player would read as a
  failed save and retry) so finishing a deck surfaces a sign-up CTA at peak
  engagement; scores only persist for signed-in users. Best %/deck is
  `MAX(score*100.0/NULLIF(total,0))` grouped by category.
- **Player** is client-side (`app/javascript/controllers/quiz_controller.js`):
  the server embeds the questions (with answer keys) as a Stimulus Array value
  and the controller grades each tap with no round-trip — acceptable for casual
  trivia. It POSTs the final score once. Flag images come from **flagcdn.com**
  (free, keyed by lowercase ISO-3166 alpha-2; no API key). Per-deck accent
  classes are in `QuizzesHelper::QUIZ_ACCENTS` as full literal strings so the
  Tailwind v4 scanner compiles every variant.

## PWA / offline

- `app/views/pwa/manifest.json.erb` — theme/colors/icons + "All trips"
  and "New trip" home-screen shortcuts. Linked from the layout via
  `pwa_manifest_path(format: :json)`.
- `app/views/pwa/service-worker.js` — versioned caches:
  - **Pages** (`/`, `/trips/...`): network-first, falls back to last
    cached HTML when offline. Once a trip page is visited online, it's
    available offline.
  - **Assets** (`/assets/*`, fonts, icons): stale-while-revalidate.
  - **Auth flows** (`/users/sign_*`, `/invitations/*`): never cached.
- Service worker registers from the `<head>` script in the application
  layout; bump the `VERSION` constant in `service-worker.js` to roll
  out cache changes.

## Services

- **`BookingLinks` (`app/services/booking_links.rb`)** — given a Trip
  (and optionally a viewing User), emits hotel/car/flight/activity search
  URLs with member-rate badges where the viewer has the relevant program.
  No scraped promo codes — only real recurring offers (Hilton Honors,
  Marriott member rate, Booking.com Genius, Costco Travel, AAA, AARP,
  Best Price Guarantee, AutoSlash). Card travel portals (Chase / Amex /
  Cap One) are surfaced as a separate "stack points" panel when the
  viewer marks the relevant card.

- **`NearbyIdeas` (`app/services/nearby_ideas.rb`)** — day-trip research:
  catalog hits (`Place.near`) merged with an LLM list (`nearby_ideas.v1`
  prompt). LLM-returned coordinates are *verified* through
  `Places::Geocoder` (OSM Nominatim, free) when they're missing or land
  outside the radius — budgeted to `GEOCODE_BUDGET` lookups/call so the
  Nominatim 1-req/sec policy is respected. Then ranked by `PlaceRanker`.
- **`Places::Geocoder` (`app/services/places/geocoder.rb`)** — name → real
  lat/lng via Nominatim, anchor-viewbox-biased, cached 90 days. The
  coordinate source of truth (LLMs hallucinate coords).
- **`WeatherReport` (`app/services/weather_report.rb`)** — per-day weather
  for a trip's dates via Open-Meteo (free, no key). Dates within 16 days get
  the live forecast (cached 3h); further out, "typical conditions" averaged
  from the same calendar dates over the past 3 years of archive data (cached
  30d); past dates get recorded actuals. Rendered by `trips/_weather` into
  lazy frames on trips/show (`GET /trips/:id/weather`) and the wizard review
  step (`GET /trip_wizard/weather`, which reuses the draft's geocoded
  coords). Always rescues to nil → the frame collapses to nothing.

### AI providers & the Perplexity option

AI calls go through `Ai::Caller` → a per-prompt provider (`AiPrompt.provider`):
`anthropic`, `openai`, `claude_cli`, or **`perplexity`**. The provider is a DB
field, so an admin can swap it per-prompt (`/admin/ai_prompts`) with no
redeploy.

**Prompts are code-first, DB-served.** The source of truth is one YAML per slug
in `db/ai_prompts/*.yml` (system/user templates are ERB rendered by
`AiPrompt#render`). `db/seed_ai_prompts.rb` (run by `db:seed`) upserts each YAML
into the `ai_prompts` table by slug, idempotently. So: **edit the YAML, then
reseed** to change a prompt in code; the `/admin/ai_prompts` UI is for live,
no-redeploy tweaks (which a reseed on the same slug will overwrite). `Ai::Caller`
logs every call to the `AiCall` model (viewable at `/admin/ai_calls`).

- `claude_cli` (current default for `nearby_ideas.v1`) — uses the operator's
  Claude subscription via the local CLI with agentic web search. Best
  instruction-following, but **slow (minutes)** and unfit for the live web
  path at scale. Good for seeding.
- `perplexity` (`Ai::PerplexityProvider`, needs `PERPLEXITY_API_KEY`) — Sonar
  models answer from a fresh web search in **one fast API call** with
  citations. Flip `nearby_ideas.v1` to `provider: perplexity, model: sonar`
  to trade some JSON-contract strictness for seconds-not-minutes latency.
  `anthropic`/`openai` providers do **not** enable web search (training-data
  only), so don't point a freshness-sensitive prompt at them.

Day-trip suggestions load **async**: `/day_trips/suggestions` renders a shell
with a lazy turbo-frame whose `src` is `/day_trips/suggestions_results`; that
frame runs the (slow) research so the page never blocks on it. Day-trip
**creation** is also async, mirroring the multi-day wizard: `DayTripsController#create`
persists a `build_status: "building"` shell + `BuildDayTripJob`, which re-derives
the chosen ideas (cached `NearbyIdeas`) and runs `Trips::DayAssembler`.

### Multi-day trip creation is async (BuildTripJob)

`Trips::WizardController#create` does **not** run the AI inline. It persists a
Trip *shell* with `build_status: "building"` (+ travelers), enqueues
`BuildTripJob`, and redirects immediately. The job runs `Trips::Assembler`
(`app/services/trips/assembler.rb`) — `TripStructureBuilder` → coordinate-fill
via `Places::Geocoder` → TripDay/Activity/ChecklistItem/RouteLandmark rows →
markdown `body` derived deterministically by `MarkdownItinerary` (no separate
itinerary AI call) — then flips `build_status` to `ready`/`failed` and
`broadcast_refresh_to(trip)`. Per-stop spoken **`guide_script` narrations are NOT
built inline** (they used to dominate the output tokens): `trip_structure.v1`
omits them, and `BuildTripJob` (and the day-trip `DayTripsController#create`) enqueue
`BackfillTripNarrationsJob`, which **fans out one `NarrateActivityJob` per blank
activity** (concurrent across Solid Queue workers); each fills its narration via
`ActivityNarrator` (`activity_narration.v1`, Anthropic) off the critical path —
so the plan is viewable ~35% sooner and the podcast/Drive Co-Pilot (which degrade
gracefully while blank) enrich within ~a minute. `Ai::Caller` dedupes identical
narrations across trips. Both `trip_structure.v1` and `day_plan.v1` omit inline
`guide_script`s and run on the Anthropic API. `TripsController#show` renders `trips/building`
(which `turbo_stream_from @trip`) until ready; `POST /trips/:id/rebuild` retries
a failed build. `build_status` defaults to `"ready"` so existing/
manually-created trips are unaffected. Build inputs (selected slugs for
multi-day; selected idea slugs + q/depart/return for day trips) are persisted in
the `build_args` jsonb so `POST /trips/:id/rebuild` can replay the exact build
(it dispatches `BuildDayTripJob` for day trips, else `BuildTripJob`). `trip_structure.v1` + `destination_brief.v1`
now run on the **Anthropic API** (no web search needed; ~2 min for a 3-day plan
vs many minutes on claude_cli, and it's off-request anyway). Discovery prompts
that need fresh web data (`destination_highlights_research`, `route_landmarks`,
`nearby_ideas`) stay on `claude_cli`/`perplexity`. Swap any of these per-prompt
in `/admin/ai_prompts`.

The **highlights step (3 of 4) also lazy-loads**: `wizard/highlights.html.erb`
is a shell with a `turbo_frame_tag "wizard-highlights"` (`target: "_top"`) whose
`src` is `/trip_wizard/highlights/results`; that frame runs DestinationHighlights
+ DestinationBrief and renders `_highlights_body` (the whole Stimulus subtree +
modal, so controllers connect with a complete DOM). The picker's form submits
carry `data-turbo-frame="_top"` to navigate the full page to review.

## Settings (`AppSetting`) — API keys & affiliate IDs

All external secrets/IDs are managed at **`/admin/app_settings`**, backed by the
`AppSetting` model (key/value, values encrypted at rest via
`ActiveSupport::MessageEncryptor` keyed off `secret_key_base` — no AR-encryption
keys to provision). The catalog of settings is `AppSetting::REGISTRY` (add a row
there to expose a new key — no migration). Resolution order is
**`AppSetting.get(key)` → DB override → ENV → registry default**, so legacy
`.env` values still work as a fallback. `AppSetting.import_from_env!` (also run
by `db:seed`) lifts existing `.env`/process-env values into the DB; it parses
the `.env` file directly so it works outside foreman.

Consumers read keys via `AppSetting.get`: the AI providers
(`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `PERPLEXITY_API_KEY`), image search
(`PEXELS_API_KEY`, `UNSPLASH_ACCESS_KEY`, `PIXABAY_API_KEY`), `BookingLinks`
(the `AFFILIATE_*` IDs, resolved at request time), and `Places::Geocoder`
(`GOOGLE_PLACES_API_KEY`). **Exception:** `CLAUDE_CLI_PATH` stays ENV-only — it's
an executable path, so a web-editable value would be an RCE vector.

`Places::Geocoder` uses **Google Places Text Search** when
`GOOGLE_PLACES_API_KEY` is set (better POI matching, no 1-req/sec cap) and falls
back to free Nominatim otherwise.

**IP blocking** (`BLOCKED_IPS`, category "Security"): comma/space-separated IPs
or CIDR ranges denied with a 403 at the Rack::Attack layer (production only)
via `IpBlocklist` (`app/services/ip_blocklist.rb`) — parsed ranges are memoized
against the raw setting value, so admin edits apply live with no redeploy. A
Fail2Ban rule in `config/initializers/rack_attack.rb` also auto-bans any IP for
1h after 20 login POSTs in 10 min. The localhost safelist always wins over
blocklists, so you can't lock yourself out locally.

## Cost control (`BuildQuota`)

Every trip build fans out paid AI calls (`trip_structure.v1` + one
`activity_narration.v1` per stop), so spend scales with signups.
`BuildQuota` (`app/services/build_quota.rb`) caps AI-built trips **per
account** in a rolling 24h / 30d — the account-side companion to the
Rack::Attack **IP** throttles in `config/initializers/rack_attack.rb`
(which only guard anonymous traffic). Checked at the top of both build
paths (`Trips::WizardController#create`, `DayTripsController#create`)
**before** the shell + job are persisted. Admins are exempt. Counts run
against `owned_trips`, not `Trip.kept`, so discarding doesn't refund quota
(else delete-and-rebuild loops around the cap). Limits are
`TRIP_BUILD_DAILY_LIMIT` / `TRIP_BUILD_MONTHLY_LIMIT` in
`AppSetting::REGISTRY` — retunable at `/admin/app_settings`, no redeploy;
0/blank disables. **Raise these before any traffic push, not after.**

## Analytics (`POSTHOG_API_KEY`)

Opt-in product analytics. `layouts/_analytics.html.erb` renders nothing
unless `POSTHOG_API_KEY` is set at `/admin/app_settings`, so dev/test/CI
and un-keyed deploys serve no tracking script. Gotchas encoded there:

- It's rendered in **five layouts** (`application`, `marketing`, `auth`,
  `public`, `wallet`) — the sign-up funnel crosses marketing → auth →
  application, so wiring one layout breaks the funnel at the conversion
  step. `admin` is excluded on purpose (operator noise).
- Pageviews fire on **`turbo:load`** with `capture_pageview: false` —
  PostHog's built-in only fires on hard loads, which in a Hotwire app
  records the first page of a session and nothing after it.
- Users are identified by **UUID only**; email/name are never sent.
- **The privacy page is coupled to this.** `/privacy` reads the same
  `analytics_enabled?` helper (`app/helpers/analytics_helper.rb`) — with
  tracking off it claims no "analytics profiles"; with it on it discloses
  PostHog. Tests pin both states, so don't decouple them: turning tracking
  on must never leave the policy claiming otherwise.
- Costs one fixed `AppSetting` lookup per page render (Solid Cache is
  DB-backed) — hence the `trips#index` query budget is 27, not 26.

## Authorization

`TripPolicy` (Pundit) — `update?`, `destroy?`, `share?` are owner-only;
`show?` and `rename?` require an active membership; `Scope#resolve` returns
all kept trips the current user has access to via membership.

## Hotwire Native

- `app/helpers/hotwire_native_helper.rb` — `hotwire_native_app?` matches
  `User-Agent: Hotwire Native ...`. The web header in
  `app/views/layouts/application.html.erb` is hidden when this is true so
  the native nav bar takes over.
- `public/configurations/{ios,android}.json` — path rules:
  modal context for sign-in / sign-up / new trip / edit trip / share /
  account; default push for everything else.
- The native apps fetch the path config on each launch — change navigation
  in those JSON files without rebuilding the APK / IPA.

## Adding a new trip (programmatically — for seeding)

```ruby
trip = user.owned_trips.create!(
  title: "...", destination: "...",
  start_date: ..., end_date: ...,
  body: File.read("docs/TRIP_X.md")
)
trip.trails.create!(name: "...", alltrails_url: "https://www.alltrails.com/trail/...")
trip.trip_memberships.create!(user: another_user, role: "member")  # share
```

## Conventions

- UUID primary keys for every new table (`config/initializers/generators.rb`).
- Soft delete via `discarded_at` (Discard gem) — use `Trip.kept` in queries.
- Per-user title via `Trip#title_for(user)` — uses `TripMembership.custom_title`
  if set, falls back to `Trip.title`.
- The two static PWAs in `public/` (vegas-trip-4days.html, vegas-packing.html)
  predate the Rails app and are kept as-is — they're shareable, offline-capable
  artifacts. The Rails app renders the same trip data dynamically.
