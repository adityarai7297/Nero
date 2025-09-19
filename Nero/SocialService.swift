import Foundation
import Supabase
import SwiftUI

// MARK: - Social Models

struct SocialNotification: Identifiable, Codable {
    let id: Int
    let recipientId: UUID
    let senderId: UUID
    let notificationType: String
    let isRead: Bool
    let createdAt: Date
    let metadata: [String: String]
    
    // Computed properties for easier access
    var senderUsername: String? {
        metadata["sender_username"]
    }
    
    var accepterUsername: String? {
        metadata["accepter_username"]
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case senderId = "sender_id"
        case notificationType = "notification_type"
        case isRead = "is_read"
        case createdAt = "created_at"
        case metadata
    }
}

struct FollowRequest: Identifiable, Codable {
    let id: Int
    let followerId: UUID
    let followingId: UUID
    let status: String
    let createdAt: Date
    let followerUsername: String?
    let followerDisplayName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case status
        case createdAt = "created_at"
        case followerUsername = "follower_username"
        case followerDisplayName = "follower_display_name"
    }
}

struct PublicUserProfile: Identifiable, Codable {
    let id: UUID
    let username: String
    let displayName: String?
    let bio: String?
    let profileImageUrl: String?
    let followerCount: Int
    let followingCount: Int
    let isPrivate: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case profileImageUrl = "profile_image_url"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case isPrivate = "is_private"
    }
}

enum FollowAction {
    case accept
    case reject
}

enum FollowRequestResult {
    case success(String) // Message
    case error(String)   // Error message
}

// MARK: - Social Service

class SocialService: ObservableObject {
    @Published var socialNotifications: [SocialNotification] = []
    @Published var pendingRequests: [FollowRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sentFollowRequests: Set<String> = [] // Track usernames we've sent requests to
    @Published var processingRequests: Set<Int> = [] // Track request IDs being processed
    
    private var currentUserId: UUID?
    
    func setUser(_ userId: UUID?) {
        currentUserId = userId
        if userId != nil {
            Task {
                await loadSocialNotifications()
                await loadPendingRequests()
                await loadSentFollowRequests()
                // Debug: List all usernames to see what's in the database
                await debugListAllUsernames()
            }
        } else {
            socialNotifications = []
            pendingRequests = []
            sentFollowRequests = []
            processingRequests = []
        }
    }
    
    // MARK: - Username Management
    
    func updateUsername(_ username: String) async -> Bool {
        guard let userId = currentUserId else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return false
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Check if username is available using SQL function
            let isAvailable: Bool = try await supabase
                .rpc("check_username_availability", params: ["username_to_check": username])
                .execute()
                .value
            
            guard isAvailable else {
                await MainActor.run {
                    self.errorMessage = "Username is already taken"
                    self.isLoading = false
                }
                print("❌ Username '\(username)' is already taken")
                return false
            }
            
            print("✅ Username '\(username)' is available, proceeding with update")
            
            // Update username and mark social setup as completed
            struct UserUpdate: Encodable {
                let username: String
                let social_setup_completed: Bool
            }
            
            let updateData = UserUpdate(username: username, social_setup_completed: true)
            try await supabase
                .from("users")
                .update(updateData)
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Verify the update worked by checking the database
            struct VerificationCheck: Codable {
                let id: UUID
                let username: String?
            }
            
            let verificationQuery: [VerificationCheck] = try await supabase
                .from("users")
                .select("id, username")
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            
            if let updatedUser = verificationQuery.first, updatedUser.username == username {
                print("✅ Username update verified successfully: \(username)")
            } else {
                print("⚠️ Username update may have failed - verification check did not match")
            }
            
            await MainActor.run {
                self.isLoading = false
            }
            
            print("✅ Username updated successfully: \(username)")
            return true
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update username: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ Failed to update username: \(error)")
            return false
        }
    }
    
