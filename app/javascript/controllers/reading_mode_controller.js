import { Controller } from "@hotwired/stimulus"
import { getSpeed, setSpeed, nextSpeed, formatSpeed } from "tts_settings"
import { speak, cancelSpeech, canSpeak, availableVoices, onVoicesChanged } from "speech"

// Fullscreen "podcast mode" modal that walks through a trip's plan one
// scene at a time. Each scene carries an array of dialogue lines spoken
// by two voices (host + guide). Auto-advances on speech end so the only
// thing the driver ever needs to do is press play once.
export default class extends Controller {
  static values = { scenes: Array }
  static targets = [
    "modal", "photo", "photoFallback", "mapGrid", "mapPin", "mapsLink",
    "eyebrow", "title", "subtitle", "text", "progress", "playPauseLabel",
    "speakerBadge", "speakerLabel", "speedLabel"
  ]

  // Voice-name patterns we try (in order) when picking the host and the
  // guide. We want two clearly distinct voices — typically a warmer
  // female voice for the host and a steadier male voice for the guide,
  // but we fall back gracefully if the platform only ships one.
  HOST_HINTS = [
    /Samantha/i, /Karen/i, /Allison/i, /Ava/i, /Susan/i,
    /Google US English/i, /Microsoft Zira/i, /Microsoft Aria/i,
    /en-US.*Female/i, /en-GB.*Female/i
  ]
  GUIDE_HINTS = [
    /Daniel/i, /Alex/i, /Fred/i, /Tom/i, /Aaron/i,
    /Google UK English Male/i, /Microsoft Mark/i, /Microsoft Guy/i,
    /en-GB.*Male/i, /en-US.*Male/i
  ]

  connect() {
    this._sceneIdx = 0
    this._lineIdx  = 0
    this._paused = false
    this._utter = null
    this._pendingTimer = null
    this._hostVoice = null
    this._guideVoice = null
    this._closeOnKey = (e) => { if (e.key === "Escape") this.close() }

    // Voices populate asynchronously in some browsers.
    this._loadVoices()
    onVoicesChanged(() => this._loadVoices())
    this._renderSpeedLabel()
  }

  cycleSpeed(event) {
    if (event) event.preventDefault()
    setSpeed(nextSpeed())
    this._renderSpeedLabel()
    // Reflect the new speed mid-playback: cancel current utterance and
    // re-speak the same line so the listener hears the change immediately.
    if (!this._paused) {
      this._cancelSpeech()
      this._playFromCurrentLine()
    }
  }

  _renderSpeedLabel() {
    // Multiple chips share the same target name (trip-level button + modal
    // header) so update all of them.
    this.speedLabelTargets.forEach(el => { el.textContent = formatSpeed() })
  }

