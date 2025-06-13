import Foundation

struct DeepseekWorkoutPlanDay: Codable {
    let dayOfWeek: String
    let exerciseName: String
    let sets: Int
    let reps: Int
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
        You are a professional fitness coach and workout plan generator. Generate a comprehensive 4-week workout plan based on the user's personal details and workout preferences.
        
        CRITICAL: Return ONLY a valid JSON object with NO markdown formatting, NO code blocks, NO backticks, NO explanations.
        
        Use this EXACT format:
        {
          "plan": [
            {
              "dayOfWeek": "Monday",
              "exerciseName": "Squat",
              "sets": 3,
              "reps": 8
            },
            {
              "dayOfWeek": "Monday", 
              "exerciseName": "Bench Press",
              "sets": 3,
              "reps": 8
            },
            {
              "dayOfWeek": "Tuesday",
              "exerciseName": "Pull-ups",
              "sets": 3,
              "reps": 10
            }
          ]
        }
        
        Requirements:
        - Include exercises for all 4 weeks (Week 1: Monday-Friday, Week 2: Monday-Friday, etc.)
        - Each day should have 4-6 exercises
        - "sets" must be an integer (3, 4, etc.)
        - "reps" must be an integer (8, 10, 12, etc.) - NO strings like "60 sec"
        - "dayOfWeek" must be: Monday, Tuesday, Wednesday, Thursday, or Friday
        - "exerciseName" should be clear exercise names
        - DO NOT include any extra fields like "weightIncrease", "week", "days", etc.
        - Return raw JSON only - no markdown, no code blocks, no backticks
        """
        
        let userPrompt = """
        Personal Details:
        \(personalDetailsText)
        
        Workout Preferences:
        \(preferencesText)
        
        Please generate a 4-week workout plan based on this information.
        """

        let chatRequest = DeepseekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekRequestMessage(role: "system", content: systemPrompt),
                DeepseekRequestMessage(role: "user", content: userPrompt)
            ],
            stream: false,
            temperature: 0.7
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