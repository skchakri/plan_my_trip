import { Controller } from "@hotwired/stimulus"

// Drive Co-Pilot — opt-in, geolocation-driven landmark narration.
//
// Activates only when the user taps "Enable Drive Co-Pilot" and grants
// geolocation permission. Once active, it polls position via
// navigator.geolocation.watchPosition and, when the user gets within
// PROXIMITY_MI of any activity that has both coordinates AND a
// guide_script, speaks that script via the Web Speech API.
//
// Dedup: each landmark plays at most once per active session — we don't
// want the same narration triggering every 30 seconds while you sit in a
// parking lot. Tap "Stop" then "Enable" again to reset.
//
// Data shape (passed via stops-value):
//   [{ id, name, lat, lng, script }, ...]
//
// Markup contract (see plan.html.erb):
//   <div data-controller="drive-copilot"
//        data-drive-copilot-stops-value="...JSON...">
//     <button data-action="drive-copilot#enable">Enable</button>
//     <button data-action="drive-copilot#disable" hidden>Stop</button>
//     <div data-drive-copilot-target="status"></div>
//     <div data-drive-copilot-target="nowPlaying" hidden>
//       <span data-drive-copilot-target="nowPlayingName"></span>
//       <button data-action="drive-copilot#skipCurrent">Skip</button>
//     </div>
//   </div>
export default class extends Controller {
  static targets = [
    "enableButton", "disableButton", "status",
    "narratingCard", "narratingCardInner", "narratingImage",
    "narratingName", "narratingKind",
    "stopsList", "stopItem"
  ]
  static values = {
    stops: Array,        // [{id, name, lat, lng, script}]
    proximityMi: { type: Number, default: 3 },
    pollMs: { type: Number, default: 8000 }   // throttle target — watchPosition fires often, we down-sample
  }

  connect() {
    this._enabled = false
    this._played = new Set()
    this._watchId = null
    this._lastPollAt = 0
    this._currentUtter = null
    this._lastFix = null
    this._renderStatus("Tap Enable to start. We'll narrate landmarks within ~" + this.proximityMiValue + " miles as you drive.")
  }

  disconnect() {
    this._teardownWatch()
    this._stopSpeaking()
  }

  enable(event) {
    event?.preventDefault()
    if (this._enabled) return

    if (!("geolocation" in navigator)) {
      this._renderStatus("This browser doesn't support geolocation.", "error")
      return
    }
    if (!("speechSynthesis" in window)) {
      this._renderStatus("This browser doesn't support speech synthesis.", "error")
      return
    }
    if (!this.stopsValue || this.stopsValue.length === 0) {
      this._renderStatus("No landmarks with narration on this trip yet.", "warn")
      return
    }

    this._renderStatus("Requesting location permission…")
    this._watchId = navigator.geolocation.watchPosition(
      (pos) => this._onPosition(pos),
      (err) => this._onError(err),
      { enableHighAccuracy: true, maximumAge: 5000, timeout: 30000 }
    )
    this._enabled = true
    this._toggleButtons()
  }

  disable(event) {
    event?.preventDefault()
    this._teardownWatch()
    this._stopSpeaking()
    this._enabled = false
    this._played.clear()
    this._toggleButtons()
    this._renderStatus("Drive Co-Pilot off. Your location is no longer being read.")
  }

  skipCurrent(event) {
    event?.preventDefault()
    this._stopSpeaking()
  }

  // --- internals ---

  _onPosition(pos) {
    const now = Date.now()
    // Throttle expensive distance work — watchPosition can fire 1Hz.
    if (now - this._lastPollAt < this.pollMsValue) return
    this._lastPollAt = now

    const lat = pos.coords.latitude
    const lng = pos.coords.longitude
    this._lastFix = { lat, lng, accuracy: pos.coords.accuracy }

    // If we're already speaking, skip — don't interrupt narration with a new one.
    if (window.speechSynthesis.speaking) {
      this._renderStatus(`Narrating · last fix ±${Math.round(pos.coords.accuracy)}m`)
      return
    }

    // Find the nearest UNPLAYED stop with a script.
    let bestStop = null
    let bestMi = Infinity
    for (const s of this.stopsValue) {
      if (!s.script || this._played.has(s.id)) continue
      const mi = haversineMiles(lat, lng, s.lat, s.lng)
      if (mi < bestMi) { bestMi = mi; bestStop = s }
    }

    if (bestStop && bestMi <= this.proximityMiValue) {
      this._speak(bestStop)
    } else if (bestStop) {
      this._renderStatus(
        `Listening… next up: ${bestStop.name} (${bestMi.toFixed(1)} mi away)`
      )
    } else {
      this._renderStatus("All landmarks narrated. Tap Stop when you're done.")
    }
  }

  _onError(err) {
    if (err.code === err.PERMISSION_DENIED) {
      // Permission denied is terminal — watchPosition won't recover on its
      // own. Reset state so the Enable button comes back and the user can
      // retry after unblocking in browser settings.
      this._teardownWatch()
      this._stopSpeaking()
      this._enabled = false
      this._toggleButtons()
      this._renderStatus("Permission denied. Click the 🔒/📍 icon in the address bar → Location → Allow, then tap Enable again.", "error")
      return
    }
    let msg = "Location error."
    if (err.code === err.POSITION_UNAVAILABLE) msg = "Can't determine location right now. Trying again…"
    else if (err.code === err.TIMEOUT) msg = "Location request timed out. Retrying…"
    this._renderStatus(msg, "error")
  }

