//
//  ContentView.swift
//  Nero
//
//  Created by Aditya Rai on 5/19/25.
//

import Supabase
import SwiftUI
import UIKit

// Next-Set Recommendations Algorithm
struct NextSetRecommendations {
    let weightOptions: [Int]
    let repOptions: [Int] 
    let rpeOptions: [Double]
    
    static func calculate(from lastSet: WorkoutSet) -> NextSetRecommendations {
        let weight = Double(lastSet.weight)
        let reps = Int(lastSet.reps)
        let rpe = Double(lastSet.rpe) // RPE is in percentage form (e.g. 75)
        
        return calculate(weight: weight, reps: reps, rpe: rpe)
    }
    
    static func calculate(weight: Double, reps: Int, rpe: Double) -> NextSetRecommendations {
        // Weight recommendations: -20, -10, +10, +20
        let weightDeltas = [-20, -10, 10, 20]
        let weightOptions = weightDeltas.compactMap { delta -> Int? in
            let newWeight = weight + Double(delta)
            return newWeight > 0 ? Int(newWeight) : nil // Ensure positive weight
        }
        
        // Reps recommendations: -2, +2 from last rep count
        let repDeltas = [-2, 2]
        let repOptions = repDeltas.compactMap { delta -> Int? in
            let newReps = reps + delta
            return newReps > 0 ? newReps : nil // Ensure at least 1 rep
        }
        
        // RPE recommendations: -10, +10 from last RPE (in percentage form)
        let rpeDeltas = [-10.0, 10.0]
        let rpeOptions = rpeDeltas.compactMap { delta -> Double? in
            let newRPE = rpe + delta
            if newRPE >= 50.0 && newRPE <= 100.0 { // Keep within 50-100% range
                return newRPE
            }
            return nil
        }
        
        return NextSetRecommendations(
            weightOptions: weightOptions,
            repOptions: repOptions,
            rpeOptions: rpeOptions
        )
    }
}

// Individual set model with all the details
struct WorkoutSet: Identifiable, Equatable {
    let id = UUID()
    var databaseId: Int? // Track the Supabase database ID
    var exerciseName: String
    var weight: CGFloat
    var reps: CGFloat
    var rpe: CGFloat
    var timestamp: Date
    var exerciseType: String? // Optional field for exercise type ("static_hold" for timed exercises)
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // Equatable conformance
    static func == (lhs: WorkoutSet, rhs: WorkoutSet) -> Bool {
        return lhs.id == rhs.id &&
               lhs.databaseId == rhs.databaseId &&
               lhs.exerciseName == rhs.exerciseName &&
               lhs.weight == rhs.weight &&
               lhs.reps == rhs.reps &&
               lhs.rpe == rhs.rpe &&
               lhs.timestamp == rhs.timestamp &&
               lhs.exerciseType == rhs.exerciseType
    }
}

// Exercise model with name and default preferences
struct Exercise: Equatable {
    let name: String
    let defaultWeight: CGFloat
    let defaultReps: CGFloat
    let defaultRPE: CGFloat
    var setsCompleted: Int = 0
    let exerciseType: String? // Optional field for exercise type ("static_hold" for timed exercises)
    
    static let allExercises: [Exercise] = [
        Exercise(name: "Bench Press", defaultWeight: 50, defaultReps: 8, defaultRPE: 60, exerciseType: nil),
        Exercise(name: "Squat", defaultWeight: 80, defaultReps: 10, defaultRPE: 70, exerciseType: nil),
        Exercise(name: "Deadlift", defaultWeight: 100, defaultReps: 6, defaultRPE: 80, exerciseType: nil),
        Exercise(name: "Overhead Press", defaultWeight: 35, defaultReps: 8, defaultRPE: 65, exerciseType: nil),
        Exercise(name: "Pull-ups", defaultWeight: 0, defaultReps: 12, defaultRPE: 70, exerciseType: nil),
        Exercise(name: "Barbell Row", defaultWeight: 60, defaultReps: 10, defaultRPE: 75, exerciseType: nil),
        Exercise(name: "Incline Bench", defaultWeight: 40, defaultReps: 8, defaultRPE: 65, exerciseType: nil),
        Exercise(name: "Dips", defaultWeight: 0, defaultReps: 15, defaultRPE: 70, exerciseType: nil),
        Exercise(name: "Romanian Deadlift", defaultWeight: 70, defaultReps: 12, defaultRPE: 70, exerciseType: nil),
        Exercise(name: "Leg Press", defaultWeight: 120, defaultReps: 15, defaultRPE: 75, exerciseType: nil)
    ]
}

// MARK: - Exercise History Models

enum ExerciseHistoryTimeframe: String, CaseIterable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"
    
    var displayName: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        case .all: return "All Time"
        }
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .all:
            return Date.distantPast
        }
    }
}

enum ExerciseChartType: String, CaseIterable {
    case volume = "Volume"
    case weight = "Weight"
    
    var displayName: String {
        return self.rawValue
    }
    
    var unit: String {
        switch self {
        case .volume: return "Volume (lbs × reps)"
        case .weight: return "Weight (lbs)"
        }
    }
}

struct ExerciseStats {
    let exerciseName: String
    let totalSets: Int
    let maxWeight: Double
    let maxVolume: Double
    let averageWeight: Double
    let averageVolume: Double
    let firstWorkout: Date?
    let lastWorkout: Date?
}

// Simple ThemeManager for the WheelPicker
class ThemeManager: ObservableObject {
    @Published var wheelPickerColor: Color = .black.opacity(0.7)
    @Published var isDarkMode: Bool = false
    
    func updateForDarkMode(_ enabled: Bool) {
        isDarkMode = enabled
        wheelPickerColor = enabled ? .white.opacity(0.7) : .black.opacity(0.7)
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var preferencesService: WorkoutPreferencesService
    @StateObject private var workoutService = WorkoutService()
    
    var body: some View {
        ExerciseView(workoutService: workoutService)
            .environmentObject(authService)
            .environmentObject(themeManager)
            .environmentObject(preferencesService)
    }
}

struct ExerciseView: View {
    let workoutService: WorkoutService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var preferencesService: WorkoutPreferencesService
    @State private var currentExerciseIndex: Int = 0
    @State private var weights: [CGFloat] = [50, 8, 60] // Will be updated based on current exercise
    @StateObject private var themeManager = ThemeManager()
    @State private var showRadialBurst: Bool = false
    @State private var showingSetsModal: Bool = false // Control modal presentation
    @State private var showingLogoutAlert: Bool = false
    @State private var showingDeleteAccountAlert: Bool = false // Control delete account confirmation presentation
    @State private var showingDeleteAccountSuccess: Bool = false // Control delete account success screen presentation
    @State private var showingSideMenu: Bool = false // Control side menu presentation
    @State private var showingWorkoutQuestionnaire: Bool = false // Control workout questionnaire presentation
    @State private var showingPersonalDetails: Bool = false // Control personal details presentation
    @State private var showingWorkoutPlan: Bool = false // Control workout plan view presentation
    @State private var showingWorkoutEditChat: Bool = false // Control workout edit chat presentation
    @State private var showingExerciseHistory: Bool = false // Control exercise history view presentation
    @State private var showingAIChat: Bool = false // Control AI chat view presentation
    @State private var showingMacroChat: Bool = false // Macro chat
    @State private var showingMacroHistory: Bool = false // Macro history
    @State private var menuDarkModeEnabled: Bool = false // Dark mode switch state for menu UI only
    
