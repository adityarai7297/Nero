import Foundation
import SwiftUI
import Supabase

// MARK: - Progressive Overload Models

struct ProgressiveOverloadSuggestion: Codable {
    let exerciseName: String
    let suggestions: [OverloadChange]
    let reasoning: String? // Optional reasoning for exercises with no changes needed
}

struct OverloadChange: Codable {
    let changeType: String // "sets", "reps", "weight"
    let changeValue: Int // positive for increase, negative for decrease
    let reasoning: String
}

struct ProgressiveOverloadResponse: Codable {
    let suggestions: [ProgressiveOverloadSuggestion]
    let summary: String
}

struct ProgressiveOverloadAnalysisRecord: Codable {
    let id: String
    let user_id: String
    let analysis_date: String
    let suggestions: [ProgressiveOverloadSuggestion]
    let summary: String
    let created_at: String
    let updated_at: String
}

struct ProgressiveOverloadAnalysisInsert: Codable {
    let user_id: String
    let analysis_date: String
    let suggestions: [ProgressiveOverloadSuggestion]
    let summary: String
}

// MARK: - Progressive Overload Service

class ProgressiveOverloadService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var lastAnalysisResult: ProgressiveOverloadResponse?
    
    private var currentUserId: UUID?
    
    init() {
        // Don't load data in init - wait for user to be set
    }
    
    func setUser(_ userId: UUID?) {
        currentUserId = userId
        if userId != nil {
            // Load existing analysis result when user is set
            Task {
                await loadLastAnalysisResult()
            }
        } else {
            // Clear data if no user
            Task { @MainActor in
                self.lastAnalysisResult = nil
            }
        }
    }
    
    /// Analyze exercise history and get progressive overload suggestions
    func analyzeProgressiveOverload(
        exerciseHistory: [WorkoutSet],
        currentWorkoutPlan: DeepseekWorkoutPlan,
        personalDetails: PersonalDetails,
        preferences: WorkoutPreferences
    ) async -> ProgressiveOverloadResponse? {
        
        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
        }
        
        do {
            print("🔍 ProgressiveOverloadService: Starting progressive overload analysis")
            
            // Calculate and display actual data span
            if exerciseHistory.isEmpty {
                print("📊 Exercise History: No workout data available (new user)")
            } else {
                let sortedHistory = exerciseHistory.sorted { $0.timestamp < $1.timestamp }
                if let earliestDate = sortedHistory.first?.timestamp,
                   let latestDate = sortedHistory.last?.timestamp {
                    let timeSpan = Calendar.current.dateComponents([.weekOfYear, .day], from: earliestDate, to: latestDate)
                    let weeks = timeSpan.weekOfYear ?? 0
                    let days = timeSpan.day ?? 0
                    
                    if weeks > 0 {
                        print("📊 Exercise History: \(exerciseHistory.count) sets spanning \(weeks) weeks")
                    } else {
                        print("📊 Exercise History: \(exerciseHistory.count) sets spanning \(days) days")
                    }
                } else {
                    print("📊 Exercise History: \(exerciseHistory.count) sets (limited time range)")
                }
            }
            
            print("📋 Current Plan: \(currentWorkoutPlan.plan.count) exercises")
            
            let result = try await DeepseekAPIClient.shared.analyzeProgressiveOverload(
                exerciseHistory: exerciseHistory,
                currentWorkoutPlan: currentWorkoutPlan,
                personalDetails: personalDetails,
                preferences: preferences
            )
            
            await MainActor.run {
                self.isAnalyzing = false
                self.lastAnalysisResult = result
            }
            
            // Save the result to Supabase
            await saveAnalysisResult(result)
            
            print("✅ ProgressiveOverloadService: Analysis completed with \(result.suggestions.count) suggestions")
            return result
            
        } catch {
            print("❌ ProgressiveOverloadService: Analysis failed: \(error.localizedDescription)")
            await MainActor.run {
                self.isAnalyzing = false
                self.errorMessage = "Failed to analyze progressive overload: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    /// Manually refresh analysis data from Supabase (useful for testing or data sync)
    func refreshAnalysisData() async {
        guard currentUserId != nil else {
            print("❌ ProgressiveOverloadService: Cannot refresh data without user ID")
            return
        }
        await loadLastAnalysisResult()
    }
    
    // MARK: - Supabase Persistence
    
    /// Save analysis result to Supabase
    private func saveAnalysisResult(_ result: ProgressiveOverloadResponse) async {
        do {
            // Get current user ID
            guard let userId = currentUserId else {
                print("❌ ProgressiveOverloadService: No user ID available for saving analysis")
                return
            }
            
            // Create a proper codable structure for database insertion
            let analysisRecord = ProgressiveOverloadAnalysisInsert(
                user_id: userId.uuidString,
                analysis_date: ISO8601DateFormatter().string(from: Date()),
                suggestions: result.suggestions,
                summary: result.summary
            )
            
            let response = try await supabase
                .from("progressive_overload_analyses")
                .insert(analysisRecord)
                .execute()
            
            print("✅ ProgressiveOverloadService: Analysis result saved to Supabase")
            
        } catch {
            print("❌ ProgressiveOverloadService: Failed to save analysis result: \(error.localizedDescription)")
        }
    }
    
    /// Load the most recent analysis result from Supabase
    private func loadLastAnalysisResult() async {
        do {
            // Get current user ID
            guard let userId = currentUserId else {
                print("❌ ProgressiveOverloadService: No user ID available for loading analysis")
                return
            }
            
            let response: [ProgressiveOverloadAnalysisRecord] = try await supabase
                .from("progressive_overload_analyses")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .order("analysis_date", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let record = response.first {
                // Convert back to ProgressiveOverloadResponse
                let progressiveOverloadResponse = ProgressiveOverloadResponse(
                    suggestions: record.suggestions,
                    summary: record.summary
                )
                
                await MainActor.run {
                    self.lastAnalysisResult = progressiveOverloadResponse
                }
                print("✅ ProgressiveOverloadService: Loaded existing analysis result from Supabase")
            } else {
                print("📋 ProgressiveOverloadService: No existing analysis found")
            }
            
        } catch {
            print("❌ ProgressiveOverloadService: Failed to load analysis result: \(error.localizedDescription)")
        }
    }
    
    /// Format exercise history for the AI prompt
    private func formatExerciseHistory(_ history: [WorkoutSet]) -> String {
        // Group by exercise name and format
        let groupedHistory = Dictionary(grouping: history) { $0.exerciseName }
        
        var formatted = ""
        for (exerciseName, sets) in groupedHistory.sorted(by: { $0.key < $1.key }) {
            formatted += "\n\(exerciseName):\n"
            
            // Sort by timestamp and show progression over time
            let sortedSets = sets.sorted { $0.timestamp < $1.timestamp }
            for set in sortedSets {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: set.timestamp)
                
                if set.exerciseType == "static_hold" {
                    formatted += "  \(dateString): \(Int(set.weight))lbs x \(Int(set.reps))s @ \(Int(set.rpe))% RPE\n"
                } else {
                    formatted += "  \(dateString): \(Int(set.weight))lbs x \(Int(set.reps)) reps @ \(Int(set.rpe))% RPE\n"
                }
            }
        }
        
        return formatted.isEmpty ? "No exercise history available" : formatted
    }
    
    /// Format current workout plan for the AI prompt
    private func formatCurrentWorkoutPlan(_ plan: DeepseekWorkoutPlan) -> String {
        let groupedPlan = Dictionary(grouping: plan.plan) { $0.dayOfWeek }
        
        var formatted = ""
        let daysOrder = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        
        for day in daysOrder {
            if let exercises = groupedPlan[day], !exercises.isEmpty {
                formatted += "\n\(day):\n"
                for exercise in exercises {
                    if exercise.exerciseType == "static_hold" {
                        formatted += "  \(exercise.exerciseName): \(exercise.sets) sets x \(exercise.reps)s\n"
                    } else {
                        formatted += "  \(exercise.exerciseName): \(exercise.sets) sets x \(exercise.reps) reps\n"
                    }
                }
            }
        }
        
        return formatted.isEmpty ? "No current workout plan available" : formatted
    }
}

// MARK: - Progressive overload API functionality moved to DeepseekAPIClient.swift to fix access issues