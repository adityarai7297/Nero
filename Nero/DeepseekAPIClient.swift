import Foundation

struct DeepseekWorkoutPlanDay: Codable {
    let dayOfWeek: String
    let exerciseName: String
    let sets: Int
    let reps: Int
    let exerciseType: String? // Optional field for exercise type ("static_hold" for timed exercises)
}

struct DeepseekWorkoutPlan: Codable {
    let plan: [DeepseekWorkoutPlanDay]
}

// MARK: - API Response Models
struct DeepseekChatResponse: Codable {
    let choices: [DeepseekChoice]
}

struct DeepseekChoice: Codable {
    let message: DeepseekMessage
}

struct DeepseekMessage: Codable {
    let content: String
}

// MARK: - API Request Models
struct DeepseekChatRequest: Codable {
    let model: String
    let messages: [DeepseekRequestMessage]
    let stream: Bool
    let temperature: Double?
}

struct DeepseekRequestMessage: Codable {
    let role: String
    let content: String
}

class DeepseekAPIClient {
    static let shared = DeepseekAPIClient()
    private let apiKey = Config.deepseekAPIKey
    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    private init() {}

    func generateWorkoutPlan(personalDetails: PersonalDetails, preferences: WorkoutPreferences) async throws -> DeepseekWorkoutPlan {
        // Validate API key before making request
        guard Config.validateConfiguration() else {
            throw NSError(domain: "DeepseekAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API key not configured. Please set your API key in Config.swift"])
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Create a comprehensive prompt with user data
        let personalDetailsText = formatPersonalDetails(personalDetails)
        let preferencesText = formatWorkoutPreferences(preferences)
        
        print("🔄 DeepSeek API: Generating workout plan")
        print("📋 Personal Details: \(personalDetailsText)")
        print("🏋️ Preferences: \(preferencesText)")
        
        let systemPrompt = """
        You are an expert fitness coach. Create a personalized weekly workout plan based on the user's details and preferences. Use your expertise to design an effective program.

        Return ONLY a valid JSON object in this exact format:
        {
          "plan": [
            {
              "dayOfWeek": "Monday",
              "exerciseName": "Barbell Squat",
              "sets": 3,
              "reps": 8,
              "exerciseType": null
            },
            {
              "dayOfWeek": "Monday",
              "exerciseName": "Plank Hold",
              "sets": 3,
              "reps": 0,
              "exerciseType": "static_hold"
            }
          ]
        }

        JSON Requirements:
        - "dayOfWeek": Any day of the week (Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday)
        - "exerciseName": Specific exercise name
        - "sets": Integer (typically 2-5)
        - "reps": Integer for repetition exercises (typically 6-15) OR 0 for timed exercises (planks, holds, etc.)
        - "exerciseType": null for regular exercises OR "static_hold" for timed exercises if they exist in plan (planks, wall sits, holds, etc.)
        - Return only the JSON - no markdown, no explanations, no code blocks

        Exercise Type Guidelines:
        - Regular exercises (squats, push-ups, bench press, etc.): reps = 6-15, exerciseType = null
        - If static hold exercises exist in plan (plank, wall sit, dead hang, hollow hold, side plank, etc.): reps = 0, exerciseType = "static_hold"

        Design Principles:
        - Honor the exact session frequency specified by the user—never add or omit training days.
        - Match their equipment access and movement style preferences
        - Consider their experience level and goals
        - Organize each workout around the user's preferred split (full body, push/pull/legs, upper/lower, etc.)
        - Prioritize focus muscle groups with additional sets, angles, and exercises; give lower-priority areas only the minimum effective volume to maintain balance.
        - Lead sessions with large compound lifts for efficiency and strength, then layer accessory compounds and isolation work—finishing with core or metabolic/finisher drills if time permits.
        - Use your fitness expertise to create a balanced, effective program
        - Include variety while maintaining focus on their primary goal
        - Pay attention to focus muscle groups and less focus muscle groups and make sure to include exercises that emphasize this
        - Prescribe evidence-based hypertrophy parameters (Example: ≈ 6–12 reps for compounds, 8–15 for isolations, 2–5 sets) while ensuring total weekly volume (example: ≈ 10–20 hard sets per target muscle).
        """
        
        let userPrompt = """
        Create a workout plan for this user:

        Personal Details:
        \(personalDetailsText)

        Preferences:
        \(preferencesText)

        Use your expertise to design an effective weekly program that matches their preferences and constraints. Focus on their goal of \(preferences.primaryGoal.rawValue) with \(preferences.sessionFrequency.rawValue) sessions per week using \(preferences.equipmentAccess.rawValue).
        """

        let chatRequest = DeepseekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekRequestMessage(role: "system", content: systemPrompt),
                DeepseekRequestMessage(role: "user", content: userPrompt)
            ],
            stream: false,
            temperature: 0.7 // Balanced creativity and consistency
        )

        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
            print("✅ Request body encoded successfully")
        } catch {
            print("❌ Failed to encode request: \(error)")
            throw error
        }

        print("🌐 Making API request to DeepSeek...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response type")
            throw NSError(domain: "DeepseekAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Deepseek API"])
        }
        
        print("📡 API Response - Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "DeepseekAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errorMessage)"])
        }

        // Debug: Print raw response data
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw API Response: \(responseString)")
        }

        do {
            let chatResponse = try JSONDecoder().decode(DeepseekChatResponse.self, from: data)
            print("✅ Chat response decoded successfully")
            
            guard let content = chatResponse.choices.first?.message.content else {
                print("❌ No content in API response")
                throw NSError(domain: "DeepseekAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No content in API response"])
            }
            
            print("📝 Content from API: \(content)")
            
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
                print("🧹 Cleaned content (removed markdown): \(cleanedContent)")
            }
            
            // Parse the JSON content from the response
            guard let contentData = cleanedContent.data(using: .utf8) else {
                print("❌ Failed to convert content to UTF-8 data")
                throw NSError(domain: "DeepseekAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response content to data"])
            }
            
            print("🔧 Attempting to parse workout plan JSON...")
            do {
                let plan = try JSONDecoder().decode(DeepseekWorkoutPlan.self, from: contentData)
                print("✅ Workout plan parsed successfully with \(plan.plan.count) exercises")
                
                // Simple validation - just basic sanity checks
                if plan.plan.isEmpty {
                    throw NSError(domain: "DeepseekAPI", code: 5, userInfo: [NSLocalizedDescriptionKey: "Generated plan is empty"])
                }
                
                // Check for obviously invalid data
                for exercise in plan.plan {
                    if exercise.sets < 1 || exercise.sets > 10 {
                        print("⚠️ Warning: Unusual sets count for \(exercise.exerciseName): \(exercise.sets)")
                    }
                    if exercise.reps < 0 {
                        throw NSError(domain: "DeepseekAPI", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid negative reps for \(exercise.exerciseName)"])
                    }
                }
                
                print("✅ Plan validation passed - \(plan.plan.count) exercises across \(Set(plan.plan.map { $0.dayOfWeek }).count) days")
                return plan
            } catch {
                print("❌ JSON parsing error: \(error)")
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
                
                throw NSError(domain: "DeepseekAPI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse workout plan JSON: \(error.localizedDescription)"])
            }
        } catch {
            print("❌ Failed to decode chat response: \(error)")
            throw error
        }
    }
    
    func editWorkoutPlan(editRequest: String, currentPlan: DeepseekWorkoutPlan, personalDetails: PersonalDetails, preferences: WorkoutPreferences) async throws -> DeepseekWorkoutPlan {
        // Validate API key before making request
        guard Config.validateConfiguration() else {
            throw NSError(domain: "DeepseekAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API key not configured. Please set your API key in Config.swift"])
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Format the current workout plan as JSON string
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let currentPlanData = try encoder.encode(currentPlan)
        let currentPlanString = String(data: currentPlanData, encoding: .utf8) ?? "Unable to encode current plan"
        
        // Create context with user data
        let personalDetailsText = formatPersonalDetails(personalDetails)
        let preferencesText = formatWorkoutPreferences(preferences)
        
        print("🔄 DeepSeek API: Editing workout plan")
        print("✏️ Edit Request: \(editRequest)")
        print("📋 Current Plan: \(currentPlanString)")
        
        let systemPrompt = """
        You are an expert fitness coach. The user has an existing workout plan and wants to make specific changes to it. Modify the plan according to their request while keeping the same JSON format.

        Return ONLY a valid JSON object in this exact format:
        {
          "plan": [
            {
              "dayOfWeek": "Monday",
              "exerciseName": "Barbell Squat",
              "sets": 3,
              "reps": 8,
              "exerciseType": null
            },
            {
              "dayOfWeek": "Monday",
              "exerciseName": "Plank Hold",
              "sets": 3,
              "reps": 0,
              "exerciseType": "static_hold"
            }
          ]
        }

        JSON Requirements:
        - "dayOfWeek": Any day of the week (Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday)
        - "exerciseName": Specific exercise name
        - "sets": Integer (typically 2-5)
        - "reps": Integer for repetition exercises (typically 6-15) OR 0 for timed exercises (planks, holds, etc.)
        - "exerciseType": null for regular exercises OR "static_hold" for timed exercises (planks, wall sits, holds, etc.)
        - Return only the JSON - no markdown, no explanations, no code blocks

        Exercise Type Guidelines:
        - Regular exercises (squats, push-ups, bench press, etc.): reps = 6-15, exerciseType = null
        - Static hold exercises (plank, wall sit, dead hang, hollow body hold, side plank, etc.): reps = 0, exerciseType = "static_hold"

        Editing Guidelines:
        - Make the requested changes while preserving the overall structure and balance of the plan
        - If adding exercises, ensure they fit logically with the existing workout split
        - If removing exercises, maintain balance across muscle groups unless specifically requested otherwise
        - Keep user's training experience, goals, and equipment access in mind
        - Maintain appropriate volume and intensity for their level
        """
        
        let userPrompt = """
        Here is my current workout plan:
        \(currentPlanString)

        My personal details:
        \(personalDetailsText)

        My preferences:
        \(preferencesText)

        Please modify my workout plan with this change: \(editRequest)

        Provide the updated complete workout plan in the required JSON format, incorporating the requested changes while maintaining balance and effectiveness.
        """

        let chatRequest = DeepseekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekRequestMessage(role: "system", content: systemPrompt),
                DeepseekRequestMessage(role: "user", content: userPrompt)
            ],
            stream: false,
            temperature: 0.7 // Balanced creativity and consistency
        )

        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
            print("✅ Edit request body encoded successfully")
        } catch {
            print("❌ Failed to encode edit request: \(error)")
            throw error
        }

        print("🌐 Making edit API request to DeepSeek...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response type")
            throw NSError(domain: "DeepseekAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Deepseek API"])
        }
        
        print("📡 Edit API Response - Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Edit API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "DeepseekAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errorMessage)"])
        }

        // Debug: Print raw response data
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw Edit API Response: \(responseString)")
        }

        do {
            let chatResponse = try JSONDecoder().decode(DeepseekChatResponse.self, from: data)
            print("✅ Edit chat response decoded successfully")
            
            guard let content = chatResponse.choices.first?.message.content else {
                print("❌ No content in edit API response")
                throw NSError(domain: "DeepseekAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No content in API response"])
            }
            
            print("📝 Edit content from API: \(content)")
            
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
                print("🧹 Cleaned edit content (removed markdown): \(cleanedContent)")
            }
            
            // Parse the JSON content from the response
            guard let contentData = cleanedContent.data(using: .utf8) else {
                print("❌ Failed to convert edit content to UTF-8 data")
                throw NSError(domain: "DeepseekAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response content to data"])
            }
            
            print("🔧 Attempting to parse edited workout plan JSON...")
            do {
                let plan = try JSONDecoder().decode(DeepseekWorkoutPlan.self, from: contentData)
                print("✅ Edited workout plan parsed successfully with \(plan.plan.count) exercises")
                
                // Simple validation - just basic sanity checks
                if plan.plan.isEmpty {
                    throw NSError(domain: "DeepseekAPI", code: 5, userInfo: [NSLocalizedDescriptionKey: "Edited plan is empty"])
                }
                
                // Check for obviously invalid data
                for exercise in plan.plan {
                    if exercise.sets < 1 || exercise.sets > 10 {
                        print("⚠️ Warning: Unusual sets count for \(exercise.exerciseName): \(exercise.sets)")
                    }
                    if exercise.reps < 0 {
                        throw NSError(domain: "DeepseekAPI", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid negative reps for \(exercise.exerciseName)"])
                    }
                }
                
                print("✅ Edit plan validation passed - \(plan.plan.count) exercises across \(Set(plan.plan.map { $0.dayOfWeek }).count) days")
                return plan
            } catch {
                print("❌ Edit JSON parsing error: \(error)")
                print("🔍 Edit content that failed to parse: \(cleanedContent)")
                
                // Try to provide more specific error information
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("🔍 Edit data corrupted: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("🔍 Edit key not found: \(key.stringValue) - \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("🔍 Edit type mismatch: \(type) - \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("🔍 Edit value not found: \(type) - \(context.debugDescription)")
                    @unknown default:
                        print("🔍 Unknown edit decoding error: \(error)")
                    }
                }
                
                throw NSError(domain: "DeepseekAPI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse edited workout plan JSON: \(error.localizedDescription)"])
            }
        } catch {
            print("❌ Failed to decode edit chat response: \(error)")
            throw error
        }
    }
    
    // MARK: - Progressive Overload Analysis
    
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
        let historyText = formatExerciseHistoryForProgressiveOverload(exerciseHistory)
        let planText = formatWorkoutPlanForProgressiveOverload(currentWorkoutPlan)
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
            var cleanedContent = content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
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
                cleanedContent = cleanedContent.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                print("🧹 Cleaned progressive overload content (removed markdown): \(cleanedContent)")
            }
            
            // Parse the JSON content from the response
            guard let contentData = cleanedContent.data(using: String.Encoding.utf8) else {
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
    
    // MARK: - Fitness Coach Chat
    
    func getFitnessCoachResponse(
        userMessage: String,
        workoutService: WorkoutService
    ) async throws -> String {
        // Validate API key before making request
        guard Config.validateConfiguration() else {
            throw NSError(domain: "DeepseekAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API key not configured. Please set your API key in Config.swift"])
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Gather comprehensive user data
        let userData = await gatherUserDataForCoaching(workoutService: workoutService)
        
        print("🔄 DeepSeek API: Getting fitness coach response")
        print("💬 User Message: \(userMessage)")
        
        let systemPrompt = """
        You are an expert fitness coach and personal trainer with years of experience helping people achieve their fitness goals. You have access to the user's complete workout history, personal details, and current training plan.

        Your role:
        - Act as a knowledgeable, encouraging, and supportive fitness coach
        - Provide evidence-based advice on training, technique, progression, and recovery
        - Be conversational, friendly, and motivating
        - Answer questions about workouts, form, progress, nutrition basics, and training strategies
        - Use the user's specific data to give personalized recommendations
        - Keep responses brief and to the point (1-2 short paragraphs maximum)
        - Use encouraging language and celebrate progress

        Context:
        - You have access to their complete workout history and personal information
        - You can answer questions about any exercise in their program or general fitness topics
        - Reference their actual workout data, progress trends, and training history when relevant

        Guidelines:
        - Be encouraging and positive
        - Use their actual data to make specific recommendations
        - If they ask about specific exercises, reference their performance data for those exercises
        - If they ask about form, provide clear, actionable tips
        - If they ask about progress, analyze their data trends across all exercises
        - If they ask about programming, consider their experience level and goals
        - Always prioritize safety and proper progression
        - You can suggest modifications to their current workout plan
        - Keep medical advice general and suggest consulting professionals for specific issues
        - Answer general fitness questions even if not directly related to their specific data
        - NEVER ask the user to send videos, images, or any media files
        - Keep responses concise and actionable - avoid lengthy explanations
        - Use markdown formatting for better readability: **bold** for emphasis, *italics* for exercise names, and bullet points for lists
        - Format exercise names in italics (e.g., *Bench Press*, *Squat*)
        - Use **bold** for key points and important advice
        - Use bullet points (•) for lists of tips or recommendations
        """
        
        let userPrompt = """
        User's Question: \(userMessage)
        
        User's Complete Fitness Profile:
        \(userData)
        
        Please provide a helpful, personalized response as their fitness coach. Use their specific data when relevant to give targeted advice.
        """
        
        let chatRequest = DeepseekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekRequestMessage(role: "system", content: systemPrompt),
                DeepseekRequestMessage(role: "user", content: userPrompt)
            ],
            stream: false,
            temperature: 0.7 // Balanced for personable but consistent coaching
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
            print("✅ Fitness coach request body encoded successfully")
        } catch {
            print("❌ Failed to encode fitness coach request: \(error)")
            throw error
        }
        
        print("🌐 Making fitness coach API request to DeepSeek...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response type")
            throw NSError(domain: "DeepseekAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Deepseek API"])
        }
        
        print("📡 Fitness Coach API Response - Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Fitness Coach API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "DeepseekAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errorMessage)"])
        }
        
        do {
            let chatResponse = try JSONDecoder().decode(DeepseekChatResponse.self, from: data)
            print("✅ Fitness coach chat response decoded successfully")
            
            guard let content = chatResponse.choices.first?.message.content else {
                print("❌ No content in fitness coach API response")
                throw NSError(domain: "DeepseekAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No content in API response"])
            }
            
            print("📝 Fitness coach content from API: \(content.prefix(200))...")
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch {
            print("❌ Failed to decode fitness coach chat response: \(error)")
            throw error
        }
    }
    
    /// Gather comprehensive user data for fitness coaching context
    private func gatherUserDataForCoaching(workoutService: WorkoutService) async -> String {
        var context = ""
        
        // Get user's personal details
        let personalDetailsService = PersonalDetailsService()
        if let personalDetails = await personalDetailsService.loadPersonalDetails() {
            context += "PERSONAL PROFILE:\n"
            context += formatPersonalDetails(personalDetails)
            context += "\n\n"
        }
        
        // Get user's workout preferences
        let preferencesService = WorkoutPreferencesService()
        if let preferences = await preferencesService.loadWorkoutPreferences() {
            context += "WORKOUT PREFERENCES:\n"
            context += formatWorkoutPreferences(preferences)
            context += "\n\n"
        }
        
        // Get current workout plan
        if let currentPlan = await preferencesService.loadCurrentWorkoutPlan() {
            context += "CURRENT WORKOUT PLAN:\n"
            context += formatWorkoutPlanForCoaching(currentPlan)
            context += "\n\n"
        }
        
        // Get all user exercises and their data
        let allExercises = await workoutService.fetchAllUserExercises()
        if !allExercises.isEmpty {
            context += "ALL EXERCISE HISTORY AND STATISTICS:\n"
            
            for exerciseName in allExercises {
                context += "\n--- \(exerciseName.uppercased()) ---\n"
                
                // Get exercise history
                let exerciseHistory = await workoutService.fetchExerciseHistory(exerciseName: exerciseName, timeframe: .all)
                if !exerciseHistory.isEmpty {
                    context += "Recent History:\n"
                    context += formatExerciseHistoryForCoaching(exerciseHistory)
                    context += "\n"
                }
                
                // Get exercise stats
                if let stats = await workoutService.getExerciseStats(exerciseName: exerciseName) {
                    context += "Statistics:\n"
                    context += formatExerciseStats(stats)
                    context += "\n"
                }
            }
            context += "\n"
        }
        
        // Get recent overall workout history for broader context
        if let recentHistory = await workoutService.fetchUpToLast12WeeksHistory() {
            if !recentHistory.isEmpty {
                context += "RECENT PERFORMANCE TRENDS (All Exercises - Last 12 weeks):\n"
                context += formatAllExercisesTrends(recentHistory)
                context += "\n\n"
            }
        }
        
        return context.isEmpty ? "No workout data available yet. This user is just getting started!" : context
    }
    
    /// Format workout plan specifically for coaching context
    private func formatWorkoutPlanForCoaching(_ plan: DeepseekWorkoutPlan) -> String {
        let groupedByDay = Dictionary(grouping: plan.plan) { $0.dayOfWeek }
        var formatted = ""
        
        let daysOrder = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        
        for day in daysOrder {
            if let exercises = groupedByDay[day] {
                formatted += "\(day):\n"
                for exercise in exercises {
                    if exercise.exerciseType == "static_hold" {
                        formatted += "  - \(exercise.exerciseName): \(exercise.sets) sets x \(exercise.reps) seconds\n"
                    } else {
                        formatted += "  - \(exercise.exerciseName): \(exercise.sets) sets x \(exercise.reps) reps\n"
                    }
                }
                formatted += "\n"
            }
        }
        
        return formatted
    }
    
    /// Format exercise history specifically for coaching context
    private func formatExerciseHistoryForCoaching(_ history: [WorkoutSet]) -> String {
        let sortedHistory = history.sorted { $0.timestamp < $1.timestamp }
        var formatted = ""
        
        // Show last 10 workouts for this exercise
        let recentHistory = Array(sortedHistory.suffix(10))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for set in recentHistory {
            let dateString = dateFormatter.string(from: set.timestamp)
            if set.exerciseType == "static_hold" {
                formatted += "- \(dateString): \(Int(set.weight))lbs x \(Int(set.reps)) seconds @ \(Int(set.rpe))% effort\n"
            } else {
                formatted += "- \(dateString): \(Int(set.weight))lbs x \(Int(set.reps)) reps @ \(Int(set.rpe))% effort\n"
            }
        }
        
        return formatted
    }
    
    /// Format exercise statistics for coaching context
    private func formatExerciseStats(_ stats: ExerciseStats) -> String {
        var formatted = ""
        formatted += "Total Sets Completed: \(stats.totalSets)\n"
        formatted += "Max Weight Achieved: \(Int(stats.maxWeight)) lbs\n"
        formatted += "Average Weight: \(Int(stats.averageWeight)) lbs\n"
        formatted += "Max Volume: \(Int(stats.maxVolume)) lbs×reps\n"
        formatted += "Average Volume: \(Int(stats.averageVolume)) lbs×reps\n"
        
        if let firstWorkout = stats.firstWorkout {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatted += "First Workout: \(formatter.string(from: firstWorkout))\n"
        }
        
        if let lastWorkout = stats.lastWorkout {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatted += "Most Recent Workout: \(formatter.string(from: lastWorkout))\n"
        }
        
        return formatted
    }
    
    /// Format recent performance trends for coaching insights
    private func formatRecentTrends(_ recentHistory: [WorkoutSet]) -> String {
        guard !recentHistory.isEmpty else { return "No recent data available" }
        
        let sortedHistory = recentHistory.sorted { $0.timestamp < $1.timestamp }
        var formatted = ""
        
        // Calculate trends
        let weights = sortedHistory.map { Double($0.weight) }
        let volumes = sortedHistory.map { Double($0.weight * $0.reps) }
        let rpes = sortedHistory.map { Double($0.rpe) }
        
        if let firstWeight = weights.first, let lastWeight = weights.last {
            let weightChange = lastWeight - firstWeight
            let weightChangePercent = (weightChange / firstWeight) * 100
            formatted += "Weight Progress: \(weightChange > 0 ? "+" : "")\(Int(weightChange)) lbs (\(String(format: "%.1f", weightChangePercent))%)\n"
        }
        
        if let firstVolume = volumes.first, let lastVolume = volumes.last {
            let volumeChange = lastVolume - firstVolume
            let volumeChangePercent = (volumeChange / firstVolume) * 100
            formatted += "Volume Progress: \(volumeChange > 0 ? "+" : "")\(Int(volumeChange)) lbs×reps (\(String(format: "%.1f", volumeChangePercent))%)\n"
        }
        
        let averageRPE = rpes.reduce(0, +) / Double(rpes.count)
        formatted += "Average Effort Level: \(Int(averageRPE))% RPE\n"
        formatted += "Total Sets in Period: \(sortedHistory.count)\n"
        
        return formatted
    }
    
    /// Format recent performance trends for all exercises
    private func formatAllExercisesTrends(_ recentHistory: [WorkoutSet]) -> String {
        guard !recentHistory.isEmpty else { return "No recent data available" }
        
        // Group by exercise
        let groupedHistory = Dictionary(grouping: recentHistory) { $0.exerciseName }
        var formatted = ""
        
        for (exerciseName, sets) in groupedHistory.sorted(by: { $0.key < $1.key }) {
            formatted += "\n\(exerciseName):\n"
            
            let sortedSets = sets.sorted { $0.timestamp < $1.timestamp }
            
            // Calculate trends for this exercise
            let weights = sortedSets.map { Double($0.weight) }
            let volumes = sortedSets.map { Double($0.weight * $0.reps) }
            let rpes = sortedSets.map { Double($0.rpe) }
            
            if let firstWeight = weights.first, let lastWeight = weights.last, weights.count > 1 {
                let weightChange = lastWeight - firstWeight
                let weightChangePercent = (weightChange / firstWeight) * 100
                formatted += "  Weight Progress: \(weightChange > 0 ? "+" : "")\(Int(weightChange)) lbs (\(String(format: "%.1f", weightChangePercent))%)\n"
            }
            
            if let firstVolume = volumes.first, let lastVolume = volumes.last, volumes.count > 1 {
                let volumeChange = lastVolume - firstVolume
                let volumeChangePercent = (volumeChange / firstVolume) * 100
                formatted += "  Volume Progress: \(volumeChange > 0 ? "+" : "")\(Int(volumeChange)) lbs×reps (\(String(format: "%.1f", volumeChangePercent))%)\n"
            }
            
            if !rpes.isEmpty {
                let averageRPE = rpes.reduce(0, +) / Double(rpes.count)
                formatted += "  Average Effort: \(Int(averageRPE))% RPE\n"
            }
            
            formatted += "  Total Sets: \(sortedSets.count)\n"
        }
        
        return formatted
    }
    
    // MARK: - Helper Methods for Progressive Overload
    
    private func formatExerciseHistoryForProgressiveOverload(_ history: [WorkoutSet]) -> String {
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
    
    private func formatWorkoutPlanForProgressiveOverload(_ plan: DeepseekWorkoutPlan) -> String {
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
    
    // MARK: - Helper Methods
    private func formatPersonalDetails(_ details: PersonalDetails) -> String {
        return """
        Age: \(details.age)
        Gender: \(details.gender.rawValue)
        Height: \(details.heightFeet)'\(details.heightInches)"
        Weight: \(details.weight) lbs
        Body Fat: \(details.bodyFatPercentage)%
        Activity Level: \(details.activityLevel.rawValue)
        Primary Fitness Goal: \(details.primaryFitnessGoal.rawValue)
        Injury History: \(details.injuryHistory.rawValue)
        Sleep Hours: \(details.sleepHours.rawValue)
        Stress Level: \(details.stressLevel.rawValue)
        Workout History: \(details.workoutHistory.rawValue)
        """
    }
    
    private func formatWorkoutPreferences(_ preferences: WorkoutPreferences) -> String {
        let movementStylesText = preferences.movementStyles.isEmpty ? "No preference" : preferences.movementStyles.map { $0.rawValue }.joined(separator: ", ")
        let moreFocusText = preferences.moreFocusMuscleGroups.isEmpty ? "No specific focus" : preferences.moreFocusMuscleGroups.map { $0.rawValue }.joined(separator: ", ")
        let lessFocusText = preferences.lessFocusMuscleGroups.isEmpty ? "No specific restrictions" : preferences.lessFocusMuscleGroups.map { $0.rawValue }.joined(separator: ", ")
        
        return """
        Primary Goal: \(preferences.primaryGoal.rawValue)
        Training Experience: \(preferences.trainingExperience.rawValue)
        Session Frequency: \(preferences.sessionFrequency.rawValue) per week
        Session Length: \(preferences.sessionLength.rawValue)
        Equipment Access: \(preferences.equipmentAccess.rawValue)
        Movement Styles: \(movementStylesText)
        Weekly Split: \(preferences.weeklySplit.rawValue)
        More Focus Muscle Groups: \(moreFocusText)
        Less Focus Muscle Groups: \(lessFocusText)
        """
    }
} 