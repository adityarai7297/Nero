import Foundation
import SwiftUI

// MARK: - View State Persistence Manager

class ViewStatePersistenceManager {
    static let shared = ViewStatePersistenceManager()
    
    private init() {}
    
    // MARK: - AI Chat View State
    
    struct AIChatViewState: Codable {
        let messages: [AIChatMessage]
        let currentTaskId: String?
        let isLoading: Bool
        let lastUpdated: Date
    }
    
    func saveAIChatViewState(messages: [AIChatMessage], currentTaskId: String?, isLoading: Bool) {
        let state = AIChatViewState(
            messages: messages,
            currentTaskId: currentTaskId,
            isLoading: isLoading,
            lastUpdated: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: "AIChatViewState")
            print("💾 ViewStatePersistenceManager: Saved AI chat state with \(messages.count) messages")
        } catch {
            print("❌ ViewStatePersistenceManager: Failed to save AI chat state: \(error)")
        }
    }
    
    func loadAIChatViewState() -> AIChatViewState? {
        guard let data = UserDefaults.standard.data(forKey: "AIChatViewState") else {
            return nil
        }
        
        do {
            let state = try JSONDecoder().decode(AIChatViewState.self, from: data)
            // Only return state if it's recent (within last 24 hours)
            if Date().timeIntervalSince(state.lastUpdated) < 86400 {
                print("🔄 ViewStatePersistenceManager: Loaded AI chat state with \(state.messages.count) messages")
                return state
            } else {
                print("🗑️ ViewStatePersistenceManager: AI chat state too old, ignoring")
                clearAIChatViewState()
                return nil
            }
        } catch {
            print("❌ ViewStatePersistenceManager: Failed to load AI chat state: \(error)")
            return nil
        }
    }
    
    func clearAIChatViewState() {
        UserDefaults.standard.removeObject(forKey: "AIChatViewState")
        print("🧹 ViewStatePersistenceManager: Cleared AI chat state")
    }
    
    // MARK: - Macro Chat View State
    
    struct MacroChatViewState: Codable {
        let messages: [MacroChatMessage]
        let currentTaskId: String?
        let isLoading: Bool
        let selectedDate: Date
        let lastUpdated: Date
    }
    
    func saveMacroChatViewState(messages: [MacroChatMessage], currentTaskId: String?, isLoading: Bool, selectedDate: Date) {
        let state = MacroChatViewState(
            messages: messages,
            currentTaskId: currentTaskId,
            isLoading: isLoading,
            selectedDate: selectedDate,
            lastUpdated: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: "MacroChatViewState")
            print("💾 ViewStatePersistenceManager: Saved macro chat state with \(messages.count) messages")
        } catch {
            print("❌ ViewStatePersistenceManager: Failed to save macro chat state: \(error)")
        }
    }
    
    func loadMacroChatViewState() -> MacroChatViewState? {
        guard let data = UserDefaults.standard.data(forKey: "MacroChatViewState") else {
            return nil
        }
        
        do {
            let state = try JSONDecoder().decode(MacroChatViewState.self, from: data)
            // Only return state if it's recent (within last 24 hours)
            if Date().timeIntervalSince(state.lastUpdated) < 86400 {
                print("🔄 ViewStatePersistenceManager: Loaded macro chat state with \(state.messages.count) messages")
                return state
            } else {
                print("🗑️ ViewStatePersistenceManager: Macro chat state too old, ignoring")
                clearMacroChatViewState()
                return nil
            }
        } catch {
            print("❌ ViewStatePersistenceManager: Failed to load macro chat state: \(error)")
            return nil
        }
    }
    
    func clearMacroChatViewState() {
        UserDefaults.standard.removeObject(forKey: "MacroChatViewState")
        print("🧹 ViewStatePersistenceManager: Cleared macro chat state")
    }
    
    // MARK: - Workout Edit Chat View State
    
    struct WorkoutEditChatViewState: Codable {
        let messages: [ChatMessage]
        let currentTaskId: String?
        let isProcessing: Bool
        let lastUpdated: Date
    }
    
    func saveWorkoutEditChatViewState(messages: [ChatMessage], currentTaskId: String?, isProcessing: Bool) {
        let state = WorkoutEditChatViewState(
            messages: messages,
            currentTaskId: currentTaskId,
            isProcessing: isProcessing,
            lastUpdated: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: "WorkoutEditChatViewState")
            print("💾 ViewStatePersistenceManager: Saved workout edit chat state with \(messages.count) messages")
        } catch {
            print("❌ ViewStatePersistenceManager: Failed to save workout edit chat state: \(error)")
        }
    }
    
    func loadWorkoutEditChatViewState() -> WorkoutEditChatViewState? {
        guard let data = UserDefaults.standard.data(forKey: "WorkoutEditChatViewState") else {
            return nil
        }
        
        do {
            let state = try JSONDecoder().decode(WorkoutEditChatViewState.self, from: data)
            // Only return state if it's recent (within last 24 hours)
            if Date().timeIntervalSince(state.lastUpdated) < 86400 {
                print("🔄 ViewStatePersistenceManager: Loaded workout edit chat state with \(state.messages.count) messages")
                return state
            } else {
                print("🗑️ ViewStatePersistenceManager: Workout edit chat state too old, ignoring")
                clearWorkoutEditChatViewState()
                return nil
            }
        } catch {
            print("❌ ViewStatePersistenceManager: Failed to load workout edit chat state: \(error)")
            return nil
        }
    }
    
    func clearWorkoutEditChatViewState() {
        UserDefaults.standard.removeObject(forKey: "WorkoutEditChatViewState")
        print("🧹 ViewStatePersistenceManager: Cleared workout edit chat state")
    }
    
    // MARK: - Global Cleanup
    
    func cleanupOldViewStates(olderThan interval: TimeInterval = 86400) { // 24 hours default
        let cutoffDate = Date().addingTimeInterval(-interval)
        
        // Check AI Chat state
        if let aiState = loadAIChatViewState(), aiState.lastUpdated < cutoffDate {
            clearAIChatViewState()
        }
        
        // Check Macro Chat state
        if let macroState = loadMacroChatViewState(), macroState.lastUpdated < cutoffDate {
            clearMacroChatViewState()
        }
        
        // Check Workout Edit Chat state
        if let workoutState = loadWorkoutEditChatViewState(), workoutState.lastUpdated < cutoffDate {
            clearWorkoutEditChatViewState()
        }
        
        print("🧹 ViewStatePersistenceManager: Cleaned up old view states")
    }
    
    // MARK: - Task-View Association
    
    func associateTaskWithView(taskId: String, viewType: String) {
        UserDefaults.standard.set(viewType, forKey: "TaskViewAssociation_\(taskId)")
        print("🔗 ViewStatePersistenceManager: Associated task \(taskId) with view \(viewType)")
    }
    
    func getViewForTask(taskId: String) -> String? {
        return UserDefaults.standard.string(forKey: "TaskViewAssociation_\(taskId)")
    }
    
    func clearTaskViewAssociation(taskId: String) {
        UserDefaults.standard.removeObject(forKey: "TaskViewAssociation_\(taskId)")
    }
}

// MARK: - Codable Support for Messages

extension AIChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case content, isFromUser, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        isFromUser = try container.decode(Bool.self, forKey: .isFromUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(isFromUser, forKey: .isFromUser)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

extension MacroChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case content, isFromUser, timestamp, mealData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        isFromUser = try container.decode(Bool.self, forKey: .isFromUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        mealData = try container.decodeIfPresent(MacroMeal.self, forKey: .mealData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(isFromUser, forKey: .isFromUser)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(mealData, forKey: .mealData)
    }
}

extension ChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case text, isFromUser, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        isFromUser = try container.decode(Bool.self, forKey: .isFromUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(isFromUser, forKey: .isFromUser)
        try container.encode(timestamp, forKey: .timestamp)
    }
}
