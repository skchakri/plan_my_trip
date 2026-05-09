import { Controller } from "@hotwired/stimulus"

// Fullscreen "reading mode" modal that walks through a trip's plan one
// scene at a time — big photo, map tiles beside, and TTS narration that
// auto-advances on speech end. Designed for in-car viewing on a dash-
// mounted phone or tablet.
export default class extends Controller {
  static values = { scenes: Array }
  static targets = [
    "modal", "photo", "photoFallback", "mapGrid", "mapPin", "mapsLink",
    "eyebrow", "title", "subtitle", "text", "progress", "playPauseLabel"
  ]

  connect() {
    this._idx = 0
    this._paused = false
    this._utter = null
    this._closeOnKey = (e) => { if (e.key === "Escape") this.close() }
  }

  open(event) {
    if (event) event.preventDefault()
    if (!this.scenesValue.length) return
    if (!("speechSynthesis" in window)) {
      alert("Your browser doesn't support speech synthesis — reading mode needs that.")
      return
    }
    this._idx = 0
    this._paused = false
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this._closeOnKey)
    this._render()
    this._speak()
  }

  close() {
    if (!this.hasModalTarget) return
    window.speechSynthesis.cancel()
    this._utter = null
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this._closeOnKey)
  }

  next() {
    window.speechSynthesis.cancel()
    if (this._idx < this.scenesValue.length - 1) {
      this._idx++
      this._render()
      if (!this._paused) this._speak()
    } else {
      // Last scene reached; just stop speaking.
      this._utter = null
    }
  }

  prev() {
    window.speechSynthesis.cancel()
    if (this._idx > 0) {
      this._idx--
      this._render()
      if (!this._paused) this._speak()
    }
  }

  togglePlay() {
    if (this._paused) {
      this._paused = false
      this._setPlayLabel("Pause")
      this._speak()
    } else {
      this._paused = true
      this._setPlayLabel("Play")
      window.speechSynthesis.cancel()
    }
  }

  // Click on backdrop closes
  backdropClose(event) {
    if (event.target === event.currentTarget) this.close()
  }

  _render() {
    const scene = this.scenesValue[this._idx]
    if (!scene) return

    this.eyebrowTarget.textContent = scene.eyebrow || ""
    this.titleTarget.textContent   = scene.title   || ""
    this.subtitleTarget.textContent = [scene.location, scene.address].filter(Boolean).join(" · ")
    this.textTarget.textContent    = scene.text    || ""

    // Photo
    if (scene.photo) {
      this.photoTarget.src = scene.photo
      this.photoTarget.classList.remove("hidden")
      this.photoFallbackTarget.classList.add("hidden")
    } else {
      this.photoTarget.classList.add("hidden")
      this.photoTarget.removeAttribute("src")
      this.photoFallbackTarget.classList.remove("hidden")
    }

    // Map (2x2 OSM tiles + pin)
    this.mapGridTarget.innerHTML = ""
    if (Array.isArray(scene.tiles) && scene.tiles.length) {
      this.mapGridTarget.classList.remove("hidden")
      for (const url of scene.tiles) {
        const img = document.createElement("img")
        img.loading = "lazy"
        img.src     = url
        img.alt     = ""
        img.referrerPolicy = "no-referrer"
        img.className = "w-full h-full object-cover"
        this.mapGridTarget.appendChild(img)
      }
      this.mapPinTarget.style.left = (scene.pin_x_pct ?? 50) + "%"
      this.mapPinTarget.style.top  = (scene.pin_y_pct ?? 50) + "%"
      this.mapPinTarget.classList.remove("hidden")
    } else {
      this.mapGridTarget.classList.add("hidden")
      this.mapPinTarget.classList.add("hidden")
    }

    // Open-in-Maps link
    if (scene.maps_link && this.hasMapsLinkTarget) {
      this.mapsLinkTarget.href = scene.maps_link
      this.mapsLinkTarget.classList.remove("hidden")
    } else if (this.hasMapsLinkTarget) {
      this.mapsLinkTarget.classList.add("hidden")
    }

    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${this._idx + 1} / ${this.scenesValue.length}`
    }
  }

  _speak() {
    const scene = this.scenesValue[this._idx]
    if (!scene) return
    const phrase = [scene.eyebrow, scene.title, scene.text].filter(Boolean).join(". ")

    window.speechSynthesis.cancel()
    const u = new SpeechSynthesisUtterance(phrase)
    u.rate  = 1.0
    u.pitch = 1.0
    u.onend = () => {
      // Only auto-advance if this was the most-recently issued utterance,
      // we're not paused, and the modal is still open.
      if (this._utter !== u || this._paused) return
      if (this.modalTarget.classList.contains("hidden")) return
      this.next()
    }
    u.onerror = u.onend
    this._utter = u
    this._setPlayLabel("Pause")
    window.speechSynthesis.speak(u)
  }

  _setPlayLabel(text) {
    if (this.hasPlayPauseLabelTarget) this.playPauseLabelTarget.textContent = text
  }
}
