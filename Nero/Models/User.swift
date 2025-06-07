import Foundation
import Supabase

struct User: Codable, Equatable {
    let id: UUID
    let email: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
    
    // Equatable conformance
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id && lhs.email == rhs.email
    }
}

@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        // Check if user is already logged in
        checkSession()
    }
    
    private func checkSession() {
        isLoading = true
        Task {
            do {
                let session = try await supabase.auth.session
                let authUser = session.user
                
                // For existing sessions, just ensure profile exists
                let profileExists = await UserProfileService.ensureUserProfileExists(for: authUser)
                if profileExists {
                    print("✅ Session restored for user: \(authUser.email ?? "unknown")")
                } else {
                    print("⚠️ Session restored but profile creation failed for: \(authUser.email ?? "unknown")")
                }
                
                await MainActor.run {
                    self.user = User(
                        id: authUser.id,
                        email: authUser.email ?? "",
                        createdAt: authUser.createdAt
                    )
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.user = nil
                    self.isLoading = false
                }
            }
        }
    }
    
    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔄 Creating new user account for: \(email)")
            let response = try await supabase.auth.signUp(email: email, password: password)
            let authUser = response.user
            
            // Wait a moment for trigger to execute
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Verify profile was created by trigger, create manually if needed
            let profileExists = await UserProfileService.verifyUserProfile(for: authUser)
            if !profileExists {
                print("🔧 Trigger didn't create profile, creating manually...")
                let manualCreation = await UserProfileService.createUserProfile(for: authUser)
                if !manualCreation {
                    print("❌ Failed to create user profile both automatically and manually")
                    // Don't fail the signup - user auth was successful
                }
            }
            
            await MainActor.run {
                self.user = User(
                    id: authUser.id,
                    email: authUser.email ?? "",
                    createdAt: authUser.createdAt
                )
                self.isLoading = false
            }
            
            print("✅ New user signup completed for: \(email)")
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Signup failed for \(email): \(error.localizedDescription)")
            return false
        }
    }
    
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔄 Signing in user: \(email)")
            let response = try await supabase.auth.signIn(email: email, password: password)
            let authUser = response.user
            
            // For sign-in, just ensure profile exists (shouldn't be needed for new users)
            let profileExists = await UserProfileService.ensureUserProfileExists(for: authUser)
            if profileExists {
                print("✅ Profile verified for existing user: \(email)")
            } else {
                print("⚠️ Profile issue detected for user: \(email)")
            }
            
            await MainActor.run {
                self.user = User(
                    id: authUser.id,
                    email: authUser.email ?? "",
                    createdAt: authUser.createdAt
                )
                self.isLoading = false
            }
            
            print("✅ Sign in completed for: \(email)")
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Sign in failed for \(email): \(error.localizedDescription)")
            return false
        }
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            await MainActor.run {
                self.user = nil
            }
            print("✅ User signed out successfully")
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            print("❌ Sign out failed: \(error.localizedDescription)")
        }
    }
    
    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔄 Initiating Google OAuth sign-in...")
            let response = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "com.yourapp.nero://login")
            )
            
            // OAuth sign-in will handle the redirect, so we return true here
            // The actual user will be set when the app receives the callback
            await MainActor.run {
                self.isLoading = false
            }
            print("✅ Google OAuth initiated successfully")
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Google OAuth failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func signInWithApple() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔄 Initiating Apple OAuth sign-in...")
            let response = try await supabase.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: URL(string: "com.yourapp.nero://login")
            )
            
            // OAuth sign-in will handle the redirect, so we return true here
            // The actual user will be set when the app receives the callback
            await MainActor.run {
                self.isLoading = false
            }
            print("✅ Apple OAuth initiated successfully")
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Apple OAuth failed: \(error.localizedDescription)")
            return false
        }
    }
} 