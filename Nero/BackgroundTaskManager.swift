import Foundation
import UIKit
import Combine

// MARK: - Background Task Manager

class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    // Task storage for pending operations
    @Published var activeTasks: [String: BackgroundTaskInfo] = [:]
    private var taskIdentifiers: [String: UIBackgroundTaskIdentifier] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAppLifecycleObservers()
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidEnterBackground() {
        print("📱 BackgroundTaskManager: App entered background, protecting \(activeTasks.count) active tasks")
        
        // Request extended background time for all active tasks
        for (taskId, _) in activeTasks {
            if taskIdentifiers[taskId] == nil {
                requestBackgroundTime(for: taskId)
            }
        }
        
        // Persist active tasks
        persistActiveTasks()
    }
    
    private func handleAppWillEnterForeground() {
        print("📱 BackgroundTaskManager: App entering foreground, restoring state")
        
        // Restore any persisted tasks
        restoreActiveTasks()
        
        // Clean up background task identifiers that are no longer needed
        cleanupCompletedBackgroundTasks()
    }
    
    func startBackgroundTask<T>(
        id: String,
        type: BackgroundTaskType,
        operation: @escaping () async throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        print("🚀 BackgroundTaskManager: Starting background task '\(id)' of type \(type)")
        
        let taskInfo = BackgroundTaskInfo(
            id: id,
            type: type,
            startTime: Date(),
            status: .running
        )
        
        DispatchQueue.main.async {
            self.activeTasks[id] = taskInfo
        }
        
        // Request background time immediately
        requestBackgroundTime(for: id)
        
        // Execute the operation in background queue
        Task.detached(priority: .userInitiated) {
            do {
                let result = try await operation()
                
                await MainActor.run {
                    self.activeTasks[id]?.status = .completed
                    self.activeTasks[id]?.completionTime = Date()
                    completion(.success(result))
                    
                    // Give UI time to detect the completed state and set persistent flags
                    // Clean up after a longer delay to ensure UI state is properly handled
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.cleanupTask(id)
                    }
                }
            } catch {
                await MainActor.run {
                    self.activeTasks[id]?.status = .failed
                    self.activeTasks[id]?.error = error.localizedDescription
                    self.activeTasks[id]?.completionTime = Date()
                    completion(.failure(error))
                    
                    // Clean up after a longer delay to ensure UI state is properly handled
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.cleanupTask(id)
                    }
                }
            }
        }
    }
    
    private func requestBackgroundTime(for taskId: String) {
        let backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "BackgroundTask_\(taskId)") { [weak self] in
            // Background time expired
            print("⏰ BackgroundTaskManager: Background time expired for task '\(taskId)'")
            self?.cleanupTask(taskId)
        }
        
        if backgroundTaskId != .invalid {
            taskIdentifiers[taskId] = backgroundTaskId
            print("🕐 BackgroundTaskManager: Requested background time for task '\(taskId)'")
        }
    }
    
    private func cleanupTask(_ taskId: String) {
        print("🧹 BackgroundTaskManager: Cleaning up task '\(taskId)'")
        
        activeTasks.removeValue(forKey: taskId)
        
        if let backgroundTaskId = taskIdentifiers.removeValue(forKey: taskId) {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            print("✅ BackgroundTaskManager: Ended background task for '\(taskId)'")
        }
        
        // Update persistence
        persistActiveTasks()
    }
    
    private func cleanupCompletedBackgroundTasks() {
        let completedTasks = activeTasks.filter { $0.value.status != .running }
        for (taskId, _) in completedTasks {
            if let backgroundTaskId = taskIdentifiers.removeValue(forKey: taskId) {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func persistActiveTasks() {
        do {
            let data = try JSONEncoder().encode(Array(activeTasks.values))
            UserDefaults.standard.set(data, forKey: "BackgroundTasks_Active")
            print("💾 BackgroundTaskManager: Persisted \(activeTasks.count) active tasks")
        } catch {
            print("❌ BackgroundTaskManager: Failed to persist tasks: \(error)")
        }
    }
    
    private func restoreActiveTasks() {
        guard let data = UserDefaults.standard.data(forKey: "BackgroundTasks_Active") else { return }
        
        do {
            let taskInfos = try JSONDecoder().decode([BackgroundTaskInfo].self, from: data)
            var restoredTasks: [String: BackgroundTaskInfo] = [:]
            
            for taskInfo in taskInfos {
                // Only restore running tasks, others are considered completed/failed
                if taskInfo.status == .running {
                    restoredTasks[taskInfo.id] = taskInfo
                }
            }
            
            DispatchQueue.main.async {
                self.activeTasks = restoredTasks
            }
            
            print("🔄 BackgroundTaskManager: Restored \(restoredTasks.count) active tasks")
        } catch {
            print("❌ BackgroundTaskManager: Failed to restore tasks: \(error)")
        }
    }
    
    // MARK: - Task Query Methods
    
    func isTaskActive(_ taskId: String) -> Bool {
        return activeTasks[taskId]?.status == .running
    }
    
    func getTaskStatus(_ taskId: String) -> BackgroundTaskStatus? {
        return activeTasks[taskId]?.status
    }
    
    func getTaskInfo(_ taskId: String) -> BackgroundTaskInfo? {
        return activeTasks[taskId]
    }
}

// MARK: - Supporting Types

enum BackgroundTaskType: String, Codable {
    case workoutPlanGeneration = "workout_plan_generation"
    case workoutPlanEdit = "workout_plan_edit"
    case macroMealParsing = "macro_meal_parsing"
    case macroMealEdit = "macro_meal_edit"
    case fitnessCoachChat = "fitness_coach_chat"
    case audioTranscription = "audio_transcription"
}

enum BackgroundTaskStatus: String, Codable {
    case running = "running"
    case completed = "completed"
    case failed = "failed"
}

struct BackgroundTaskInfo: Codable, Identifiable, Equatable {
    let id: String
    let type: BackgroundTaskType
    let startTime: Date
    var status: BackgroundTaskStatus
    var completionTime: Date?
    var error: String?
    
    var duration: TimeInterval? {
        guard let completionTime = completionTime else { return nil }
        return completionTime.timeIntervalSince(startTime)
    }
    
    var isActive: Bool {
        return status == .running
    }
    
    static func == (lhs: BackgroundTaskInfo, rhs: BackgroundTaskInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.startTime == rhs.startTime &&
               lhs.status == rhs.status &&
               lhs.completionTime == rhs.completionTime &&
               lhs.error == rhs.error
    }
}

// MARK: - Result Persistence Manager

class ResultPersistenceManager {
    static let shared = ResultPersistenceManager()
    
    private init() {}
    
    // MARK: - Workout Plan Results
    
    func saveWorkoutPlanResult(_ plan: DeepseekWorkoutPlan, taskId: String) {
        do {
            let data = try JSONEncoder().encode(plan)
            UserDefaults.standard.set(data, forKey: "WorkoutPlan_\(taskId)")
            UserDefaults.standard.set(Date(), forKey: "WorkoutPlan_\(taskId)_timestamp")
            print("💾 ResultPersistenceManager: Saved workout plan for task \(taskId)")
        } catch {
            print("❌ ResultPersistenceManager: Failed to save workout plan: \(error)")
        }
    }
    
    func loadWorkoutPlanResult(taskId: String) -> (plan: DeepseekWorkoutPlan, timestamp: Date)? {
        guard let data = UserDefaults.standard.data(forKey: "WorkoutPlan_\(taskId)"),
              let timestamp = UserDefaults.standard.object(forKey: "WorkoutPlan_\(taskId)_timestamp") as? Date else {
            return nil
        }
        
        do {
            let plan = try JSONDecoder().decode(DeepseekWorkoutPlan.self, from: data)
            return (plan, timestamp)
        } catch {
            print("❌ ResultPersistenceManager: Failed to load workout plan: \(error)")
            return nil
        }
    }
    
    // MARK: - Macro Meal Results
    
    func saveMacroMealResult(_ meal: MacroMeal, taskId: String) {
        do {
            let data = try JSONEncoder().encode(meal)
            UserDefaults.standard.set(data, forKey: "MacroMeal_\(taskId)")
            UserDefaults.standard.set(Date(), forKey: "MacroMeal_\(taskId)_timestamp")
            print("💾 ResultPersistenceManager: Saved macro meal for task \(taskId)")
        } catch {
            print("❌ ResultPersistenceManager: Failed to save macro meal: \(error)")
        }
    }
    
    func loadMacroMealResult(taskId: String) -> (meal: MacroMeal, timestamp: Date)? {
        guard let data = UserDefaults.standard.data(forKey: "MacroMeal_\(taskId)"),
              let timestamp = UserDefaults.standard.object(forKey: "MacroMeal_\(taskId)_timestamp") as? Date else {
            return nil
        }
        
        do {
            let meal = try JSONDecoder().decode(MacroMeal.self, from: data)
            return (meal, timestamp)
        } catch {
            print("❌ ResultPersistenceManager: Failed to load macro meal: \(error)")
            return nil
        }
    }
    
    // MARK: - Chat Response Results
    
    func saveChatResponse(_ response: String, taskId: String) {
        UserDefaults.standard.set(response, forKey: "ChatResponse_\(taskId)")
        UserDefaults.standard.set(Date(), forKey: "ChatResponse_\(taskId)_timestamp")
        print("💾 ResultPersistenceManager: Saved chat response for task \(taskId)")
    }
    
    func loadChatResponse(taskId: String) -> (response: String, timestamp: Date)? {
        guard let response = UserDefaults.standard.string(forKey: "ChatResponse_\(taskId)"),
              let timestamp = UserDefaults.standard.object(forKey: "ChatResponse_\(taskId)_timestamp") as? Date else {
            return nil
        }
        
        return (response, timestamp)
    }
    
    // MARK: - Cleanup
    
    func cleanupOldResults(olderThan interval: TimeInterval = 86400 * 7) { // 7 days default
        let cutoffDate = Date().addingTimeInterval(-interval)
        let defaults = UserDefaults.standard
        
        // Get all keys
        for key in defaults.dictionaryRepresentation().keys {
            if key.contains("_timestamp") {
                if let timestamp = defaults.object(forKey: key) as? Date,
                   timestamp < cutoffDate {
                    // Remove both the result and timestamp
                    let resultKey = key.replacingOccurrences(of: "_timestamp", with: "")
                    defaults.removeObject(forKey: resultKey)
                    defaults.removeObject(forKey: key)
                    print("🗑️ ResultPersistenceManager: Cleaned up old result: \(resultKey)")
                }
            }
        }
    }
}