    // Target completion state
    @State private var showTargetCompletion: Bool = false

    // Dynamic recommendation state
    @State private var currentRecommendations: NextSetRecommendations = NextSetRecommendations(
        weightOptions: [123, 135, 145, 155], // 4 options
        repOptions: [8, 12], // 2 options
        rpeOptions: [60.0, 80.0] // 2 options
    )
    
    // Haptic feedback generators
    private let setButtonFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let navigationFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private var currentExercise: Exercise {
        guard !workoutService.exercises.isEmpty else {
            return Exercise(name: "Loading...", defaultWeight: 0, defaultReps: 0, defaultRPE: 0, exerciseType: nil)
        }
        
        // Ensure currentExerciseIndex is within bounds
        let safeIndex = min(max(currentExerciseIndex, 0), workoutService.exercises.count - 1)
        if safeIndex != currentExerciseIndex {
            // Update currentExerciseIndex to the safe value
            DispatchQueue.main.async {
                currentExerciseIndex = safeIndex
            }
        }
        
        return workoutService.exercises[safeIndex]
    }
    
    var body: some View {
        ZStack {
            (menuDarkModeEnabled ? Color.black : Color.offWhite).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Debug the state
                let _ = print("🎯 UI State - hasWorkoutPlan: \(workoutService.hasWorkoutPlan), exercises.count: \(workoutService.exercises.count), isLoading: \(workoutService.isLoading)")
                
                if workoutService.hasWorkoutPlan && !workoutService.exercises.isEmpty {
                    // Show normal workout interface
                    let _ = print("✅ UI: Showing workout interface with \(workoutService.exercises.count) exercises")
                    MainExerciseContentView()
                } else if !workoutService.hasWorkoutPlan && !workoutService.isLoading {
                    // Show create workout plan message
                    let _ = print("⚠️ UI: Showing create workout plan view")
                    CreateWorkoutPlanView()
                } else if workoutService.isLoading {
                    // Show loading state
                    let _ = print("🔄 UI: Showing loading view")
                    LoadingView()
                } else {
                    // Fallback - should not normally reach here
                    let _ = print("❌ UI: Showing empty state view (fallback)")
                    EmptyStateView()
                }
            }
            
            // Side Menu Overlay
            if showingSideMenu {
                SideMenuView()
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .overlay(RadialBurstOverlay())
        .sheet(isPresented: $showingSetsModal) {
            SetsModalView(
                allSets: workoutService.todaySets,
                workoutService: workoutService
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingWorkoutQuestionnaire) {
            WorkoutQuestionnaireView() {
                // Show side menu after completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu = true
                    }
                }
            }
            .onDisappear {
                // Reload workout plan when questionnaire is dismissed
                if let userId = authService.user?.id {
                    workoutService.setUser(userId)
                }
            }
        }
        .sheet(isPresented: $showingPersonalDetails) {
            PersonalDetailsView()
        }
        .sheet(isPresented: $showingWorkoutPlan) {
            WorkoutPlanView(
                onExerciseSelected: { exerciseName in
                    // Find the exercise index and navigate to it
                    if let index = workoutService.exercises.firstIndex(where: { $0.name == exerciseName }) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentExerciseIndex = index
                            loadExerciseData()
                        }
                    }
                    // Dismiss the workout plan sheet
                    showingWorkoutPlan = false
                },
                workoutService: workoutService
            )
                .environmentObject(preferencesService)
        }
        .sheet(isPresented: $showingWorkoutEditChat) {
            WorkoutEditChatView(workoutService: workoutService)
                .environmentObject(preferencesService)
        }
        .sheet(isPresented: $showingExerciseHistory) {
            ExerciseHistoryListView(workoutService: workoutService)
        }
        .sheet(isPresented: $showingAIChat) {
            AIChatView(workoutService: workoutService)
        }
        .sheet(isPresented: $showingMacroChat) {
            MacroChatView(userId: authService.user?.id)
        }
        .sheet(isPresented: $showingMacroHistory) {
            MacroHistoryView(userId: authService.user?.id)
        }
        .alert("Error", isPresented: .constant(workoutService.errorMessage != nil)) {
            Button("OK") { workoutService.errorMessage = nil }
        } message: {
            if let errorMessage = workoutService.errorMessage {
                Text(errorMessage)
            }
        }
        // Custom glass-style sign-out confirmation overlay replaces the default alert
        .overlay {
            if showingLogoutAlert {
                SignOutGlassPopup(
                    confirmAction: {
                        Task {
                            await authService.signOut()
                        }
                        // Dismiss popup
                        showingLogoutAlert = false
                    },
                    cancelAction: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingLogoutAlert = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .zIndex(1000)
            }
        }
        // Custom delete account confirmation overlay
        .overlay {
            if showingDeleteAccountAlert {
                DeleteAccountConfirmationView(
                    userEmail: authService.user?.email ?? "",
                    confirmAction: {
                        Task {
                            let success = await authService.deleteAccount()
                            await MainActor.run {
                                showingDeleteAccountAlert = false
                                if success {
                                    // Show success screen
                                    showingDeleteAccountSuccess = true
                                } else {
                                    // Error handling is done in AuthService
                                    // Could add additional UI feedback here if needed
                                }
                            }
                        }
                    },
                    cancelAction: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingDeleteAccountAlert = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .zIndex(1001)
            }
        }
        // Account deletion success screen
        .overlay {
            if showingDeleteAccountSuccess {
                AccountDeletionSuccessView {
                    // Complete the cleanup and sign out after showing success
                    Task {
                        await authService.completeAccountDeletionCleanup()
                        await MainActor.run {
                            showingDeleteAccountSuccess = false
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale))
                .zIndex(1002)
            }
        }
        .onChange(of: workoutService.todaySets) { oldSets, newSets in
            updateRecommendationsForCurrentExercise()
            // Check for target completion when sets data changes
            checkForTargetCompletion()
        }
        .onChange(of: workoutService.exercises) { oldExercises, newExercises in
            // Reset currentExerciseIndex if it's out of bounds
            if !newExercises.isEmpty && currentExerciseIndex >= newExercises.count {
                currentExerciseIndex = 0
                print("🔄 ContentView: Reset currentExerciseIndex to 0 due to exercises array change")
            }
            
            // Check for target completion when exercises data changes
            if !newExercises.isEmpty {
                checkForTargetCompletion()
                // Reload exercise data for the current (potentially new) exercise
                loadExerciseData()
                updateRecommendationsForCurrentExercise()
            }
        }
        .onChange(of: authService.user) { _, newUser in
            // Initialize workout service when user changes
            workoutService.setUser(newUser?.id)
            if newUser != nil {
                loadExerciseData()
                updateRecommendationsForCurrentExercise()
            }
        }
        .onAppear {
            // Initialize workout service on appear
            setButtonFeedback.prepare()
            navigationFeedback.prepare()
            workoutService.setUser(authService.user?.id)
            if authService.user != nil {
                loadExerciseData()
                updateRecommendationsForCurrentExercise()
            }
        }
        .onChange(of: menuDarkModeEnabled) { oldValue, newValue in
            themeManager.updateForDarkMode(newValue)
        }
        .onTapGesture {
            // Close side menu when tapping outside
            if showingSideMenu {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSideMenu = false
                }
            }
        }
    }
    
    // MARK: - Component Views
    
    @ViewBuilder
    private func CreateWorkoutPlanView() -> some View {
        VStack(spacing: 32) {
            // Header with menu button
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentBlue.opacity(0.8))
                }
                .frame(width: 44, height: 44)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            
            Spacer()
            
            // Main content
            VStack(spacing: 24) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(spacing: 16) {
                    Text("Create a Workout Plan")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Complete the workout questionnaire to see your personalized exercises")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button(action: {
                    showingWorkoutQuestionnaire = true
                }) {
                    Text("Create Workout Plan")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentBlue)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func LoadingView() -> some View {
        VStack(spacing: 20) {
            // Header with menu button
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentBlue.opacity(0.8))
                }
                .frame(width: 44, height: 44)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            
            Spacer()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("Loading your workout plan...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func EmptyStateView() -> some View {
        VStack(spacing: 20) {
            // Header with menu button
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentBlue.opacity(0.8))
                }
                .frame(width: 44, height: 44)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please try again or contact support")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func ExerciseTitleView() -> some View {
        VStack {
            HStack {
                // Center the exercise name
                Spacer()
                
                Text(currentExercise.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(menuDarkModeEnabled ? .white : .black)
                    .shadow(color: menuDarkModeEnabled ? .black.opacity(0.8) : .white.opacity(0.8), radius: 1, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.3), value: currentExercise.name)
                
                Spacer()
            }
            .padding(.top, 15)
            .padding(.bottom, 5)
            .padding(.horizontal, 20)
            .overlay(alignment: .leading) {
                // Modern menu icon positioned on the left
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentBlue.opacity(0.8))
                }
                .frame(width: 44, height: 44)
                .padding(.leading, 20)
            }
            .overlay(alignment: .trailing) {
                // Counter button in top right corner
                if currentExercise.setsCompleted > 0 {
                    SetCounterButton()
                        .padding(.trailing, 20)
                }
            }
        }
    }
    
    @ViewBuilder
    private func SetCounterButton() -> some View {
        Button(action: {
            showingSetsModal = true
        }) {
            HStack(spacing: 6) {
                Text("\(currentExercise.setsCompleted)")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(Color.green.opacity(0.8))
                    .lineLimit(1)
                
                // Only show checkmark for exercises scheduled today that have reached their target
                if showTargetCompletion && 
                   (workoutService.getTargetSetsForToday(exerciseName: currentExercise.name) ?? 0) > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 16, height: 16)
                        
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: showTargetCompletion && (workoutService.getTargetSetsForToday(exerciseName: currentExercise.name) ?? 0) > 0 ? 80 : 44, height: 44)
        .animation(.bouncy(duration: 0.4), value: showTargetCompletion)
    }
    
    @ViewBuilder
    private func ExerciseComponentsView() -> some View {
        VStack(spacing: 32) {
            ExerciseComponent(
                value: $weights[0], 
                type: .weight, 
                recommendations: currentRecommendations,
                exerciseType: currentExercise.exerciseType,
                isDarkMode: menuDarkModeEnabled
            )
                .environmentObject(themeManager)
            ExerciseComponent(
                value: $weights[1], 
                type: .repetitions, 
                recommendations: currentRecommendations,
                exerciseType: currentExercise.exerciseType,
                isDarkMode: menuDarkModeEnabled
            )
                .environmentObject(themeManager)
            ExerciseComponent(
                value: $weights[2], 
                type: .rpe, 
                recommendations: currentRecommendations,
                exerciseType: currentExercise.exerciseType,
                isDarkMode: menuDarkModeEnabled
            )
                .environmentObject(themeManager)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func NavigationButtonsView() -> some View {
        HStack(spacing: 40) {
            LeftNavigationButton()
            SetButton()
            RightNavigationButton()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 25)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private func LeftNavigationButton() -> some View {
        Button(action: {
            saveCurrentExerciseData()
            navigationFeedback.impactOccurred()
            withAnimation(.easeInOut(duration: 0.3)) {
                currentExerciseIndex = (currentExerciseIndex - 1 + workoutService.exercises.count) % workoutService.exercises.count
                loadExerciseData()
            }
        }) {
            Image(systemName: "chevron.left")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.accentBlue.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(menuDarkModeEnabled ? Color.white.opacity(0.12) : Color.accentBlue.opacity(0.06))
                        .overlay(
                            Circle()
                                .stroke(menuDarkModeEnabled ? Color.white.opacity(0.25) : Color.accentBlue.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    private func SetButton() -> some View {
        Button(action: {
            handleSetButtonTap()
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.85))
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.4), lineWidth: 2)
                        )
                )
        }
    }
    
    @ViewBuilder
    private func RightNavigationButton() -> some View {
        Button(action: {
            saveCurrentExerciseData()
            navigationFeedback.impactOccurred()
            withAnimation(.easeInOut(duration: 0.3)) {
                currentExerciseIndex = (currentExerciseIndex + 1) % workoutService.exercises.count
                loadExerciseData()
            }
        }) {
            Image(systemName: "chevron.right")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.accentBlue.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(menuDarkModeEnabled ? Color.white.opacity(0.12) : Color.accentBlue.opacity(0.06))
                        .overlay(
                            Circle()
                                .stroke(menuDarkModeEnabled ? Color.white.opacity(0.25) : Color.accentBlue.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    private func RadialBurstOverlay() -> some View {
        Group {
            if showRadialBurst {
                RoundedRectangle(cornerRadius: 40)
                    .stroke(
                        Color.green,
                        lineWidth: showRadialBurst ? 8 : 2
                    )
                    .blur(radius: 8)
                    .opacity(showRadialBurst ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.15), value: showRadialBurst)
                    .allowsHitTesting(false)
                    .zIndex(999)
                    .ignoresSafeArea(.all)
            }
        }
    }
    
    // Save current exercise data when switching exercises
    private func saveCurrentExerciseData() {
        // The weights array is automatically maintained through bindings
        // Set counts are already saved in the exercises array
    }
    
    // Load exercise data when switching to a new exercise
    private func loadExerciseData() {
        let exercise = currentExercise
        
        // Check if there's a latest set for this exercise and use those values
        let exerciseName = exercise.name
        let latestSet = workoutService.todaySets
            .filter { $0.exerciseName == exerciseName }
            .sorted { $0.timestamp > $1.timestamp }
            .first
        
        if let latestSet = latestSet {
            // Use the latest set values to maintain continuity
            weights = [latestSet.weight, latestSet.reps, latestSet.rpe]
        } else {
            // No sets yet for this exercise, use default values
            weights = [exercise.defaultWeight, exercise.defaultReps, exercise.defaultRPE]
        }
        
        // Check if current exercise has already reached target sets
        checkForTargetCompletion()
        
        // Update recommendations based on the latest set for this exercise
        updateRecommendationsForCurrentExercise()
    }
    
    // Update recommendations based on the latest set for the current exercise
    private func updateRecommendationsForCurrentExercise() {
        let exerciseName = currentExercise.name
        let latestSet = workoutService.todaySets
            .filter { $0.exerciseName == exerciseName }
            .sorted { $0.timestamp > $1.timestamp }
            .first
        
        if let latestSet = latestSet {
            // Use the latest set to calculate recommendations
            currentRecommendations = NextSetRecommendations.calculate(from: latestSet)
        } else {
            // No sets yet, use default recommendations
            currentRecommendations = NextSetRecommendations(
                weightOptions: [123, 135, 145, 155], // 4 options
                repOptions: [8, 12], // 2 options
                rpeOptions: [60.0, 80.0] // 2 options
            )
        }
    }
    
    // Update recommendations after logging a new set
    private func updateRecommendationsAfterSet() {
        // Create a temporary set with current values to calculate recommendations
        let tempSet = WorkoutSet(
            exerciseName: currentExercise.name,
            weight: weights[0],
            reps: weights[1], 
            rpe: weights[2],
            timestamp: Date(),
            exerciseType: currentExercise.exerciseType
        )
        
        currentRecommendations = NextSetRecommendations.calculate(from: tempSet)
    }
    
    private func handleSetButtonTap() {
        // Create a new set with current values
        let newSet = WorkoutSet(
            databaseId: nil, // New set, will be set by the service
            exerciseName: currentExercise.name,
            weight: weights[0],
            reps: weights[1],
            rpe: weights[2],
            timestamp: Date(),
            exerciseType: currentExercise.exerciseType
        )
        
        print("SET pressed for \(currentExercise.name) with weights: \(weights)")
        
        // Save to Supabase
        Task {
            let success = await workoutService.saveWorkoutSet(newSet)
            if success {
                await handleSuccessfulSetSave()
            }
        }
    }
    
    private func handleSuccessfulSetSave() async {
        await MainActor.run {
            // Haptic feedback
            setButtonFeedback.impactOccurred()
            
            // Update recommendations immediately after successful save
            updateRecommendationsAfterSet()
            
            // Check if we've reached the target sets for today
            checkForTargetCompletionWithAnimation()
            
            // Show radial burst effect
            withAnimation(.easeOut(duration: 0.15)) {
                showRadialBurst = true
            }
            
            // Hide burst after short delay for quick pulse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showRadialBurst = false
                }
            }
        }
    }
    
    private func checkForTargetCompletion() {
        let exerciseName = currentExercise.name
        let completedSets = currentExercise.setsCompleted
        
        if let targetSets = workoutService.getTargetSetsForToday(exerciseName: exerciseName),
           targetSets > 0,  // Only show completion for exercises actually scheduled today
           completedSets >= targetSets {
            
            // Show checkmark (but don't animate if we're just switching exercises)
            if !showTargetCompletion {
                showTargetCompletion = true
            }
        } else {
            showTargetCompletion = false
        }
    }
    
    private func checkForTargetCompletionWithAnimation() {
        let exerciseName = currentExercise.name
        let completedSets = currentExercise.setsCompleted
        
        if let targetSets = workoutService.getTargetSetsForToday(exerciseName: exerciseName),
           targetSets > 0,  // Only show completion for exercises actually scheduled today
           completedSets >= targetSets && !showTargetCompletion {
            
            // Show checkmark with bouncy animation
            showCheckmarkAnimation()
        }
    }
    
    private func showCheckmarkAnimation() {
        // Haptic feedback for target achievement
        let achievementFeedback = UINotificationFeedbackGenerator()
        achievementFeedback.notificationOccurred(.success)
        
        // Show checkmark with bouncy animation
        withAnimation(.bouncy(duration: 0.6)) {
            showTargetCompletion = true
        }
    }
    
    @ViewBuilder
    private func SideMenuView() -> some View {
        ZStack {
            // Blur background overlay - dynamic based on dark mode
            (menuDarkModeEnabled ? Color.black.opacity(0.8) : Color.white.opacity(0.1))
                .ignoresSafeArea()
                .background(menuDarkModeEnabled ? AnyShapeStyle(Color.black.opacity(0.9)) : AnyShapeStyle(Material.ultraThinMaterial))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu = false
                    }
                }
            
            // Centered menu content with grid layout
            VStack(spacing: 16) {
                Spacer()
                
                // Grid of menu tiles
                VStack(spacing: 16) {
                    // Grid of menu tiles
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        // Workout Plan Generation Status Indicator or View Plan Button
                        if preferencesService.generationStatus.isActive {
                            // Show status indicator while generating
                            WorkoutPlanStatusTile(
                                status: preferencesService.generationStatus,
                                isDarkMode: menuDarkModeEnabled
                            )
                        } else if preferencesService.generationStatus == .completed || workoutService.hasWorkoutPlan {
                            // Show "View Workout Plan" button when completed or plan exists
                            NeumorphicMenuTile(
                                title: "View Plan",
                                icon: "doc.text.fill",
                                color: Color.green,
                                isDarkMode: menuDarkModeEnabled
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingSideMenu = false
                                }
                                // Small delay to let menu close animation finish
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingWorkoutPlan = true
                                }
                            }
                        }
                        
                        // Edit Workout Plan button (only show if user has a workout plan)
                        if workoutService.hasWorkoutPlan {
                            NeumorphicMenuTile(
                                title: "Edit Plan",
                                icon: "bubble.left.and.bubble.right.fill",
                                color: Color.mint,
                                isDarkMode: menuDarkModeEnabled
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingSideMenu = false
                                }
                                // Small delay to let menu close animation finish
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingWorkoutEditChat = true
                                }
                            }
                        }
                        
                        // Create Workout Plan button
                        NeumorphicMenuTile(
                            title: "Create Plan",
                            icon: "dumbbell.fill",
                            color: Color.accentBlue,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            // Small delay to let menu close animation finish
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingWorkoutQuestionnaire = true
                            }
                        }
                        
                        // Personal Details button
                        NeumorphicMenuTile(
                            title: "Personal",
                            icon: "person.fill",
                            color: Color.accentBlue,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            // Small delay to let menu close animation finish
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingPersonalDetails = true
                            }
                        }
                        

                        
                        // Exercise History button
                        NeumorphicMenuTile(
                            title: "History",
                            icon: "chart.xyaxis.line",
                            color: Color.blue,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            // Small delay to let menu close animation finish
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingExerciseHistory = true
                            }
                        }
                        
                        // AI Chat button
                        NeumorphicMenuTile(
                            title: "AI Chat",
                            icon: "bubble.left.and.bubble.right.fill",
                            color: Color.mint,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            // Small delay to let menu close animation finish
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingAIChat = true
                            }
                        }
                        
                        // Macro Tracker button
                        NeumorphicMenuTile(
                            title: "Macro Tracker",
                            icon: "fork.knife",
                            color: Color.orange,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingMacroChat = true
                            }
                        }
                        
                        // Macro History button
                        NeumorphicMenuTile(
                            title: "Macro History",
                            icon: "chart.pie.fill",
                            color: Color.orange,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingMacroHistory = true
                            }
                        }
                        
                        // Sign Out button
                        NeumorphicMenuTile(
                            title: "Sign Out",
                            icon: "power",
                            color: .red,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            // Small delay to let menu close animation finish
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingLogoutAlert = true
                            }
                        }
                        
                        // Delete Account button
                        NeumorphicMenuTile(
                            title: "Delete Account",
                            icon: "trash.fill",
                            color: .red,
                            isDarkMode: menuDarkModeEnabled
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSideMenu = false
                            }
                            // Small delay to let menu close animation finish
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingDeleteAccountAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Image(systemName: menuDarkModeEnabled ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(menuDarkModeEnabled ? .yellow : .orange)
                Toggle("", isOn: $menuDarkModeEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(menuDarkModeEnabled ? AnyShapeStyle(Color.white.opacity(0.2)) : AnyShapeStyle(Material.ultraThinMaterial), in: Capsule())
            .padding(.trailing, 16)
            .padding(.top, 16)
        }
    }
    

    
    @ViewBuilder
    private func MainExerciseContentView() -> some View {
        VStack(spacing: 12) {
            ExerciseTitleView()
            ExerciseComponentsView()
            NavigationButtonsView()
        }
        .padding(.horizontal, 0)
    }
}

