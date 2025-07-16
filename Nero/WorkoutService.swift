import Foundation
import Supabase
import SwiftUI

// Database models
struct DBExercise: Codable {
    let id: Int?
    let name: String
    let defaultWeight: Double
    let defaultReps: Int
    let defaultRpe: Int
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case defaultWeight = "default_weight"
        case defaultReps = "default_reps"
        case defaultRpe = "default_rpe"
        case createdAt = "created_at"
    }
}

// Simplified struct for fetching unique exercise names
struct DBExerciseName: Codable {
    let exerciseName: String
    
    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
    }
}

struct DBWorkoutSet: Codable {
    let id: Int?
    let exerciseName: String
    let weight: Double
    let reps: Int
    let rpe: Int
    let completedAt: Date?
    let createdAt: Date?
    let userId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case exerciseName = "exercise_name"
        case weight
        case reps
        case rpe
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case userId = "user_id"
    }
}

// Database model for workout plans
struct DBWorkoutPlan: Codable {
    let id: Int?
    let userId: UUID
    let planJson: DeepseekWorkoutPlan
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planJson = "plan_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

class WorkoutService: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var todaySets: [WorkoutSet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasWorkoutPlan = false
    
    private var currentUserId: UUID?
    private var currentWorkoutPlan: DeepseekWorkoutPlan?
    
    init() {
        // Set up notification observer for workout plan updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkoutPlanUpdate),
            name: NSNotification.Name("WorkoutPlanUpdated"),
            object: nil
        )
        
        // Set up notification observer for workout sets updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkoutSetsUpdate),
            name: NSNotification.Name("WorkoutSetsUpdated"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleWorkoutPlanUpdate() {
        print("🔔 WorkoutService: Received workout plan update notification")
        // Reload exercises on the main thread after a short delay to ensure database is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadUserExercises()
        }
    }
    
    @objc private func handleWorkoutSetsUpdate() {
        print("🔔 WorkoutService: Received workout sets update notification")
        // Reload today's sets to ensure UI stays in sync
        DispatchQueue.main.async {
            self.loadTodaySets()
        }
    }
    
    func setUser(_ userId: UUID?) {
        currentUserId = userId
        if userId != nil {
            loadUserExercises()
            loadTodaySets()
        } else {
            // Clear data if no user
            exercises = []
            todaySets = []
            hasWorkoutPlan = false
            updateSetCounts()
        }
    }
    
    // MARK: - Exercise Operations
    
    func loadUserExercises() {
        guard let userId = currentUserId else {
            print("⚠️ WorkoutService: No user ID provided")
            exercises = []
            hasWorkoutPlan = false
            return
        }
        
        print("🔄 WorkoutService: Loading exercises for user: \(userId)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("📡 WorkoutService: Querying workout_plans table...")
                // Try to load user's workout plan
                let planResponse: [DBWorkoutPlan] = try await supabase
                    .from("workout_plans")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                print("📊 WorkoutService: Found \(planResponse.count) workout plans")
                
                if let userPlan = planResponse.first {
                    print("✅ WorkoutService: Found workout plan with \(userPlan.planJson.plan.count) exercises")
                    
                    // Debug: Print the plan structure
                    print("🔍 WorkoutService: Plan structure:")
                    for (index, exercise) in userPlan.planJson.plan.prefix(3).enumerated() {
                        print("  Exercise \(index + 1): \(exercise.exerciseName) - \(exercise.sets) sets x \(exercise.reps) reps on \(exercise.dayOfWeek)")
                    }
                    if userPlan.planJson.plan.count > 3 {
                        print("  ... and \(userPlan.planJson.plan.count - 3) more exercises")
                    }
                    
                    // User has a workout plan - extract exercises from it
                    let uniqueExercises = extractUniqueExercisesFromPlan(userPlan.planJson)
                    
                    await MainActor.run {
                        self.exercises = uniqueExercises
                        self.hasWorkoutPlan = true
                        self.updateSetCounts()
                        self.isLoading = false
                    }
                    
                    print("✅ WorkoutService: Loaded \(uniqueExercises.count) unique exercises from user's workout plan")
                    print("🏋️ WorkoutService: Exercise names: \(uniqueExercises.map { $0.name }.joined(separator: ", "))")
                    print("📊 WorkoutService: Final state - hasWorkoutPlan: \(true), exercises.count: \(uniqueExercises.count), isLoading: \(false)")
                } else {
                    // User has no workout plan
                    await MainActor.run {
                        self.exercises = []
                        self.hasWorkoutPlan = false
                        self.isLoading = false
                    }
                    
                    print("⚠️ WorkoutService: User has no workout plan - showing empty exercise list")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load workout plan: \(error.localizedDescription)"
                    self.isLoading = false
                    self.hasWorkoutPlan = false
                    self.exercises = []
                }
                print("❌ WorkoutService: Failed to load user workout plan: \(error)")
                print("🔍 WorkoutService: Error details: \(error.localizedDescription)")
            }
        }
    }
    
