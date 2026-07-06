# Wanderply — OBS Capture Checklist

Shot-by-shot plan to record the five master takes (A–E) into the phone frames.
Everything below uses the live demo trip **Moab Red Rock — Jul 3–6, 2026**
(`wanderply.com/trips/dc4b460c-1f77-473b-9e6e-9a6886c394cf`). Companion to
`PROMO_VIDEO_SCRIPTS.md` (the cuts) and `brand/README.md` (the frames).

---

## A. One-time setup (10 min)

### Authentic phone UI (the important trick)
The browser won't shrink below a desktop min-width, but **Chrome device mode renders
the real mobile layout at any width** — use it so the footage matches the phone frame.
1. Open the trip in Chrome → **F12** → click the **device toolbar** icon (⌘/Ctrl+Shift+M).
2. Pick **iPhone 12 Pro (390 × 844)** or set a custom **390 × 844**, DPR **3**.
3. Set zoom to a size that fills your capture region; hide the DevTools panel (dock it
   to the right, then drag it closed) so only the phone viewport shows.
4. Clean the frame: use a fresh Chrome profile (no extensions/bookmarks bar), and turn
   on **Do Not Disturb** so no OS/notification toasts leak into the recording.

### OBS
- **Settings → Video:** Base + Output canvas **1080 × 1920**, **60 fps**.
- **Scene → Sources:** add **Window Capture** (the Chrome window) *or* **Display/Region
  Capture** cropped to the 390×844 phone viewport. Crop/scale the source so the phone
  viewport fills the 1080×1920 canvas.
- **Output:** MP4 (or MKV → remux), high bitrate (~40–50 Mbps) so downscales stay crisp.
- Show the cursor; move it **slowly and deliberately** — you'll speed-ramp in the edit.
- Do **2–3 takes of every shot**, especially Take B.

> Recording wide instead? Capture the desktop layout, then in the editor scale the clip
> to fill the frame's screen window (`brand/README.md` has per-crop coords). Mobile
> device-mode gives a cleaner result — prefer it.

---

## B. Pre-flight (before you hit record)
- [ ] Logged in (the demo/owner account) — Moab trip loads fully, plan + checklist ready
- [ ] DevTools device mode on (390×844), panel hidden, page zoom set
- [ ] Chrome DND / OS notifications silenced
- [ ] OBS canvas 1080×1920 @ 60fps, source framed, cursor visible
- [ ] Reset the checklist toggles you want "empty" for Take D (uncheck a few first)

---

## C. Shot list — record these, in order

### Take A — *Describe* (wizard)  → target ~12s raw
- **URL:** `/trip_wizard/destination`
- **Do:** type **"Moab, Utah"**, tab through dates/travelers, set **Balanced** + **Moderate**,
  type preferences ("scenic overlooks, short hikes, no early mornings"). Linger on the
  pace + budget selectors.
- **Emphasize:** how little you type. Stop before clicking Continue (or continue for a full run).

### Take B — *Build* (THE money shot)  → ~10s raw, get 3 takes
- **Do:** from the wizard Review step, click **Create my trip**.
- **Capture:** the **"Building your plan"** screen — the spinner + the staged checklist
  advancing (Researching → Pinning coordinates → Writing checklist → Finding landmarks).
- **Note:** the real build takes ~1–2 min; you only need ~10s of the animation. You can
  cut/speed-ramp. This is the beat everything else supports — nail it.

### Take C — *Plan*  → ~15s raw
- **URL:** `/trips/dc4b460c-1f77-473b-9e6e-9a6886c394cf/plan`
- **Do:** slow-scroll: **Drive Co-Pilot** panel → "Why you'll love this trip" → a day
  header ("Red Rock Road to Moab") → 1–2 stops with **photos + maps + "Go"**.
- **Emphasize:** real photos, real routing, per-stop narration. Don't rush.

### Take D — *Extras* (checklist + trail + booking)  → ~12s raw
- **URL:** `/trips/dc4b460c-1f77-473b-9e6e-9a6886c394cf/checklist`
- **Do:** tap items so the **progress bar fills** (start low → ~30–50%). Then cut to the
  main trip page's **booking / "stack points"** panel and the **AllTrails trail** row.
- **Emphasize:** the bar animating, the personalized items ("Pack Arohi's sketchbook…").

### Take E — *Share / Offline*  → ~8s raw
- **Do:** on the trip page click **Share** → show the share-by-email screen (don't submit).
- **Offline bit (optional, strong):** with the plan page already visited, toggle
  **airplane mode** / OBS a second device, reload → the plan still renders. "Works offline."

---

## D. Nice-to-have B-roll (grab if time allows)
- [ ] **Quizzes** — `/quizzes` grid → play **Guess the Flag** → **Country Explorer** (`/quizzes/explore`)
- [ ] **Drive Co-Pilot** — the "Narrate landmarks as you drive" panel on the plan page
- [ ] **Trip concierge** — type a question into the "Ask about this trip" box
- [ ] **Dashboard** — the trips index / card grid (an establishing shot)
- [ ] **Native app** — same flows in the Android/iOS shell (nav bar visible) for an "it's a real app" beat

---

## E. After capture
1. **Name clips** `takeA_moab_01.mp4`, `takeB_build_02.mp4`, … so they map to the scripts.
2. **Frame them:** drop `brand/phone-frame-9x16.png` on a track above each clip; scale the
   clip to the screen window **x 150 · y 74 · 780 × 1736** (1:1 and 16:9 coords in `brand/README.md`).
3. **Assemble** per `PROMO_VIDEO_SCRIPTS.md §6` — cut the 60s first, then lift A/B/C for 30s and 15s.
4. **Brand:** amber accent, Fraunces headlines / Inter captions, end card = logo + `wanderply.com`
   (all in `brand/BRAND_KIT.html`).
5. **Export** 9:16 first, then 1:1 and 16:9 crops from the same timeline.

## Capture progress
- [ ] Take A — wizard (×2–3)
- [ ] Take B — build animation (×3)
- [ ] Take C — plan scroll
- [ ] Take D — checklist + booking + trail
- [ ] Take E — share (+ offline)
- [ ] B-roll grabbed
- [ ] VO recorded (`PROMO_VO_SCRIPT.md`)
- [ ] Music chosen (Artlist / Epidemic / YT Audio Library)