// Modal view to show all sets for the day
struct SetsModalView: View {
    let allSets: [WorkoutSet]
    let workoutService: WorkoutService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var editingSet: WorkoutSet?
    @State private var showingEditSheet = false
    @State private var deletingSetIds: Set<UUID> = [] // Track sets being deleted
    
    var body: some View {
        NavigationView {
            VStack {
                if allSets.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No sets completed today")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("Complete a set to see it here")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // List of sets
                    List {
                        ForEach(allSets.sorted(by: { $0.timestamp > $1.timestamp })) { set in
                            SetRowView(
                                set: set,
                                isDeleting: deletingSetIds.contains(set.id),
                                onEdit: {
                                    editingSet = set
                                    showingEditSheet = true
                                },
                                onDelete: {
                                    deleteSet(set)
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Today's Sets")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let editingSet = editingSet {
                EditSetView(
                    set: editingSet,
                    workoutService: workoutService,
                    onSave: { updatedSet in
                        updateSet(updatedSet)
                        showingEditSheet = false
                    },
                    onCancel: {
                        showingEditSheet = false
                    }
                )
                .environmentObject(themeManager)
            }
        }
    }
    
    private func deleteSet(_ set: WorkoutSet) {
        // Add visual feedback immediately
        withAnimation(.easeInOut(duration: 0.3)) {
            deletingSetIds.insert(set.id)
        }
        
        Task {
            let success = await workoutService.deleteWorkoutSet(set)
            
            // Always remove from deletingSetIds after operation completes
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    deletingSetIds.remove(set.id)
                }
            }
            
            if !success {
                // Error handling is done in the service
                // Could add additional UI feedback here if needed
            }
        }
    }
    
    private func updateSet(_ updatedSet: WorkoutSet) {
        Task {
            let success = await workoutService.updateWorkoutSet(updatedSet)
            if !success {
                // Error handling is done in the service
            }
        }
    }
}

// Individual set row view
struct SetRowView: View {
    let set: WorkoutSet
    let isDeleting: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(set.exerciseName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(isDeleting ? .gray : .primary)
                    
                    Text(set.formattedTime)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("\(Int(set.weight))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isDeleting ? .gray : .primary)
                        Text("lbs")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(Int(set.reps))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isDeleting ? .gray : .primary)
                        Text(set.exerciseType == "static_hold" ? "seconds" : "reps")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(Int(set.rpe))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isDeleting ? .gray : .primary)
                        Text("% RPE")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    onEdit()
                }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(Color.accentBlue)
                        .frame(width: 32, height: 32)
                        .background(Color.accentBlue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDeleting)
                .opacity(isDeleting ? 0.3 : 1.0)
                
                Button(action: {
                    onDelete()
                }) {
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDeleting)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(isDeleting ? 0.6 : 1.0)
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isDeleting)
    }
}

