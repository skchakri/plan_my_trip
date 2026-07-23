package com.skchakri.planmytrip

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.Locale

/**
 * Speech for the WebView, which has none.
 *
 * Android's WebView implements neither `speechSynthesis` nor
 * `SpeechRecognition` — a Chromium limitation open since 2015
 * (crbug.com/487255). Every Wanderply feature that talks or listens (the trip
 * podcast, Drive Co-Pilot narration, the concierge mic) was therefore dead in
 * the app while working fine in Chrome on the same phone.
 *
 * This component backs those features with the platform's own
 * [TextToSpeech] and [SpeechRecognizer]. The web side calls it through
 * app/javascript/speech.js, which prefers the Web Speech API and only falls
 * back here — so this is Android-only plumbing, not a second code path for
 * the whole app.
 *
 * Error codes deliberately mirror the Web Speech API's vocabulary
 * ("not-allowed", "no-speech", …) so the JS branches once for both backends.
 */
class SpeechComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    private val fragment: Fragment get() = delegate.destination.fragment

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeak: SpeakData? = null

    private var recognizer: SpeechRecognizer? = null
    private var listening = false

    override fun onReceive(message: Message) {
        when (message.event) {
            "speak" -> handleSpeak(message)
            "stopSpeaking" -> stopSpeaking()
            "listen" -> handleListen(message)
            "stopListening" -> stopListening()
            else -> Log.w(TAG, "Unknown event: ${message.event}")
        }
    }

    override fun onStop() {
        // Leaving the screen must not leave a voice talking over the next one.
        stopSpeaking()
        stopListening()
    }

    // ── Speaking ─────────────────────────────────────────────────────

    private fun handleSpeak(message: Message) {
        val data = message.data<SpeakData>() ?: return

        if (ttsReady) {
            speakNow(data)
            return
        }

        // TextToSpeech initialises asynchronously; hold the request and speak
        // it the moment the engine reports ready.
        pendingSpeak = data
        if (tts != null) return
        tts = TextToSpeech(fragment.requireContext().applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (!ttsReady) {
                replyToSpeak(error = "synthesis-failed")
                pendingSpeak = null
                return@TextToSpeech
            }
            tts?.language = Locale.getDefault()
            tts?.setOnUtteranceProgressListener(utteranceListener)
            pendingSpeak?.let { speakNow(it) }
            pendingSpeak = null
        }
    }

    private fun speakNow(data: SpeakData) {
        val engine = tts ?: return
        engine.setSpeechRate(data.rate.toFloat().coerceIn(0.1f, 4.0f))
        engine.setPitch(data.pitch.toFloat().coerceIn(0.1f, 2.0f))
        val result = engine.speak(data.text, TextToSpeech.QUEUE_FLUSH, null, UTTERANCE_ID)
        if (result == TextToSpeech.ERROR) replyToSpeak(error = "synthesis-failed")
    }

    private val utteranceListener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {}

        override fun onDone(utteranceId: String?) {
            replyToSpeak()
        }

        @Deprecated("Required by UtteranceProgressListener", ReplaceWith(""))
        override fun onError(utteranceId: String?) {
            replyToSpeak(error = "synthesis-failed")
        }

        override fun onError(utteranceId: String?, errorCode: Int) {
            replyToSpeak(error = "synthesis-failed")
        }

        // QUEUE_FLUSH from our own stopSpeaking() lands here. The web side
        // treats a stop as a normal end, same as the Web Speech API does.
        override fun onStop(utteranceId: String?, interrupted: Boolean) {
            replyToSpeak()
        }
    }

    private fun stopSpeaking() {
        tts?.stop()
        pendingSpeak = null
    }

    private fun replyToSpeak(error: String? = null) {
        // Bridge replies must happen on the main thread — TTS callbacks don't.
        fragment.view?.post { replyTo("speak", SpeakReply(done = true, error = error)) }
    }

    // ── Listening ────────────────────────────────────────────────────

    private fun handleListen(message: Message) {
        val data = message.data<ListenData>() ?: ListenData()

        if (!hasMicPermission()) {
            // The shell asks for RECORD_AUDIO up front (MainActivity); if it
            // was denied there's nothing useful to do here but say so, using
            // the same code the Web Speech API uses.
            replyToListen(error = "not-allowed")
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(fragment.requireContext())) {
            replyToListen(error = "service-not-allowed")
            return
        }

        stopListening()
        val context = fragment.requireContext().applicationContext
        recognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(recognitionListener)
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, data.lang)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }
        listening = true
        recognizer?.startListening(intent)
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onPartialResults(partialResults: Bundle?) {
            firstResult(partialResults)?.let { replyToListen(transcript = it, final = false) }
        }

        override fun onResults(results: Bundle?) {
            listening = false
            replyToListen(transcript = firstResult(results).orEmpty(), final = true)
        }

        override fun onError(error: Int) {
            listening = false
            replyToListen(error = webSpeechError(error))
        }

        private fun firstResult(bundle: Bundle?): String? =
            bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
    }

    private fun stopListening() {
        if (listening) recognizer?.stopListening()
        listening = false
        recognizer?.destroy()
        recognizer = null
    }

    private fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            fragment.requireContext(), Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

    /** Android recognizer codes → the Web Speech API strings the JS expects. */
    private fun webSpeechError(code: Int): String = when (code) {
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "not-allowed"
        SpeechRecognizer.ERROR_NO_MATCH,
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no-speech"
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "network"
        SpeechRecognizer.ERROR_CLIENT -> "aborted"
        else -> "audio-capture"
    }

    private fun replyToListen(transcript: String? = null, final: Boolean = false, error: String? = null) {
        fragment.view?.post {
            replyTo("listen", ListenReply(transcript = transcript, final = final, error = error))
        }
    }

    @Serializable
    data class SpeakData(
        @SerialName("text") val text: String = "",
        @SerialName("rate") val rate: Double = 1.0,
        @SerialName("pitch") val pitch: Double = 1.0
    )

    @Serializable
    data class ListenData(
        @SerialName("lang") val lang: String = "en-US"
    )

    @Serializable
    data class SpeakReply(
        @SerialName("done") val done: Boolean = true,
        @SerialName("error") val error: String? = null
    )

    @Serializable
    data class ListenReply(
        @SerialName("transcript") val transcript: String? = null,
        @SerialName("final") val final: Boolean = false,
        @SerialName("error") val error: String? = null
    )

    private companion object {
        const val TAG = "SpeechComponent"
        const val UTTERANCE_ID = "wanderply-speech"
    }
}
