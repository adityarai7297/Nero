import SwiftUI

struct SocialView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var socialService = SocialService()
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack {
                    if authService.user?.socialSetupCompleted == false {
                        // Show username setup
                        UsernameSetupView(socialService: socialService, isDarkMode: isDarkMode)
                    } else {
                        // Show main social interface
                        SocialMainView(socialService: socialService, isDarkMode: isDarkMode)
                    }
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Debug DB") {
                        Task {
                            await socialService.debugListAllUsernames()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentBlue)
                }
            }
        }
        .onAppear {
            socialService.setUser(authService.user?.id)
        }
    }
}

struct UsernameSetupView: View {
    @ObservedObject var socialService: SocialService
    let isDarkMode: Bool
    @EnvironmentObject var authService: AuthService
    
    @State private var username = ""
    @State private var isCheckingAvailability = false
    @State private var isAvailable: Bool?
    @State private var showingError = false
    
    private var isValidUsername: Bool {
        username.count >= 3 && username.count <= 30 && username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(isDarkMode ? Color.accentBlue.opacity(0.8) : Color.accentBlue.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("Choose Your Username")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("You'll need a username to connect with other users")
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            // Username input
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Username")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Spacer()
                        
                        if isCheckingAvailability {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let isAvailable = isAvailable {
                            HStack(spacing: 4) {
                                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isAvailable ? .green : .red)
                                Text(isAvailable ? "Available" : "Taken")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(isAvailable ? .green : .red)
                            }
                        }
                    }
                    
                    TextField("Enter username", text: $username)
                        .textFieldStyle(SocialFieldStyle(
                            hasError: isAvailable == false,
                            isDarkMode: isDarkMode
                        ))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: username) { _, newValue in
                            // Reset availability check when username changes
                            isAvailable = nil
                            
                            // Check availability with debounce
                            if isValidUsername {
                                Task {
                                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                    if username == newValue && isValidUsername {
                                        await checkAvailability()
                                    }
                                }
                            }
                        }
                    
                    if !username.isEmpty && !isValidUsername {
                        Text("Username must be 3-30 characters and contain only letters, numbers, and underscores")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Button("Set Username") {
                    Task {
                        let success = await socialService.updateUsername(username)
                        if success {
                            // Refresh user data to get updated social fields
                            await authService.refreshSession()
                        } else {
                            showingError = true
                        }
                    }
                }
                .disabled(!isValidUsername || isAvailable != true || socialService.isLoading)
                .buttonStyle(PrimaryButtonStyle(
                    isEnabled: isValidUsername && isAvailable == true && !socialService.isLoading,
                    isDarkMode: isDarkMode
                ))
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.vertical, 20)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(socialService.errorMessage ?? "Failed to set username")
        }
    }
    
    private func checkAvailability() async {
        await MainActor.run {
            isCheckingAvailability = true
        }
        
        let available = await socialService.checkUsernameAvailability(username)
        
        await MainActor.run {
            isCheckingAvailability = false
            isAvailable = available
        }
    }
}

struct SocialMainView: View {
    @ObservedObject var socialService: SocialService
    let isDarkMode: Bool
    
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var searchResults: [PublicUserProfile] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Social Tab", selection: $selectedTab) {
                Text("Notifications").tag(0)
                Text("Requests").tag(1)
                Text("Search").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Notifications tab
                NotificationsView(socialService: socialService, isDarkMode: isDarkMode)
                    .tag(0)
                
                // Requests tab
                RequestsView(socialService: socialService, isDarkMode: isDarkMode)
                    .tag(1)
                
                // Search tab
                SearchView(
                    socialService: socialService,
                    isDarkMode: isDarkMode,
                    searchText: $searchText,
                    searchResults: $searchResults,
                    isSearching: $isSearching
                )
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

struct NotificationsView: View {
    @ObservedObject var socialService: SocialService
    let isDarkMode: Bool
    
