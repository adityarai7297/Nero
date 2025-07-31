//
//  NeroApp.swift
//  Nero
//
//  Created by Aditya Rai on 5/19/25.
//

import SwiftUI

@main
struct NeroApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var preferencesService = WorkoutPreferencesService()
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authService)
                .environmentObject(themeManager)
                .environmentObject(preferencesService)
                .onOpenURL { url in
                    print("🚨 onOpenURL FIRED with URL: \(url)")
                    print("🔍 URL scheme: \(url.scheme ?? "no scheme")")
                    print("🔍 URL host: \(url.host ?? "no host")")
                    
                    // Handle OAuth callback for Google/Apple Sign-In
                    Task {
                        do {
                            let session = try await supabase.auth.session(from: url)
                            print("✅ OAuth session established successfully")
                            print("👤 User: \(session.user.email ?? "unknown")")
                            
                            // Force immediate navigation by directly setting user
                            let user = User(
                                id: session.user.id,
                                email: session.user.email ?? "",
                                createdAt: session.user.createdAt
                            )
                            
                            await MainActor.run {
                                print("📝 BEFORE: authService.user = \(authService.user?.email ?? "nil")")
                                print("📝 BEFORE: authService.phase = \(authService.phase)")
                                
                                authService.user = user
                                authService.phase = .success(user)
                                authService.isLoading = false
                                
                                print("📝 AFTER: authService.user = \(authService.user?.email ?? "nil")")
                                print("📝 AFTER: authService.phase = \(authService.phase)")
                                print("🚀 Force updated AuthService!")
                            }
                            
                        } catch {
                            print("❌ OAuth callback error: \(error)")
                        }
                    }
                }
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var preferencesService: WorkoutPreferencesService
    
    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView()
            } else if authService.user != nil {
                MainContentView()
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(.light) // Force light mode, override system default
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Cerro")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct MainContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var preferencesService: WorkoutPreferencesService
    
    var body: some View {
        ContentView()
            .environmentObject(authService)
            .environmentObject(themeManager)
            .environmentObject(preferencesService)
    }
}
