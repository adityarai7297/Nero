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

enum AuthError: LocalizedError, Equatable {
    case userExists
    case wrongCredentials
    case weakPassword
    case invalidEmail
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .userExists:
            return "Email already in use"
        case .wrongCredentials:
            return "Incorrect email or password"
        case .weakPassword:
            return "Password too weak"
        case .invalidEmail:
            return "Invalid email format"
        case .networkError:
            return "Network connection error"
        case .unknown(let message):
            return message
        }
    }
    
    var suggestions: [String] {
        switch self {
        case .userExists:
            return [
                "Try signing in instead",
                "Use a different email address",
                "Reset your password if you forgot it"
            ]
        case .wrongCredentials:
            return [
                "Double-check your email and password",
                "Try creating an account if you don't have one",
                "Use 'Forgot Password' if you can't remember"
            ]
        case .weakPassword:
            return [
                "Use at least 8 characters",
                "Include letters and numbers",
                "Add special characters for strength"
            ]
        case .invalidEmail:
            return [
                "Make sure to include @ in your email",
                "Check for typos in your email address"
            ]
        case .networkError:
            return [
                "Check your internet connection",
                "Try again in a moment"
            ]
        case .unknown:
            return [
                "Try again in a moment",
                "Contact support if the problem persists"
            ]
        }
    }
}

enum AuthPhase: Equatable {
    case idle
    case loading
    case success(User)
    case error(AuthError)
    
    static func == (lhs: AuthPhase, rhs: AuthPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.success(let user1), .success(let user2)):
            return user1 == user2
        case (.error(let error1), .error(let error2)):
            return error1 == error2
        default:
            return false
        }
    }
}

enum AuthErrorType {
    case invalidEmail
    case passwordTooShort
    case passwordTooWeak
    case invalidCredentials
    case userAlreadyExists
    case passwordError
    case emailError
    case networkError
}

@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var phase: AuthPhase = .idle
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firstLaunchKey = "hasLaunchedBefore"
    
    init() {
        // Check if this is a fresh installation
        checkForFreshInstall()
        // Check if user is already logged in
        checkSession()
    }
    
    private func checkForFreshInstall() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: firstLaunchKey)
        
        if !hasLaunchedBefore {
            // This is a fresh install - clear any persisted auth data
            print("🆕 Fresh app installation detected - clearing any persisted auth data")
            
            Task {
                do {
                    // Sign out to clear any stored sessions/tokens
                    try await supabase.auth.signOut()
                    print("✅ Cleared any persisted auth data for fresh install")
                } catch {
                    print("⚠️ Error clearing auth data on fresh install: \(error.localizedDescription)")
                }
            }
            
            // Mark that the app has been launched
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
        }
    }
    
    private func checkSession() {
        // Skip session check if this is a fresh install
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: firstLaunchKey)
        if !hasLaunchedBefore {
            phase = .idle
            return
        }
        
        phase = .loading
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
                
                let user = User(
                    id: authUser.id,
                    email: authUser.email ?? "",
                    createdAt: authUser.createdAt
                )
                
                await MainActor.run {
                    self.user = user
                    self.phase = .success(user)
                }
            } catch {
                await MainActor.run {
                    self.user = nil
                    self.phase = .idle
                }
            }
        }
    }
    
    func signUp(email: String, password: String) async {
        phase = .loading
        
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
            
            let user = User(
                id: authUser.id,
                email: authUser.email ?? "",
                createdAt: authUser.createdAt
            )
            
            await MainActor.run {
                self.user = user
                self.phase = .success(user)
            }
            
            print("✅ New user signup completed for: \(email)")
        } catch {
            let authError = parseError(error)
            await MainActor.run {
                self.phase = .error(authError)
            }
            print("❌ Signup failed for \(email): \(error.localizedDescription)")
        }
    }
    
    func signIn(email: String, password: String) async {
        print("🔐 AuthService.signIn() called for: \(email)")
        phase = .loading
        
        do {
            print("🔄 Signing in user: \(email)")
            let response = try await supabase.auth.signIn(email: email, password: password)
            let authUser = response.user
            print("🔐 AuthService: Supabase signIn successful for: \(email)")
            
            // For sign-in, just ensure profile exists (shouldn't be needed for new users)
            let profileExists = await UserProfileService.ensureUserProfileExists(for: authUser)
            if profileExists {
                print("✅ Profile verified for existing user: \(email)")
            } else {
                print("⚠️ Profile issue detected for user: \(email)")
            }
            
            let user = User(
                id: authUser.id,
                email: authUser.email ?? "",
                createdAt: authUser.createdAt
            )
            
            await MainActor.run {
                self.user = user
                self.phase = .success(user)
            }
            
            print("✅ Sign in completed for: \(email)")
        } catch {
            print("🚨 AuthService: signIn caught error: \(error)")
            let authError = parseError(error)
            await MainActor.run {
                self.phase = .error(authError)
            }
            print("❌ Sign in failed for \(email): \(error.localizedDescription)")
        }
    }
    
    private func parseError(_ error: Error) -> AuthError {
        let errorStr = error.localizedDescription.lowercased()
        
        if errorStr.contains("invalid login credentials") ||
           errorStr.contains("user not found") ||
           errorStr.contains("invalid email or password") {
            return .wrongCredentials
        } else if errorStr.contains("user already registered") ||
                  errorStr.contains("email address already exists") ||
                  errorStr.contains("user already exists") {
            return .userExists
        } else if errorStr.contains("password") && 
                  (errorStr.contains("weak") || errorStr.contains("strength") || errorStr.contains("short")) {
            return .weakPassword
        } else if errorStr.contains("email") {
            return .invalidEmail
        } else if errorStr.contains("network") || errorStr.contains("connection") {
            return .networkError
        } else {
            return .unknown(error.localizedDescription)
        }
    }
    
    func resetPhase() {
        phase = .idle
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            await MainActor.run {
                self.user = nil
                self.phase = .idle
            }
            print("✅ User signed out successfully")
        } catch {
            await MainActor.run {
                self.phase = .error(.networkError)
            }
            print("❌ Sign out failed: \(error.localizedDescription)")
        }
    }
    
    // Method to manually reset first launch (useful for testing)
    func resetFirstLaunch() {
        UserDefaults.standard.removeObject(forKey: firstLaunchKey)
        print("🔄 Reset first launch flag - next app launch will be treated as fresh install")
    }
    
    // Method to manually clear error message after UI has processed it
    func clearErrorMessage() {
        errorMessage = nil
        print("🧹 AuthService: Error message manually cleared")
    }
    
    // Method to validate credentials without full authentication
    // This allows UI to show errors before loading state changes
    func validateCredentials(email: String, password: String, isSignUp: Bool) async -> (isValid: Bool, errorType: AuthErrorType?) {
        print("🔍 AuthService.validateCredentials() called for: \(email), isSignUp: \(isSignUp)")
        
        // Basic validation first
        if email.isEmpty || !email.contains("@") {
            print("❌ Validation failed: Invalid email format")
            return (false, .invalidEmail)
        }
        
        if password.count < 6 {
            print("❌ Validation failed: Password too short")
            return (false, .passwordTooShort)
        }
        
        // For sign up, check password strength
        if isSignUp {
            if password.count < 8 {
                print("❌ Validation failed: Password too weak for signup")
                return (false, .passwordTooWeak)
            }
            print("✅ Validation passed for signup")
            return (true, nil)
        }
        
        // For sign in, we'll do basic validation here
        // The real credential check will happen during actual sign in
        // This just ensures we don't have obvious format issues
        print("✅ Basic validation passed for signin")
        return (true, nil)
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