// Edit set view
struct EditSetView: View {
    let set: WorkoutSet
    let workoutService: WorkoutService
    let onSave: (WorkoutSet) -> Void
    let onCancel: () -> Void
    
    @State private var weightText: String
    @State private var repsText: String
    @State private var rpeText: String
    
    init(set: WorkoutSet, workoutService: WorkoutService, onSave: @escaping (WorkoutSet) -> Void, onCancel: @escaping () -> Void) {
        self.set = set
        self.workoutService = workoutService
        self.onSave = onSave
        self.onCancel = onCancel
        self._weightText = State(initialValue: "\(Int(set.weight))")
        self._repsText = State(initialValue: "\(Int(set.reps))")
        self._rpeText = State(initialValue: "\(Int(set.rpe))")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(set.exerciseName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)
                }
                
                Section("Set Details") {
                    HStack {
                        Text("Weight")
                            .frame(width: 60, alignment: .leading)
                        TextField("Weight", text: $weightText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("lbs")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Reps")
                            .frame(width: 60, alignment: .leading)
                        TextField("Reps", text: $repsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text(set.exerciseType == "static_hold" ? "seconds" : "reps")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("RPE")
                            .frame(width: 60, alignment: .leading)
                        TextField("RPE", text: $rpeText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("% RPE")
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    HStack {
                        Text("Time")
                            .frame(width: 60, alignment: .leading)
                        Text(set.formattedTime)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidInput)
                }
            }
        }
    }
    
    private var isValidInput: Bool {
        guard let weight = Double(weightText), weight > 0,
              let reps = Double(repsText), reps > 0,
              let rpe = Double(rpeText), rpe >= 0, rpe <= 100 else {
            return false
        }
        return true
    }
    
    private func saveChanges() {
        guard let weight = Double(weightText),
              let reps = Double(repsText),
              let rpe = Double(rpeText) else {
            return
        }
        
        var updatedSet = set
        updatedSet.weight = CGFloat(weight)
        updatedSet.reps = CGFloat(reps)
        updatedSet.rpe = CGFloat(rpe)
        onSave(updatedSet)
    }
}

enum ExerciseComponentType {
    case weight
    case repetitions
    case rpe
    
