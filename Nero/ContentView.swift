//
//  ContentView.swift
//  Nero
//
//  Created by Aditya Rai on 5/19/25.
//

import Supabase
import SwiftUI
import UIKit
import IrregularGradient
import Neumorphic

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
               lhs.timestamp == rhs.timestamp
    }
}

// Exercise model with name and default preferences
struct Exercise {
    let name: String
    let defaultWeight: CGFloat
    let defaultReps: CGFloat
    let defaultRPE: CGFloat
    var setsCompleted: Int = 0
    
    static let allExercises: [Exercise] = [
        Exercise(name: "Bench Press", defaultWeight: 50, defaultReps: 8, defaultRPE: 60),
        Exercise(name: "Squat", defaultWeight: 80, defaultReps: 10, defaultRPE: 70),
        Exercise(name: "Deadlift", defaultWeight: 100, defaultReps: 6, defaultRPE: 80),
        Exercise(name: "Overhead Press", defaultWeight: 35, defaultReps: 8, defaultRPE: 65),
        Exercise(name: "Pull-ups", defaultWeight: 0, defaultReps: 12, defaultRPE: 70),
        Exercise(name: "Barbell Row", defaultWeight: 60, defaultReps: 10, defaultRPE: 75),
        Exercise(name: "Incline Bench", defaultWeight: 40, defaultReps: 8, defaultRPE: 65),
        Exercise(name: "Dips", defaultWeight: 0, defaultReps: 15, defaultRPE: 70),
        Exercise(name: "Romanian Deadlift", defaultWeight: 70, defaultReps: 12, defaultRPE: 70),
        Exercise(name: "Leg Press", defaultWeight: 120, defaultReps: 15, defaultRPE: 75)
    ]
}

// Simple ThemeManager for the WheelPicker
class ThemeManager: ObservableObject {
    @Published var wheelPickerColor: Color = .black.opacity(0.7)
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ExerciseView()
            .environmentObject(authService)
            .environmentObject(themeManager)
    }
}

