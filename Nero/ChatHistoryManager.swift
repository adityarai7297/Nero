import SwiftUI

// MARK: - Chat History Manager

struct ChatHistoryManager {
    static func clearAllChatHistory() {
        ViewStatePersistenceManager.shared.clearAIChatViewState()
        ViewStatePersistenceManager.shared.clearMacroChatViewState()
        ViewStatePersistenceManager.shared.clearWorkoutEditChatViewState()
        
        print("🧹 ChatHistoryManager: Cleared all chat history")
    }
    
    static func clearSpecificChatHistory(_ chatType: ChatType) {
        switch chatType {
        case .aiChat:
            ViewStatePersistenceManager.shared.clearAIChatViewState()
        case .macroChat:
            ViewStatePersistenceManager.shared.clearMacroChatViewState()
        case .workoutEditChat:
            ViewStatePersistenceManager.shared.clearWorkoutEditChatViewState()
        }
        
        print("🧹 ChatHistoryManager: Cleared \(chatType.rawValue) history")
    }
    
    static func hasAnyStoredHistory() -> Bool {
        return ViewStatePersistenceManager.shared.loadAIChatViewState() != nil ||
               ViewStatePersistenceManager.shared.loadMacroChatViewState() != nil ||
               ViewStatePersistenceManager.shared.loadWorkoutEditChatViewState() != nil
    }
}

enum ChatType: String, CaseIterable {
    case aiChat = "AI Chat"
    case macroChat = "Macro Tracker"
    case workoutEditChat = "Workout Editor"
}

// MARK: - Chat History Settings View

struct ChatHistorySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let isDarkMode: Bool
    
    @State private var showingClearAllAlert = false
    @State private var showingClearSpecificAlert = false
    @State private var selectedChatType: ChatType?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Chat History")
                                .font(.headline)
                                .foregroundColor(isDarkMode ? .white : .primary)
                            
                            Text("Your chat conversations are automatically saved so you can continue where you left off when navigating between views.")
                                .font(.caption)
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Clear History") {
                    ForEach(ChatType.allCases, id: \.self) { chatType in
                        Button(action: {
                            selectedChatType = chatType
                            showingClearSpecificAlert = true
                        }) {
                            HStack {
                                Image(systemName: iconForChatType(chatType))
                                    .foregroundColor(colorForChatType(chatType))
                                    .frame(width: 24)
                                
                                Text("Clear \(chatType.rawValue) History")
                                    .foregroundColor(isDarkMode ? .white : .primary)
                                
                                Spacer()
                                
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                            }
                        }
                    }
                    
                    Button(action: {
                        showingClearAllAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            Text("Clear All Chat History")
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isDarkMode ? .white : .primary)
                        
                        BulletPoint(text: "Chat history is saved when you navigate away from chat views", isDarkMode: isDarkMode)
                        BulletPoint(text: "Background tasks continue running and results are restored when you return", isDarkMode: isDarkMode)
                        BulletPoint(text: "History automatically expires after 24 hours", isDarkMode: isDarkMode)
                        BulletPoint(text: "Clear history anytime for a fresh start", isDarkMode: isDarkMode)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert("Clear All Chat History", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                ChatHistoryManager.clearAllChatHistory()
            }
        } message: {
            Text("This will clear all saved chat conversations from AI Chat, Macro Tracker, and Workout Editor. This action cannot be undone.")
        }
        .alert("Clear \(selectedChatType?.rawValue ?? "") History", isPresented: $showingClearSpecificAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                if let chatType = selectedChatType {
                    ChatHistoryManager.clearSpecificChatHistory(chatType)
                }
            }
        } message: {
            Text("This will clear all saved conversations for \(selectedChatType?.rawValue ?? ""). This action cannot be undone.")
        }
    }
    
    private func iconForChatType(_ chatType: ChatType) -> String {
        switch chatType {
        case .aiChat:
            return "brain.head.profile"
        case .macroChat:
            return "fork.knife"
        case .workoutEditChat:
            return "dumbbell.fill"
        }
    }
    
    private func colorForChatType(_ chatType: ChatType) -> Color {
        switch chatType {
        case .aiChat:
            return .mint
        case .macroChat:
            return .orange
        case .workoutEditChat:
            return .blue
        }
    }
}

struct BulletPoint: View {
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                .fontWeight(.bold)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
        }
    }
}