    func label(exerciseType: String? = nil) -> String {
        switch self {
        case .weight: return "lbs"
        case .repetitions: 
            return exerciseType == "static_hold" ? "seconds" : "reps"
        case .rpe: return "% RPE"
        }
    }
    
    var wheelConfig: WheelPicker.Config {
        switch self {
        case .weight:
            return WheelPicker.Config(
                count: 200, // 0 to 2000 lbs (200 intervals of 10)
                steps: 10,   // 10 small ticks between major ticks
                spacing: 8,
                multiplier: 10, // Each major tick represents 10 lbs
                showsText: true
            )
        case .repetitions:
            return WheelPicker.Config(
                count: 100,  // 0 to 100 reps
                steps: 1,    // Single increments
                spacing: 35, // Same spacing as RPE scale
                multiplier: 1, // Each tick represents 1 rep
                showsText: true,
                showTextOnlyOnEven: true // New property for reps
            )
        case .rpe:
            return WheelPicker.Config(
                count: 10,   // 0 to 100 (10 intervals of 10)
                steps: 1,    // 1 interval between ticks
                spacing: 35, // Much bigger spacing for RPE
                multiplier: 10,
                showsText: true,
                showTextOnlyOnEven: true, // Will show on 0, 20, 40, 60, 80, 100
                evenInterval: 20 // Show text every 20 units
            )
        }
    }
    
