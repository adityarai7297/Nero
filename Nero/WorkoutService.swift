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

class WorkoutService: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var todaySets: [WorkoutSet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentUserId: UUID?
    
    init() {
        loadExercises()
        checkUserAndLoadSets()
    }
    
    func setUser(_ userId: UUID?) {
        currentUserId = userId
        checkUserAndLoadSets()
    }
    
    private func checkUserAndLoadSets() {
        if currentUserId != nil {
            loadTodaySets()
        } else {
            // Clear sets if no user
            todaySets = []
            updateSetCounts()
        }
    }
    
    // MARK: - Exercise Operations
    
    func loadExercises() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response: [DBExercise] = try await supabase
                    .from("exercises")
                    .select()
                    .order("name")
                    .execute()
                    .value
                
                let loadedExercises = response.map { dbExercise in
                    Exercise(
                        name: dbExercise.name,
                        defaultWeight: CGFloat(dbExercise.defaultWeight),
                        defaultReps: CGFloat(dbExercise.defaultReps),
                        defaultRPE: CGFloat(dbExercise.defaultRpe),
                        setsCompleted: 0 // Will be calculated from today's sets
                    )
                }
                
                await MainActor.run {
                    self.exercises = loadedExercises
                    self.updateSetCounts()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load exercises: \(error.localizedDescription)"
                    self.isLoading = false
                    // Fallback to local data
                    self.exercises = Exercise.allExercises
                }
            }
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