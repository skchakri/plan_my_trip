# Plan: Consolidate Place / RouteLandmark / Activity

Status: **plan only — do not execute without approval**.
Owner: TBD. Estimated effort: 2–3 days, including migration safety.

## Why now

Three tables today represent "a real-world location" with overlapping schemas
and overlapping write paths:

| Table | Scope | Owner | Lat/Lng | Image | Narration | Notes |
|---|---|---|---|---|---|---|
| `places` | Global shared catalog | `contributed_by_id` (User, optional) | yes | yes | `description`, `famous_for` | Used across all trips; SEO landing at `/p/:slug`. |
| `route_landmarks` | Trip-scoped **or** global | `trip_id` (nullable since 2026-05-15) | yes (NOT NULL) | yes | `narration`, `wikipedia_url` | Drive Co-Pilot stops. "Global" rows have `trip_id=NULL`. |
| `activities` | Trip-scoped (via `trip_day_id`) | `trip_day_id` | yes (nullable) | `photo_url` | `notes`, `guide_script`, `famous_for` | The actual itinerary entries. Has `place_id` already. |

The reconciliation lives in `app/services/destination_highlights.rb` (444 LOC)
and in `Trip#nearby_global_landmarks` — both walk all three tables and dedupe
by name/coords. Every new write path (wizard, day-trip, AI seeder,
admin landmark editor, Places::Seeder) has to remember to update all three or
make the merge logic smarter.

## Target shape

One canonical table — **`places`** — owns location identity (name, coords,
kind, image, description). `route_landmarks` and `activities` become
*relationships to* a place, not duplicates of one.

```
places                          ← canonical location
  id, name, lat, lng, kind, image_url, description, famous_for,
  slug (SEO), contributed_by_id, discarded_at

place_narrations                ← optional, polymorphic, many-per-place
  id, place_id, kind ("drive_by" | "tour_guide" | "30s_radio"),
  body, wikipedia_url, source ("ai" | "human")

activities                      ← itinerary entries (UNCHANGED schema,
  ..., place_id NOT NULL          but place_id becomes required)

route_landmarks                 ← DROPPED. Replaced by:
trip_route_stops                ← which places to narrate on a given trip
  id, trip_id, place_id, position, source ("ai" | "user" | "global_catalog")

global_route_stops              ← marquee landmarks worth narrating on
  id, place_id, regions[]         any trip that passes within radius.
                                  Replaces the trip_id=NULL rows in
                                  route_landmarks.
```

Trade-off: introduces a join hop on the Drive Co-Pilot read path
(`trip_route_stops → places`) but saves the dedupe logic and keeps a single
authoritative copy of every location's coordinates / image / description.

## Migration phases

1. **Backfill `places` from existing `route_landmarks`.** For each landmark,
   find-or-create a `Place` by `(name, lat±300m, lng±300m)`. Write the
   resulting `place_id` to a new `route_landmarks.place_id` column. Verify
   100% coverage; manually reconcile mismatches.
2. **Dual-write.** New landmarks go through `Places::Seeder` → returns
   `Place`, then a `RouteLandmark` row is created pointing at it. Existing
   reads still hit `route_landmarks` directly.
3. **Switch reads.** Update `Trip#nearby_global_landmarks` and
   `app/services/route_landmarks_builder.rb` to read via `places + trip_route_stops`.
   Update `DestinationHighlights` to source from `places` only and drop its
   internal dedupe pass. Keep `route_landmarks` legible behind a thin
   facade so old admin views still work.
4. **Drop legacy.** Remove `route_landmarks` table, delete the facade,
   delete the dedupe logic in `destination_highlights.rb`.

Each phase is independently shippable + reversible.

## Test surface needed *before* phase 1

- `DestinationHighlights` golden-output test for a known destination (e.g.
  Hanksville). Pin to a fixture so phase-3 refactor doesn't change the
  user-visible highlight set.
- `Places::Seeder` idempotency test: seeding the same name twice returns
  the same row.
- `Trip#nearby_global_landmarks` integration test with a fixture of
  trip-scoped + global landmarks; assert ordering + dedupe.
- Drive Co-Pilot endpoint test (controller spec — copilot / copilot_question
  / copilot_response on `trips_controller`).

Right now the AI services have **0 tests**. Phase 1 cannot start safely
without these.

## Open questions

- **Slug strategy.** `places.slug` already exists for SEO. After consolidation,
  `place.slug` is the only stable URL. Trip-scoped narration variants don't
  need slugs.
- **Per-user community ratings.** Already on `place`. Stays.
- **Image dedupe.** Today `Trip#cover_image_url` already de-dupes within a
  trip. Once `activity.place_id` is required, `activity.photo_url` becomes
  an override that can be removed in most cases.
- **AI prompt impact.** `regional_places_research.v1` writes to `places`
  directly. `route_landmarks.v1` writes to `route_landmarks`. After
  consolidation, both write to `places`, with the latter additionally
  writing a `place_narrations` row.
- **`destination_highlights.v1`.** Today returns ephemeral highlights merged
  on read; once `places` is canonical, the AI's "trip-report-only" hits
  can be persisted as `places` rows with `tier="hidden_gem"` instead of
  living only in cache.

## Decision needed before executing

1. Adopt this target shape, or pick a different canonical (e.g. keep
   `route_landmarks` as canonical and drop `places`)?
2. Acceptable to have a 2-week dual-write window?
3. SEO impact: `/p/:slug` URLs MUST remain valid through the migration.
