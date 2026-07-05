# Wanderply — Promotional Video Scripts

Ready-to-shoot scripts for promoting **Wanderply** (wanderply.com) — the AI
trip-planning app. Each script pairs a **voiceover / on-screen line** with a
**concrete screen to capture** so you know exactly what to record from the live
app. Capture at `wanderply.com` logged in as a demo user (or `demo@example.com`
after `db:seed`).

> **Recording tips**
> - Record the web app in a phone-sized viewport (390×844) for vertical clips and
>   1280×720+ for landscape. The layout is mobile-optimized, so phone framing looks great.
> - Screen-record the **async build animation** live — the "building your trip"
>   shimmer → itinerary reveal is the single most impressive moment. Don't fake it.
> - Grab the **native app** (iOS/Android Hotwire shells) for at least one shot so
>   it reads as "a real app," not just a website.
> - Keep cursor/finger movement deliberate and slow — you'll speed clips up in the edit.

---

## 1. Hero Ad — 30 seconds ("Plan a whole trip in one sentence")
**Use:** paid social, YouTube pre-roll, website hero loop. Punchy, one big promise.

| # | Time | On-screen / VO | Screen to capture |
|---|------|----------------|-------------------|
| 1 | 0:00–0:03 | **VO:** "Planning a trip used to mean twenty browser tabs." | Fast montage: cluttered tabs, a spreadsheet, sticky notes (stock B-roll) |
| 2 | 0:03–0:07 | **VO:** "Now it takes one sentence." **Text:** *Wanderply* | Wanderply logo animates in on brand-colored background |
| 3 | 0:07–0:13 | **VO:** "Tell it where you're going…" | New-trip wizard: type destination "Lisbon, Portugal", set dates + travelers, pick pace **Balanced** / budget **Moderate** |
| 4 | 0:13–0:18 | **VO:** "…and Wanderply builds the whole plan." | **Live capture** of the async build: "Building your trip" shimmer → itinerary streams in |
| 5 | 0:18–0:24 | **VO:** "Day by day. Every stop. Ready to go." | Scroll the finished `/trips/:id/plan` page — day headers, activities, map |
| 6 | 0:24–0:28 | **VO:** "Share it, pack for it, and never miss a thing." | Quick cuts: share-by-email modal → checklist page with progress bar filling |
| 7 | 0:28–0:30 | **Text:** *Wanderply.com — Your trip, planned.* | Logo + URL end card |

---

## 2. Feature Walkthrough — 60 seconds ("From idea to itinerary")
**Use:** landing page explainer, app store long-form, onboarding email.

**[0:00] Hook**
> **VO:** "This is Wanderply. Watch me plan a four-day trip to Lisbon — start to finish — before this video ends."
> **Screen:** Landing page, then click **New Trip**.

**[0:06] Step 1 — Describe it**
> **VO:** "I just tell it the basics: where, when, who's coming, and how I like to travel — relaxed or packed, shoestring or luxury."
> **Screen:** Fill the wizard. Linger on the **pace** and **budget** selectors and the free-form **preferences** field ("vegetarian, love viewpoints, no early mornings").

**[0:16] Step 2 — Highlights**
> **VO:** "Wanderply researches the destination and shows me the highlights worth building a trip around."
> **Screen:** Highlights step (3 of 4) lazy-loading in, cards with photos, tap a couple to select.

**[0:26] Step 3 — It builds**
> **VO:** "Then it does the hard part — assembling a real, day-by-day itinerary with directions, timing, and local picks."
> **Screen:** **Live** build animation → `trips/building` → itinerary ready.

**[0:36] Step 4 — The plan**
> **VO:** "Here's the whole thing. Every day mapped, every stop with a note on why it's worth your time."
> **Screen:** Scroll the plan page; pause on the map + a day's activities.

**[0:44] Extras that matter**
> **VO:** "Add hiking trails from AllTrails. Get a smart packing checklist. Even find day-trips nearby — and booking links with member rates baked in."
> **Screen:** Quick cuts — AllTrails trail linked on the trip → checklist toggles → day-trip suggestions → BookingLinks panel with a member-rate badge.

**[0:54] Share + close**
> **VO:** "Share it with anyone by email, plan together, and take it anywhere — it works offline. Wanderply. Your trip, planned."
> **Screen:** Share modal → offline indicator / airplane-mode plan still loading → logo end card.

---

## 3. Short-Form Vertical Set (TikTok / Reels / Shorts) — 15–20s each
**Use:** organic social. Shoot 9:16. No slow intros — hook in the first second.

### 3a. "One sentence → whole trip"
> **Text overlay (0:00):** "POV: you're too lazy to plan a trip"
> **Screen:** Type "Tokyo, 5 days, food-obsessed" into the wizard.
> **Text (0:05):** "so you let AI do it"
> **Screen:** Live build → itinerary reveal.
> **Text (0:12):** "…that's genuinely a good plan??"
> **Screen:** Scroll day 1 — ramen spot, market, viewpoint.
> **CTA (0:16):** "Wanderply.com 🌏"

