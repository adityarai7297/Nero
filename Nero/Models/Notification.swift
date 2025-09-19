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
        
        // Social notifications
        case followRequest = "follow_request"
        case followAccepted = "follow_accepted"
        case newFollower = "new_follower"
        
        var color: String {
            switch self {
            case .workoutCompleted: return "green"
            case .achievement: return "orange" 
            case .reminder: return "blue"
            case .system: return "gray"
            case .followRequest: return "blue"
            case .followAccepted: return "green"
            case .newFollower: return "purple"
            }
        }
        
        var defaultIcon: String {
            switch self {
            case .workoutCompleted: return "checkmark.circle.fill"
            case .achievement: return "trophy.fill"
            case .reminder: return "bell.fill"
            case .system: return "info.circle.fill"
            case .followRequest: return "person.badge.plus"
            case .followAccepted: return "checkmark.circle.fill"
            case .newFollower: return "person.fill.checkmark"
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