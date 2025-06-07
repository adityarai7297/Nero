import Foundation
import Supabase
import Auth

struct UserProfile: Codable {
    let id: UUID
    let email: String
    let created_at: String
    let updated_at: String?
}

class UserProfileService: ObservableObject {
    
    /// Creates a user profile in public.users table (fallback if trigger fails)
    static func createUserProfile(for authUser: Auth.User) async -> Bool {
        do {
            let userProfile = UserProfile(
                id: authUser.id,
                email: authUser.email ?? "",
                created_at: Date().ISO8601String(),
                updated_at: nil
            )
            
            try await supabase
                .from("users")
                .insert(userProfile)
                .execute()
            
            print("✅ User profile created successfully for: \(authUser.email ?? "unknown")")
            return true
        } catch {
            print("❌ Failed to create user profile: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Ensures user profile exists - optimized for fresh start
    /// With the trigger function, this should rarely need to create profiles manually
    static func ensureUserProfileExists(for authUser: Auth.User) async -> Bool {
        do {
            // Try to fetch the user profile
            let _: UserProfile = try await supabase
                .from("users")
                .select("id, email, created_at, updated_at")
                .eq("id", value: authUser.id)
                .single()
                .execute()
                .value
            
            print("✅ User profile exists for: \(authUser.email ?? "unknown")")
            return true
        } catch {
            // Profile doesn't exist - this should be rare with the trigger
            print("⚠️ User profile not found (trigger may have failed), creating manually for: \(authUser.email ?? "unknown")")
            return await createUserProfile(for: authUser)
        }
    }
    
    /// Verifies the user profile was created properly (useful for testing)
    static func verifyUserProfile(for authUser: Auth.User) async -> Bool {
        do {
            let profile: UserProfile = try await supabase
                .from("users")
                .select("id, email, created_at, updated_at")
                .eq("id", value: authUser.id)
                .single()
                .execute()
                .value
            
            print("✅ Profile verified - ID: \(profile.id), Email: \(profile.email)")
            return true
        } catch {
            print("❌ Profile verification failed: \(error.localizedDescription)")
            return false
        }
    }
} 