    var minValue: CGFloat {
        return 0
    }
}

struct ExerciseComponent: View {
    @Binding var value: CGFloat
    let type: ExerciseComponentType
    @EnvironmentObject var themeManager: ThemeManager
    let recommendations: NextSetRecommendations
    let exerciseType: String?
    let isDarkMode: Bool
    
    // Get recommendation values based on component type
    private var recommendationValues: [Int] {
        switch type {
        case .weight:
            return recommendations.weightOptions
        case .repetitions:
            return recommendations.repOptions
        case .rpe:
            return recommendations.rpeOptions.map { Int(round($0)) } // Round RPE to nearest integer
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Value viewport with label
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDarkMode ? Color.white.opacity(0.12) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isDarkMode ? Color.white.opacity(0.25) : Color.accentBlue.opacity(0.15), lineWidth: 1.5)
                    )
                
                Text("\(Int(value))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .contentTransition(.numericText())
                    .animation(.bouncy(duration: 0.3), value: value)
            }
            .frame(width: 75, height: 40)
            .overlay(alignment: Alignment.leading) {
                Text(type.label(exerciseType: exerciseType))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .shadow(color: isDarkMode ? .black.opacity(0.8) : .white.opacity(0.8), radius: 1, x: 0, y: 0)
                    .offset(x: 85) // 75px (box width) + 10px spacing
            }
            .padding(.top, 5)
            
            // Edge-to-edge wheel picker
            WheelPicker(
                config: type.wheelConfig,
                value: .init(
                    get: { value - type.minValue },
                    set: { newValue in
                        value = newValue + type.minValue
                    }
                )
            )
            .frame(height: 70)
            .background(Color.clear)
            .environmentObject(themeManager)
            
