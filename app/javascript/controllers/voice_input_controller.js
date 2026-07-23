import { Controller } from "@hotwired/stimulus"
import { listen, canListen } from "speech"

// Voice-to-text for a paired text input, through the speech façade: the Web
// Speech API where it exists, Android's SpeechRecognizer via the native bridge
// where it doesn't.
//
// Markup:
//   <div data-controller="voice-input">
//     <input data-voice-input-target="input" name="q">
//     <button type="button" data-action="click->voice-input#toggle"
//             data-voice-input-target="button">🎤</button>
//     <span data-voice-input-target="status" hidden></span>
//   </div>
//
// Clicking the mic starts recognition with interim results piped into the
// input. Pressing again, or 1.5s of silence after a final result, stops
// capture and auto-submits the form if
// `data-voice-input-submit-on-end-value="true"`.
export default class extends Controller {
  static targets = ["input", "button", "status"]
  static values = { submitOnEnd: { type: Boolean, default: false } }

  connect() {
    this.listening = false
    this.session = null
    this._setIdle()
    // The bridge controller on <body> may connect after this one, so don't
    // latch "unsupported" — re-check when the button is actually pressed.
    if (this.hasButtonTarget) this.buttonTarget.hidden = false
  }

  disconnect() {
    clearTimeout(this._idleTimer)
    this.session?.abort()
    this.listening = false
  }

  toggle(event) {
    event?.preventDefault?.()
    if (this.listening) {
      this.session?.stop()
      return
    }
    if (!canListen()) {
      this._flashStatus("Voice input isn't available on this device")
      if (this.hasButtonTarget) this.buttonTarget.hidden = true
      return
    }

    this._baseline = this.inputTarget.value
    this.listening = true
    this._setListening()
    this.session = listen({
      onResult: (transcript, isFinal) => this._onResult(transcript, isFinal),
      onEnd: () => this._onEnd(),
      onError: (code) => this._onError(code)
    })
  }

  _onResult(transcript, isFinal) {
    const base = (this._baseline || "").trim()
    this.inputTarget.value = [ base, transcript.trim() ].filter(Boolean).join(" ").trim()
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))

    if (!isFinal) return
    // After a final result, schedule a soft stop so the user can pause
    // mid-thought without losing the mic — 1.5s of follow-up silence ends
    // capture cleanly.
    clearTimeout(this._idleTimer)
    this._idleTimer = setTimeout(() => {
      if (this.listening) this.session?.stop()
    }, 1500)
  }

  _onEnd() {
    clearTimeout(this._idleTimer)
    this.listening = false
    this._setIdle()
    if (this.submitOnEndValue && this.inputTarget.value.trim()) {
      this.inputTarget.form?.requestSubmit()
    }
  }

  _onError(code) {
    this.listening = false
    this._setIdle()
    this._flashStatus(
      code === "not-allowed" || code === "service-not-allowed"
        ? "Microphone blocked — allow mic access to talk"
        : `Voice error: ${code || "unknown"}`
    )
  }

  _flashStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.hidden = false
    this.statusTarget.textContent = message
    clearTimeout(this._statusTimer)
    this._statusTimer = setTimeout(() => { this.statusTarget.hidden = true }, 3000)
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
