import Foundation
import UIKit
import SwiftUI

// MARK: - App Lifecycle Manager

class AppLifecycleManager: ObservableObject {
    static let shared = AppLifecycleManager()
    
    @Published var isAppActive: Bool = true
    @Published var isAppInBackground: Bool = false
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("📱 AppLifecycleManager: App entered background")
        DispatchQueue.main.async {
            self.isAppInBackground = true
            self.isAppActive = false
        }
        
        // Cleanup old persisted results when app goes to background
        ResultPersistenceManager.shared.cleanupOldResults()
        ViewStatePersistenceManager.shared.cleanupOldViewStates()
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 AppLifecycleManager: App will enter foreground")
        DispatchQueue.main.async {
            self.isAppInBackground = false
        }
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 AppLifecycleManager: App became active")
        DispatchQueue.main.async {
            self.isAppActive = true
        }
    }
    
    @objc private func appWillResignActive() {
        print("📱 AppLifecycleManager: App will resign active")
        DispatchQueue.main.async {
            self.isAppActive = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - View Extension for Easy Lifecycle Handling

extension View {
    func onAppLifecycleChange(
        active: (() -> Void)? = nil,
        inactive: (() -> Void)? = nil,
        background: (() -> Void)? = nil,
        foreground: (() -> Void)? = nil
    ) -> some View {
        self
            .environmentObject(AppLifecycleManager.shared)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                active?()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                inactive?()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                background?()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                foreground?()
            }
    }
}

// MARK: - Background Task Status View

struct BackgroundTaskStatusView: View {
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    let isDarkMode: Bool
    
    var activeTasks: [BackgroundTaskInfo] {
        Array(backgroundTaskManager.activeTasks.values.filter { $0.isActive })
    }
    
    var body: some View {
        if !activeTasks.isEmpty {
            VStack(spacing: 8) {
                ForEach(activeTasks, id: \.id) { task in
                    BackgroundTaskStatusRow(task: task, isDarkMode: isDarkMode)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                    .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
}

struct BackgroundTaskStatusRow: View {
    let task: BackgroundTaskInfo
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: taskColor))
                .scaleEffect(0.7)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(taskTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Text("Running for \(taskDuration)")
                    .font(.caption2)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
            }
            
            Spacer()
            
            Image(systemName: taskIcon)
                .font(.caption)
                .foregroundColor(taskColor)
        }
    }
    
    private var taskColor: Color {
        switch task.type {
        case .workoutPlanGeneration, .workoutPlanEdit:
            return .blue
        case .macroMealParsing, .macroMealEdit:
            return .orange
        case .fitnessCoachChat:
            return .mint
        case .audioTranscription:
            return .purple
        }
    }
    
    private var taskIcon: String {
        switch task.type {
        case .workoutPlanGeneration, .workoutPlanEdit:
            return "dumbbell.fill"
        case .macroMealParsing, .macroMealEdit:
            return "fork.knife"
        case .fitnessCoachChat:
            return "brain.head.profile"
        case .audioTranscription:
            return "mic.fill"
        }
    }
    
    private var taskTitle: String {
        switch task.type {
        case .workoutPlanGeneration:
            return "Generating workout plan"
        case .workoutPlanEdit:
            return "Editing workout plan"
        case .macroMealParsing:
            return "Processing meal"
        case .macroMealEdit:
            return "Editing meal"
        case .fitnessCoachChat:
            return "Getting AI response"
        case .audioTranscription:
            return "Transcribing audio"
        }
    }
    
    private var taskDuration: String {
        let duration = Date().timeIntervalSince(task.startTime)
        if duration < 60 {
            return "\(Int(duration))s"
        } else {
            return "\(Int(duration / 60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s"
        }
    }
}

// MARK: - Helpful Extensions

extension BackgroundTaskInfo {
    var timeRunning: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
    
    var isLongRunning: Bool {
        return timeRunning > 30 // More than 30 seconds
    }
}

extension WorkoutPreferencesService {
    var hasActiveBackgroundTask: Bool {
        return generationStatus.isActive
    }
}

// MARK: - Task Recovery Helper

struct TaskRecoveryHelper {
    static func recoverIncompleteTasks() {
        let backgroundManager = BackgroundTaskManager.shared
        
        // Check for any tasks that were running when the app was terminated
        for (taskId, taskInfo) in backgroundManager.activeTasks {
            if taskInfo.status == .running && taskInfo.timeRunning > 300 { // 5 minutes
                print("🔄 TaskRecoveryHelper: Found stale task \(taskId), marking as failed")
                Task { @MainActor in
                    var updatedTask = taskInfo
                    updatedTask.status = .failed
                    updatedTask.error = "Task timeout - app was inactive too long"
                    updatedTask.completionTime = Date()
                    backgroundManager.activeTasks[taskId] = updatedTask
                }
            }
        }
    }
}
