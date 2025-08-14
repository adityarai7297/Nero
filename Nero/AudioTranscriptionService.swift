import Foundation
import Speech
import AVFoundation

@MainActor
class AudioTranscriptionService: NSObject, ObservableObject {
    // Audio recording states
    enum RecordingState: Equatable {
        case idle
        case recording
        case processing
        case completed(text: String)
        case error(String)
        
        static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.recording, .recording), (.processing, .processing):
                return true
            case (.completed(let lhsText), .completed(let rhsText)):
                return lhsText == rhsText
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    @Published var recordingState: RecordingState = .idle
    @Published var hasPermission = false
    
    // Keep track of most recent partial transcription to improve reliability
    private var latestTranscribedText: String = ""
    
    // Core components
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Audio session
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognizer() {
        // Use the device's default locale for best recognition
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async {
        // Request speech recognition permission
        let speechAuthStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        // Request microphone permission
        let microphoneGranted: Bool
        if #available(iOS 17.0, *) {
            microphoneGranted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            microphoneGranted = await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        
        // Update permission status
        hasPermission = speechAuthStatus == .authorized && microphoneGranted
        
        if !hasPermission {
            recordingState = .error("Microphone and speech recognition permissions are required")
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() async {
        guard hasPermission else {
            await requestPermissions()
            return
        }
        
        guard speechRecognizer?.isAvailable == true else {
            recordingState = .error("Speech recognition not available")
            return
        }
        
        // Stop any existing recording
        await stopRecording()
        
        do {
            try await setupAudioSession()
            try await startSpeechRecognition()
            latestTranscribedText = ""
            recordingState = .recording
        } catch {
            recordingState = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() async {
        // Transition UI to processing state
        recordingState = .processing
        
        // Stop capturing audio but DO NOT cancel the recognition task
        // Allow it to deliver the final result
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        // Signal end of audio to the recognition request
        recognitionRequest?.endAudio()
        
        // Fallback: if no final result arrives within a short timeout,
        // complete with the latest partial (or empty) to avoid hanging
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            if case .processing = recordingState {
                let text = latestTranscribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                recordingState = .completed(text: text)
                finalizeRecognition()
            }
        }
    }
    
    func cancelRecording() async {
        await stopRecording()
        recordingState = .idle
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() async throws {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startSpeechRecognition() async throws {
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw NSError(domain: "AudioTranscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
        }
        
        let inputNode = audioEngine.inputNode
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "AudioTranscriptionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    // If we already transitioned to completed or idle, ignore trailing errors
                    switch self.recordingState {
                    case .completed, .idle:
                        self.finalizeRecognition()
                        return
                    default:
                        break
                    }
                    
                    // Handle actual errors gracefully, prefer partial text if available
                    let errorMessage = error.localizedDescription
                    let fallback = self.latestTranscribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if errorMessage.localizedCaseInsensitiveContains("no speech") ||
                        errorMessage.localizedCaseInsensitiveContains("no audio") {
                        self.recordingState = .completed(text: fallback)
                        self.finalizeRecognition()
                    } else {
                        self.recordingState = .error("Recognition failed: \(errorMessage)")
                        self.finalizeRecognition()
                    }
                    return
                }
                
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Keep track of partials so we can fall back if the final doesn't arrive
                    if !transcribedText.isEmpty {
                        self.latestTranscribedText = transcribedText
                    }
                    
                    if result.isFinal {
                        // Only update state if we're waiting for the final
                        if case .processing = self.recordingState {
                            self.recordingState = .completed(text: transcribedText)
                        } else if case .recording = self.recordingState {
                            // If user didn't explicitly stop yet, keep recording state
                            // (we don't auto-complete while still recording)
                        }
                        self.finalizeRecognition()
                    }
                    // For partial results during recording, we only cache text
                }
            }
        }
        
        // Configure audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Cleanup
    private func finalizeRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension AudioTranscriptionService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && recordingState == .recording {
                recordingState = .error("Speech recognition became unavailable")
            }
        }
    }
}