  open(event) {
    if (event) event.preventDefault()
    if (!this.scenesValue.length) return
    // No TTS (or offline with no voices)? Open anyway as a readable transcript —
    // the scene text + next/prev still work, just without audio narration.
    this._ttsAvailable = canSpeak()
    this._sceneIdx = 0
    this._lineIdx  = 0
    this._paused = !this._ttsAvailable
    if (this._ttsAvailable) this._loadVoices()
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this._closeOnKey)
    this._render()
    if (this._ttsAvailable) {
      this._setPlayLabel("Pause")
      this._playFromCurrentLine()
    } else {
      this._setPlayLabel("Read")
    }
  }

  close() {
    if (!this.hasModalTarget) return
    this._cancelSpeech()
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this._closeOnKey)
  }

  next() {
    this._cancelSpeech()
    if (this._sceneIdx < this.scenesValue.length - 1) {
      this._sceneIdx++
      this._lineIdx = 0
      this._render()
      if (!this._paused) this._playFromCurrentLine()
    }
  }

  prev() {
    this._cancelSpeech()
    if (this._sceneIdx > 0) {
      this._sceneIdx--
      this._lineIdx = 0
      this._render()
      if (!this._paused) this._playFromCurrentLine()
    }
  }

  togglePlay() {
    if (!this._ttsAvailable) return // transcript-only mode — no audio to toggle
    if (this._paused) {
      this._paused = false
      this._setPlayLabel("Pause")
      this._playFromCurrentLine()
    } else {
      this._paused = true
      this._setPlayLabel("Play")
      this._cancelSpeech()
    }
  }

  // Click on backdrop closes
  backdropClose(event) {
    if (event.target === event.currentTarget) this.close()
  }

  // ── Internal ───────────────────────────────────────────────────────

  _cancelSpeech() {
    if (this._pendingTimer) {
      clearTimeout(this._pendingTimer)
      this._pendingTimer = null
    }
    cancelSpeech()
    this._utter = null
  }

  _loadVoices() {
    // Empty on the native bridge path — Android speaks through its own engine
    // and exposes no voice list, so host/guide are cast by pitch instead.
    const voices = availableVoices()
    if (!voices.length) return

    const en = voices.filter(v => /^en[-_]/i.test(v.lang) || /^en$/i.test(v.lang))
    const pool = en.length ? en : voices

    const matchFirst = (hints) => {
      for (const hint of hints) {
        const found = pool.find(v => hint.test(v.name))
        if (found) return found
      }
      return null
    }

    this._hostVoice  = matchFirst(this.HOST_HINTS)  || pool[0] || null
    this._guideVoice = matchFirst(this.GUIDE_HINTS) || pool.find(v => v !== this._hostVoice) || this._hostVoice
  }

  _currentScene() {
    return this.scenesValue[this._sceneIdx]
  }

  _currentLine() {
    const scene = this._currentScene()
    if (!scene || !Array.isArray(scene.lines)) return null
    return scene.lines[this._lineIdx] || null
  }

  _render() {
    const scene = this._currentScene()
    if (!scene) return

    this.eyebrowTarget.textContent  = scene.eyebrow || ""
    this.titleTarget.textContent    = scene.title   || ""
    this.subtitleTarget.textContent = [scene.location, scene.address].filter(Boolean).join(" · ")
    this.textTarget.textContent     = scene.text    || ""

    if (scene.photo) {
      this.photoTarget.src = scene.photo
      this.photoTarget.classList.remove("hidden")
      this.photoFallbackTarget.classList.add("hidden")
    } else {
      this.photoTarget.classList.add("hidden")
      this.photoTarget.removeAttribute("src")
      this.photoFallbackTarget.classList.remove("hidden")
    }

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

    if (scene.maps_link && this.hasMapsLinkTarget) {
      this.mapsLinkTarget.href = scene.maps_link
      this.mapsLinkTarget.classList.remove("hidden")
    } else if (this.hasMapsLinkTarget) {
      this.mapsLinkTarget.classList.add("hidden")
    }

    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${this._sceneIdx + 1} / ${this.scenesValue.length}`
    }
  }

  _playFromCurrentLine() {
    if (!this._ttsAvailable) return // transcript-only mode: nothing to speak
    if (this._paused) return
    const line = this._currentLine()
    if (!line) {
      // No more lines in this scene — advance to the next scene if any.
      if (this._sceneIdx < this.scenesValue.length - 1) {
        this._sceneIdx++
        this._lineIdx = 0
        this._render()
        this._playFromCurrentLine()
      } else {
        this._setPlayLabel("Play")
      }
      return
    }

    this._setSpeakerBadge(line.voice)

    const isGuide = line.voice === "guide"
    const voice = isGuide ? this._guideVoice : this._hostVoice
    const basePitch = typeof line.pitch === "number" ? line.pitch : 1.0
    // With no voice list (native bridge) the two speakers would sound
    // identical, so drop the guide a little to keep them apart.
    const pitch = voice ? basePitch : (isGuide ? basePitch * 0.85 : basePitch)

    // Token identifies "the utterance currently playing" — every callback
    // bails if a newer line has started since.
    const token = {}
    this._utter = token

    speak(line.text || "", {
      rate: typeof line.rate === "number" ? line.rate : 1.0,
      pitch,
      voice,
      onEnd: () => {
        if (this._utter !== token) return
        if (this._paused) return
        if (this.modalTarget.classList.contains("hidden")) return
        this._lineIdx++
        const basePause = typeof line.pause_after_ms === "number" ? line.pause_after_ms : 200
        // Tighten the pause when the user picks a faster speed so the
        // cadence between lines tracks the speech rate instead of dragging.
        const pause = Math.max(80, Math.round(basePause / getSpeed()))
        this._pendingTimer = setTimeout(() => {
          this._pendingTimer = null
          this._playFromCurrentLine()
        }, pause)
      }
    })
  }

  _setSpeakerBadge(voice) {
    if (!this.hasSpeakerLabelTarget) return
    const isGuide = voice === "guide"
    const which = isGuide ? "Guide" : "Host"
    const v = isGuide ? this._guideVoice : this._hostVoice
    this.speakerLabelTarget.textContent = v ? `${which} · ${v.name}` : which
    if (this.hasSpeakerBadgeTarget) {
      this.speakerBadgeTarget.dataset.voice = isGuide ? "guide" : "host"
    }
  }

  _setPlayLabel(text) {
    if (this.hasPlayPauseLabelTarget) this.playPauseLabelTarget.textContent = text
  }
}
