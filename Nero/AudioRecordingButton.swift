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
            case .idle:
                microphoneButton
            case .recording:
                recordingButton
            case .processing:
                processingButton
            case .completed(let text):
                completedButtons(text: text)
            case .error(_):
                microphoneButton // Reset to microphone on error
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
            Image(systemName: "stop.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
        }
    }
    
    private var processingButton: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentBlue))
            .scaleEffect(0.8)
    }
    
    private func completedButtons(text: String) -> some View {
        HStack(spacing: 8) {
            // Cancel button with proper SF Symbol
            Button(action: cancelTranscription) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            // Accept button with proper SF Symbol
            Button(action: {
                acceptTranscription(text)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
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

// MARK: - Recording Chat Message View

struct RecordingChatMessage: View {
    let isDarkMode: Bool
    let onStop: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("Recording...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    // Stop button with clear label
                    Button(action: onStop) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title3)
                            Text("Stop")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.red)
                    }
                }
                
                AudioWaveletVisualization(isDarkMode: isDarkMode)
                    .frame(height: 30)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    )
            )
            .onTapGesture {
                // Make the entire recording area tappable to stop
                onStop()
            }
            
            Spacer()
        }
    }
}

// MARK: - Processing Chat Message View

struct ProcessingChatMessage: View {
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentBlue))
                        .scaleEffect(0.7)
                    
                    Text("Transcribing...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isDarkMode ? .white : .primary)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentBlue.opacity(0.3), lineWidth: 2)
                    )
            )
            
            Spacer()
        }
    }
}

// MARK: - Transcription Completed Chat Message View

struct TranscriptionCompletedMessage: View {
    let transcribedText: String
    let isDarkMode: Bool
    let onAccept: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text(transcribedText.isEmpty ? "No speech detected - try again" : "Transcription Complete")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(transcribedText.isEmpty ? .orange : .green)
                    
                    Spacer()
                }
                
                if !transcribedText.isEmpty {
                    Text(transcribedText)
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.1))
                        )
                    
                    HStack(spacing: 12) {
                        Button(action: onAccept) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                Text("Use Text")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                        }
                        
                        Spacer()
                    }
                } else {
                    // No text detected - just show a message and auto-dismiss
                    Text("Try speaking louder or closer to the microphone")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        .italic()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke((transcribedText.isEmpty ? Color.orange : Color.green).opacity(0.3), lineWidth: 2)
                    )
            )
            
            Spacer()
        }
        .onAppear {
            // Auto-dismiss if no text was detected after 3 seconds
            if transcribedText.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    onAccept() // This will reset the state
                }
            }
        }
    }
}

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
            case .idle, .error(_):
                microphoneButton
            case .recording, .processing, .completed(_):
                // Hide button during recording - user uses stop button in chat
                EmptyView()
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
            Image(systemName: "stop.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
        }
    }
    
    private var processingButton: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentBlue))
            .scaleEffect(0.8)
    }
    
    private func completedButtons(text: String) -> some View {
        HStack(spacing: 8) {
            // Cancel button with proper SF Symbol
            Button(action: cancelTranscription) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            // Accept button with proper SF Symbol
            Button(action: {
                acceptTranscription(text)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
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
            
            RecordingChatMessage(isDarkMode: false, onStop: {})
            
            ProcessingChatMessage(isDarkMode: false)
            
            TranscriptionCompletedMessage(
                transcribedText: "This is a sample transcribed text from voice recording",
                isDarkMode: false,
                onAccept: {}
            )
            
            AudioWaveletVisualization(isDarkMode: false)
                .frame(height: 30)
                .padding()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
