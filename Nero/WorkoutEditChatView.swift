//
//  WorkoutEditChatView.swift
//  Nero
//
//  Created by Workout Plan Editor
//

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

struct WorkoutEditChatView: View {
    let workoutService: WorkoutService
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var preferencesService: WorkoutPreferencesService
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var showingWorkoutPlan = false
    @State private var currentTaskId: String?
    @StateObject private var audioTranscription = AudioTranscriptionService()
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Welcome message
                                if messages.isEmpty {
                                    WelcomeMessageView(isDarkMode: isDarkMode)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 20)
                                }
                                
                                ForEach(messages) { message in
                                    MessageBubbleView(message: message, isDarkMode: isDarkMode)
                                        .padding(.horizontal, 16)
                                        .id(message.id)
                                }
                                
                                // (Recording UI now shows in the input field)
                                
                                // Processing indicator
                                if isProcessing && !preferencesService.generationStatus.isActive {
                                    ProcessingMessageView(isDarkMode: isDarkMode)
                                        .padding(.horizontal, 16)
                                        .id("processing")
                                } else if preferencesService.generationStatus.isActive {
                                    StatusMessageView(status: preferencesService.generationStatus, isDarkMode: isDarkMode)
                                        .padding(.horizontal, 16)
                                        .id("status")
                                } else if preferencesService.generationStatus == .completed {
                                    CompletedMessageView(isDarkMode: isDarkMode) {
                                        showingWorkoutPlan = true
                                    }
                                    .padding(.horizontal, 16)
                                    .id("completed")
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .onChange(of: messages.count) { _ in
                            if let lastMessage = messages.last {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isProcessing) { processing in
                            if processing {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo("processing", anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: preferencesService.generationStatus) { status in
                            if status.isActive {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo("status", anchor: .bottom)
                                }
                            } else if status == .completed {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo("completed", anchor: .bottom)
                                }
                            } else if case .failed(let error) = status, error == "Could not understand" {
                                // Handle "could not understand" error specifically
                                isProcessing = false
                                messages.append(ChatMessage(
                                    text: "I couldn't understand your request. Please try rephrasing with more specific details about what you'd like to change in your workout plan.",
                                    isFromUser: false,
                                    timestamp: Date()
                                ))
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                                }
                                // Reset status so user can try again
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    preferencesService.generationStatus = .idle
                                }
                            } else if case .failed(_) = status {
                                // Handle other failures
                                isProcessing = false
                                messages.append(ChatMessage(
                                    text: "Sorry, there was an error processing your request. Please try again.",
                                    isFromUser: false,
                                    timestamp: Date()
                                ))
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                                }
                                // Reset status so user can try again
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    preferencesService.generationStatus = .idle
                                }
                            }
                        }
                    }
                    
                    // Input Area
                    MessageInputView(
                        messageText: $messageText,
                        isProcessing: isProcessing || preferencesService.generationStatus.isActive,
                        onSend: sendMessage,
                        isDarkMode: isDarkMode,
                        audioTranscription: audioTranscription
                    )
                }
            }
            .navigationTitle("Edit Workout Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.accentBlue)
                }
            }
        }
        .sheet(isPresented: $showingWorkoutPlan) {
            // This will show the workout plan view when editing is complete
            WorkoutPlanView(
                onExerciseSelected: { _ in }, // Not needed in this context
                workoutService: workoutService,
                isDarkMode: isDarkMode
            )
        }
        .onAppear {
            // Reset status when view appears
            if preferencesService.generationStatus == .completed {
                preferencesService.generationStatus = .idle
            }
            checkForCompletedTasks()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // App became active, check for any completed background tasks
                checkForCompletedTasks()
            }
        }
    }
    
    private func checkForCompletedTasks() {
        guard let taskId = currentTaskId else { return }
        
        // Check if the task has completed while we were away
        if let taskInfo = backgroundTaskManager.getTaskInfo(taskId) {
            switch taskInfo.status {
            case .completed:
                // Check if we have a persisted workout plan result
                if let result = ResultPersistenceManager.shared.loadWorkoutPlanResult(taskId: taskId) {
                    // The workout plan was completed, update the status
                    preferencesService.generationStatus = .completed
                    isProcessing = false
                    currentTaskId = nil
                }
            case .failed:
                isProcessing = false
                preferencesService.generationStatus = .failed("Edit failed while app was in background")
                currentTaskId = nil
            case .running:
                // Task is still running, keep the processing state
                isProcessing = true
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            text: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
            isFromUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let messageToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        // Start processing
        isProcessing = true
        
        Task {
            await editWorkoutPlan(with: messageToSend)
        }
    }
    
    private func editWorkoutPlan(with editRequest: String) async {
        do {
            // Load current workout plan
            guard let currentPlan = await preferencesService.loadCurrentWorkoutPlan() else {
                await MainActor.run {
                    isProcessing = false
                    messages.append(ChatMessage(
                        text: "Sorry, I couldn't find your current workout plan. Please create a workout plan first.",
                        isFromUser: false,
                        timestamp: Date()
                    ))
                }
                return
            }
            
            // Load personal details and preferences for context
            let personalDetailsService = PersonalDetailsService()
            guard let personalDetails = await personalDetailsService.loadPersonalDetails(),
                  let preferences = await preferencesService.loadWorkoutPreferences() else {
                await MainActor.run {
                    isProcessing = false
                    messages.append(ChatMessage(
                        text: "Sorry, I couldn't load your personal details and preferences. Please check your profile setup.",
                        isFromUser: false,
                        timestamp: Date()
                    ))
                }
                return
            }
            
            await MainActor.run {
                isProcessing = false
            }
            
            // Call the edit workout plan API
            await preferencesService.startWorkoutPlanEdit(
                editRequest: editRequest,
                currentPlan: currentPlan,
                personalDetails: personalDetails,
                preferences: preferences
            )
            
        } catch {
            await MainActor.run {
                isProcessing = false
                messages.append(ChatMessage(
                    text: "Sorry, there was an error processing your request. Please try again.",
                    isFromUser: false,
                    timestamp: Date()
                ))
            }
        }
    }
}

// MARK: - Supporting Views

struct WelcomeMessageView: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.accentBlue)
            
            VStack(spacing: 8) {
                Text("Edit Your Workout Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Text("Tell me what you'd like to change about your current workout plan. For example:")
                    .font(.body)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ExamplePromptView(text: "Add more chest exercises", isDarkMode: isDarkMode)
                ExamplePromptView(text: "Remove all leg workouts", isDarkMode: isDarkMode)
                ExamplePromptView(text: "Make the workouts shorter", isDarkMode: isDarkMode)
                ExamplePromptView(text: "Focus more on arms and shoulders", isDarkMode: isDarkMode)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ExamplePromptView: View {
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.bubble")
                .font(.caption)
                .foregroundColor(Color.accentBlue)
            
            Text("\"\(text)\"")
                .font(.caption)
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                .italic()
        }
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.accentBlue)
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
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
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProcessingMessageView: View {
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentBlue))
                        .scaleEffect(0.8)
                    
                    Text("Processing your request...")
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

