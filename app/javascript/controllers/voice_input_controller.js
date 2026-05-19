import { Controller } from "@hotwired/stimulus"

// Voice-to-text for a paired text input. Uses the browser-native
// SpeechRecognition (Web Speech API) — no API key, no server roundtrip,
// works offline once the browser model has cached the language pack.
//
// Markup:
//   <div data-controller="voice-input">
//     <input data-voice-input-target="input" name="q">
//     <button type="button" data-action="click->voice-input#toggle"
//             data-voice-input-target="button">🎤</button>
//     <span data-voice-input-target="status" hidden></span>
//   </div>
//
// On supported browsers (Chrome, Edge, Safari 14.1+) clicking the mic
// starts continuous recognition with interim results piped into the input.
// Pressing again, or 1.5s of silence after a final result, stops capture
// and auto-submits the form if `data-voice-input-submit-on-end-value="true"`.
export default class extends Controller {
  static targets = ["input", "button", "status"]
  static values = { submitOnEnd: { type: Boolean, default: false } }

  connect() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SR) {
      // Browser doesn't support the API — hide the mic so the UI doesn't
      // imply a feature that won't work. Text input still functions.
      if (this.hasButtonTarget) this.buttonTarget.hidden = true
      return
    }
    this.recognition = new SR()
    this.recognition.lang = navigator.language || "en-US"
    this.recognition.continuous = false
    this.recognition.interimResults = true

    this.recognition.addEventListener("result", (e) => this._onResult(e))
    this.recognition.addEventListener("end",    ()  => this._onEnd())
    this.recognition.addEventListener("error",  (e) => this._onError(e))

    this.listening = false
    this._setIdle()
  }

  disconnect() {
    if (this.recognition && this.listening) {
      try { this.recognition.abort() } catch (_) {}
    }
  }

  toggle(event) {
    event?.preventDefault?.()
    if (!this.recognition) return
    if (this.listening) {
      try { this.recognition.stop() } catch (_) {}
    } else {
      this._baseline = this.inputTarget.value
      try {
        this.recognition.start()
        this.listening = true
        this._setListening()
      } catch (err) {
        // start() throws if invoked twice rapidly — recover silently.
        this._setIdle()
      }
    }
  }

  _onResult(event) {
    let interim = ""
    let finalTxt = ""
    for (let i = event.resultIndex; i < event.results.length; i++) {
      const res = event.results[i]
      if (res.isFinal) finalTxt += res[0].transcript
      else interim += res[0].transcript
    }
    const base = (this._baseline || "").trim()
    const combined = [base, (finalTxt + interim).trim()].filter(Boolean).join(" ").trim()
    this.inputTarget.value = combined
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))

    if (finalTxt) {
      // After a final result, schedule a soft stop so the user can pause
      // mid-thought without losing the mic — 1.5s of follow-up silence
      // ends capture cleanly.
      clearTimeout(this._idleTimer)
      this._idleTimer = setTimeout(() => {
        if (this.listening) {
          try { this.recognition.stop() } catch (_) {}
        }
      }, 1500)
    }
  }

  _onEnd() {
    this.listening = false
    this._setIdle()
    if (this.submitOnEndValue && this.inputTarget.value.trim()) {
      const form = this.inputTarget.form
      if (form) form.requestSubmit()
    }
  }

  _onError(event) {
    this.listening = false
    this._setIdle()
    if (this.hasStatusTarget) {
      this.statusTarget.hidden = false
      this.statusTarget.textContent = `Voice error: ${event.error || "unknown"}`
      setTimeout(() => { this.statusTarget.hidden = true }, 3000)
    }
  }

  _setListening() {
    if (this.hasButtonTarget) {
      this.buttonTarget.dataset.listening = "true"
      this.buttonTarget.setAttribute("aria-pressed", "true")
    }
    if (this.hasStatusTarget) {
      this.statusTarget.hidden = false
      this.statusTarget.textContent = "Listening…"
    }
  }

  _setIdle() {
    if (this.hasButtonTarget) {
      this.buttonTarget.dataset.listening = "false"
      this.buttonTarget.setAttribute("aria-pressed", "false")
    }
    if (this.hasStatusTarget) {
      this.statusTarget.hidden = true
      this.statusTarget.textContent = ""
    }
  }
}
