# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Plan My Trip — a trip-planning app: users sign up, create trips, share with
other users by email, rename a trip just for themselves, and link AllTrails
trails into the plan. Built as a Rails 8 + Hotwire web app with optional
Hotwire Native iOS and Android shells (web is the source of truth).

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
```

Demo login (after `db:seed`): `demo@example.com / password123`.

## Database

Hosted on the shared `dev_datastack` Postgres (localhost:5432, root/password).
Don't stand up another Postgres locally for this app. See workspace
`~/CLAUDE.md` for full connection details.

## Models

- **User** (Devise) — `name`, `email`, `alltrails_pro` boolean (self-declared).
- **Trip** — `owner` (User), `title`, `destination`, `start_date`, `end_date`,
  `body` (markdown), `discarded_at`. Owner relationship via `owner_id`.
- **TripMembership** — join between Trip and User with `role` (owner/member)
  and `custom_title` (per-user title override). Created automatically for
  the owner on Trip creation; created by `TripSharesController#create` for
  invitees.
- **Trail** — belongs_to Trip, with `name`, `alltrails_url` (validated to
  `alltrails.com`), `notes`, `position`. Nested-attribute editing via the
  Trip form.

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