    func checkUsernameAvailability(_ username: String) async -> Bool {
        guard !username.isEmpty else { 
            print("🔍 Username check: empty username")
            return false 
        }
        
        // Basic validation
        guard username.count >= 3 && username.count <= 30 else {
            print("🔍 Username '\(username)' invalid length (must be 3-30 characters)")
            return false
        }
        
        // Check if username contains only valid characters (alphanumeric, underscore, hyphen)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard username.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            print("🔍 Username '\(username)' contains invalid characters")
            return false
        }
        
        do {
            print("🔍 Checking username availability for: '\(username)' using SQL function")
            
            // Use the secure SQL function for username availability checking
            print("🔍 Calling SQL function with parameter: \(username)")
            
            // The function returns a single boolean value
            let isAvailable: Bool = try await supabase
                .rpc("check_username_availability", params: ["username_to_check": username])
                .execute()
                .value
            
            print("🔍 Username '\(username)' availability: \(isAvailable ? "✅ available" : "❌ taken")")
            return isAvailable
            
        } catch {
            print("❌ Failed to check username availability for '\(username)': \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            
            // Return false on error (assume taken for safety)
            return false
        }
    }
    
    // MARK: - Debug Functions
    
    func debugListAllUsernames() async {
        print("🔍 DEBUG: Starting comprehensive database test...")
        print("🔍 Current user ID: \(currentUserId?.uuidString ?? "none")")
        
        do {
            print("🔍 DEBUG: Step 1 - Testing basic database connection...")
            
            // First, test basic connection with just id and email
            struct BasicUser: Codable {
                let id: UUID
                let email: String
            }
            
            let basicUsers: [BasicUser] = try await supabase
                .from("users")
                .select("id, email")
                .execute()
                .value
            
            print("✅ Step 1 SUCCESS: Basic connection works! Found \(basicUsers.count) users")
            print("🔍 WARNING: If this shows only 1 user, it's likely due to Row Level Security (RLS)")
            for user in basicUsers.prefix(5) { // Show first 5 users
                print("  - ID: \(user.id), Email: \(user.email)")
            }
            
            print("🔍 DEBUG: Step 2 - Testing if username column exists...")
            
            // Now test if username column exists
            struct UserWithUsername: Codable {
                let id: UUID
                let email: String
                let username: String?
            }
            
            let usersWithUsernames: [UserWithUsername] = try await supabase
                .from("users")
                .select("id, email, username")
                .execute()
                .value
            
            print("✅ Step 2 SUCCESS: Username column exists! Found \(usersWithUsernames.count) users with username data:")
            for user in usersWithUsernames.prefix(5) { // Show first 5 users
                print("  - ID: \(user.id), Email: \(user.email), Username: \(user.username ?? "nil")")
            }
            
            // Count how many users actually have usernames set
            let usersWithUsernamesSet = usersWithUsernames.filter { $0.username != nil && !$0.username!.isEmpty }
            print("📊 SUMMARY: \(usersWithUsernamesSet.count) out of \(usersWithUsernames.count) users have usernames set")
            
            if usersWithUsernamesSet.count > 0 {
                print("👥 Users with usernames:")
                for user in usersWithUsernamesSet {
                    print("  - \(user.username!) (\(user.email))")
                }
            }
            
            print("🔍 DEBUG: Step 3 - Testing SQL function for username availability...")
            
            // First, test if the function exists by calling it with a simple test
            print("🔍 Testing if SQL function exists...")
            do {
                let simpleTest: Bool = try await supabase
                    .rpc("check_username_availability", params: ["username_to_check": "nonexistent_test_user_12345"])
                    .execute()
                    .value
                print("✅ SQL function exists! Test response: \(simpleTest)")
                print("✅ Function returned: \(simpleTest) (should be true for nonexistent user)")
            } catch {
                print("❌ SQL function test failed: \(error)")
                print("🔍 This means the function might not be created correctly in Supabase")
                return
            }
            
            do {
                // Test the new SQL function with existing username
                if let existingUsername = usersWithUsernamesSet.first?.username {
                    let isAvailable: Bool = try await supabase
                        .rpc("check_username_availability", params: ["username_to_check": existingUsername])
                        .execute()
                        .value
                    
                    print("🔍 Debug test - Response: \(isAvailable)")
                    print("✅ Step 3 SUCCESS: SQL function works! Username '\(existingUsername)' shows as: \(isAvailable ? "available" : "taken")")
                    
                    if !isAvailable {
                        print("✅ Perfect! Existing username correctly shows as taken")
                    } else {
                        print("⚠️ Warning: Existing username shows as available - this might be an issue")
                    }
                }
                
                // Test with a new username
                let testUsername = "test_username_\(Int.random(in: 1000...9999))"
                let testIsAvailable: Bool = try await supabase
                    .rpc("check_username_availability", params: ["username_to_check": testUsername])
                    .execute()
                    .value
                
                print("🔍 Test username - Response: \(testIsAvailable)")
                print("✅ SQL function test with '\(testUsername)': \(testIsAvailable ? "available" : "taken")")
                if testIsAvailable {
                    print("✅ Perfect! New username correctly shows as available")
                }
                
            } catch {
                print("❌ Step 3 FAILED: SQL function test failed: \(error)")
                print("🔍 Make sure the SQL function was created correctly in Supabase")
            }
            
            print("🔍 DEBUG: Step 4 - Testing user search function...")
            
            do {
                // Test user search function with a username we know exists
                if let existingUsername = usersWithUsernamesSet.first?.username {
                    let searchResults: [PublicUserProfile] = try await supabase
                        .rpc("search_users", params: ["search_query": String(existingUsername.prefix(3))])
                        .execute()
                        .value
                    
                    print("✅ Step 4 SUCCESS: User search function works! Found \(searchResults.count) users")
                    for user in searchResults.prefix(3) {
                        print("  - \(user.username) (\(user.displayName ?? "no display name"))")
                    }
                } else {
                    print("⚠️ No existing usernames to test search with")
                }
            } catch {
                print("❌ Step 4 FAILED: User search function test failed: \(error)")
                print("🔍 Make sure the search_users function was created correctly in Supabase")
            }
            
            print("🔍 DEBUG: Step 5 - Testing follow request functions...")
            
            // First, let's test if we can call any basic PostgreSQL function
            do {
                print("🔍 Testing basic PostgreSQL function call...")
                struct EmptyParams: Encodable {}
                let basicTest = try await supabase
                    .rpc("version", params: EmptyParams())
                    .execute()
                
                print("✅ Basic function call works: \(basicTest.value)")
            } catch {
                print("❌ Basic function call failed: \(error)")
            }
            
            do {
                // Test the follow request function (just test the call, don't actually send)
                // We'll test with a non-existent user to avoid creating real follow requests
                let testResponseValue = try await supabase
                    .rpc("send_follow_request", params: ["target_username": "nonexistent_test_user_12345"])
                    .execute()
                    .value
                
                print("🔍 Test follow request - Raw response: \(testResponseValue)")
                print("🔍 Test follow request - Response type: \(type(of: testResponseValue))")
                
                let testResponse: [String: Any] = testResponseValue as? [String: Any] ?? [:]
                
                print("✅ Step 5 SUCCESS: Follow request function callable! Test response: \(testResponse)")
                
                // Check if the response is in a different format
                if testResponse.isEmpty {
                    print("⚠️ Response is empty - might be different format")
                    if let stringResponse = testResponseValue as? String {
                        print("🔍 Response as string: \(stringResponse)")
                    } else if let boolResponse = testResponseValue as? Bool {
                        print("🔍 Response as bool: \(boolResponse)")
                    }
                }
                
                if let success = testResponse["success"] as? Bool, !success {
                    if let error = testResponse["error"] as? String {
                        print("✅ Function correctly rejected invalid user: \(error)")
                    }
                }
            } catch {
                print("❌ Step 5 FAILED: Follow request function test failed: \(error)")
                print("🔍 Make sure the send_follow_request function was created correctly in Supabase")
            }
            
        } catch {
            print("❌ DATABASE TEST FAILED!")
            print("❌ Error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            
            if let supabaseError = error as? any LocalizedError {
                print("❌ Supabase specific error: \(supabaseError.errorDescription ?? "unknown")")
            }
        }
    }
    
    // MARK: - Follow System
    
    func sendFollowRequest(to username: String) async -> FollowRequestResult {
        guard currentUserId != nil else {
            return .error("User not authenticated")
        }
        
        // Basic validation
        guard !username.isEmpty else {
            return .error("Username cannot be empty")
        }
        
        do {
            print("🔍 Sending follow request to: \(username)")
            
            // Use the secure SQL function for sending follow requests (returns boolean)
            let success: Bool = try await supabase
                .rpc("send_follow_request", params: ["target_username": username])
                .execute()
                .value
            
            print("🔍 Follow request result: \(success)")
            
            if success {
                print("✅ Follow request sent to \(username)")
                
                // Update UI state to show request was sent
                await MainActor.run {
                    self.sentFollowRequests.insert(username)
                }
                
                // Reload notifications to show any new ones
                await loadSocialNotifications()
                return .success("Follow request sent successfully")
            } else {
                print("❌ Follow request failed")
                return .error("Failed to send follow request")
            }
            
        } catch {
            let errorDescription = error.localizedDescription
            print("❌ Failed to send follow request to \(username): \(error)")
            
            // Handle specific error cases with better messaging
            if errorDescription.contains("Follow request already exists") {
                return .error("You have already sent a follow request to this user")
            } else if errorDescription.contains("User not found") {
                return .error("User not found")
            } else if errorDescription.contains("Cannot follow yourself") {
                return .error("You cannot follow yourself")
            } else {
                return .error("Failed to send follow request: \(errorDescription)")
            }
        }
    }
    
    func handleFollowRequest(requestId: Int, action: FollowAction) async -> Bool {
        guard currentUserId != nil else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return false
        }
        
        // Mark request as being processed
        await MainActor.run {
            self.processingRequests.insert(requestId)
        }
        
        do {
            let actionString = action == .accept ? "accept" : "reject"
            print("🔍 Handling follow request \(requestId) with action: \(actionString)")
            
            // Use the secure SQL function for handling follow requests  
            struct FollowRequestParams: Encodable {
                let request_id: Int
                let action: String
            }
            
            let params = FollowRequestParams(request_id: requestId, action: actionString)
            let responseValue = try await supabase
                .rpc("handle_follow_request", params: params)
                .execute()
                .value
            
            let response: [String: Any] = responseValue as? [String: Any] ?? [:]
            
            print("🔍 Handle follow request response: \(response)")
            
            // Parse the JSON response
            if let success = response["success"] as? Bool, success {
                let message = response["message"] as? String ?? "Follow request handled successfully"
                print("✅ Follow request \(requestId) \(actionString)ed successfully")
                
                // Remove from processing state and reload data
                await MainActor.run {
                    self.processingRequests.remove(requestId)
                }
                
                // Reload data to reflect changes
                await loadPendingRequests()
                await loadSocialNotifications()
                return true
            } else {
                let errorMessage = response["error"] as? String ?? "Unknown error occurred"
                print("❌ Handle follow request failed: \(errorMessage)")
                await MainActor.run {
                    self.processingRequests.remove(requestId)
                    self.errorMessage = errorMessage
                }
                return false
            }
            
        } catch {
            await MainActor.run {
                self.processingRequests.remove(requestId)
                self.errorMessage = "Failed to handle follow request: \(error.localizedDescription)"
            }
            print("❌ Failed to handle follow request \(requestId): \(error)")
            return false
        }
    }
    