    private func extractUniqueExercisesFromPlan(_ plan: DeepseekWorkoutPlan) -> [Exercise] {
        // Store the workout plan for later use
        self.currentWorkoutPlan = plan
        
        // Get today's day of the week for prioritization
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let todayString = formatter.string(from: Date())
        
        print("📅 WorkoutService: Today is \(todayString)")
        
        // Get all unique exercise names from the entire plan (not just today)
        let allExerciseNames = Set(plan.plan.map { $0.exerciseName })
        
        print("🏋️ WorkoutService: Found \(allExerciseNames.count) unique exercises in plan: \(Array(allExerciseNames).joined(separator: ", "))")
        
        // Get today's scheduled exercise names for prioritization
        let todayExercises = plan.plan.filter { $0.dayOfWeek == todayString }
        let todayExerciseNames = Set(todayExercises.map { $0.exerciseName })
        
        // Create Exercise objects for all exercises in the plan
        let exercises = allExerciseNames.map { exerciseName in
            // Try to get today's specific exercise data first, otherwise use any available data
            let todayExerciseData = plan.plan.filter { $0.dayOfWeek == todayString && $0.exerciseName == exerciseName }
            let exerciseData = todayExerciseData.first ?? plan.plan.first { $0.exerciseName == exerciseName }!
            
            let isScheduledToday = todayExerciseNames.contains(exerciseName)
            let scheduleInfo = isScheduledToday ? "scheduled for TODAY" : "scheduled on \(exerciseData.dayOfWeek)"
            print("📝 WorkoutService: Creating exercise \(exerciseName) with \(exerciseData.sets) sets x \(exerciseData.reps) reps (\(scheduleInfo))")
            
            return Exercise(
                name: exerciseName,
                defaultWeight: getDefaultWeightForExercise(exerciseName),
                defaultReps: CGFloat(exerciseData.reps),
                defaultRPE: 70, // Default RPE
                setsCompleted: 0,
                exerciseType: exerciseData.exerciseType
            )
        }.sorted { lhs, rhs in
            let lhsIsToday = todayExerciseNames.contains(lhs.name)
            let rhsIsToday = todayExerciseNames.contains(rhs.name)
            
            // Prioritize today's exercises first
            if lhsIsToday && !rhsIsToday {
                return true  // lhs (today's exercise) comes first
            } else if !lhsIsToday && rhsIsToday {
                return false // rhs (today's exercise) comes first
            } else {
                // Both are today's exercises or both are not - sort alphabetically
                return lhs.name < rhs.name
            }
        }
        
        // Log the final ordering and today's status
        if todayExercises.isEmpty {
            print("⚠️ WorkoutService: No exercises scheduled for today (\(todayString)), showing all \(exercises.count) exercises in alphabetical order")
        } else {
            let todayCount = todayExerciseNames.count
            print("✅ WorkoutService: \(todayCount) exercises scheduled for today (\(todayString)), prioritized at top of \(exercises.count) total exercises")
            print("🔝 WorkoutService: Today's exercises (top priority): \(exercises.prefix(todayCount).map { $0.name }.joined(separator: ", "))")
        }
        
        return exercises
    }
    
