# Trip Planning Strategy

Distilled from the Vegas trip planning session (May 6, 2026). These are the
heuristics that produced a workable 4-day plan for a 6-person group with mixed
energy levels (kids + grandparents) in 100°F heat.

## 1. Constraint-first planning

Before suggesting activities, surface the hard constraints:

- **Group composition** — how many people, ages, mobility, dietary needs.
  Drives vehicle size, room count, restaurant choice, walking tolerance.
- **Travel windows** — start time, return-by time. Drives departure logistics
  and which days are "drive days" vs "activity days."
- **Climate** — heat/cold/rain shapes when activities happen, not just what.
  In Vegas: morning outdoor / midday indoor-AC / evening outdoor again.
- **Budget signal** — even unstated, infer from hotel/car preferences.

## 2. Pace by the slowest member, not the average

A plan that exhausts grandparents on day 1 ruins days 2-4. Specifically:

- One **anchor activity** per day. Build everything else around it.
- Build in **rest blocks** (pool, kitchen suite, AC mall) — these are not
  filler, they protect the anchor.
- Long drives count as a fatigue cost; don't pair them with high-energy
  activities the same day.

## 3. Split when interests diverge

Friday's split (wife + kids → Spy Ninjas; user + parents → Bellagio →
Forum Shops → Eataly) was the highest-value move of the session. Lessons:

- A split day requires a **regroup point** with a hard time and a fallback
  meeting spot ("at the LED orb on the south side").
- The split should **converge on something all-ages** (the Sphere show).
- Different transport per group is fine — minivan for the kids' group,
  Uber/walking for the parents' group.

## 4. Booking order

Book in order of **scarcity × time-sensitivity**:

1. Timed-entry attractions (Sphere) — sell out, fixed dates
2. Vehicle (minivan class is limited) — refundable rate first, re-shop later
3. Hotel (kitchen-suite inventory is thin for groups of 6)
4. Day-of activities (Spy Ninjas, High Roller) — book online for faster check-in
5. Restaurants — usually walk-in unless special

Always book **refundable** when possible, then re-shop closer to the date
(AutoSlash for cars, Costco Travel for hotels).

## 5. Hidden-cost defenses

The plan should pre-empt the gotchas the user won't think of:

- **Counter upsells** (CDW, prepaid fuel, GPS) — say no, but only after
  confirming credit card primary CDW coverage.
- **Resort fees / parking** — tell the user the all-in number, not the rack rate.
- **Lock-in surprises** (no phones on Skywalk, AC inside Sphere is 30°F cooler)
  — flag these *before* arrival, not as discovery.

## 6. Deliverable: mobile-first hybrid app

The session's final artifacts were two self-contained HTML files designed
as PWAs (Add to Home Screen). Why this format wins for trip planning:

- **Works offline** once loaded — critical at canyon edges with no signal.
- **Deep-links to native apps** — `maps://` for directions, `uber://` for
  rides, `tel:` for venue calls. One tap, no copy/paste.
- **Per-person tabs** with localStorage state — each family member checks
  off their own packing list without coordination overhead.
- **Single file = one share action** — text it as an attachment, done.
- **Color-coded per day/persona** — instant orientation, no reading required.

## 7. The "what would I forget" pass

Before declaring a plan done, run through:

- Cardigans/jackets for over-AC venues
- Cell-signal gaps — screenshot QR codes, download offline maps
- Charging — phone batteries die mid-day on tourist days
- Meds & snacks for the slowest member
- A backup meeting point if phones fail

These cost nothing to add and prevent specific failure modes.
