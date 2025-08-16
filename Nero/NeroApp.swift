//
//  NeroApp.swift
//  Nero
//
//  Created by Aditya Rai on 5/19/25.
//

import SwiftUI
import UIKit

// AppDelegate for orientation control
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct NeroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var preferencesService = WorkoutPreferencesService()
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    @StateObject private var appLifecycleManager = AppLifecycleManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authService)
                .environmentObject(themeManager)
                .environmentObject(preferencesService)
                .environmentObject(backgroundTaskManager)
                .environmentObject(appLifecycleManager)
                .onAppear {
                    // Recover any incomplete tasks on app startup
                    TaskRecoveryHelper.recoverIncompleteTasks()
                }
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
                                
                                // Load dark mode preference for OAuth user
                                Task {
                                    await themeManager.loadDarkModePreference(for: user.id)
                                }
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
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onAppear {
            print("📱 MainAppView onAppear - user: \(authService.user?.email ?? "nil"), hasLoadedPreference: \(themeManager.hasLoadedUserPreference)")
            
            // Load theme preferences for existing user on app start
            if let user = authService.user, !themeManager.hasLoadedUserPreference {
                print("🚀 Loading theme preferences on app start for user: \(user.email)")
                Task {
                    await themeManager.loadDarkModePreference(for: user.id)
                }
            }
        }
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
