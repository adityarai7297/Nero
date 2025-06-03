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
            let response = try await supabase.auth.signUp(email: email, password: password)
            let authUser = response.user
            await MainActor.run {
                self.user = User(
                    id: authUser.id,
                    email: authUser.email ?? "",
                    createdAt: authUser.createdAt
                )
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await supabase.auth.signIn(email: email, password: password)
            let authUser = response.user
            await MainActor.run {
                self.user = User(
                    id: authUser.id,
                    email: authUser.email ?? "",
                    createdAt: authUser.createdAt
                )
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            await MainActor.run {
                self.user = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
} 