### 3b. "The packing list that packs itself"
> **Text:** "I never forget a charger again"
> **Screen:** Open `/trips/:id/checklist`, tap items, progress bar fills to 100%.
> **CTA:** "Free on Wanderply"

### 3c. "Trivia while you wait at the gate"
> **Text:** "Delayed flight starter pack"
> **Screen:** `/quizzes` grid → play **Guess the Flag** → tap right answer, score animates → **Country Explorer** fact sheet.
> **CTA:** "16 free travel quizzes on Wanderply"

### 3d. "Plan it together"
> **Text:** "me + my group chat finally agreeing on something"
> **Screen:** Share-by-email modal → second user's view of the same trip → each renames it their own way (`custom_title`).
> **CTA:** "Shared trips on Wanderply"

### 3e. "Your co-pilot for the drive"
> **Text:** "roadtrip but make it a guided tour"
> **Screen:** Day-trip plan with narrated stops / Drive Co-Pilot narration playing.
> **CTA:** "Wanderply"

---

## 4. App Store Preview — 3 slides (15–20s)
**Use:** iOS App Store / Google Play preview video. Show the **native shell**, not the browser.

1. **"Plan trips with AI"** — native app, wizard fills in, build animates. Caption: *Describe it. Wanderply builds it.*
2. **"Everything in one place"** — swipe plan → checklist → trails → map. Caption: *Itinerary, packing, trails — together.*
3. **"Works offline, plays anywhere"** — airplane-mode plan loads + a quiz deck. Caption: *Saved for offline. Ready anywhere.*

---

## 5. 6-second bumper (YouTube non-skippable)
> **VO/Text:** "A whole trip, planned from one sentence. Wanderply."
> **Screen:** Wizard type → build → itinerary snap, 3 hard cuts + logo.

---

## 6. Length variants from ONE source — 15s tight cut + 60s cut
**Use:** run one recording session, deliver both a scroll-stopping 15s (paid social,
Shorts) and a full 60s (landing page, YouTube). Both are cut from the **same five
"Lisbon" master takes** below — the 15s is the 60s with the connective tissue removed,
so the footage, VO voice, music bed, and color grade all match across the pair.

### Shared source takes (record these five, clean, once)
| Take | Label | What to capture (aim for the given length so both cuts have room) |
|------|-------|---------|
| **A** | *Describe* | Wizard fill — destination "Lisbon", dates, 2 travelers, pace **Balanced**, budget **Moderate**, preferences "viewpoints, seafood, no early mornings". ~12s raw. |
| **B** | *Build* | **Live** async build — "Building your trip" shimmer → itinerary reveal. ~10s raw, grab 3 takes. |
| **C** | *Plan* | Slow scroll of `/trips/:id/plan` — day headers, an activity note, the map. ~15s raw. |
| **D** | *Extras* | Checklist progress bar filling → one AllTrails trail → a booking-links member-rate badge. ~12s raw. |
| **E** | *Share/Offline* | Share-by-email modal → airplane-mode plan still loads. ~8s raw. |

The 15s uses **A → B → C** only. The 60s uses **A → B → C → D → E** with the takes
run closer to full length and a bit more VO. Same order, same grade — nothing to re-shoot.

### 15-second tight cut
| Time | VO (fast, energetic) | Source | On-screen text |
|------|----------------------|--------|----------------|
| 0:00–0:04 | "Plan a whole trip in one sentence." | **A** (speed-ramped, ~2× so the type-in lands by 0:04) | *Wanderply* |
| 0:04–0:09 | "Wanderply builds the itinerary for you—" | **B** (the money shot, near real-time) | — |
| 0:09–0:13 | "—day by day, ready to go." | **C** (quick scroll, 1 day only) | — |
| 0:13–0:15 | "Wanderply dot com." | Logo end card | *Wanderply.com* |

### 60-second cut
| Time | VO (relaxed, warm) | Source | On-screen text |
|------|--------------------|--------|----------------|
| 0:00–0:05 | "Planning a trip used to mean twenty tabs and a spreadsheet." | Stock B-roll of clutter | — |
| 0:05–0:10 | "Wanderply just needs one sentence." | Cut to **A** start | *Wanderply* |
| 0:10–0:22 | "Tell it where you're going, when, who's coming, and how you like to travel." | **A** full — linger on pace, budget, preferences | — |
| 0:22–0:34 | "Then it does the hard part: a real, day-by-day plan with timing, directions, and local picks." | **B** full → into **C** | — |
| 0:34–0:44 | "Every day mapped. Every stop with a reason it's worth your time." | **C** full slow scroll | — |
| 0:44–0:54 | "Add trails, get a packing checklist, find booking deals with member rates built in." | **D** full | — |
| 0:54–0:60 | "Share it with anyone, and take it anywhere — even offline. Wanderply. Your trip, planned." | **E** → logo end card | *Wanderply.com — Your trip, planned.* |

