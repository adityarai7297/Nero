import Foundation
import UserNotifications
import SwiftUI
import Supabase

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var hasPermission: Bool = false
    
    private var currentUserId: UUID?
    
    private init() {
        checkNotificationPermission()
    }
    
    // MARK: - Permission Handling
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.hasPermission = granted
            }
            return granted
        } catch {
            print("❌ NotificationService: Failed to request permission: \(error)")
            return false
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - User Management
    
    func setUser(_ userId: UUID?) {
        currentUserId = userId
        if userId != nil {
            loadNotifications()
        } else {
            notifications = []
            unreadCount = 0
        }
    }
    
    // MARK: - In-App Notifications
    
    func loadNotifications() {
        guard let userId = currentUserId else {
            notifications = []
            unreadCount = 0
            return
        }
        
        Task {
            do {
                let response: [DBNotification] = try await supabase
                    .from("notifications")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .order("timestamp", ascending: false)
                    .limit(50)
                    .execute()
                    .value
                
                let loadedNotifications = response.compactMap { dbNotification -> AppNotification? in
                    guard let notificationType = AppNotification.NotificationType(rawValue: dbNotification.type) else {
                        return nil
                    }
                    
                    return AppNotification(
                        title: dbNotification.title,
                        message: dbNotification.message,
                        type: notificationType,
                        timestamp: dbNotification.timestamp,
                        isRead: dbNotification.isRead,
                        imageIcon: dbNotification.imageIcon
                    )
                }
                
                await MainActor.run {
                    self.notifications = loadedNotifications
                    self.updateUnreadCount()
                }
            } catch {
                print("❌ NotificationService: Failed to load notifications: \(error)")
            }
        }
    }
    
    func createNotification(
        title: String,
        message: String,
        type: AppNotification.NotificationType,
        imageIcon: String? = nil
    ) {
        guard let userId = currentUserId else {
            print("⚠️ NotificationService: Cannot create notification without user")
            return
        }
        
        let notification = AppNotification(
            title: title,
            message: message,
            type: type,
            timestamp: Date(),
            isRead: false,
            imageIcon: imageIcon ?? type.defaultIcon
        )
        
        // Add to local array immediately for responsiveness
        notifications.insert(notification, at: 0)
        updateUnreadCount()
        
        // Save to database
        Task {
            await saveNotificationToDatabase(notification, userId: userId)
        }
    }
    
    private func saveNotificationToDatabase(_ notification: AppNotification, userId: UUID) async {
        let dbNotification = DBNotification(
            id: nil,
            userId: userId,
            title: notification.title,
            message: notification.message,
            type: notification.type.rawValue,
            timestamp: notification.timestamp,
            isRead: notification.isRead,
            imageIcon: notification.imageIcon,
            createdAt: nil
        )
        
        do {
            try await supabase
                .from("notifications")
                .insert(dbNotification)
                .execute()
        } catch {
            print("❌ NotificationService: Failed to save notification: \(error)")
        }
    }
    
    func markAsRead(_ notification: AppNotification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        
        notifications[index].isRead = true
        updateUnreadCount()
        
        // Update in database
        Task {
            await updateNotificationReadStatus(notification.id, isRead: true)
        }
    }
    
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        updateUnreadCount()
        
        // Update all in database
        Task {
            await markAllNotificationsAsRead()
        }
    }
    
    private func updateNotificationReadStatus(_ notificationId: UUID, isRead: Bool) async {
        guard let userId = currentUserId else { return }
        
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": isRead])
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            print("❌ NotificationService: Failed to update notification read status: \(error)")
        }
    }
    
    private func markAllNotificationsAsRead() async {
        guard let userId = currentUserId else { return }
        
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": true])
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()
        } catch {
            print("❌ NotificationService: Failed to mark all notifications as read: \(error)")
        }
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    // MARK: - Local Push Notifications
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval = 1,
        userInfo: [String: Any] = [:]
    ) async {
        guard hasPermission else {
            print("⚠️ NotificationService: No permission for local notifications")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        // Add thumbs up emoji to the content for workout completion
        if userInfo["type"] as? String == "workout_completed" {
            content.title = "👍 " + content.title
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ NotificationService: Scheduled local notification")
        } catch {
            print("❌ NotificationService: Failed to schedule notification: \(error)")
        }
    }
    
    // MARK: - Workout Completion Notifications
    
    func checkWorkoutCompletion(workoutService: WorkoutService) {
        guard !workoutService.exercises.isEmpty else { return }
        
        // Check if all exercises are completed for today
        let allExercisesCompleted = workoutService.exercises.allSatisfy { exercise in
            workoutService.isExerciseCompletedForToday(exerciseName: exercise.name)
        }
        
        if allExercisesCompleted {
            // Create in-app notification
            createNotification(
                title: "🎉 Workout Complete!",
                message: "Amazing! You've completed all your exercises for today. Keep up the great work!",
                type: .workoutCompleted,
                imageIcon: "thumbs_up"
            )
            
            // Schedule local notification
            Task {
                await scheduleLocalNotification(
                    title: "🎉 Workout Complete!",
                    body: "Amazing! You've completed all your exercises for today.",
                    timeInterval: 1,
                    userInfo: ["type": "workout_completed"]
                )
            }
        }
    }
} 