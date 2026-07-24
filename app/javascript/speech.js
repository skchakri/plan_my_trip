// One speech API for the whole app, with two backends.
//
// Android WebView implements NEITHER `speechSynthesis` NOR `SpeechRecognition`
// — a Chromium limitation open since 2015 (crbug.com/487255). The same page
// speaks fine in Chrome on the same phone and is silent inside the Hotwire
// Native shell. So every caller goes through here, and here picks:
//
//   1. The Web Speech API when the browser has it (desktop, mobile web, iOS).
//   2. The native bridge otherwise — Android's own TextToSpeech and
//      SpeechRecognizer, reached through the `speech` bridge component
//      (see controllers/speech_bridge_controller.js + SpeechComponent.kt).
//
// Callers must not touch window.speechSynthesis directly; if they do, Android
// silently loses the feature again.

import { getSpeed } from "tts_settings"

// Set by the bridge controller when the native shell advertises the component.
// Null everywhere else, which is the signal to use the Web Speech API.
let bridge = null

// Controllers that hide a mic/speak affordance when unsupported listen for
// this, because the bridge can connect after they do — Stimulus generally
// wires <body> before its descendants, but lazy controller loading makes that
// an ordering assumption not worth betting a dead button on.
export const SPEECH_CHANGED = "wanderply:speech-changed"

function announce() {
  document.dispatchEvent(new CustomEvent(SPEECH_CHANGED))
}

export function registerSpeechBridge(component) {
  bridge = component
  announce()
}

export function unregisterSpeechBridge(component) {
  if (bridge !== component) return
  bridge = null
  announce()
}

const nativeSpeech = () => bridge
const webSynthesis = () => ("speechSynthesis" in window ? window.speechSynthesis : null)
const WebRecognition = () => window.SpeechRecognition || window.webkitSpeechRecognition || null

// Whether the Web Speech synthesis has at least one installed voice. The API
// object can be present with no voices at all (desktop Linux Chrome without
// speech-dispatcher voices), where speak() silently produces nothing.
const hasWebVoices = (synth) => Boolean(synth && (synth.getVoices() || []).length)

// Voices often populate asynchronously — wait one `voiceschanged` (capped) so a
// capable-but-still-loading browser isn't wrongly reported as voiceless.
function waitForWebVoices(synth, done) {
  let settled = false
  const finish = () => {
    if (settled) return
    settled = true
    synth.removeEventListener?.("voiceschanged", finish)
    clearTimeout(timer)
    done()
  }
  synth.addEventListener?.("voiceschanged", finish)
  const timer = setTimeout(finish, 600)
}

// ── Capability checks ────────────────────────────────────────────────
// Call these instead of `"speechSynthesis" in window`.

export function canSpeak() {
  return Boolean(webSynthesis() || nativeSpeech())
}

export function canListen() {
  return Boolean(WebRecognition() || nativeSpeech())
}

// Shown when a device can't do it at all, so the copy can be honest about why.
export const UNSUPPORTED_SPEAK = "This device can't read text aloud."
export const UNSUPPORTED_LISTEN = "This device can't take voice input."

// ── Speaking ─────────────────────────────────────────────────────────

let activeWebUtterance = null

// The browser's installed voices, for callers that cast different speakers
// (the podcast host vs guide). Empty on the native path — there, differentiate
// with `pitch` instead.
export function availableVoices() {
  const synth = webSynthesis()
  return synth ? (synth.getVoices() || []) : []
}

export function onVoicesChanged(handler) {
  const synth = webSynthesis()
  if (synth) synth.onvoiceschanged = handler
}

