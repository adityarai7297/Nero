import Foundation

// MARK: - In-App Notification Models

struct AppNotification: Identifiable, Codable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let timestamp: Date
    var isRead: Bool = false
    let imageIcon: String? // SF Symbol or image name
    
    enum NotificationType: String, CaseIterable, Codable {
        case workoutCompleted = "workout_completed"
        case achievement = "achievement"
        case reminder = "reminder"
        case system = "system"
        
        var color: String {
            switch self {
            case .workoutCompleted: return "green"
            case .achievement: return "orange" 
            case .reminder: return "blue"
            case .system: return "gray"
            }
        }
        
        var defaultIcon: String {
            switch self {
            case .workoutCompleted: return "checkmark.circle.fill"
            case .achievement: return "trophy.fill"
            case .reminder: return "bell.fill"
            case .system: return "info.circle.fill"
            }
        }
    }
}

// MARK: - Database model for notifications
struct DBNotification: Codable {
    let id: Int?
    let userId: UUID
    let title: String
    let message: String
    let type: String
    let timestamp: Date
    let isRead: Bool
    let imageIcon: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case message
        case type
        case timestamp
        case isRead = "is_read"
        case imageIcon = "image_icon"
        case createdAt = "created_at"
    }
} 