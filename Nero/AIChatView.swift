import SwiftUI

// MARK: - Chat Models

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    
    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat View

struct AIChatView: View {
    let workoutService: WorkoutService
    let macroService: MacroService
    let isDarkMode: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AIChatMessage] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var audioTranscription = AudioTranscriptionService()
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Chat messages area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Welcome message
                                if messages.isEmpty && !isLoading {
                                    AIChatWelcomeMessageView(isDarkMode: isDarkMode)
                                }
                                
                                // Chat messages
                                ForEach(messages) { message in
                                    AIChatMessageView(message: message, isDarkMode: isDarkMode)
                                        .id(message.id)
                                }
                                
                                // (Recording UI now shows in the input field, not as chat bubbles)
                                
                                // Loading indicator
                                if isLoading {
                                    TypingIndicatorView(isDarkMode: isDarkMode)
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: messages) { _, _ in
                            // Auto-scroll to bottom when new messages arrive
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if let lastMessage = messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                } else if isLoading {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isLoading) { _, _ in
                            // Auto-scroll when loading state changes
                            if isLoading {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input area
                    VStack(spacing: 12) {
                        if let errorMessage = errorMessage {
                            ErrorMessageView(message: errorMessage, isDarkMode: isDarkMode) {
                                self.errorMessage = nil
                            }
                        }
                        
                        AIChatMessageInputView(
                            messageText: $messageText,
                            isLoading: isLoading,
                            onSend: sendMessage,
                            isDarkMode: isDarkMode,
                            audioTranscription: audioTranscription
                        )
                        .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .background(isDarkMode ? Color.black : Color.offWhite)
                }
            }
            .navigationTitle("Ask Cerro")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentBlue)
                }
            }
        }
        .onAppear {
            setupWelcomeMessage()
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupWelcomeMessage() {
        // Add a slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTextFieldFocused = true
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty && !isLoading else { return }
        
        // Add user message
        let userMessage = AIChatMessage(
            content: trimmedMessage,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Clear input
        messageText = ""
        isLoading = true
        errorMessage = nil
        
        // Get AI response
        Task {
            await getAIResponse(for: trimmedMessage)
        }
    }
    
    private func getAIResponse(for userMessage: String) async {
        do {
            // This will be implemented when we extend the DeepseekAPIClient
            let response = try await DeepseekAPIClient.shared.getFitnessCoachResponse(
                userMessage: userMessage,
                workoutService: workoutService,
                macroService: macroService
            )
            
            await MainActor.run {
                let aiMessage = AIChatMessage(
                    content: response,
                    isFromUser: false,
                    timestamp: Date()
                )
                messages.append(aiMessage)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to get AI response: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Views

struct AIChatWelcomeMessageView: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(Color.mint)
            
            
            Text("Ask me anything about your workouts, nutrition, macros, progress, form, or training strategies. I'm here to help you reach your fitness goals!")
                .font(.body)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
    }
}

struct AIChatMessageView: View {
    let message: AIChatMessage
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accentBlue)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 4,
                                topTrailingRadius: 16
                            )
                        )
                    
                    Text(formatMessageTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                }
                .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(Color.mint)
                        
                        Text("AI Coach")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.mint)
                        
                        Spacer()
                    }
                    
                    Text(parseMarkdown(message.content))
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 4,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 16
                            )
                        )
                        .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    Text(formatMessageTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                }
                .frame(maxWidth: .infinity * 0.8, alignment: .leading)
                
                Spacer()
            }
        }
    }
    
    private func formatMessageTime(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    private func parseMarkdown(_ content: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: content,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        } catch {
            // If markdown parsing fails, return plain text
            return AttributedString(content)
        }
    }
}

struct TypingIndicatorView: View {
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.mint))
                        .scaleEffect(0.8)
                    
                    Text("Thinking...")
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Spacer()
        }
    }
}

struct AIChatMessageInputView: View {
    @Binding var messageText: String
    let isLoading: Bool
    let onSend: () -> Void
    let isDarkMode: Bool
    @ObservedObject var audioTranscription: AudioTranscriptionService
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                // Text field background (fixed compact height)
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                    .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .frame(height: 40)
                
                // Content overlay: either wavelet while recording, or multiline text field
                if case .recording = audioTranscription.recordingState {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill").foregroundColor(.red)
                        AudioWaveletVisualization(isDarkMode: isDarkMode)
                            .frame(height: 18)
                        Spacer(minLength: 0)
                        // Visual hint checkmark to match outer control
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                            .opacity(0.6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                } else {
                    TextField("Ask about your workouts, nutrition, macros...", text: $messageText, axis: .vertical)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .lineLimit(1...5)
                        .onSubmit { onSend() }
                }
            }
            
            // Audio recording button
            SharedAudioRecordingButton(
                messageText: $messageText,
                isDarkMode: isDarkMode,
                isDisabled: isLoading,
                transcriptionService: audioTranscription
            )
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray : Color.accentBlue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .onChange(of: audioTranscription.recordingState) { _, newValue in
            // When transcription completes, populate the input field and reset
            if case .completed(let text) = newValue {
                if !text.isEmpty {
                    if messageText.isEmpty { messageText = text } else { messageText += " " + text }
                }
                Task { await audioTranscription.cancelRecording() }
            }
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    let isDarkMode: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.orange)
                .lineLimit(2)
            
            Spacer()
            
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
} 