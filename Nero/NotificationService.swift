import Foundation
import UserNotifications
import SwiftUI
import Supabase

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var hasPermission: Bool = false
    
    private var currentUserId: UUID?
    private var completionNotificationSentToday: Bool = false
    private var lastCompletionDate: Date?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkNotificationPermission()
        
        // Listen for workout plan updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkoutPlanUpdate),
            name: NSNotification.Name("WorkoutPlanUpdated"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Permission Handling
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.hasPermission = granted
            }
            print("🔔 NotificationService: Permission granted: \(granted)")
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
                print("🔔 NotificationService: Current permission status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
    
    // MARK: - User Management
    
    func setUser(_ userId: UUID?) {
        currentUserId = userId
        if userId != nil {
            loadNotifications()
            resetDailyCompletionTracking()
        } else {
            notifications = []
            unreadCount = 0
            completionNotificationSentToday = false
            lastCompletionDate = nil
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
        // Check permission status first
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        print("🔔 NotificationService: Scheduling notification with permission status: \(settings.authorizationStatus.rawValue)")
        
        if settings.authorizationStatus != .authorized {
            print("⚠️ NotificationService: No permission for local notifications. Status: \(settings.authorizationStatus.rawValue)")
            // Try to request permission if not yet determined
            if settings.authorizationStatus == .notDetermined {
                let granted = await requestNotificationPermission()
                if !granted {
                    print("❌ NotificationService: Permission denied, cannot schedule notification")
                    return
                }
                // If permission was granted, continue with the function
            } else {
                return
            }
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
            try await center.add(request)
            print("✅ NotificationService: Successfully scheduled local notification with ID: \(request.identifier)")
        } catch {
            print("❌ NotificationService: Failed to schedule notification: \(error)")
        }
    }
    
    // MARK: - Workout Completion Notifications
    
    func checkWorkoutCompletion(workoutService: WorkoutService) {
        guard !workoutService.exercises.isEmpty else { 
            print("🔔 NotificationService: No exercises found, skipping completion check")
            return 
        }
        
        // Check if we need to reset daily tracking (new day)
        resetDailyCompletionTrackingIfNeeded()
        
        // Check if we already sent a completion notification today
        if completionNotificationSentToday {
            print("🔔 NotificationService: Completion notification already sent today, skipping")
            return
        }
        
        print("🔔 NotificationService: Checking workout completion for \(workoutService.exercises.count) exercises")
        
        // Check if all exercises are completed for today
        let allExercisesCompleted = workoutService.exercises.allSatisfy { exercise in
            let isCompleted = workoutService.isExerciseCompletedForToday(exerciseName: exercise.name)
            print("🔔 NotificationService: Exercise '\(exercise.name)' completed: \(isCompleted)")
            return isCompleted
        }
        
        print("🔔 NotificationService: All exercises completed: \(allExercisesCompleted)")
        
        if allExercisesCompleted {
            print("🎉 NotificationService: Workout completed! Creating notifications...")
            
            // Mark that we've sent the completion notification for today
            completionNotificationSentToday = true
            lastCompletionDate = Date()
            
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
                    timeInterval: 2, // Give a bit more time for the app to process
                    userInfo: ["type": "workout_completed"]
                )
            }
        }
    }
    
    // MARK: - Helper Methods for Daily Tracking
    
    private func resetDailyCompletionTracking() {
        completionNotificationSentToday = false
        lastCompletionDate = nil
        print("🔔 NotificationService: Reset daily completion tracking")
    }
    
    private func resetDailyCompletionTrackingIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastDate = lastCompletionDate {
            let lastCompletionDay = Calendar.current.startOfDay(for: lastDate)
            
            // If it's a new day, reset the tracking
            if today > lastCompletionDay {
                print("🔔 NotificationService: New day detected, resetting completion tracking")
                resetDailyCompletionTracking()
            }
        }
    }
    
    // Call this when the workout plan changes
    func resetCompletionTrackingForPlanChange() {
        print("🔔 NotificationService: Workout plan changed, resetting completion tracking")
        resetDailyCompletionTracking()
    }
    
    @objc private func handleWorkoutPlanUpdate() {
        print("🔔 NotificationService: Received workout plan update notification")
        resetCompletionTrackingForPlanChange()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // This method is called when a notification is delivered while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 NotificationService: Notification will present in foreground: \(notification.request.content.title)")
        
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // This method is called when the user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 NotificationService: Notification tapped: \(response.notification.request.content.title)")
        
        let userInfo = response.notification.request.content.userInfo
        print("🔔 NotificationService: Notification userInfo: \(userInfo)")
        
        // Handle the notification tap here if needed
        // For example, navigate to a specific screen
        
        completionHandler()
    }

} 