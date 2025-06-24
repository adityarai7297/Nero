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
        - Respect the user's session frequency preference (number of sessions per week)
        - Match their equipment access and movement style preferences
        - Consider their experience level and goals
        - Consider the users workout split preferences (full body, push/pull/legs, upper/lower, etc.)
        - Use your fitness expertise to create a balanced, effective program
        - Include variety while maintaining focus on their primary goal
        - Pay attention to focus muscle groups and less focus muscle groups and make sure to include exercises that emphasize this
        - Take care to include appropriate sets, reps and general exercise volume
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