            // Preset buttons with dynamic recommendations (variable count)
            // Exclude RPE recommendation panels
            if type != .rpe {
                HStack(spacing: 15) {
                    ForEach(recommendationValues, id: \.self) { presetValue in
                        PresetButton(
                            value: presetValue, 
                            currentValue: $value,
                            isDarkMode: isDarkMode
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct PresetButton: View {
    let value: Int
    @Binding var currentValue: CGFloat
    let isDarkMode: Bool
    
    var body: some View {
        Button(action: {
            currentValue = CGFloat(value)
        }) {
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isDarkMode ? Color.accentBlue.opacity(0.9) : Color.accentBlue.opacity(0.8))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .frame(width: 75, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDarkMode ? Color.accentBlue.opacity(0.15) : Color.accentBlue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDarkMode ? Color.accentBlue.opacity(0.4) : Color.accentBlue.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}

struct WheelPicker: View {
    /// Config
    var config: Config
    @Binding var value: CGFloat
    /// View Properties
    @State private var isLoaded: Bool = false
    @State private var lastHapticValue: CGFloat = 0
    @EnvironmentObject var themeManager: ThemeManager
    // Store the last value to detect when to trigger haptics

    // Haptic feedback generator
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader {
            let size = $0.size
            let horizontalPadding = size.width / 2
            
            ScrollView(.horizontal) {
                HStack(spacing: config.spacing) {
                    let totalSteps = config.steps * config.count
                    
                    ForEach(0...totalSteps, id: \.self) { index in
                        let remainder = index % config.steps
                        
                        Rectangle()
                            .fill(themeManager.wheelPickerColor)
                            .frame(width: 0.6, height: remainder == 0 ? 20 : 10, alignment: .center)
                            .frame(maxHeight: 20, alignment: .bottom)
                            .overlay(alignment: .bottom) {
                                if remainder == 0 && config.showsText {
                                    let value = (index / config.steps) * config.multiplier
                                    let shouldShowText = config.showTextOnlyOnEven ? 
                                        (value % (config.evenInterval > 0 ? config.evenInterval : 2) == 0) : true
                                    
                                    if shouldShowText {
                                        Text("\(value)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                                            .shadow(color: themeManager.isDarkMode ? .black.opacity(0.8) : .white.opacity(0.8), radius: 1, x: 0, y: 0)
                                            .textScale(.secondary)
                                            .fixedSize()
                                            .offset(y: 20)
                                    }
                                }
                            }
                    }
                }
                .frame(height: size.height)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: .init(get: {
                let position: Int? = isLoaded ? Int(value * CGFloat(config.steps)) / config.multiplier : nil
                return position
            }, set: { newValue in
                if let newValue {
                    value = (CGFloat(newValue) / CGFloat(config.steps)) * CGFloat(config.multiplier)

                    // Trigger more frequent haptic feedback when scrolling past smaller dividers
                    if abs(value - lastHapticValue) >= CGFloat(config.multiplier) / CGFloat(config.steps) {
                        feedbackGenerator.impactOccurred() // Trigger haptic feedback
                        lastHapticValue = value // Update last haptic value
                    }
                }
            }))
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(themeManager.isDarkMode ? .white : Color.accentBlue)
                    .frame(width: 2, height: 40)
                    .padding(.bottom, 20)
            }
            .safeAreaPadding(.horizontal, horizontalPadding)
            .onAppear {
                if !isLoaded {
                    isLoaded = true
                    feedbackGenerator.prepare() // Prepare the haptic feedback generator
                }
            }
        }
        /// Optional
        .onChange(of: config) { oldValue, newValue in
            value = 0
        }
    }
    
    /// Picker Configuration
    struct Config: Equatable {
        var count: Int
        var steps: Int
        var spacing: CGFloat
        var multiplier: Int
        var showsText: Bool = true
        var showTextOnlyOnEven: Bool = false
        var evenInterval: Int = 0
    }
}

// Color extension to support hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Video game style menu button component
struct GameStyleMenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let unreadCount: Int?
    let action: () -> Void
    
    @State private var isPressed = false
    
    // Convenience initializer without unread count
    init(title: String, icon: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.unreadCount = nil
        self.action = action
    }
    
    // Full initializer with unread count
    init(title: String, icon: String, color: Color, unreadCount: Int?, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.unreadCount = unreadCount
        self.action = action
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
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Icon with solid outline and optional badge
                ZStack {
                    Circle()
                        .fill(Color.offWhite)
                        .overlay(
                            Circle()
                                .stroke(color, lineWidth: 2)
                        )
                    Image(systemName: icon)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    // Unread count badge
                    if let unreadCount = unreadCount, unreadCount > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 20, height: 20)
                                    Text("\(min(unreadCount, 99))")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: 44, height: 44)
                
                // Title text
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(
                Group {
                    if isPressed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: 300)
    }
}

// MARK: - Neumorphic Menu Tile Component

struct NeumorphicMenuTile: View {
    let title: String
    let icon: String
    let color: Color
    let unreadCount: Int?
    let isDarkMode: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    // Convenience initializer without unread count
    init(title: String, icon: String, color: Color, isDarkMode: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.unreadCount = nil
        self.isDarkMode = isDarkMode
        self.action = action
    }
    
    // Full initializer with unread count
    init(title: String, icon: String, color: Color, unreadCount: Int?, isDarkMode: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.unreadCount = unreadCount
        self.isDarkMode = isDarkMode
        self.action = action
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
                action()
            }
        }) {
            VStack(spacing: 12) {
                // Icon with enhanced neumorphic styling
                ZStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    // Unread count badge
                    if let unreadCount = unreadCount, unreadCount > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 18, height: 18)
                                    Text("\(min(unreadCount, 99))")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Title text
                Text(title)
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isPressed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isDarkMode ? Color.white.opacity(0.25) : Color.offWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isDarkMode ? Color.white.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isDarkMode ? Color.white.opacity(0.12) : Color.offWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isDarkMode ? Color.white.opacity(0.25) : Color.gray.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Status Tile Components

struct WorkoutPlanStatusTile: View {
    let status: WorkoutPlanGenerationStatus
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Status icon with animation
            ZStack {
                if status.isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.orange))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
            
            // Status text
            Text(status.isActive ? "Generating..." : "Plan Ready")
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.12) : Color.offWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDarkMode ? Color.white.opacity(0.25) : Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Glass-Style Sign Out Popup

struct SignOutGlassPopup: View {
    let confirmAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    cancelAction()
                }

            // Translucent card
            VStack(spacing: 24) {
                Text("Are you sure you want to sign out?")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    // Cancel button
                    Button(action: cancelAction) {
                        Text("Cancel")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Sign Out button
                    Button(action: confirmAction) {
                        Text("Sign Out")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Account Deletion Success View

struct AccountDeletionSuccessView: View {
    let onDismiss: () -> Void
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Darker background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Success card
            VStack(spacing: 32) {
                // Success animation
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .scaleEffect(showContent ? 1.0 : 0.3)
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.bouncy(duration: 0.6).delay(0.2), value: showContent)
                }
                
                VStack(spacing: 16) {
                    Text("Account Deleted Successfully")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 8) {
                        Text("Your account and all associated data have been permanently removed.")
                            .font(.body)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("Thank you for using our app.")
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.4).delay(0.5), value: showContent)
                
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3).delay(0.8), value: showContent)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            withAnimation {
                showContent = true
            }
        }
    }
}

// MARK: - Delete Account Confirmation Popup

struct DeleteAccountConfirmationView: View {
    let userEmail: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void
    @State private var confirmationText: String = ""
    @State private var isDeleting: Bool = false
    
