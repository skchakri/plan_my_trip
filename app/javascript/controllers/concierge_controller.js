import { Controller } from "@hotwired/stimulus"
import { getSpeed } from "tts_settings"

// Trip Concierge chat panel. The server owns the message log (turbo-stream
// appends both the question and the answer), so this controller only handles
// the transient UX: a "thinking…" indicator while the request is in flight,
// clearing the input, keeping the log scrolled to the latest message, and an
// optional hands-free voice mode (mic → speech-to-text → auto-send → the
// answer is read aloud → the mic reopens for the follow-up). Voice uses the
// browser-native Web Speech API — no key, no server audio roundtrip. The mic
// button hides itself where the API is missing (Firefox, native WKWebView).
export default class extends Controller {
  static targets = ["input", "pending", "log", "submit", "mic", "voiceStatus"]

  connect() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    this.voiceMode = false
    this.listening = false
    this.awaitingReply = false
    this.silentRounds = 0
    if (!SR || !("speechSynthesis" in window)) {
      if (this.hasMicTarget) this.micTarget.hidden = true
      return
    }
    this.recognition = new SR()
    this.recognition.lang = navigator.language || "en-US"
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.addEventListener("result", (e) => this.#onSpeechResult(e))
    this.recognition.addEventListener("end",    ()  => this.#onSpeechEnd())
    this.recognition.addEventListener("error",  (e) => this.#onSpeechError(e))
  }

  disconnect() {
    this.#exitVoiceMode()
  }

  // turbo:submit-start
  pending(event) {
    if (this.hasInputTarget && !this.inputTarget.value.trim()) {
      event.preventDefault()
      return
    }
    // A suggestion chip can submit while the mic is open — close it so the
    // recognizer doesn't transcribe over the in-flight question.
    if (this.listening) {
      try { this.recognition.stop() } catch (_) {}
    }
    if (this.hasPendingTarget) this.pendingTarget.hidden = false
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    this.scroll()
  }

  // turbo:submit-end
  done() {
    if (this.hasPendingTarget) this.pendingTarget.hidden = true
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      // Focusing mid-conversation pops the keyboard on mobile — skip in voice mode.
      if (!this.voiceMode) this.inputTarget.focus()
    }
    // Let the appended turbo-stream paint before scrolling to it.
    requestAnimationFrame(() => {
      this.scroll()
      if (this.voiceMode && this.awaitingReply) {
        this.awaitingReply = false
        this.#speakLastAnswer()
      }
    })
  }

  // Click an example chip → drop it in the box and send.
  suggest(event) {
    const q = event.currentTarget.dataset.question
    if (!q || !this.hasInputTarget) return
    this.inputTarget.value = q
    this.element.querySelector("form")?.requestSubmit()
  }

  // Enter to send, Shift+Enter for a newline.
  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      event.target.closest("form")?.requestSubmit()
    }
  }

  // Dismiss a proposed-edit card without applying it (purely client-side).
  dismissEdit(event) {
    const id = event.currentTarget.dataset.editId
    if (id) document.getElementById(id)?.remove()
  }

  scroll() {
    if (this.hasLogTarget) this.logTarget.scrollTop = this.logTarget.scrollHeight
  }

  // ---- Voice mode ----------------------------------------------------

  // Mic button. One tap enters voice mode and opens the mic; tapping again
  // (including mid-answer, to interrupt the speech) exits it.
  toggleVoice(event) {
    event?.preventDefault?.()
    if (!this.recognition) return
    if (this.voiceMode) {
      this.#exitVoiceMode()
    } else {
      this.voiceMode = true
      this.silentRounds = 0
      if (this.hasMicTarget) this.micTarget.setAttribute("aria-pressed", "true")
      this.#listen()
    }
  }

  #listen() {
    if (!this.voiceMode || this.listening) return
    window.speechSynthesis.cancel()
    try {
      this.recognition.start()
      this.listening = true
      if (this.hasMicTarget) this.micTarget.dataset.listening = "true"
      this.#setVoiceStatus("Listening…")
    } catch (_) {
      // start() throws if called twice rapidly — recover on the next end event.
    }
  }

  #onSpeechResult(event) {
    let interim = ""
    let finalTxt = ""
    for (let i = event.resultIndex; i < event.results.length; i++) {
      const res = event.results[i]
      if (res.isFinal) finalTxt += res[0].transcript
      else interim += res[0].transcript
    }
    const text = (finalTxt + interim).trim()
    if (this.hasInputTarget && text) this.inputTarget.value = text
    if (finalTxt) {
      // Soft stop: 1.2s of follow-up silence ends capture and sends.
      clearTimeout(this.silenceTimer)
      this.silenceTimer = setTimeout(() => {
        if (this.listening) {
          try { this.recognition.stop() } catch (_) {}
        }
      }, 1200)
    }
  }

  #onSpeechEnd() {
    this.listening = false
    if (this.hasMicTarget) this.micTarget.dataset.listening = "false"
    if (!this.voiceMode) {
      this.#setVoiceStatus(null)
      return
    }
    const text = this.hasInputTarget ? this.inputTarget.value.trim() : ""
    if (text) {
      this.silentRounds = 0
      this.awaitingReply = true
      this.element.querySelector("form")?.requestSubmit()
    } else if (++this.silentRounds <= 2) {
      // The recognizer times out after a few silent seconds — reopen it so a
      // pause doesn't hang up the conversation, but give up after two
      // empty rounds rather than keeping the mic hot indefinitely.
      this.#listen()
    } else {
      this.#exitVoiceMode()
    }
  }

  #onSpeechError(event) {
    this.listening = false
    if (event.error === "not-allowed" || event.error === "service-not-allowed") {
      this.#exitVoiceMode()
      this.#setVoiceStatus("Microphone blocked — allow mic access to talk")
      setTimeout(() => this.#setVoiceStatus(null), 4000)
    }
    // Other errors ("no-speech", "aborted") fall through to the end event,
    // which handles retry/exit.
  }

  #speakLastAnswer() {
    const answers = this.hasLogTarget ? this.logTarget.querySelectorAll(".prose-concierge") : []
    const last = answers[answers.length - 1]
    const text = last ? last.innerText.replace(/\s+/g, " ").trim() : ""
    if (!text) {
      this.#listen()
      return
    }
    window.speechSynthesis.cancel()
    const utter = new SpeechSynthesisUtterance(text)
    utter.rate = getSpeed()
    utter.onend = utter.onerror = () => {
      if (this.voiceMode) this.#listen()
    }
    this.#setVoiceStatus("Speaking — tap the mic to interrupt")
    window.speechSynthesis.speak(utter)
  }

  #exitVoiceMode() {
    this.voiceMode = false
    this.awaitingReply = false
    clearTimeout(this.silenceTimer)
    if (this.listening) {
      try { this.recognition.abort() } catch (_) {}
      this.listening = false
    }
    if ("speechSynthesis" in window) window.speechSynthesis.cancel()
    if (this.hasMicTarget) {
      this.micTarget.dataset.listening = "false"
      this.micTarget.setAttribute("aria-pressed", "false")
    }
    this.#setVoiceStatus(null)
  }

  #setVoiceStatus(text) {
    if (!this.hasVoiceStatusTarget) return
    this.voiceStatusTarget.hidden = !text
    this.voiceStatusTarget.textContent = text || ""
  }
}