    // MARK: - Data Loading
    
    func loadSocialNotifications() async {
        guard let userId = currentUserId else { return }
        
        do {
            print("🔍 Loading social notifications...")
            
            let notifications: [SocialNotification] = try await supabase
                .from("social_notifications")
                .select()
                .eq("recipient_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            print("🔍 Found \(notifications.count) notifications")
            for notification in notifications.prefix(3) {
                print("  - Type: \(notification.notificationType), Metadata: \(notification.metadata)")
            }
            
            await MainActor.run {
                self.socialNotifications = notifications
            }
            
        } catch {
            print("❌ Failed to load social notifications: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load notifications"
            }
        }
    }
    
    func loadPendingRequests() async {
        guard currentUserId != nil else { return }
        
        do {
            print("🔍 Loading pending follow requests...")
            
            // Use SQL function to get pending requests
            struct PendingRequestData: Codable {
                let id: Int
                let follower_id: UUID
                let following_id: UUID
                let status: String
                let created_at: Date
                let sender_username: String
                let sender_display_name: String?
            }
            
            let requestsData: [PendingRequestData] = try await supabase
                .rpc("get_pending_follow_requests")
                .execute()
                .value
            
            print("🔍 Found \(requestsData.count) pending requests")
            
            let requests = requestsData.map { data in
                FollowRequest(
                    id: data.id,
                    followerId: data.follower_id,
                    followingId: data.following_id,
                    status: data.status,
                    createdAt: data.created_at,
                    followerUsername: data.sender_username,
                    followerDisplayName: data.sender_display_name
                )
            }
            
            for request in requests {
                print("  - Request from: \(request.followerUsername ?? "unknown")")
            }
            
            await MainActor.run {
                self.pendingRequests = requests
            }
            
        } catch {
            print("❌ Failed to load pending requests: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load pending requests"
            }
        }
    }
    
    func loadSentFollowRequests() async {
        guard currentUserId != nil else { return }
        
        do {
            print("🔍 Loading sent follow requests...")
            
            // Get all follow requests we've sent (pending or accepted)
            struct SentRequestData: Codable {
                let following_id: UUID
                let status: String
                let target_username: String
            }
            
            let sentRequests: [SentRequestData] = try await supabase
                .rpc("get_sent_follow_requests")
                .execute()
                .value
            
            print("🔍 Found \(sentRequests.count) sent requests")
            
            let sentUsernames = Set(sentRequests.map { $0.target_username })
            
            await MainActor.run {
                self.sentFollowRequests = sentUsernames
            }
            
            for request in sentRequests.prefix(3) {
                print("  - Sent to: \(request.target_username) (status: \(request.status))")
            }
            
        } catch {
            print("❌ Failed to load sent follow requests: \(error)")
        }
    }
    
    func markNotificationAsRead(_ notificationId: Int) async {
        do {
            struct NotificationUpdate: Encodable {
                let is_read: Bool
            }
            
            let updateData = NotificationUpdate(is_read: true)
            try await supabase
                .from("social_notifications")
                .update(updateData)
                .eq("id", value: notificationId)
                .execute()
            
            await MainActor.run {
                if let index = self.socialNotifications.firstIndex(where: { $0.id == notificationId }) {
                    self.socialNotifications[index] = SocialNotification(
                        id: self.socialNotifications[index].id,
                        recipientId: self.socialNotifications[index].recipientId,
                        senderId: self.socialNotifications[index].senderId,
                        notificationType: self.socialNotifications[index].notificationType,
                        isRead: true,
                        createdAt: self.socialNotifications[index].createdAt,
                        metadata: self.socialNotifications[index].metadata
                    )
                }
            }
            
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
        }
    }
    
    // MARK: - User Search
    
    func searchUsers(_ query: String) async -> [PublicUserProfile] {
        guard !query.isEmpty else { 
            print("🔍 Empty search query")
            return [] 
        }
        
        // Basic validation for search query
        guard query.count >= 2 else {
            print("🔍 Search query too short (minimum 2 characters)")
            return []
        }
        
        do {
            print("🔍 Searching users with query: '\(query)' using SQL function")
            
            // Use the secure SQL function for user search
            let users: [PublicUserProfile] = try await supabase
                .rpc("search_users", params: ["search_query": query])
                .execute()
                .value
            
            print("🔍 Found \(users.count) users matching '\(query)'")
            for user in users.prefix(3) { // Show first 3 results for debugging
                print("  - \(user.username) (\(user.displayName ?? "no display name"))")
            }
            
            return users
            
        } catch {
            print("❌ Failed to search users for '\(query)': \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            return []
        }
    }
}