struct ExerciseView: View {
    @StateObject private var workoutService = WorkoutService()
    @EnvironmentObject var authService: AuthService
    @State private var currentExerciseIndex: Int = 0
    @State private var weights: [CGFloat] = [50, 8, 60] // Will be updated based on current exercise
    @StateObject private var themeManager = ThemeManager()
    @State private var showRadialBurst: Bool = false
    @State private var showingSetsModal: Bool = false // Control modal presentation
    @State private var showingLogoutAlert: Bool = false
    @State private var showingSideMenu: Bool = false // Control side menu presentation
    @State private var showingWorkoutQuestionnaire: Bool = false // Control workout questionnaire presentation
    @State private var showingPersonalDetails: Bool = false // Control personal details presentation
    
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
            return Exercise(name: "Loading...", defaultWeight: 0, defaultReps: 0, defaultRPE: 0)
        }
        return workoutService.exercises[currentExerciseIndex]
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                MainExerciseContentView()
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
            WorkoutQuestionnaireView()
        }
        .sheet(isPresented: $showingPersonalDetails) {
            PersonalDetailsView()
        }
        .alert("Error", isPresented: .constant(workoutService.errorMessage != nil)) {
            Button("OK") { workoutService.errorMessage = nil }
        } message: {
            if let errorMessage = workoutService.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .overlay {
            if workoutService.isLoading {
                ProgressView("Loading exercises...")
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
            }
        }
        .onChange(of: workoutService.todaySets) { oldSets, newSets in
            updateRecommendationsForCurrentExercise()
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
    private func ExerciseTitleView() -> some View {
        VStack {
            HStack {
                // Center the exercise name
                Spacer()
                
                Text(currentExercise.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .shadow(color: .white.opacity(0.8), radius: 1, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.3), value: currentExercise.name)
                
                Spacer()
            }
            .padding(.top, 15)
            .padding(.bottom, 5)
            .padding(.horizontal, 20)
            .overlay(alignment: .leading) {
                // Hamburger menu icon positioned on the left
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
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
            Text("\(currentExercise.setsCompleted)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .softButtonStyle(Circle(), padding: 10, mainColor: Color.white, textColor: .green.opacity(0.8))
        .frame(width: 36, height: 36)
    }
    
    @ViewBuilder
    private func ExerciseComponentsView() -> some View {
        VStack(spacing: 32) {
            ExerciseComponent(
                value: $weights[0], 
                type: .weight, 
                recommendations: currentRecommendations
            )
                .environmentObject(themeManager)
            ExerciseComponent(
                value: $weights[1], 
                type: .repetitions, 
                recommendations: currentRecommendations
            )
                .environmentObject(themeManager)
            ExerciseComponent(
                value: $weights[2], 
                type: .rpe, 
                recommendations: currentRecommendations
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
        .onAppear {
            setButtonFeedback.prepare()
            navigationFeedback.prepare()
            loadExerciseData()
            updateRecommendationsForCurrentExercise()
            workoutService.setUser(authService.user?.id)
        }
        .onChange(of: authService.user) { _, newUser in
            workoutService.setUser(newUser?.id)
        }
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
                .foregroundColor(.blue.opacity(0.8))
        }
        .softButtonStyle(Circle(), padding: 12, mainColor: Color.white, textColor: .blue.opacity(0.8))
        .frame(width: 44, height: 44)
    }
    
    @ViewBuilder
    private func SetButton() -> some View {
        Button(action: {
            handleSetButtonTap()
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.green.opacity(0.8))
        }
        .softButtonStyle(Circle(), padding: 23, mainColor: Color.white, textColor: .green.opacity(0.8))
        .frame(width: 70, height: 70)
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
                .foregroundColor(.blue.opacity(0.8))
        }
        .softButtonStyle(Circle(), padding: 12, mainColor: Color.white, textColor: .blue.opacity(0.8))
        .frame(width: 44, height: 44)
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
        weights = [exercise.defaultWeight, exercise.defaultReps, exercise.defaultRPE]
        
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
            timestamp: Date()
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
            timestamp: Date()
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
    
    @ViewBuilder
    private func SideMenuView() -> some View {
        ZStack {
            // Blur background overlay - keeping white background
            Color.white.opacity(0.1)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSideMenu = false
                    }
                }
            
            // Centered menu content
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Edit Workout Plan button
                    GameStyleMenuButton(
                        title: "Edit Workout Plan",
                        icon: "dumbbell.fill",
                        color: .blue
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
                    GameStyleMenuButton(
                        title: "Personal Details",
                        icon: "person.fill",
                        color: .blue
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSideMenu = false
                        }
                        // Small delay to let menu close animation finish
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingPersonalDetails = true
                        }
                    }
                    
                    // Sign Out button
                    GameStyleMenuButton(
                        title: "Sign Out",
                        icon: "power",
                        color: .red
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSideMenu = false
                        }
                        // Small delay to let menu close animation finish
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingLogoutAlert = true
                        }
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
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
                        Text("reps")
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
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
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
                        Text("reps")
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
    
    var label: String {
        switch self {
        case .weight: return "lbs"
        case .repetitions: return "reps"
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
                    .fill(Color.white)
                    .softInnerShadow(
                        RoundedRectangle(cornerRadius: 8),
                        darkShadow: Color.black.opacity(0.3),
                        lightShadow: Color.white.opacity(0.9),
                        spread: 0.15,
                        radius: 4
                    )
                
                Text("\(Int(value))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .contentTransition(.numericText())
                    .animation(.bouncy(duration: 0.3), value: value)
            }
            .frame(width: 60, height: 40)
            .overlay(alignment: Alignment.leading) {
                Text(type.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .shadow(color: .white.opacity(0.8), radius: 1, x: 0, y: 0)
                    .offset(x: 70) // 60px (box width) + 10px spacing
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
                            currentValue: $value
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
    
    var body: some View {
        Button(action: {
            currentValue = CGFloat(value)
        }) {
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue.opacity(0.8))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .softButtonStyle(
            RoundedRectangle(cornerRadius: 8),
            padding: 12,
            mainColor: Color.white,
            textColor: .blue.opacity(0.8)
        )
        .frame(width: 75, height: 40)
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
                                            .foregroundColor(.black)
                                            .shadow(color: .white.opacity(0.8), radius: 1, x: 0, y: 0)
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
                    .fill(Color.blue)
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
    let action: () -> Void
    
    @State private var isPressed = false
    
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
                // Icon with solid outline
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(color, lineWidth: 2)
                            )
                    )
                
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: 300)
    }
}

#Preview {
    ContentView()
}