### 30-second cut (the middle of the matched set)
Same five takes, sits between the two — uses **A → B → C → D**, drops only **E**
(share/offline) to make room. Gives you a matched **15 / 30 / 60** trio from one shoot.

| Time | VO (confident, balanced pace) | Source | On-screen text |
|------|-------------------------------|--------|----------------|
| 0:00–0:04 | "Planning a trip used to mean twenty tabs." | Stock clutter B-roll → **A** start | *Wanderply* |
| 0:04–0:11 | "Wanderply just needs one sentence — where, when, and how you like to travel." | **A** (linger on pace + preferences) | — |
| 0:11–0:18 | "Then it builds the whole itinerary. Day by day, ready to go." | **B** full → **C** start | — |
| 0:18–0:24 | "Every stop mapped, with a reason it's worth your time." | **C** slow scroll | — |
| 0:24–0:28 | "Trails, packing lists, booking deals — all built in." | **D** (checklist + badge) | — |
| 0:28–0:30 | "Wanderply. Your trip, planned." | Logo end card | *Wanderply.com* |

> **Editor's note:** cut the 60s first and lock the grade + music, then lift takes to
> build the 30s (drop E), then tighten A/B/C again for the 15s. Same logo end card on
> all three so the trio reads as one campaign — deliver 15/30/60 from a single shoot.

---

## Shot list — screens to capture once, reuse everywhere
Record these clean takes and you can cut every script above from them:

- [ ] **Wizard fill** — destination, dates, travelers, pace, budget, preferences
- [ ] **Highlights step** loading + selecting cards
- [ ] **Build animation** (the money shot) — capture 2–3 full takes, live
- [ ] **Plan page** slow scroll — day headers, activities, map
- [ ] **Checklist** — toggling items, progress bar filling
- [ ] **AllTrails trail** linked on a trip
- [ ] **Day-trip suggestions** + a booking-links panel with a member-rate badge
- [ ] **Share-by-email** modal + a second user viewing/renaming the trip
- [ ] **Quizzes** — index grid, Guess the Flag round, Country Explorer
- [ ] **Offline** — airplane mode, plan + quiz still load
- [ ] **Native app** — same flows inside the iOS/Android shell (nav bar visible)

## Canonical demo trip + captured assets (2026-07-05)
Drove the **live production app** (logged in as Kalyan) through all five takes and
seeded a real, reusable demo trip you can screen-record anytime at full quality:

- **Demo trip:** *Moab Red Rock — Jul 3–6, 2026* — `wanderply.com/trips/dc4b460c-1f77-473b-9e6e-9a6886c394cf`
  (3 nights, 4 travelers, 1 AllTrails trail, budget Moderate, pace Balanced). The AI
  produced a genuinely strong itinerary (SLC → Green River → Arches → Canyonlands),
  real per-leg drive stats (669 mi · 20h 40m · ~$91 fuel), per-stop photos + maps, and
  a personalized 24-item checklist.
- **Two proof GIFs in `~/Downloads`:**
  - `wanderply-takeAB-wizard-to-build.gif` — wizard fill → "Building your plan" stages
  - `wanderply-takeCD-plan-and-checklist.gif` — final plan scroll → checklist filling 0→29%

> **Brand note:** the app is positioned around **Western US road trips**, so I used
> **Moab** (not the scripts' original "Lisbon"). Treat *Moab Red Rock* as the canonical
> demo across all cuts — it matches the offline-maps / drive-podcast / "road-trip
> families across the West" messaging on the homepage.

> ⚠️ **Two things to know before you shoot:**
> 1. **The proof GIFs carry Claude Code overlays** (orange click dots, action labels,
>    watermark) and are compressed — they're storyboard references, **not** final promo
>    footage. For broadcast quality, **screen-record the live demo trip** above with a
>    real recorder (OBS / macOS screen capture) at phone or 1080p framing. The browser
>    automation window enforces a desktop min-width, so true phone framing needs a
>    device/emulator or a narrow OBS crop.
> 2. **Found a real bug while filming:** editing a trip with **Getting around = "No
>    preference"** fails to save — *"Transport mode is not included in the list"* (the
>    option submits an empty value that fails the `transport_mode` inclusion validation).
>    Worth fixing before a launch push. Say the word and I'll patch it (allow blank, or
>    give "No preference" a real value) and run the tests.

## Voice & tone
- Warm, confident, a little playful. Never "revolutionary AI platform" — say what it *does*.
- Lead with the outcome ("a whole trip, planned"), not the mechanism ("LLM itinerary generation").
- Keep the promise honest: it drafts a real plan you then tweak — don't imply zero effort.
