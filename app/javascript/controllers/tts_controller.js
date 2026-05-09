import { Controller } from "@hotwired/stimulus"

// Speaks text via the Web Speech API.
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
    if (!("speechSynthesis" in window)) {
      this.element.disabled = true
      this.element.title = "Your browser doesn't support speech synthesis."
    } else {
      // If something else cancels speech, repaint our button.
      this._onEnd = () => this._setSpeaking(false)
    }
    this.element.addEventListener("click", this.toggle.bind(this))
  }

  disconnect() {
    if (this._speaking) window.speechSynthesis.cancel()
  }

  toggle(e) {
    e.preventDefault()
    if (this._speaking) {
      window.speechSynthesis.cancel()
      this._setSpeaking(false)
      return
    }
    this.speak()
  }

  speak() {
    const text = this._collectText()
    if (!text || !("speechSynthesis" in window)) return
    window.speechSynthesis.cancel() // stop anything else mid-speak
    const utter = new SpeechSynthesisUtterance(text)
    utter.rate  = this.rateValue
    utter.pitch = this.pitchValue
    utter.onend = utter.onerror = () => this._setSpeaking(false)
    this._setSpeaking(true)
    window.speechSynthesis.speak(utter)
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
