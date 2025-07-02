import Foundation
import SwiftUI

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

// MARK: - Progressive Overload Service

class ProgressiveOverloadService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var lastAnalysisResult: ProgressiveOverloadResponse?
    
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

// MARK: - Deepseek API Extension for Progressive Overload

extension DeepseekAPIClient {
    
    func analyzeProgressiveOverload(
        exerciseHistory: [WorkoutSet],
        currentWorkoutPlan: DeepseekWorkoutPlan,
        personalDetails: PersonalDetails,
        preferences: WorkoutPreferences
    ) async throws -> ProgressiveOverloadResponse {
        
        // Validate API key before making request
        guard Config.validateConfiguration() else {
            throw NSError(domain: "DeepseekAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API key not configured. Please set your API key in Config.swift"])
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Format the data for the prompt
        let historyText = formatExerciseHistoryForAPI(exerciseHistory)
        let planText = formatWorkoutPlanForAPI(currentWorkoutPlan)
        let personalDetailsText = formatPersonalDetails(personalDetails)
        let preferencesText = formatWorkoutPreferences(preferences)
        
        print("🔄 DeepSeek API: Analyzing progressive overload")
        print("📋 Exercise History: \(exerciseHistory.count) sets")
        print("🏋️ Current Plan: \(currentWorkoutPlan.plan.count) exercises")
        
        let systemPrompt = """
        SYSTEM PROMPT – Progressive‑Overload Recommendation Engine

        You are an expert strength‑and‑conditioning coach.
        Your task is to analyze a lifter's exercise history (up to 12 weeks) and recommend evidence‑based progressive‑overload or deload adjustments for every exercise currently in their program.
        Return only the JSON structure defined below—no markdown, code fences or additional text.

        ────────────────────────────────────────────────────────
        1. DATA PROVIDED
        • Exercise history (≤ 12 weeks): date, sets, reps, load, RPE (or %1 RM), optional notes.
        • Current workout plan: list of all exercises.
        • NOTE: New users may have limited or no exercise history - handle accordingly.

        ────────────────────────────────────────────────────────
        2. ANALYSIS CHECKLIST
        1) Consistency – frequency performed.
        2) Load/rep/set progression – rising, stalling, or falling.
        3) RPE level & trend:
           – <7.0 (70 %) → under‑loaded
           – 7.0‑8.5  → ideal adaptive zone
           – 8.6‑9.0  → high intensity
           – >9.0   → overreaching
        4) Plateaus – ≥ 2 weeks without performance change plus stable RPE.
        5) Recent changes – progressed or deloaded inside last 2 weeks.
        6) Load‑RPE relationship – is RPE appropriate for load used?
        7) For limited data: Use user profile to guide conservative recommendations.

        ────────────────────────────────────────────────────────
        3. DECISION RULES
        • RPE <7 and volume also low → increase reps first, then sets or load if RPE remains <7.
        • RPE <7 with high reps → small load ↑ or +1 set.
        • RPE 7–8.5 with steady gains → maintain or single small ↑.
        • RPE 8.6–9 with flat load → hold load; small volume ↑ only if progressing.
        • RPE >9 for ≥2 sessions OR rising RPE with flat/falling performance → deload (↓load and/or volume).
        • New exercise (<3 sessions) → change only one parameter.
        • Insufficient data → conservative recommendations based on user profile, or no change.
        • New users (no history) → provide conservative starting adjustments if current plan seems inappropriate for their experience level.

        ────────────────────────────────────────────────────────
        4. CHANGE MENU
        • Load: upper body +2.5‑5 kg (5‑10 lb); lower body +5‑10 kg (10‑20 lb).
        • Reps: +1‑3 (or −1‑3 for deload).
        • Sets: ±1 (rarely ±2).
        • Combination: up to 3 parameters only when clearly justified (e.g., RPE <6 for 2 weeks).

        ────────────────────────────────────────────────────────
        4a. EXERCISE‑TYPE GUIDELINES (infer via exerciseName)

        **Big Compound Movements**
        (e.g., back squat, front squat, deadlift variants, bench press, overhead press, barbell row, pull‑up, dip, Olympic lifts)
        • Primary progression = load.
        • Typical jumps: upper‑body +2.5‑5 kg, lower‑body +5‑10 kg.
        • Rep ↑ ≤2; set ↑ sparingly (+1) only after plateau.
        • Deload: 5‑15 % load drop or −1‑2 sets if systemic fatigue high.
        • Progress more slowly if weekly frequency ≥2; monitor global fatigue.

        **Isolation / Small‑Muscle Movements**
        (e.g., biceps curl, triceps extension, lateral raise, leg extension/curl, calf raise, face‑pull, reverse fly)
        • Primary progression = volume.
        • Prioritise +1‑3 reps or +1 set before load ↑.
        • Load jumps small: 1‑2 kg (2‑5 lb) or next machine plate.
        • Deload by reducing sets or reps first; large load cuts rarely required.
        • Higher weekly frequencies are tolerable.

        **Body‑weight or Machine‑stabilised Movements**
        (e.g., push‑up progressions, machine chest press, hack squat, smith‑machine variations)
        • If systemic demand high, treat like compounds; otherwise treat like isolation.
        • When reps >15 with RPE <7, add external resistance, tempo manipulation, or progress leverage.

        If an exercise name is ambiguous, classify by muscle mass and skill demand; default to isolation‑style increments when unsure.

        ────────────────────────────────────────────────────────
        5. OUTPUT SPECIFICATION
        Return exactly this JSON shape:

        {
          "suggestions": [
            {
              "exerciseName": "string",
              "suggestions": [
                {
                  "changeType": "sets | reps | weight",
                  "changeValue": number,
                  "reasoning": "≤40 words referencing RPE, trend, plateau, or recovery"
                }
                … (multiple allowed)
              ],
              "reasoning": "≤40 words – required even when suggestions array is empty"
            }
            … (one object per exercise in the current plan)
          ],
          "summary": "≤120 words summarising overall overload/deload strategy"
        }

        Rules:
        • Include every exercise from the current plan; use an empty suggestions array if no change is needed.
        • Reference RPE data in every reasoning field.
        • changeValue positive for increases, negative for reductions.
        • Output nothing except the JSON object.

        ────────────────────────────────────────────────────────
        END OF SYSTEM PROMPT
        """
        
        let userPrompt = """
        Analyze this user's exercise history and suggest progressive-overload changes:

        USER PROFILE:
        \(personalDetailsText)

        PREFERENCES:
        \(preferencesText)

        CURRENT WORKOUT PLAN:
        \(planText)

        EXERCISE HISTORY (Up to last 12 weeks - may be less for new users):
        \(historyText)

        CRITICAL REQUIREMENTS:
        1. Return exactly the JSON structure defined by the system prompt—nothing else.
        2. Include **every** exercise from the CURRENT WORKOUT PLAN in the output object.
        3. Classify each exercise as a big compound, isolation/small-muscle, or body-weight/machine movement (based on its name) and apply the corresponding progression guidelines.
        4. Base recommendations on available exercise history data (may be less than 12 weeks for new users):
           • Consistency • Load/Rep/Set trends • RPE level & trend • Plateau detection • Recent changes.
        5. For new users with limited or no history, provide conservative starting recommendations based on their profile and preferences.
        6. Suggest progressive-overload or deload adjustments only when the data support them; multiple parameter changes (sets + reps + weight) are allowed.
        7. If no change is warranted or insufficient data exists, output an empty `suggestions` array and a brief reasoning that references available data.
        8. For every change object use:  
           `"changeType": "sets" | "reps" | "weight", "changeValue": number` (positive = increase, negative = reduction) and `"reasoning"` ≤ 40 words citing RPE or trend evidence.

        Please analyze each exercise for:
        1. RPE PATTERNS: Are values consistently in the 70-90 % target range?
        2. RPE TRENDS: Is RPE stable, increasing, or decreasing over time?
        3. Progression trends (increasing/decreasing/stalled) relative to RPE changes
        4. Consistency of performance and RPE relationship
        5. Recent changes or improvements and how RPE responded
        6. Whether current load/volume is appropriate based on RPE feedback
        7. For exercises with limited history, consider user profile for appropriate starting parameters

        RPE-BASED DECISION MAKING:
        - RPE consistently <70 %: Ready for progressive overload (consider multiple parameter increases)
        - RPE 70-85 %: Monitor for progression opportunities (single or multiple changes)
        - RPE 85-90 %: Progress cautiously or maintain (conservative single changes only)
        - RPE >90 %: Consider deload or reduction (may need multiple parameter reductions)
        - Rising RPE trends: May indicate overreaching
        - Stable RPE with load increases: Good adaptation
        - Insufficient data: Provide conservative recommendations based on user profile

        COMBINATION CHANGE EXAMPLES:
        - Very low RPE (<65 %): Weight + reps increase together
        - Plateau breaking: Sets + weight adjustment
        - Volume progression: Sets + reps combination
        - Strength focus: Weight + sets increase
        - Overreaching recovery: Weight + reps reduction together
        - New users: Conservative single parameter adjustments to establish baseline

        Provide specific suggestions for sets, reps, or weight changes (or combinations thereof) following the exact JSON format specified, OR explain why no changes are needed for exercises that are progressing appropriately. For exercises with limited or no history, base recommendations on user profile and provide conservative starting adjustments. ALWAYS include available data analysis in your reasoning.
        """
        
        let chatRequest = DeepseekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekRequestMessage(role: "system", content: systemPrompt),
                DeepseekRequestMessage(role: "user", content: userPrompt)
            ],
            stream: false,
            temperature: 0.3 // Lower temperature for more consistent analysis
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
            print("✅ Progressive overload request body encoded successfully")
        } catch {
            print("❌ Failed to encode progressive overload request: \(error)")
            throw error
        }
        
        print("🌐 Making progressive overload API request to DeepSeek...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response type")
            throw NSError(domain: "DeepseekAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Deepseek API"])
        }
        
        print("📡 Progressive Overload API Response - Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Progressive Overload API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "DeepseekAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errorMessage)"])
        }
        
        // Debug: Print raw response data
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw Progressive Overload API Response: \(responseString)")
        }
        
        do {
            let chatResponse = try JSONDecoder().decode(DeepseekChatResponse.self, from: data)
            print("✅ Progressive overload chat response decoded successfully")
            
            guard let content = chatResponse.choices.first?.message.content else {
                print("❌ No content in progressive overload API response")
                throw NSError(domain: "DeepseekAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No content in API response"])
            }
            
            print("📝 Progressive overload content from API: \(content)")
            
            // Clean the content - remove markdown code blocks if present
            var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove markdown code blocks (```json ... ``` or ``` ... ```)
            if cleanedContent.hasPrefix("```") {
                // Find the first newline after ```
                if let firstNewline = cleanedContent.firstIndex(of: "\n") {
                    cleanedContent = String(cleanedContent[cleanedContent.index(after: firstNewline)...])
                }
                // Remove trailing ```
                if cleanedContent.hasSuffix("```") {
                    cleanedContent = String(cleanedContent.dropLast(3))
                }
                cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🧹 Cleaned progressive overload content (removed markdown): \(cleanedContent)")
            }
            
            // Parse the JSON content from the response
            guard let contentData = cleanedContent.data(using: .utf8) else {
                print("❌ Failed to convert progressive overload content to UTF-8 data")
                throw NSError(domain: "DeepseekAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response content to data"])
            }
            
            print("🔧 Attempting to parse progressive overload JSON...")
            do {
                let result = try JSONDecoder().decode(ProgressiveOverloadResponse.self, from: contentData)
                print("✅ Progressive overload analysis parsed successfully with \(result.suggestions.count) suggestions")
                
                // Simple validation
                if result.suggestions.isEmpty {
                    print("⚠️ Warning: No progressive overload suggestions provided")
                }
                
                print("✅ Progressive overload analysis validation passed")
                return result
                
            } catch {
                print("❌ Progressive overload JSON parsing error: \(error)")
                print("🔍 Content that failed to parse: \(cleanedContent)")
                
                // Try to provide more specific error information
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("🔍 Data corrupted: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("🔍 Key not found: \(key.stringValue) - \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("🔍 Type mismatch: \(type) - \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("🔍 Value not found: \(type) - \(context.debugDescription)")
                    @unknown default:
                        print("🔍 Unknown decoding error: \(error)")
                    }
                }
                
                throw NSError(domain: "DeepseekAPI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse progressive overload JSON: \(error.localizedDescription)"])
            }
        } catch {
            print("❌ Failed to decode progressive overload chat response: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods for Progressive Overload
    
    private func formatExerciseHistoryForAPI(_ history: [WorkoutSet]) -> String {
        if history.isEmpty {
            return "No exercise history available. This appears to be a new user who hasn't tracked any workouts yet."
        }
        
        // Calculate the actual time span of the data
        let sortedHistory = history.sorted { $0.timestamp < $1.timestamp }
        let timeSpanMessage: String
        
        if let earliestDate = sortedHistory.first?.timestamp,
           let latestDate = sortedHistory.last?.timestamp {
            let timeSpan = Calendar.current.dateComponents([.weekOfYear, .day], from: earliestDate, to: latestDate)
            let weeks = timeSpan.weekOfYear ?? 0
            let days = timeSpan.day ?? 0
            
            if weeks > 0 {
                timeSpanMessage = "Data spans approximately \(weeks) weeks"
            } else {
                timeSpanMessage = "Data spans \(days) days (less than 1 week)"
            }
        } else {
            timeSpanMessage = "Limited time range"
        }
        
        // Group by exercise name and format
        let groupedHistory = Dictionary(grouping: history) { $0.exerciseName }
        
        var formatted = "EXERCISE HISTORY (\(timeSpanMessage), \(history.count) total sets):\n"
        
        for (exerciseName, sets) in groupedHistory.sorted(by: { $0.key < $1.key }) {
            formatted += "\n\(exerciseName) (\(sets.count) sets):\n"
            
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
        
        return formatted
    }
    
    private func formatWorkoutPlanForAPI(_ plan: DeepseekWorkoutPlan) -> String {
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