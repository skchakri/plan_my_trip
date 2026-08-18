import { Controller } from "@hotwired/stimulus"
import { speak, cancelSpeech, canSpeak, availableVoices, onVoicesChanged } from "speech"
import { track } from "controllers/track_controller"

// "Hear a stop" — plays a canned two-voice narration entirely client-side
// (Web Speech, no AI call, no account) so a visitor experiences the wedge
// BEFORE the sign-up wall. Lines come from the partial as JSON:
//   [{ voice: "host"|"guide", text, rate, pitch, pause }]
// Mirrors reading_mode_controller's host/guide casting; degrades to a
// transcript-only card when the device has no TTS voices.
export default class extends Controller {
  static values = { lines: Array, label: String }
  static targets = ["button", "buttonLabel", "line", "unsupported"]

  HOST_HINTS  = [/Samantha/i, /Karen/i, /Allison/i, /Ava/i, /Google US English/i, /Microsoft Zira/i, /Microsoft Aria/i, /Female/i]
  GUIDE_HINTS = [/Daniel/i, /Alex/i, /Aaron/i, /Google UK English Male/i, /Microsoft Mark/i, /Microsoft Guy/i, /Male/i]

  connect() {
    this._playing = false
    this._token = 0
    this._loadVoices()
    onVoicesChanged(() => this._loadVoices())
    if (!canSpeak()) {
      if (this.hasButtonTarget) this.buttonTarget.hidden = true
      if (this.hasUnsupportedTarget) this.unsupportedTarget.hidden = false
    }
  }

  disconnect() { this.stop() }

  toggle(event) {
    if (event) event.preventDefault()
    this._playing ? this.stop() : this.play()
  }

  play() {
    if (!canSpeak() || !this.linesValue.length) return
    this._playing = true
    this._token += 1
    this._setLabel("Stop")
    this.element.dataset.playing = "true"
    track("sample_narration_played", { placement: this.labelValue || null })
    this._speakFrom(0, this._token)
  }

  stop() {
    if (!this._playing) return
    this._playing = false
    this._token += 1
    cancelSpeech()
    this._highlight(-1)
    this._setLabel("Hear a stop")
    delete this.element.dataset.playing
  }

  _speakFrom(i, token) {
    if (token !== this._token) return
    if (i >= this.linesValue.length) { this.stop(); return }
    const line = this.linesValue[i]
    this._highlight(i)
    speak(line.text || "", {
      rate: line.rate || 1.0,
      pitch: line.pitch || 1.0,
      voice: line.voice === "guide" ? this._guideVoice : this._hostVoice,
      onEnd: () => { if (token === this._token) setTimeout(() => this._speakFrom(i + 1, token), line.pause || 250) },
      onError: () => { if (token === this._token) this._speakFrom(i + 1, token) }
    })
  }

  _highlight(idx) {
    this.lineTargets.forEach((el, j) => {
      el.classList.toggle("text-amber-200", j === idx)
      el.classList.toggle("text-slate-400", j !== idx)
    })
  }

  _setLabel(text) { if (this.hasButtonLabelTarget) this.buttonLabelTarget.textContent = text }

  _loadVoices() {
    const voices = availableVoices()
    if (!voices.length) return
    const en = voices.filter(v => /^en([-_]|$)/i.test(v.lang))
    const pool = en.length ? en : voices
    const first = (hints) => { for (const h of hints) { const f = pool.find(v => h.test(v.name)); if (f) return f } return null }
    this._hostVoice  = first(this.HOST_HINTS)  || pool[0] || null
    this._guideVoice = first(this.GUIDE_HINTS) || pool.find(v => v !== this._hostVoice) || this._hostVoice
  }
}
