import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { registerSpeechBridge, unregisterSpeechBridge } from "speech"

// Native speech for the Hotwire Native shells.
//
// BridgeComponent.shouldLoad is false unless the native app advertises the
// "speech" component in its user agent, so on the web this controller never
// connects and speech.js keeps using the Web Speech API. On Android — where
// the WebView has no Web Speech API at all — it connects and hands speech.js
// a bridge to Android's TextToSpeech / SpeechRecognizer.
//
// Mounted once on <body> (see layouts/application.html.erb): speech is a
// device capability, not a property of any one element.
//
// Native counterpart: android/app/src/main/java/.../SpeechComponent.kt
export default class extends BridgeComponent {
  static component = "speech"

  connect() {
    super.connect()
    this.speakingNatively = false
    registerSpeechBridge(this)
  }

  disconnect() {
    unregisterSpeechBridge(this)
    this.stopSpeakingNatively()
    super.disconnect()
    this.speakingNatively = false
  }

  // Native replies once when the utterance finishes (or errors).
  speakNatively(text, { rate, pitch }, callback) {
    this.speakingNatively = true
    this.send("speak", { text, rate, pitch }, (message) => {
      this.speakingNatively = false
      callback?.(message?.data || {})
    })
  }

  stopSpeakingNatively() {
    if (!this.speakingNatively) return
    this.speakingNatively = false
    this.send("stopSpeaking", {})
  }

  // Native may reply more than once — interim transcripts, then a final one —
  // so the bridge deliberately keeps the callback registered after each reply.
  listenNatively({ lang }, callback) {
    this.send("listen", { lang }, (message) => callback?.(message?.data || {}))
  }

  stopListeningNatively() {
    this.send("stopListening", {})
  }
}