  _speak(stop) {
    this._played.add(stop.id)
    this._renderStatus(`Narrating: ${stop.name}`, "playing")
    this._showNarratingCard(stop)

    const utter = new SpeechSynthesisUtterance(stop.script)
    utter.rate = 1.0
    utter.pitch = 1.0
    utter.onend = utter.onerror = () => {
      this._hideNarratingCard()
      this._renderStatus("Listening for the next landmark…")
    }
    this._currentUtter = utter
    window.speechSynthesis.cancel()
    window.speechSynthesis.speak(utter)
  }

  _showNarratingCard(stop) {
    if (!this.hasNarratingCardTarget) return
    if (this.hasNarratingNameTarget) this.narratingNameTarget.textContent = stop.name
    if (this.hasNarratingKindTarget) {
      this.narratingKindTarget.textContent = (stop.kind || "stop").replace(/_/g, " ")
    }
    if (this.hasNarratingImageTarget) {
      if (stop.image_url) {
        this.narratingImageTarget.style.backgroundImage = `url("${stop.image_url.replace(/"/g, '\\"')}")`
        this.narratingImageTarget.classList.remove(...KIND_GRADIENTS_ALL)
      } else {
        // No image — use a kind-appropriate gradient as fallback.
        this.narratingImageTarget.style.backgroundImage = ""
        this.narratingImageTarget.classList.remove(...KIND_GRADIENTS_ALL)
        const grad = KIND_GRADIENTS[stop.kind] || KIND_GRADIENTS.default
        this.narratingImageTarget.classList.add(...grad)
      }
    }
    this.narratingCardTarget.hidden = false
    // Force a frame before flipping the data attribute so the transition runs.
    requestAnimationFrame(() => {
      if (this.hasNarratingCardInnerTarget) this.narratingCardInnerTarget.dataset.shown = "true"
    })
  }

  _hideNarratingCard() {
    if (!this.hasNarratingCardTarget) return
    if (this.hasNarratingCardInnerTarget) this.narratingCardInnerTarget.dataset.shown = "false"
    // Wait for the slide-out transition before hiding the wrapper.
    setTimeout(() => { this.narratingCardTarget.hidden = true }, 220)
  }

  _stopSpeaking() {
    if ("speechSynthesis" in window) window.speechSynthesis.cancel()
    this._hideNarratingCard()
    this._currentUtter = null
  }

  _teardownWatch() {
    if (this._watchId !== null && "geolocation" in navigator) {
      navigator.geolocation.clearWatch(this._watchId)
    }
    this._watchId = null
  }

  _toggleButtons() {
    if (this.hasEnableButtonTarget) this.enableButtonTarget.hidden = this._enabled
    if (this.hasDisableButtonTarget) this.disableButtonTarget.hidden = !this._enabled
  }

  _renderStatus(text, kind = "info") {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.dataset.kind = kind
  }
}

// Fallback gradients per landmark kind — used when we don't have an
// image for the stop. Keeps the card visually distinct from itinerary
// stops and hints at the category. Tailwind compiles these classes
// because they appear as string literals here.
const KIND_GRADIENTS = {
  itinerary:      ["bg-gradient-to-br", "from-amber-700",   "to-amber-950"],
  historic:       ["bg-gradient-to-br", "from-stone-700",   "to-stone-950"],
  geological:     ["bg-gradient-to-br", "from-orange-800",  "to-stone-900"],
  scenic:         ["bg-gradient-to-br", "from-sky-800",     "to-slate-950"],
  cultural:       ["bg-gradient-to-br", "from-rose-800",    "to-slate-950"],
  engineering:    ["bg-gradient-to-br", "from-slate-700",   "to-slate-950"],
  natural:        ["bg-gradient-to-br", "from-emerald-800", "to-slate-950"],
  ghost_town:     ["bg-gradient-to-br", "from-stone-800",   "to-zinc-950"],
  battlefield:    ["bg-gradient-to-br", "from-red-900",     "to-stone-950"],
  river_crossing: ["bg-gradient-to-br", "from-cyan-800",    "to-slate-950"],
  pass_summit:    ["bg-gradient-to-br", "from-indigo-800",  "to-slate-950"],
  observatory:    ["bg-gradient-to-br", "from-violet-900",  "to-slate-950"],
  tribal:         ["bg-gradient-to-br", "from-amber-900",   "to-stone-950"],
  default:        ["bg-gradient-to-br", "from-slate-700",   "to-slate-950"]
}
const KIND_GRADIENTS_ALL = Array.from(new Set(Object.values(KIND_GRADIENTS).flat()))

function haversineMiles(lat1, lng1, lat2, lng2) {
  const R = 3958.8 // earth radius in miles
  const toRad = (d) => d * Math.PI / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(a))
}