    var body: some View {
        VStack {
            if socialService.socialNotifications.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                    
                    Text("No notifications yet")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    
                    Text("You'll see follow requests and other social updates here")
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List {
                    ForEach(socialService.socialNotifications) { notification in
                        NotificationRowView(
                            notification: notification,
                            isDarkMode: isDarkMode,
                            onTap: {
                                Task {
                                    await socialService.markNotificationAsRead(notification.id)
                                }
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top, 8)
    }
}

struct RequestsView: View {
    @ObservedObject var socialService: SocialService
    let isDarkMode: Bool
    
    var body: some View {
        VStack {
            if socialService.pendingRequests.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                    
                    Text("No follow requests")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    
                    Text("Follow requests will appear here")
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.8))
                }
                Spacer()
            } else {
                List {
                    ForEach(socialService.pendingRequests) { request in
                        RequestRowView(
                            request: request,
                            isDarkMode: isDarkMode,
                            onAccept: {
                                Task {
                                    await socialService.handleFollowRequest(requestId: request.id, action: .accept)
                                }
                            },
                            onReject: {
                                Task {
                                    await socialService.handleFollowRequest(requestId: request.id, action: .reject)
                                }
                            },
                            socialService: socialService
                        )
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top, 8)
    }
}

struct SearchView: View {
    @ObservedObject var socialService: SocialService
    let isDarkMode: Bool
    @Binding var searchText: String
    @Binding var searchResults: [PublicUserProfile]
    @Binding var isSearching: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                
                TextField("Search users...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { _, newValue in
                        Task {
                            await performSearch(newValue)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        searchResults = []
                    }
                    .font(.caption)
                    .foregroundColor(Color.accentBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.12) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isDarkMode ? Color.white.opacity(0.25) : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Search results
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                    
                    Text("No users found")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchResults.isEmpty {
                List {
                    ForEach(searchResults) { user in
                        UserSearchRowView(
                            user: user,
                            isDarkMode: isDarkMode,
                            onFollow: {
                                Task {
                                    let result = await socialService.sendFollowRequest(to: user.username)
                                    // Handle result (could show success/error message)
                                }
                            },
                            socialService: socialService
                        )
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 48))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                    
                    Text("Search for users")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    
                    Text("Enter a username or name to find other users")
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func performSearch(_ query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
        }
        
        // Debounce search
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let results = await socialService.searchUsers(query)
        
        await MainActor.run {
            if searchText == query { // Only update if search hasn't changed
                searchResults = results
            }
            isSearching = false
        }
    }
}

// MARK: - Row Views

struct NotificationRowView: View {
    let notification: SocialNotification
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notificationText)
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: notification.createdAt, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                }
                
                Spacer()
                
                if !notification.isRead {
                    Circle()
                        .fill(Color.accentBlue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch notification.notificationType {
        case "follow_request":
            return "person.badge.plus"
        case "follow_accepted":
            return "checkmark.circle.fill"
        case "new_follower":
            return "person.fill.checkmark"
        default:
            return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.notificationType {
        case "follow_request":
            return .blue
        case "follow_accepted":
            return .green
        case "new_follower":
            return .purple
        default:
            return .gray
        }
    }
    
    private var notificationText: String {
        switch notification.notificationType {
        case "follow_request":
            return "\(notification.senderUsername ?? "Someone") sent you a follow request"
        case "follow_accepted":
            return "\(notification.accepterUsername ?? "Someone") accepted your follow request"
        case "new_follower":
            return "\(notification.senderUsername ?? "Someone") is now following you"
        default:
            return "New notification"
        }
    }
}

struct RequestRowView: View {
    let request: FollowRequest
    let isDarkMode: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    @ObservedObject var socialService: SocialService
    
    private var isProcessing: Bool {
        socialService.processingRequests.contains(request.id)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(request.followerUsername?.first?.uppercased() ?? "?"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white : .black)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.followerDisplayName ?? request.followerUsername ?? "Unknown User")
                    .font(.headline)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                if let username = request.followerUsername {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                }
                
                Text(RelativeDateTimeFormatter().localizedString(for: request.createdAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 100, height: 32)
            } else {
                HStack(spacing: 8) {
                    Button("Accept", action: onAccept)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(6)
                    
                    Button("Decline", action: onReject)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isDarkMode ? .white : .black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct UserSearchRowView: View {
    let user: PublicUserProfile
    let isDarkMode: Bool
    let onFollow: () -> Void
    @ObservedObject var socialService: SocialService
    
    private var followButtonState: FollowButtonState {
        if socialService.sentFollowRequests.contains(user.username) {
            return .sent
        } else {
            return .follow
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(user.username.first?.uppercased() ?? "?"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white : .black)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? user.username)
                    .font(.headline)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    Text("\(user.followerCount) followers")
                        .font(.caption2)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                    
                    Text("\(user.followingCount) following")
                        .font(.caption2)
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                }
            }
            
            Spacer()
            
            Button(followButtonState.title, action: followButtonState == .follow ? onFollow : {})
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(followButtonState.backgroundColor)
                .cornerRadius(6)
                .disabled(followButtonState != .follow)
        }
        .padding(.vertical, 8)
    }
}

enum FollowButtonState {
    case follow
    case sent
    
    var title: String {
        switch self {
        case .follow: return "Follow"
        case .sent: return "Sent"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .follow: return Color.accentBlue
        case .sent: return Color.gray
        }
    }
}

// MARK: - Helper Styles

struct SocialFieldStyle: TextFieldStyle {
    let hasError: Bool
    let isDarkMode: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.12) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(hasError ? Color.red : (isDarkMode ? Color.white.opacity(0.25) : Color.gray.opacity(0.3)), lineWidth: 1.5)
                    )
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let isDarkMode: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? Color.accentBlue : Color.gray)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
