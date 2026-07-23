import { Controller } from "@hotwired/stimulus"
import { speak, cancelSpeech, listen, canSpeak, canListen } from "speech"

// Trip Concierge chat panel. The server owns the message log (turbo-stream
// appends both the question and the answer), so this controller only handles
// the transient UX: a "thinking…" indicator while the request is in flight,
// clearing the input, keeping the log scrolled to the latest message, and an
// optional hands-free voice mode (mic → speech-to-text → auto-send → the
// answer is read aloud → the mic reopens for the follow-up). Voice goes
// through the speech façade: the browser-native Web Speech API where it
// exists, Android's TextToSpeech/SpeechRecognizer over the native bridge where
// it doesn't. The mic hides only where BOTH are missing (e.g. Firefox).
export default class extends Controller {
  static targets = ["input", "pending", "log", "submit", "mic", "voiceStatus"]

  connect() {
    this.voiceMode = false
    this.listening = false
    this.awaitingReply = false
    this.silentRounds = 0
    this.session = null
    // Don't latch "unsupported" here: on Android the bridge controller lives
    // on <body> and may connect after this one. #voiceSupported re-checks at
    // tap time, and the mic starts visible.
    if (this.hasMicTarget) this.micTarget.hidden = false
  }

  #voiceSupported() {
    return canListen() && canSpeak()
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
    if (this.listening) this.session?.stop()
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
    if (!this.#voiceSupported()) {
      this.#setVoiceStatus("Voice isn't available on this device")
      setTimeout(() => this.#setVoiceStatus(null), 4000)
      if (this.hasMicTarget) this.micTarget.hidden = true
      return
    }
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
    cancelSpeech()
    this.listening = true
    if (this.hasMicTarget) this.micTarget.dataset.listening = "true"
    this.#setVoiceStatus("Listening…")
    this.session = listen({
      onResult: (transcript, isFinal) => this.#onSpeechResult(transcript, isFinal),
      onEnd: () => this.#onSpeechEnd(),
      onError: (code) => this.#onSpeechError(code)
    })
  }

  #onSpeechResult(transcript, isFinal) {
    const text = (transcript || "").trim()
    if (this.hasInputTarget && text) this.inputTarget.value = text
    if (!isFinal) return
    // Soft stop: 1.2s of follow-up silence ends capture and sends.
    clearTimeout(this.silenceTimer)
    this.silenceTimer = setTimeout(() => {
      if (this.listening) this.session?.stop()
    }, 1200)
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

  #onSpeechError(code) {
    this.listening = false
    if (code === "not-allowed" || code === "service-not-allowed") {
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
    this.#setVoiceStatus("Speaking — tap the mic to interrupt")
    speak(text, { onEnd: () => { if (this.voiceMode) this.#listen() } })
  }

  #exitVoiceMode() {
    this.voiceMode = false
    this.awaitingReply = false
    clearTimeout(this.silenceTimer)
    if (this.listening) {
      this.session?.abort()
      this.listening = false
    }
    cancelSpeech()
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