struct StatusMessageView: View {
    let status: WorkoutPlanGenerationStatus
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.orange))
                        .scaleEffect(0.8)
                    
                    Text(status.displayText)
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

struct CompletedMessageView: View {
    let isDarkMode: Bool
    let onViewPlan: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Text("Workout plan updated!")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(isDarkMode ? .white : .primary)
                }
                
                Button(action: onViewPlan) {
                    Text("View Updated Plan")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                }
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
            
            Spacer()
        }
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let isProcessing: Bool
    let onSend: () -> Void
    let isDarkMode: Bool
    @ObservedObject var audioTranscription: AudioTranscriptionService
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .frame(height: 40)
                    if case .recording = audioTranscription.recordingState {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill").foregroundColor(.red)
                            AudioWaveletVisualization(isDarkMode: isDarkMode)
                                .frame(height: 18)
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                                .opacity(0.6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    } else {
                        TextField("Describe what you'd like to change...", text: $messageText, axis: .vertical)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.body)
                            .lineLimit(1...4)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .disabled(isProcessing)
                
                // Audio recording button with shared transcription service
                SharedAudioRecordingButton(
                    messageText: $messageText,
                    isDarkMode: isDarkMode,
                    isDisabled: isProcessing,
                    transcriptionService: audioTranscription
                )
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing ? .gray : Color.accentBlue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(isDarkMode ? Color.black : Color.offWhite)
        .onChange(of: audioTranscription.recordingState) { _, newValue in
            if case .completed(let text) = newValue {
                if !text.isEmpty {
                    if messageText.isEmpty { messageText = text } else { messageText += " " + text }
                }
                Task { await audioTranscription.cancelRecording() }
            }
        }
    }
} 