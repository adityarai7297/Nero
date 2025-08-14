import SwiftUI

// MARK: - Audio Recording Button Component

struct AudioRecordingButton: View {
    @StateObject private var transcriptionService = AudioTranscriptionService()
    @Binding var messageText: String
    let isDarkMode: Bool
    let isDisabled: Bool
    
    @State private var isFirstLoad = true
    
    var body: some View {
        Group {
            switch transcriptionService.recordingState {
            case .idle, .error(_), .completed(_):
                microphoneButton
            case .recording:
                // Hide in-button stop to avoid duplicate control; stop is inside the input field UI
                EmptyView()
            case .processing:
                processingButton
            }
        }
        .onAppear {
            if isFirstLoad {
                Task {
                    await transcriptionService.requestPermissions()
                }
                isFirstLoad = false
            }
        }
        .onChange(of: transcriptionService.recordingState) { _, state in
            handleStateChange(state)
        }
    }
    
    // MARK: - Button States
    
    private var microphoneButton: some View {
        Button(action: startRecording) {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(isDisabled ? .gray : Color.accentBlue)
        }
        .disabled(isDisabled)
    }
    
    private var recordingButton: some View {
        Button(action: stopRecording) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        }
    }
    
    private var processingButton: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentBlue))
            .scaleEffect(0.8)
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        guard transcriptionService.hasPermission else {
            Task {
                await transcriptionService.requestPermissions()
                if transcriptionService.hasPermission {
                    await transcriptionService.startRecording()
                }
            }
            return
        }
        
        Task {
            await transcriptionService.startRecording()
        }
    }
    
    private func stopRecording() {
        Task {
            await transcriptionService.stopRecording()
        }
    }
    
    // (No longer need cancel/accept helpers; handled in parent input views)
    
    private func handleStateChange(_ state: AudioTranscriptionService.RecordingState) {
        switch state {
        case .error(let message):
            // Could show error alert here if needed
            print("Transcription error: \(message)")
        default:
            break
        }
    }
}

// MARK: - Audio Wavelet Visualization Component

struct AudioWaveletVisualization: View {
    let isDarkMode: Bool
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.2, count: 40)
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<amplitudes.count, id: \.self) { index in
                Rectangle()
                    .fill(isDarkMode ? Color.white.opacity(0.7) : Color.primary.opacity(0.7))
                    .frame(width: 3, height: max(2, amplitudes[index] * 30))
                    .animation(
                        Animation.easeInOut(duration: 0.1 + Double(index) * 0.01)
                            .repeatForever(autoreverses: true),
                        value: amplitudes[index]
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        isAnimating = true
        animateWavelets()
    }
    
    private func stopAnimation() {
        isAnimating = false
    }
    
    private func animateWavelets() {
        guard isAnimating else { return }
        
        for i in 0..<amplitudes.count {
            amplitudes[i] = CGFloat.random(in: 0.3...1.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animateWavelets()
        }
    }
}

// NOTE: Recording/Processing/Completed chat bubble components removed;
// wavelet UI now lives inside the input field.

// MARK: - Shared Audio Recording Button Component (for use with external transcription service)

struct SharedAudioRecordingButton: View {
    @Binding var messageText: String
    let isDarkMode: Bool
    let isDisabled: Bool
    @ObservedObject var transcriptionService: AudioTranscriptionService
    
    @State private var isFirstLoad = true
    
    var body: some View {
        Group {
            switch transcriptionService.recordingState {
            case .idle, .error(_), .completed(_):
                microphoneButton
            case .recording:
                recordingButton
            case .processing:
                processingButton
            }
        }
        .onAppear {
            if isFirstLoad {
                Task {
                    await transcriptionService.requestPermissions()
                }
                isFirstLoad = false
            }
        }
        .onChange(of: transcriptionService.recordingState) { _, state in
            handleStateChange(state)
        }
    }
    
    // MARK: - Button States
    
    private var microphoneButton: some View {
        Button(action: startRecording) {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(isDisabled ? .gray : Color.accentBlue)
        }
        .disabled(isDisabled)
    }
    
    private var recordingButton: some View {
        Button(action: stopRecording) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        }
    }
    
    private var processingButton: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentBlue))
            .scaleEffect(0.8)
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        guard transcriptionService.hasPermission else {
            Task {
                await transcriptionService.requestPermissions()
                if transcriptionService.hasPermission {
                    await transcriptionService.startRecording()
                }
            }
            return
        }
        
        Task {
            await transcriptionService.startRecording()
        }
    }
    
    private func stopRecording() {
        Task {
            await transcriptionService.stopRecording()
        }
    }
    
    private func cancelTranscription() {
        Task {
            await transcriptionService.cancelRecording()
        }
    }
    
    private func acceptTranscription(_ text: String) {
        // Add transcribed text to the message text
        if messageText.isEmpty {
            messageText = text
        } else {
            messageText += " " + text
        }
        
        // Reset transcription service
        Task {
            await transcriptionService.cancelRecording()
        }
    }
    
    private func handleStateChange(_ state: AudioTranscriptionService.RecordingState) {
        switch state {
        case .error(let message):
            // Could show error alert here if needed
            print("Transcription error: \(message)")
        default:
            break
        }
    }
}

// MARK: - Preview

struct AudioRecordingButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AudioRecordingButton(
                messageText: .constant(""),
                isDarkMode: false,
                isDisabled: false
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
