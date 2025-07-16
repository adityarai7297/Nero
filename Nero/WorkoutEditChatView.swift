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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferencesService: WorkoutPreferencesService
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var showingWorkoutPlan = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.offWhite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Welcome message
                                if messages.isEmpty {
                                    WelcomeMessageView()
                                        .padding(.horizontal, 16)
                                        .padding(.top, 20)
                                }
                                
                                ForEach(messages) { message in
                                    MessageBubbleView(message: message)
                                        .padding(.horizontal, 16)
                                        .id(message.id)
                                }
                                
                                // Processing indicator
                                if isProcessing && !preferencesService.generationStatus.isActive {
                                    ProcessingMessageView()
                                        .padding(.horizontal, 16)
                                        .id("processing")
                                } else if preferencesService.generationStatus.isActive {
                                    StatusMessageView(status: preferencesService.generationStatus)
                                        .padding(.horizontal, 16)
                                        .id("status")
                                } else if preferencesService.generationStatus == .completed {
                                    CompletedMessageView {
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
                            }
                        }
                    }
                    
                    // Input Area
                    MessageInputView(
                        messageText: $messageText,
                        isProcessing: isProcessing || preferencesService.generationStatus.isActive,
                        onSend: sendMessage
                    )
                }
            }
            .navigationTitle("Edit Workout Plan")
            .navigationBarTitleDisplayMode(.inline)
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
                workoutService: workoutService
            )
        }
        .onAppear {
            // Reset status when view appears
            if preferencesService.generationStatus == .completed {
                preferencesService.generationStatus = .idle
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.accentBlue)
            
            VStack(spacing: 8) {
                Text("Edit Your Workout Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Tell me what you'd like to change about your current workout plan. For example:")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ExamplePromptView(text: "Add more chest exercises")
                ExamplePromptView(text: "Remove all leg workouts")
                ExamplePromptView(text: "Make the workouts shorter")
                ExamplePromptView(text: "Focus more on arms and shoulders")
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ExamplePromptView: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.bubble")
                .font(.caption)
                .foregroundColor(Color.accentBlue)
            
            Text("\"\(text)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    
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
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentBlue))
                        .scaleEffect(0.8)
                    
                    Text("Processing your request...")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Spacer()
        }
    }
}

struct StatusMessageView: View {
    let status: WorkoutPlanGenerationStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.orange))
                        .scaleEffect(0.8)
                    
                    Text(status.displayText)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Spacer()
        }
    }
}

struct CompletedMessageView: View {
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
                        .foregroundColor(.primary)
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
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                TextField("Describe what you'd like to change...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .disabled(isProcessing)
                
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
        .background(Color.offWhite)
    }
} 