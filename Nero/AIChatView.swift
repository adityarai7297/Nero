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
    @Environment(\.scenePhase) private var scenePhase
    @State private var messages: [AIChatMessage] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentTaskId: String?
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var audioTranscription = AudioTranscriptionService()
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    
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
                        .onAppear {
                            // Auto-scroll to bottom when view appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if let lastMessage = messages.last {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    } else if isLoading {
                                        proxy.scrollTo("typing", anchor: .bottom)
                                    }
                                }
                            }
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
            restoreViewState()
            checkForCompletedTasks()
            
            // Additional safety check: if still loading but no active task, clear it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if isLoading && currentTaskId == nil {
                    print("🧹 AIChatView: Safety cleanup - clearing orphaned loading state")
                    isLoading = false
                }
            }
        }
        .onDisappear {
            saveViewState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // App became active, check for any completed background tasks
                checkForCompletedTasks()
            }
        }
        .onChange(of: messages) { _, _ in
            // Auto-save state when messages change
            saveViewState()
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupWelcomeMessage() {
        // Add a slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTextFieldFocused = true
        }
    }
    
    private func saveViewState() {
        ViewStatePersistenceManager.shared.saveAIChatViewState(
            messages: messages,
            currentTaskId: currentTaskId,
            isLoading: isLoading
        )
        
        // Associate any active task with this view
        if let taskId = currentTaskId {
            ViewStatePersistenceManager.shared.associateTaskWithView(taskId: taskId, viewType: "AIChatView")
        }
    }
    
    private func restoreViewState() {
        if let savedState = ViewStatePersistenceManager.shared.loadAIChatViewState() {
            messages = savedState.messages
            currentTaskId = savedState.currentTaskId
            
            // Only restore loading state if there's actually a running task
            if let taskId = savedState.currentTaskId,
               let taskInfo = backgroundTaskManager.getTaskInfo(taskId),
               taskInfo.status == .running {
                isLoading = savedState.isLoading
                print("🔄 AIChatView: Restored state with \(messages.count) messages, loading: \(isLoading) - task \(taskId) is still running")
            } else {
                isLoading = false  // Clear stale loading state
                if let taskId = savedState.currentTaskId {
                    print("🧹 AIChatView: Cleared stale loading state - task \(taskId) is no longer running")
                } else {
                    print("🧹 AIChatView: Cleared stale loading state - no current task")
                }
            }
            
            // Don't show welcome message if we have chat history
            if !messages.isEmpty {
                isTextFieldFocused = false
            }
        }
    }
    
    private func checkForCompletedTasks() {
        // First check for any orphaned tasks that might belong to this view
        for (taskId, taskInfo) in backgroundTaskManager.activeTasks {
            if let viewType = ViewStatePersistenceManager.shared.getViewForTask(taskId: taskId),
               viewType == "AIChatView",
               taskInfo.status == .completed {
                
                // Found a completed task for this view
                if let result = ResultPersistenceManager.shared.loadChatResponse(taskId: taskId) {
                    let aiMessage = AIChatMessage(
                        content: result.response,
                        isFromUser: false,
                        timestamp: result.timestamp
                    )
                    messages.append(aiMessage)
                    isLoading = false
                    currentTaskId = nil
                    
                    // Clean up the association
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("✅ AIChatView: Restored completed task result for \(taskId)")
                    return
                } else {
                    // Task completed but no result found - show error and clear loading
                    isLoading = false
                    currentTaskId = nil
                    messages.append(AIChatMessage(
                        content: "Sorry, there was an issue retrieving the AI response. Please try again.",
                        isFromUser: false,
                        timestamp: Date()
                    ))
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("⚠️ AIChatView: Task \(taskId) completed but no result found")
                    return
                }
            }
        }
        
        // Then check the current task if we have one
        guard let taskId = currentTaskId else { return }
        
        // Check if the task has completed while we were away
        if let taskInfo = backgroundTaskManager.getTaskInfo(taskId) {
            switch taskInfo.status {
            case .completed:
                // Try to load the persisted result
                if let result = ResultPersistenceManager.shared.loadChatResponse(taskId: taskId) {
                    let aiMessage = AIChatMessage(
                        content: result.response,
                        isFromUser: false,
                        timestamp: result.timestamp
                    )
                    messages.append(aiMessage)
                    isLoading = false
                    currentTaskId = nil
                    
                    // Clean up the association
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("✅ AIChatView: Current task \(taskId) completed successfully")
                } else {
                    // Task completed but no result found - show error and clear loading
                    isLoading = false
                    currentTaskId = nil
                    messages.append(AIChatMessage(
                        content: "Sorry, there was an issue retrieving the AI response. Please try again.",
                        isFromUser: false,
                        timestamp: Date()
                    ))
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("⚠️ AIChatView: Current task \(taskId) completed but no result found")
                }
            case .failed:
                isLoading = false
                messages.append(AIChatMessage(
                    content: "Sorry, the AI response failed while the view was not active. Please try again.",
                    isFromUser: false,
                    timestamp: Date()
                ))
                currentTaskId = nil
                
                // Clean up the association
                ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                print("❌ AIChatView: Current task \(taskId) failed")
            case .running:
                // Task is still running, keep the loading state
                isLoading = true
                print("⏳ AIChatView: Task \(taskId) still running")
            }
        } else {
            // Task not found in BackgroundTaskManager - it either completed and was cleaned up, or failed
            // Check if we have a persisted result
            if let result = ResultPersistenceManager.shared.loadChatResponse(taskId: taskId) {
                let aiMessage = AIChatMessage(
                    content: result.response,
                    isFromUser: false,
                    timestamp: result.timestamp
                )
                messages.append(aiMessage)
                isLoading = false
                currentTaskId = nil
                ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                print("✅ AIChatView: Found persisted result for cleaned up task \(taskId)")
            } else {
                // No task and no result - task likely failed or timed out
                isLoading = false
                currentTaskId = nil
                messages.append(AIChatMessage(
                    content: "Sorry, the AI response timed out or failed. Please try again.",
                    isFromUser: false,
                    timestamp: Date()
                ))
                ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                print("❌ AIChatView: Task \(taskId) not found and no result - likely failed or timed out")
            }
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
        let taskId = "fitness_chat_\(UUID().uuidString)"
        currentTaskId = taskId
        
        DeepseekAPIClient.shared.getFitnessCoachResponseInBackground(
            userMessage: userMessage,
            workoutService: workoutService,
            macroService: macroService,
            taskId: taskId
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    let aiMessage = AIChatMessage(
                        content: response,
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(aiMessage)
                    isLoading = false
                    currentTaskId = nil
                    
                case .failure(let error):
                    isLoading = false
                    errorMessage = "Failed to get AI response: \(error.localizedDescription)"
                    currentTaskId = nil
                }
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