    private var isConfirmationValid: Bool {
        confirmationText.lowercased() == "delete my account"
    }

    var body: some View {
        ZStack {
            // Darker dimmed background for better contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isDeleting {
                        cancelAction()
                    }
                }

            // Warning card with better contrast
            VStack(spacing: 24) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Delete Account")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    VStack(spacing: 12) {
                        Text("This action cannot be undone.")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        Text("All your workout data, personal details, and account information will be permanently deleted.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .lineLimit(nil)
                        
                        // Account email with better visibility
                        VStack(spacing: 4) {
                            Text("Account:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.7))
                            
                            Text(userEmail)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // Confirmation text field with better styling
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type \"delete my account\" to confirm:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                    
                    TextField("delete my account", text: $confirmationText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isConfirmationValid ? Color.red : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(isDeleting)
                }

                if isDeleting {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(1.0)
                        
                        Text("Deleting account...")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 16)
                } else {
                    HStack(spacing: 12) {
                        // Cancel button with better styling
                        Button(action: cancelAction) {
                            Text("Cancel")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Delete button with better styling
                        Button(action: {
                            isDeleting = true
                            confirmAction()
                        }) {
                            Text("Delete Account")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isConfirmationValid ? Color.red : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!isConfirmationValid)
                        .opacity(isConfirmationValid ? 1.0 : 0.6)
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Workout Plan Status Button Component

struct WorkoutPlanStatusButton: View {
    let status: WorkoutPlanGenerationStatus
    
    var statusColor: Color {
        switch status {
        case .idle:
            return .gray
        case .savingPreferences, .fetchingPersonalDetails, .generatingPlan, .editingPlan, .savingPlan:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    var statusIcon: String {
        switch status {
        case .idle:
            return "checkmark.circle"
        case .savingPreferences, .fetchingPersonalDetails, .generatingPlan, .editingPlan, .savingPlan:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon with animation for active states
            ZStack {
                Circle()
                    .fill(Color.offWhite)
                    .overlay(
                        Circle()
                            .stroke(statusColor, lineWidth: 2)
                    )
                
                if status.isActive {
                    // Animated progress indicator
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                }
            }
            .frame(width: 44, height: 44)
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout Plan")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(status.displayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
        .frame(maxWidth: 300)
    }
}

// MARK: - Workout Plan View

struct WorkoutPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var preferencesService: WorkoutPreferencesService
    @State private var workoutPlan: DeepseekWorkoutPlan?
    @State private var isLoading = true
    @State private var groupedExercises: [String: [DeepseekWorkoutPlanDay]] = [:]
    let onExerciseSelected: (String) -> Void
    let workoutService: WorkoutService
    
    private let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.offWhite.ignoresSafeArea()
                
                if isLoading {
                    LoadingStateView()
                } else if let plan = workoutPlan {
                    WorkoutPlanContentView(groupedExercises: groupedExercises)
                } else {
                    EmptyPlanStateView()
                }
            }
            .navigationTitle("Workout Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
            loadWorkoutPlan()
        }
    }
    
    private func loadWorkoutPlan() {
        Task {
            let plan = await preferencesService.loadCurrentWorkoutPlan()
            await MainActor.run {
                self.workoutPlan = plan
                if let plan = plan {
                    self.groupedExercises = groupExercisesByDay(plan.plan)
                }
                self.isLoading = false
            }
        }
    }
    
    private func groupExercisesByDay(_ exercises: [DeepseekWorkoutPlanDay]) -> [String: [DeepseekWorkoutPlanDay]] {
        return Dictionary(grouping: exercises) { $0.dayOfWeek }
    }
    
    @ViewBuilder
    private func LoadingStateView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Loading workout plan...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func EmptyPlanStateView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 16) {
                Text("No Workout Plan Found")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Create a workout plan through the questionnaire to see your personalized exercises")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    @ViewBuilder
    private func WorkoutPlanContentView(groupedExercises: [String: [DeepseekWorkoutPlanDay]]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        if let dayExercises = groupedExercises[day], !dayExercises.isEmpty {
                            DayWorkoutCard(
                                day: day, 
                                exercises: dayExercises, 
                                onExerciseSelected: onExerciseSelected, 
                                workoutService: workoutService,
                                onExpansionChange: { isExpanded in
                                    if isExpanded {
                                        // Add a small delay to let the expansion animation start
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            withAnimation(.easeInOut(duration: 0.5)) {
                                                proxy.scrollTo(day, anchor: .center)
                                            }
                                        }
                                    }
                                }
                            )
                            .id(day) // Add id for scrollTo to work
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
}

// MARK: - Day Workout Card Component

struct DayWorkoutCard: View {
    let day: String
    let exercises: [DeepseekWorkoutPlanDay]
    let onExerciseSelected: (String) -> Void
    let workoutService: WorkoutService
    let onExpansionChange: (Bool) -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Day Header - Fully Clickable
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                    onExpansionChange(isExpanded)
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("\(exercises.count) exercises")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentBlue)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Exercises List (Expandable)
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(exercises.indices, id: \.self) { index in
                        ExerciseRowCard(exercise: exercises[index], workoutService: workoutService, onTap: {
                            onExerciseSelected(exercises[index].exerciseName)
                        })
                        
                        if index < exercises.count - 1 {
                            Divider()
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
                .clipped()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentBlue.opacity(0.12), lineWidth: 2)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

// MARK: - Exercise Row Card Component

struct ExerciseRowCard: View {
    let exercise: DeepseekWorkoutPlanDay
    let workoutService: WorkoutService
    let onTap: () -> Void
    
    private var isCompleted: Bool {
        let completed = workoutService.isExerciseCompletedForToday(exerciseName: exercise.exerciseName)
        // Additional debug info 
        if completed {
            print("✅ UI: \(exercise.exerciseName) showing as completed")
        }
        return completed
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
            // Exercise Icon
            ZStack {
                Circle()
                    .fill(Color.accentBlue.opacity(0.08))
                    .overlay(
                        Circle()
                            .stroke(Color.accentBlue.opacity(0.25), lineWidth: 1.5)
                    )
                
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color.accentBlue.opacity(0.8))
            }
            .frame(width: 44, height: 44)
            
            // Exercise Details
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("\(exercise.sets)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color.accentBlue)
                        Text("sets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(exercise.reps)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color.accentBlue)
                        Text(exercise.exerciseType == "static_hold" ? "seconds" : "reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Completion Checkmark
            if isCompleted {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .transition(.scale.combined(with: .opacity))
            }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}


