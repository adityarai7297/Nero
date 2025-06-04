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
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authService)
                .environmentObject(themeManager)
                .onOpenURL { url in
                    // Handle OAuth callback for Google/Apple Sign-In
                    Task {
                        do {
                            try await supabase.auth.session(from: url)
                        } catch {
                            print("OAuth callback error: \(error)")
                        }
                    }
                }
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if authService.isLoading {
            LoadingView()
        } else if authService.user != nil {
            MainContentView()
        } else {
            AuthView()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Nero")
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
    
    var body: some View {
        ContentView()
            .environmentObject(authService)
            .environmentObject(themeManager)
    }
}
