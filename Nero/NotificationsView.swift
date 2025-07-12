import SwiftUI

struct NotificationsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.offWhite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if notificationService.notifications.isEmpty {
                        EmptyNotificationsView()
                    } else {
                        NotificationsList()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notificationService.notifications.isEmpty && notificationService.unreadCount > 0 {
                        Button("Mark All Read") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                notificationService.markAllAsRead()
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.accentBlue)
                    }
                }
            }
        }
        .onAppear {
            notificationService.loadNotifications()
        }
    }
    
    @ViewBuilder
    private func EmptyNotificationsView() -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("No Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("You're all caught up! Notifications from your workouts and achievements will appear here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func NotificationsList() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notificationService.notifications) { notification in
                    NotificationCard(
                        notification: notification,
                        onTap: {
                            if !notification.isRead {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    notificationService.markAsRead(notification)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100) // Extra padding for bottom
        }
    }
}

struct NotificationCard: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var typeColor: Color {
        switch notification.type.color {
        case "green": return .green
        case "orange": return .orange
        case "blue": return Color.accentBlue
        case "gray": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                // Icon/Image
                ZStack {
                    Circle()
                        .fill(Color.offWhite)
                        .overlay(
                            Circle()
                                .stroke(typeColor, lineWidth: 2)
                        )
                    
                    if let imageIcon = notification.imageIcon {
                        if imageIcon == "thumbs_up" {
                            // Use thumbs up SF Symbol
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(typeColor)
                        } else {
                            // Use SF Symbol
                            Image(systemName: imageIcon)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(typeColor)
                        }
                    } else {
                        Image(systemName: notification.type.defaultIcon)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(typeColor)
                    }
                }
                .frame(width: 50, height: 50)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(notification.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(typeColor)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    Text(notification.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isPressed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(notification.isRead ? Color.gray.opacity(0.15) : typeColor.opacity(0.2), lineWidth: notification.isRead ? 1 : 1.5)
                            )
                    }
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Extension to format timestamp as "time ago"
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// Preview
struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
    }
} 