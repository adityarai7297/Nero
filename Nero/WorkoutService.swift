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
        
        // Get unique exercise names from the plan
        let uniqueExerciseNames = Set(plan.plan.map { $0.exerciseName })
        
        // Get today's day of the week
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let todayString = formatter.string(from: Date())
        
        // Get exercises scheduled for today
        let todayExerciseNames = Set(plan.plan.filter { $0.dayOfWeek == todayString }.map { $0.exerciseName })
        
        // Create Exercise objects with reasonable defaults
        // We could also fetch default values from the exercises table if needed
        let exercises = uniqueExerciseNames.map { exerciseName in
            // Try to get defaults from the plan data
            let planExercises = plan.plan.filter { $0.exerciseName == exerciseName }
            let avgSets = planExercises.map { $0.sets }.reduce(0, +) / planExercises.count
            let avgReps = planExercises.map { $0.reps }.reduce(0, +) / planExercises.count
            
            return Exercise(
                name: exerciseName,
                defaultWeight: getDefaultWeightForExercise(exerciseName),
                defaultReps: CGFloat(avgReps),
                defaultRPE: 70, // Default RPE
                setsCompleted: 0
            )
        }.sorted { lhs, rhs in
            // First, prioritize exercises scheduled for today
            let lhsIsToday = todayExerciseNames.contains(lhs.name)
            let rhsIsToday = todayExerciseNames.contains(rhs.name)
            
            if lhsIsToday && !rhsIsToday {
                return true // lhs comes first
            } else if !lhsIsToday && rhsIsToday {
                return false // rhs comes first
            } else {
                // Both are today's exercises or both are not today's exercises
                // Sort alphabetically within each group
                return lhs.name < rhs.name
            }
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
        
        // Return the target sets for today's exercise
        return todayExercises.first?.sets
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
} 