    private func getDefaultWeightForExercise(_ exerciseName: String) -> CGFloat {
        // Simple heuristic for default weights based on exercise name
        let name = exerciseName.lowercased()
        
        if name.contains("squat") {
            return 135
        } else if name.contains("bench") || name.contains("press") {
            return 95
        } else if name.contains("deadlift") {
            return 185
        } else if name.contains("row") {
            return 115
        } else if name.contains("curl") || name.contains("extension") {
            return 25
        } else if name.contains("pull") || name.contains("dip") {
            return 0 // bodyweight
        } else {
            return 45 // Default barbell weight
        }
    }
    
    // MARK: - Workout Set Operations
    
    func loadTodaySets() {
        guard let userId = currentUserId else {
            todaySets = []
            updateSetCounts()
            return
        }
        
        Task {
            do {
                let today = Calendar.current.startOfDay(for: Date())
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
                
                let response: [DBWorkoutSet] = try await supabase
                    .from("workout_sets")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .gte("completed_at", value: today.ISO8601Format())
                    .lt("completed_at", value: tomorrow.ISO8601Format())
                    .order("completed_at", ascending: false)
                    .execute()
                    .value
                
                let loadedSets = response.compactMap { dbSet -> WorkoutSet? in
                    guard let completedAt = dbSet.completedAt else { return nil }
                    return WorkoutSet(
                        databaseId: dbSet.id,
                        exerciseName: dbSet.exerciseName,
                        weight: CGFloat(dbSet.weight),
                        reps: CGFloat(dbSet.reps),
                        rpe: CGFloat(dbSet.rpe),
                        timestamp: completedAt
                    )
                }
                
                await MainActor.run {
                    self.todaySets = loadedSets
                    self.updateSetCounts()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load today's sets: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func saveWorkoutSet(_ workoutSet: WorkoutSet) async -> Bool {
        guard let userId = currentUserId else {
            await MainActor.run {
                self.errorMessage = "Cannot save workout set: user not authenticated"
            }
            return false
        }
        
        let dbSet = DBWorkoutSet(
            id: nil,
            exerciseName: workoutSet.exerciseName,
            weight: Double(workoutSet.weight),
            reps: Int(workoutSet.reps),
            rpe: Int(workoutSet.rpe),
            completedAt: workoutSet.timestamp,
            createdAt: nil,
            userId: userId
        )
        
        do {
            let savedSet: DBWorkoutSet = try await supabase
                .from("workout_sets")
                .insert(dbSet)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                var newWorkoutSet = workoutSet
                newWorkoutSet.databaseId = savedSet.id
                self.todaySets.append(newWorkoutSet)
                self.updateSetCounts()
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save workout set: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func deleteWorkoutSet(_ workoutSet: WorkoutSet) async -> Bool {
        guard let databaseId = workoutSet.databaseId else {
            await MainActor.run {
                self.errorMessage = "Cannot delete set: missing database ID"
            }
            return false
        }
        
        guard currentUserId != nil else {
            await MainActor.run {
                self.errorMessage = "Cannot delete set: user not authenticated"
            }
            return false
        }
        
        do {
            try await supabase
                .from("workout_sets")
                .delete()
                .eq("id", value: databaseId)
                .execute()
            
            // Add a small delay to let the animation play
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.todaySets.removeAll { $0.id == workoutSet.id }
                }
                self.updateSetCounts()
                
                // Notify other views that sets have been updated
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutSetsUpdated"), 
                    object: nil
                )
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete workout set: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func updateWorkoutSet(_ workoutSet: WorkoutSet) async -> Bool {
        guard let databaseId = workoutSet.databaseId else {
            await MainActor.run {
                self.errorMessage = "Cannot update set: missing database ID"
            }
            return false
        }
        
        guard let userId = currentUserId else {
            await MainActor.run {
                self.errorMessage = "Cannot update set: user not authenticated"
            }
            return false
        }
        
        let updatedDBSet = DBWorkoutSet(
            id: databaseId,
            exerciseName: workoutSet.exerciseName,
            weight: Double(workoutSet.weight),
            reps: Int(workoutSet.reps),
            rpe: Int(workoutSet.rpe),
            completedAt: workoutSet.timestamp,
            createdAt: nil, // Will be preserved by Supabase
            userId: userId
        )
        
        do {
            try await supabase
                .from("workout_sets")
                .update(updatedDBSet)
                .eq("id", value: databaseId)
                .execute()
            
            await MainActor.run {
                if let index = self.todaySets.firstIndex(where: { $0.id == workoutSet.id }) {
                    self.todaySets[index] = workoutSet
                }
                self.updateSetCounts()
                
                // Notify other views that sets have been updated
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutSetsUpdated"), 
                    object: nil
                )
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update workout set: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the target number of sets for a specific exercise on today's day
    func getTargetSetsForToday(exerciseName: String) -> Int? {
        guard let workoutPlan = currentWorkoutPlan else { return nil }
        
        // Get today's day of the week
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let todayString = formatter.string(from: Date())
        
        // Find exercises for today with the given name
        let todayExercises = workoutPlan.plan.filter { 
            $0.dayOfWeek == todayString && $0.exerciseName == exerciseName 
        }
        
        if let todayExercise = todayExercises.first {
            // Exercise is scheduled for today
            return todayExercise.sets
        } else {
            // Exercise is not scheduled for today, but let's find when it's scheduled
            let exerciseInPlan = workoutPlan.plan.first { $0.exerciseName == exerciseName }
            if let exercise = exerciseInPlan {
                print("ℹ️ WorkoutService: \(exerciseName) is not scheduled for today (\(todayString)), but is scheduled on \(exercise.dayOfWeek)")
                // Return 0 to indicate this exercise is not for today
                return 0
            } else {
                print("⚠️ WorkoutService: \(exerciseName) not found in workout plan")
                return nil
            }
        }
    }
    
    private func updateSetCounts() {
        for index in exercises.indices {
            let exerciseName = exercises[index].name
            exercises[index].setsCompleted = todaySets.filter { $0.exerciseName == exerciseName }.count
        }
    }
    
    func getExercise(by name: String) -> Exercise? {
        return exercises.first { $0.name == name }
    }
    
    /// Check if an exercise is completed for today (completed sets >= target sets)
    func isExerciseCompletedForToday(exerciseName: String) -> Bool {
        guard let targetSets = getTargetSetsForToday(exerciseName: exerciseName) else { 
            print("🔍 WorkoutService: \(exerciseName) - no target sets found")
            return false 
        }
        
        // If target sets is 0, this exercise is not scheduled for today
        // Don't mark it as completed just because target is 0
        if targetSets == 0 {
            print("🔍 WorkoutService: \(exerciseName) - not scheduled for today (target: 0)")
            return false
        }
        
        let completedSets = todaySets.filter { $0.exerciseName == exerciseName }.count
        let isCompleted = completedSets >= targetSets
        print("🔍 WorkoutService: \(exerciseName) - completed: \(completedSets)/\(targetSets) = \(isCompleted)")
        
        return isCompleted
    }
    
    // MARK: - Weekly Completion
    
    /// Check if today is the last workout day of the week and if it's completed
    func isLastWorkoutDayOfWeekCompleted() -> Bool {
        guard let workoutPlan = currentWorkoutPlan else { return false }
        
        // Get all unique days of the week in the workout plan
        let workoutDays = Set(workoutPlan.plan.map { $0.dayOfWeek })
        let sortedWorkoutDays = workoutDays.sorted { dayOfWeek1, dayOfWeek2 in
            let calendar = Calendar.current
            let day1Index = calendar.weekdaySymbols.firstIndex(of: dayOfWeek1) ?? 0
            let day2Index = calendar.weekdaySymbols.firstIndex(of: dayOfWeek2) ?? 0
            return day1Index < day2Index
        }
        
        // Get today's day of the week
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let todayString = formatter.string(from: Date())
        
        // Check if today is the last workout day of the week
        guard let lastWorkoutDay = sortedWorkoutDays.last,
              todayString == lastWorkoutDay else {
            return false
        }
        
        // Check if all exercises for today are completed
        return exercises.allSatisfy { exercise in
            isExerciseCompletedForToday(exerciseName: exercise.name)
        }
    }

    
    // MARK: - Exercise History Methods (New Feature)
    
    /// Fetch all unique exercises that the user has performed
    func fetchAllUserExercises() async -> [String] {
        guard let userId = currentUserId else {
            print("❌ WorkoutService: Cannot fetch exercises - no user ID")
            return []
        }
        
        do {
            let response: [DBExerciseName] = try await supabase
                .from("workout_sets")
                .select("exercise_name")
                .eq("user_id", value: userId.uuidString)
                .order("exercise_name")
                .execute()
                .value
            
            // Get unique exercise names
            let uniqueExercises = Array(Set(response.map { $0.exerciseName })).sorted()
            print("✅ WorkoutService: Found \(uniqueExercises.count) unique exercises")
            return uniqueExercises
            
        } catch {
            print("❌ WorkoutService: Failed to fetch exercises: \(error)")
            return []
        }
    }
    
    /// Fetch exercise history for a specific exercise with optional date filtering
    func fetchExerciseHistory(exerciseName: String, timeframe: ExerciseHistoryTimeframe = .all) async -> [WorkoutSet] {
        guard let userId = currentUserId else {
            print("❌ WorkoutService: Cannot fetch exercise history - no user ID")
            return []
        }
        
        do {
            let response: [DBWorkoutSet]
            
            // Build query with conditional date filtering
            if timeframe != .all {
                let startDate = timeframe.startDate
                response = try await supabase
                    .from("workout_sets")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .eq("exercise_name", value: exerciseName)
                    .gte("completed_at", value: startDate.ISO8601Format())
                    .order("completed_at", ascending: true)
                    .execute()
                    .value
            } else {
                response = try await supabase
                    .from("workout_sets")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .eq("exercise_name", value: exerciseName)
                    .order("completed_at", ascending: true)
                    .execute()
                    .value
            }
            
            let workoutSets = response.compactMap { dbSet -> WorkoutSet? in
                guard let completedAt = dbSet.completedAt else { return nil }
                return WorkoutSet(
                    databaseId: dbSet.id,
                    exerciseName: dbSet.exerciseName,
                    weight: CGFloat(dbSet.weight),
                    reps: CGFloat(dbSet.reps),
                    rpe: CGFloat(dbSet.rpe),
                    timestamp: completedAt,
                    exerciseType: nil // Will be determined based on exercise name if needed
                )
            }
            
            print("✅ WorkoutService: Found \(workoutSets.count) sets for \(exerciseName) in \(timeframe.displayName)")
            return workoutSets
            
        } catch {
            print("❌ WorkoutService: Failed to fetch exercise history: \(error)")
            return []
        }
    }
    
    /// Get exercise statistics for a specific exercise and timeframe
    func getExerciseStats(exerciseName: String, timeframe: ExerciseHistoryTimeframe = .all) async -> ExerciseStats? {
        let history = await fetchExerciseHistory(exerciseName: exerciseName, timeframe: timeframe)
        
        guard !history.isEmpty else { return nil }
        
        let weights = history.map { Double($0.weight) }
        let volumes = history.map { Double($0.weight * $0.reps) }
        
        return ExerciseStats(
            exerciseName: exerciseName,
            totalSets: history.count,
            maxWeight: weights.max() ?? 0,
            maxVolume: volumes.max() ?? 0,
            averageWeight: weights.reduce(0, +) / Double(weights.count),
            averageVolume: volumes.reduce(0, +) / Double(volumes.count),
            firstWorkout: history.first?.timestamp,
            lastWorkout: history.last?.timestamp
        )
    }
} 