// speak(text, { rate, pitch, voice, onEnd, onError }) — onEnd fires exactly
// once, on natural completion, on error, or on cancel. `voice` is a
// SpeechSynthesisVoice and is ignored on the native path.
export function speak(text, { rate = 1.0, pitch = 1.0, voice = null, onEnd, onError } = {}) {
  const body = (text || "").toString().trim()
  if (!body) {
    onEnd?.()
    return
  }

  const finishOnce = once(() => onEnd?.())
  const synth = webSynthesis()

  if (synth) {
    const startWebUtterance = () => {
      synth.cancel()
      const utterance = new SpeechSynthesisUtterance(body)
      utterance.rate = rate * getSpeed()
      utterance.pitch = pitch
      if (voice) utterance.voice = voice
      utterance.onend = finishOnce
      utterance.onerror = (event) => {
        // "interrupted"/"canceled" are our own cancel() landing — not failures.
        if (event?.error && event.error !== "interrupted" && event.error !== "canceled") {
          onError?.(event.error)
        }
        finishOnce()
      }
      activeWebUtterance = utterance
      synth.speak(utterance)
    }

    // The API can exist with ZERO installed voices — most often desktop Linux
    // Chrome without speech-dispatcher voices — where synth.speak() is a silent
    // no-op. Voices can also just be loading (browsers populate them async), so
    // wait one `voiceschanged` (capped) before answering honestly rather than
    // faking a read that produces no sound.
    if (hasWebVoices(synth)) {
      startWebUtterance()
    } else {
      waitForWebVoices(synth, () => {
        if (hasWebVoices(synth)) {
          startWebUtterance()
        } else {
          onError?.(UNSUPPORTED_SPEAK)
          finishOnce()
        }
      })
    }
    return
  }

  const native = nativeSpeech()
  if (!native) {
    onError?.(UNSUPPORTED_SPEAK)
    finishOnce()
    return
  }
  native.speakNatively(body, { rate: rate * getSpeed(), pitch }, (reply) => {
    if (reply?.error) onError?.(reply.error)
    finishOnce()
  })
}

export function cancelSpeech() {
  const synth = webSynthesis()
  if (synth) {
    synth.cancel()
    activeWebUtterance = null
    return
  }
  nativeSpeech()?.stopSpeakingNatively()
}

export function isSpeaking() {
  const synth = webSynthesis()
  if (synth) return synth.speaking
  return Boolean(nativeSpeech()?.speakingNatively)
}

// ── Listening ────────────────────────────────────────────────────────
//
// Returns a handle with .stop() and .abort(). Callbacks:
//   onResult(transcript, isFinal), onEnd(), onError(code)
// `code` is a Web Speech error string ("not-allowed", "no-speech", …); the
// native side reports the same vocabulary so callers branch once.

export function listen({ onResult, onEnd, onError, interim = true, lang } = {}) {
  const Recognition = WebRecognition()

  if (Recognition) {
    const recognition = new Recognition()
    recognition.lang = lang || document.documentElement.lang || "en-US"
    recognition.interimResults = interim
    recognition.continuous = false
    recognition.onresult = (event) => {
      const result = event.results[event.results.length - 1]
      onResult?.(result[0].transcript, result.isFinal)
    }
    recognition.onerror = (event) => onError?.(event.error)
    recognition.onend = () => onEnd?.()
    recognition.start()
    return {
      stop: () => recognition.stop(),
      abort: () => recognition.abort()
    }
  }

  const native = nativeSpeech()
  if (!native) {
    onError?.("service-not-allowed")
    onEnd?.()
    return { stop: () => {}, abort: () => {} }
  }

  native.listenNatively({ lang: lang || "en-US" }, (reply) => {
    if (reply?.error) {
      onError?.(reply.error)
      onEnd?.()
      return
    }
    if (reply?.transcript) onResult?.(reply.transcript, Boolean(reply.final))
    if (reply?.final || reply?.done) onEnd?.()
  })
  return {
    stop: () => native.stopListeningNatively(),
    abort: () => native.stopListeningNatively()
  }
}

function once(fn) {
  let called = false
  return (...args) => {
    if (called) return
    called = true
    fn(...args)
  }
}
