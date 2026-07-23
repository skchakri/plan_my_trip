import AVFoundation
import HotwireNative
import Speech
import UIKit

/// Speech for the iOS shell.
///
/// WKWebView *does* implement `speechSynthesis`, so the trip podcast, Read
/// aloud, and Drive Co-Pilot narration already work on iOS through the Web
/// Speech API — app/javascript/speech.js keeps speaking there and never calls
/// this component's `speak`. What WKWebView lacks is `SpeechRecognition`, so
/// the concierge/day-trip mic was dead: the façade falls back to this
/// component's `listen`, which drives `SFSpeechRecognizer` + `AVAudioEngine`.
///
/// `speak` is implemented anyway so the bridge honours the full contract (and
/// covers any WebView variant missing synthesis); it's simply not exercised on
/// a normal iOS build.
///
/// Error codes mirror the Web Speech API's vocabulary ("not-allowed",
/// "no-speech", …) so the JS branches once for both backends.
///
/// Web counterpart: app/javascript/controllers/speech_bridge_controller.js
final class SpeechComponent: BridgeComponent {
    override class var name: String { "speech" }

    // MARK: Speaking (AVSpeechSynthesizer)

    private lazy var synthesizer: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = speechDelegate
        return s
    }()

    private lazy var speechDelegate = SynthesizerDelegate { [weak self] in
        self?.reply(to: "speak", with: SpeakReply())
    }

    // MARK: Listening (SFSpeechRecognizer)

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    override func onReceive(message: Message) {
        switch message.event {
        case "speak": handleSpeak(message: message)
        case "stopSpeaking": stopSpeaking()
        case "listen": handleListen(message: message)
        case "stopListening": stopListening()
        default: break
        }
    }

    // Leaving the screen must not leave a voice talking or the mic hot.
    override func onViewDidDisappear() {
        stopSpeaking()
        stopListening()
    }

    // MARK: - Speaking

    private func handleSpeak(message: Message) {
        guard let data: SpeakMessageData = message.data() else { return }

        let utterance = AVSpeechUtterance(string: data.text)
        // Web `rate` is ~1.0 = normal; AVSpeech uses 0…1 around a slower
        // default, so scale onto that curve and clamp.
        utterance.rate = Self.avRate(forWebRate: data.rate)
        utterance.pitchMultiplier = Float(max(0.5, min(2.0, data.pitch)))

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    private func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// AVSpeech's normal rate is `AVSpeechUtteranceDefaultSpeechRate` (~0.5).
    /// Web `rate: 1.0` should sound normal, `2.0` fast, `0.5` slow.
    private static func avRate(forWebRate webRate: Double) -> Float {
        let normal = AVSpeechUtteranceDefaultSpeechRate
        let scaled = normal * Float(max(0.1, min(4.0, webRate)))
        return max(AVSpeechUtteranceMinimumSpeechRate,
                   min(AVSpeechUtteranceMaximumSpeechRate, scaled))
    }

    // MARK: - Listening

    private func handleListen(message: Message) {
        let data: ListenMessageData = message.data() ?? ListenMessageData()

        requestAuthorization { [weak self] authorized in
            guard let self else { return }
            guard authorized else {
                self.reply(to: "listen", with: ListenReply(error: "not-allowed"))
                return
            }
            do {
                try self.startRecognition(lang: data.lang)
            } catch {
                self.reply(to: "listen", with: ListenReply(error: "audio-capture"))
            }
        }
    }

    private func startRecognition(lang: String) throws {
        stopListening()

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: lang))
            ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            reply(to: "listen", with: ListenReply(error: "service-not-allowed"))
            return
        }
        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // The recognition handler is called on an arbitrary queue, but bridge
        // replies post into the WKWebView and audio teardown touches UIKit
        // state — both must run on main.
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString
                    self.reply(to: "listen", with: ListenReply(transcript: transcript, final: result.isFinal))
                    if result.isFinal { self.stopListening() }
                }
                if let error {
                    // A stop after a good final result surfaces here too; only
                    // report when the task is still live (nothing transcribed).
                    if self.task != nil {
                        self.reply(to: "listen", with: ListenReply(error: Self.webError(from: error)))
                        self.stopListening()
                    }
                }
            }
        }
    }

    private func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Authorization

    /// Both speech-recognition and microphone permission are required. Asked
    /// on first use; iOS remembers the answer thereafter.
    private func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                DispatchQueue.main.async { completion(micGranted) }
            }
        }
    }

    /// SFSpeech / NSError → the Web Speech API strings the JS expects.
    private static func webError(from error: Error) -> String {
        let nsError = error as NSError
        // 203 = "no speech detected"; 216/1110 = no match, in practice.
        switch nsError.code {
        case 203, 216, 1110: return "no-speech"
        case 4, 301: return "aborted"
        default: return "audio-capture"
        }
    }

    // MARK: - Message payloads

    private struct SpeakMessageData: Decodable {
        let text: String
        var rate: Double = 1.0
        var pitch: Double = 1.0
    }

    private struct ListenMessageData: Decodable {
        var lang: String = "en-US"
    }

    private struct SpeakReply: Encodable {
        var done: Bool = true
    }

    private struct ListenReply: Encodable {
        var transcript: String?
        var final: Bool = false
        var error: String?
    }
}

/// AVSpeechSynthesizer's delegate must be an NSObject; the closure fires when
/// an utterance finishes or is cancelled — both are a normal "ended" to the
/// web side, matching the Web Speech API.
private final class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish() }
    }
}
