import { Controller } from "@hotwired/stimulus"
import { speak, cancelSpeech, canSpeak, UNSUPPORTED_SPEAK } from "speech"

// Speaks text through the speech façade (Web Speech API, or the native bridge
// on Android where the WebView has no Web Speech API).
// Usage in markup:
//   <button data-controller="tts" data-tts-text-value="Hello world">▶ Read aloud</button>
// or:
//   <button data-controller="tts" data-action="tts#speak"
//           data-tts-target-selector-value="#some-section">Read this section</button>
export default class extends Controller {
  static values = {
    text: String,
    targetSelector: String,
    rate: { type: Number, default: 1.0 },
    pitch: { type: Number, default: 1.0 }
  }

  connect() {
    this._speaking = false
    // The bridge controller connects on <body>, which Stimulus may not have
    // wired yet when a deep-in-the-page button connects. Re-check on click
    // rather than latching "unsupported" here forever.
    this.element.addEventListener("click", this.toggle.bind(this))
  }

  disconnect() {
    if (this._speaking) cancelSpeech()
  }

  toggle(e) {
    e.preventDefault()
    if (this._speaking) {
      cancelSpeech()
      this._setSpeaking(false)
      return
    }
    this.speak()
  }

  speak() {
    const text = this._collectText()
    if (!text) return
    if (!canSpeak()) {
      this.element.title = UNSUPPORTED_SPEAK
      return
    }
    this._setSpeaking(true)
    speak(text, {
      rate: this.rateValue,
      pitch: this.pitchValue,
      onEnd: () => this._setSpeaking(false)
    })
  }

  _collectText() {
    if (this.hasTextValue && this.textValue.length) return this.textValue
    if (this.hasTargetSelectorValue) {
      const el = document.querySelector(this.targetSelectorValue)
      if (el) return el.innerText.replace(/\s+/g, " ").trim()
    }
    return ""
  }

  _setSpeaking(flag) {
    this._speaking = flag
    this.element.dataset.ttsActive = flag ? "true" : "false"
    const lbl = this.element.querySelector("[data-tts-label]")
    if (lbl) lbl.textContent = flag ? (lbl.dataset.stopLabel || "Stop") : (lbl.dataset.playLabel || "Read aloud")
  }
}
