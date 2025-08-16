import Foundation

// MARK: - Custom Error Types
enum DeepseekError: Error, LocalizedError, Equatable {
    case couldNotUnderstand
    case apiError(String)
    case configurationError(String)
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .couldNotUnderstand:
            return "I couldn't understand your request. Please try rephrasing your request with more specific details about what you'd like to change in your workout plan."
        case .apiError(let message):
            return "API Error: \(message)"
        case .configurationError(let message):
            return "Configuration Error: \(message)"
        case .parsingError(let message):
            return "Parsing Error: \(message)"
        }
    }
}

struct DeepseekWorkoutPlanDay: Codable, Equatable {
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
    
    // Background-capable URLSession with extended timeout
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120 // 2 minutes
        config.timeoutIntervalForResource = 300 // 5 minutes
        config.waitsForConnectivity = true
        config.shouldUseExtendedBackgroundIdleMode = true
        return URLSession(configuration: config)
    }()

    private init() {}
    
    // MARK: - Background-Enabled Wrapper Methods
    
    func generateWorkoutPlanInBackground(
        personalDetails: PersonalDetails,
        preferences: WorkoutPreferences,
        taskId: String? = nil,
        completion: @escaping (Result<DeepseekWorkoutPlan, Error>) -> Void
    ) {
        let actualTaskId = taskId ?? "workout_plan_\(UUID().uuidString)"
        
        BackgroundTaskManager.shared.startBackgroundTask(
            id: actualTaskId,
            type: .workoutPlanGeneration,
            operation: {
                try await self.generateWorkoutPlan(personalDetails: personalDetails, preferences: preferences)
            },
            completion: { result in
                switch result {
                case .success(let plan):
                    ResultPersistenceManager.shared.saveWorkoutPlanResult(plan, taskId: actualTaskId)
                    completion(.success(plan))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    func editWorkoutPlanInBackground(
        editRequest: String,
        currentPlan: DeepseekWorkoutPlan,
        personalDetails: PersonalDetails,
        preferences: WorkoutPreferences,
        taskId: String? = nil,
        completion: @escaping (Result<DeepseekWorkoutPlan, Error>) -> Void
    ) {
        let actualTaskId = taskId ?? "workout_edit_\(UUID().uuidString)"
        
        BackgroundTaskManager.shared.startBackgroundTask(
            id: actualTaskId,
            type: .workoutPlanEdit,
            operation: {
                try await self.editWorkoutPlan(editRequest: editRequest, currentPlan: currentPlan, personalDetails: personalDetails, preferences: preferences)
            },
            completion: { result in
                switch result {
                case .success(let plan):
                    ResultPersistenceManager.shared.saveWorkoutPlanResult(plan, taskId: actualTaskId)
                    completion(.success(plan))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    func getMealFromDescriptionInBackground(
        userText: String,
        taskId: String? = nil,
        completion: @escaping (Result<DeepseekParsedMeal, Error>) -> Void
    ) {
        let actualTaskId = taskId ?? "macro_meal_\(UUID().uuidString)"
        
        BackgroundTaskManager.shared.startBackgroundTask(
            id: actualTaskId,
            type: .macroMealParsing,
            operation: {
                try await self.getMealFromDescription(userText: userText)
            },
            completion: { result in
                completion(result)
            }
        )
    }
    
    func getFitnessCoachResponseInBackground(
        userMessage: String,
        workoutService: WorkoutService,
        macroService: MacroService,
        taskId: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let actualTaskId = taskId ?? "fitness_chat_\(UUID().uuidString)"
        
        BackgroundTaskManager.shared.startBackgroundTask(
            id: actualTaskId,
            type: .fitnessCoachChat,
            operation: {
                try await self.getFitnessCoachResponse(userMessage: userMessage, workoutService: workoutService, macroService: macroService)
            },
            completion: { result in
                switch result {
                case .success(let response):
                    ResultPersistenceManager.shared.saveChatResponse(response, taskId: actualTaskId)
                    completion(.success(response))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }

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
        - "reps": Integer for repetition exercises (typically 6-15) OR 60 for timed exercises (planks, holds, etc.)
        - "exerciseType": null for regular exercises OR "static_hold" for timed exercises if they exist in plan (planks, wall sits, holds, etc.)
        - Return only the JSON - no markdown, no explanations, no code blocks

        Exercise Type Guidelines:
        - Regular exercises (squats, push-ups, bench press, etc.): reps = 6-15, exerciseType = null
        - If static hold exercises exist in plan (plank, wall sit, dead hang, hollow hold, side plank, etc.): reps = 0, exerciseType = "static_hold"

        Design Principles:
        - Honor the exact session frequency specified by the user—never add or omit training days.
        - For higher frequency splits (5+ days), distribute workout days across the entire week INCLUDING Saturday and Sunday. Do not avoid weekends.
        - For 6-day splits, include at least one weekend day (Saturday or Sunday). For 7-day splits, include both Saturday and Sunday.
        - Decide whit set/rep range the user would primarily work in for their bigger and main lifts based on their workout goals. Like when should it be 5 sets of 5 reps and when should it be 3 sets of 10 reps, 4 sets of 8 reps, etc
        - Match their equipment access and movement style preferences
        - Consider their experience level and goals
        - Organize each workout around the user's preferred split (full body, push/pull/legs, upper/lower, etc.)
        - Prioritize focus muscle groups with additional sets, angles, and exercises; give lower-priority areas only the minimum effective volume to maintain balance.
        - Lead sessions with large compound lifts for efficiency and strength, then layer accessory compounds and isolation work.
        - ONLY include core/ab exercises if: (1) the user specifically requests them, (2) they're in the "more focus" muscle groups, or (3) they're truly necessary for the training split. Do not automatically add core work as "finishers."
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
        let (data, response) = try await backgroundSession.data(for: request)
        
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
    
    // MARK: - Macro Parsing Models
    struct DeepseekMealItem: Codable {
        let name: String
        let quantity: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }

    struct DeepseekParsedMeal: Codable {
        let mealTitle: String
        let items: [DeepseekMealItem]
        let totals: MacroTotals
    }

    // MARK: - Macro Parsing
    func getMealFromDescription(userText: String) async throws -> DeepseekParsedMeal {
        guard Config.validateConfiguration() else {
            throw NSError(domain: "DeepseekAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API key not configured. Please set your API key in Config.swift"])
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = """
        You are a nutrition analyst AI. Parse the user's free-text description of what they ate into a structured meal JSON.

        Return ONLY a valid JSON object with this exact schema:
        {
          "mealTitle": "string", // short title inferred from description (e.g., "Breakfast", "Lunch", or key item)
          "items": [
            {
              "name": "string",
              "quantity": "string", // include units like "1 cup", "2 slices", "1 tbsp"
              "calories": number,
              "protein": number, // grams
              "carbs": number,   // grams
              "fat": number      // grams
            }
          ],
          "totals": {
            "calories": number,
            "protein": number,
            "carbs": number,
            "fat": number
          }
        }

        Rules:
        - Infer reasonable amounts only if missing; prefer using given quantities or brands if supplied
        - Keep items granular (bread, eggs, butter separately)
        - Use common nutrition references when unspecified
        - Never include markdown or code fences
        - If a branded product is mentioned, use typical values for that brand.
        - Adjust for cooking method (e.g., fried vs. baked) if possible.
        - For unclear amounts, infer the most likely serving size a person would consume in that context (e.g., "bowl of cereal" = 1 cup cereal + 1 cup milk unless otherwise stated).
        - Be realistic—avoid overestimation and underestimation.
        - If the user's input is gibberish, unclear, not about food, or impossible (e.g., "1 mountain"), respond with exactly: COULD_NOT_UNDERSTAND_REQUEST
        """

        let userPrompt = """
        User description of meal:
        \(userText)
        """

        let chatRequest = DeepseekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekRequestMessage(role: "system", content: systemPrompt),
                DeepseekRequestMessage(role: "user", content: userPrompt)
            ],
            stream: false,
            temperature: 0.3
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (data, response) = try await backgroundSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DeepseekAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let chatResponse = try JSONDecoder().decode(DeepseekChatResponse.self, from: data)
        guard var content = chatResponse.choices.first?.message.content else {
            throw NSError(domain: "DeepseekAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No content in API response"])
        }
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content == "COULD_NOT_UNDERSTAND_REQUEST" {
            throw DeepseekError.couldNotUnderstand
        }
        if content.hasPrefix("```") {
            if let firstNewline = content.firstIndex(of: "\n") { content = String(content[content.index(after: firstNewline)...]) }
            if content.hasSuffix("```") { content = String(content.dropLast(3)) }
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let contentData = content.data(using: .utf8) else {
            throw NSError(domain: "DeepseekAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"])
        }

        // Decode via a local wrapper that reuses MacroTotals from app domain
        let parsed = try JSONDecoder().decode(DeepseekParsedMeal.self, from: contentData)
        return parsed
    }

    func editMealFromRequest(editRequest: String, currentMeal: MacroMeal) async throws -> DeepseekParsedMeal {
        guard Config.validateConfiguration() else {
            throw NSError(domain: "DeepseekAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API key not configured. Please set your API key in Config.swift"])
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Encode current meal to JSON for context
        struct CurrentMealContext: Codable { let mealTitle: String; let items: [DeepseekMealItem]; let totals: MacroTotals }
        let items: [DeepseekMealItem] = currentMeal.items.map { DeepseekMealItem(name: $0.name, quantity: $0.quantityDescription, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat) }
        let context = CurrentMealContext(mealTitle: currentMeal.title, items: items, totals: currentMeal.totals)
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let contextString = String(data: try encoder.encode(context), encoding: .utf8) ?? "{}"

        let systemPrompt = """
        You are a nutrition analyst AI. Adjust the provided meal JSON according to the user's edit request (portion changes, substitutions, etc.).
        Return ONLY a valid JSON object with the same schema as before (mealTitle, items[], totals).
        Keep items granular and ensure totals equal the sum of items. No markdown.
        If the request is unclear, respond with exactly: COULD_NOT_UNDERSTAND_REQUEST
        """

        let userPrompt = """
        CURRENT MEAL (JSON):
        \(contextString)

        EDIT REQUEST:
        \(editRequest)
        """

        let chatRequest = DeepseekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepseekRequestMessage(role: "system", content: systemPrompt),
                DeepseekRequestMessage(role: "user", content: userPrompt)
            ],
            stream: false,
            temperature: 0.2
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)
        let (data, response) = try await backgroundSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DeepseekAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let chatResponse = try JSONDecoder().decode(DeepseekChatResponse.self, from: data)
        guard var content = chatResponse.choices.first?.message.content else {
            throw NSError(domain: "DeepseekAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No content in API response"])
        }
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content == "COULD_NOT_UNDERSTAND_REQUEST" {
            throw DeepseekError.couldNotUnderstand
        }
        if content.hasPrefix("```") {
            if let firstNewline = content.firstIndex(of: "\n") { content = String(content[content.index(after: firstNewline)...]) }
            if content.hasSuffix("```") { content = String(content.dropLast(3)) }
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let contentData = content.data(using: .utf8) else {
            throw NSError(domain: "DeepseekAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"])
        }
        let parsed = try JSONDecoder().decode(DeepseekParsedMeal.self, from: contentData)
        return parsed
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

        IMPORTANT: If the user's request is unclear, gibberish, nonsensical, or doesn't relate to workout planning, respond with exactly this text: "COULD_NOT_UNDERSTAND_REQUEST"

        Otherwise, return ONLY a valid JSON object in this exact format:
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
        - For higher frequency splits (5+ days), ensure workout days are distributed across the entire week INCLUDING Saturday and Sunday. Do not avoid weekends.
        - For 6-day splits, include at least one weekend day (Saturday or Sunday). For 7-day splits, include both Saturday and Sunday.
        - If adding exercises, ensure they fit logically with the existing workout split
        - If removing exercises, maintain balance across muscle groups unless specifically requested otherwise
        - ONLY include core/ab exercises if: (1) the user specifically requests them, (2) they're in the "more focus" muscle groups, or (3) they're truly necessary for the training split. Do not automatically add core work as "finishers."
        - Keep user's training experience, goals, and equipment access in mind
        - Maintain appropriate volume and intensity for their level

        Remember: If you can't understand the request or it's not related to workout editing, respond with "COULD_NOT_UNDERSTAND_REQUEST"
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
        let (data, response) = try await backgroundSession.data(for: request)
        
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
            
            // Check if DeepSeek couldn't understand the request
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedContent == "COULD_NOT_UNDERSTAND_REQUEST" {
                print("❌ DeepSeek could not understand the edit request")
                throw DeepseekError.couldNotUnderstand
            }
            
            // Clean the content - remove markdown code blocks if present
            var cleanedContent = trimmedContent
            
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
    
    // MARK: - Fitness Coach Chat
    
    func getFitnessCoachResponse(
        userMessage: String,
        workoutService: WorkoutService,
        macroService: MacroService
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
        let userData = await gatherUserDataForCoaching(workoutService: workoutService, macroService: macroService)
        
        print("🔄 DeepSeek API: Getting fitness coach response")
        print("💬 User Message: \(userMessage)")
        
        let systemPrompt = """
        You are an expert fitness coach and personal trainer and nutritionist with years of experience helping people achieve their fitness goals. You have access to the user's complete workout history, personal details, current training plan, meal, macros and nutrition history.

        Your role:
        - Act as a knowledgeable, encouraging, and supportive fitness coach
        - Provide evidence-based advice on training, technique, progression, recovery, and nutrition
        - Be conversational, friendly, and motivating
        - Answer questions about workouts, form, progress, macros, nutrition, and training strategies
        - Use the user's specific data to give personalized recommendations
        - Keep responses brief and to the point (1-2 short paragraphs maximum)
        - Use encouraging language and celebrate progress
        - Be to the point and don't unnessarily produce more text than needed.

        Context:
        - You have access to their complete workout history, nutrition data, and personal information
        - You can answer questions about any exercise in their program, nutrition intake, or general fitness topics
        - Reference their actual workout data, nutrition patterns, progress trends, and training history when relevant

        Guidelines:
        - Be encouraging and positive
        - Use their actual data to make specific recommendations
        - If they ask about specific exercises, reference their performance data for those exercises
        - If they ask about form, provide clear, actionable tips
        - If they ask about progress, analyze their data trends across exercises and nutrition
        - If they ask about programming, consider their experience level and goals
        - If they ask about nutrition or macros, reference their actual intake data and patterns
        - No need to include nutrition information if the user has only asked about a workout, and vice versa.
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
        let (data, response) = try await backgroundSession.data(for: request)
        
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
    private func gatherUserDataForCoaching(workoutService: WorkoutService, macroService: MacroService) async -> String {
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

        // Get user's macro and nutrition data
        let todayMeals = macroService.todayMeals
        let todayTotals = macroService.todayTotals
        
        if !todayMeals.isEmpty || todayTotals.calories > 0 {
            context += "TODAY'S NUTRITION:\n"
            context += formatTodayNutrition(meals: todayMeals, totals: todayTotals)
            context += "\n\n"
            
            // Get recent nutrition history
            let nutritionHistory = await macroService.fetchHistoryDays(limitDays: 30)
            if !nutritionHistory.isEmpty {
                context += "RECENT NUTRITION HISTORY (last 30 days):\n"
                context += formatNutritionHistory(nutritionHistory)
                context += "\n\n"
            }
        }
        
        return context.isEmpty ? "No workout or nutrition data available yet. This user is just getting started!" : context
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
    
    /// Format today's nutrition data for coaching context
    private func formatTodayNutrition(meals: [MacroMeal], totals: MacroTotals) -> String {
        var formatted = ""
        
        // Today's totals
        formatted += "Total for Today:\n"
        formatted += "- Calories: \(Int(totals.calories))\n"
        formatted += "- Protein: \(Int(totals.protein))g\n"
        formatted += "- Carbs: \(Int(totals.carbs))g\n"
        formatted += "- Fat: \(Int(totals.fat))g\n\n"
        
        // Individual meals
        if !meals.isEmpty {
            formatted += "Meals Today (\(meals.count) meals):\n"
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            
            for meal in meals {
                let timeString = dateFormatter.string(from: meal.createdAt)
                formatted += "\n\(timeString) - \(meal.title):\n"
                formatted += "  Calories: \(Int(meal.totals.calories)), "
                formatted += "Protein: \(Int(meal.totals.protein))g, "
                formatted += "Carbs: \(Int(meal.totals.carbs))g, "
                formatted += "Fat: \(Int(meal.totals.fat))g\n"
                
                // Show top 3 items for context
                let topItems = Array(meal.items.prefix(3))
                if !topItems.isEmpty {
                    formatted += "  Items: "
                    formatted += topItems.map { "\($0.name) (\($0.quantityDescription))" }.joined(separator: ", ")
                    if meal.items.count > 3 {
                        formatted += " and \(meal.items.count - 3) more"
                    }
                    formatted += "\n"
                }
            }
        }
        
        return formatted
    }
    
    /// Format nutrition history for coaching context
    private func formatNutritionHistory(_ history: [MacroDaySummary]) -> String {
        var formatted = ""
        
        // Get recent data (last 7 days for detailed view)
        let recentDays = Array(history.prefix(7))
        
        if !recentDays.isEmpty {
            formatted += "Last 7 days average:\n"
            let avgCalories = recentDays.reduce(0) { $0 + $1.totals.calories } / Double(recentDays.count)
            let avgProtein = recentDays.reduce(0) { $0 + $1.totals.protein } / Double(recentDays.count)
            let avgCarbs = recentDays.reduce(0) { $0 + $1.totals.carbs } / Double(recentDays.count)
            let avgFat = recentDays.reduce(0) { $0 + $1.totals.fat } / Double(recentDays.count)
            
            formatted += "- Calories: \(Int(avgCalories))/day\n"
            formatted += "- Protein: \(Int(avgProtein))g/day\n"
            formatted += "- Carbs: \(Int(avgCarbs))g/day\n"
            formatted += "- Fat: \(Int(avgFat))g/day\n\n"
        }
        
        // Show daily breakdown for last few days
        formatted += "Recent daily breakdown:\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for summary in recentDays {
            let dateString = dateFormatter.string(from: summary.date)
            formatted += "- \(dateString): \(Int(summary.totals.calories)) cal, "
            formatted += "\(Int(summary.totals.protein))p, "
            formatted += "\(Int(summary.totals.carbs))c, "
            formatted += "\(Int(summary.totals.fat))f "
            formatted += "(\(summary.mealsCount) meals)\n"
        }
        
        // Nutrition patterns and insights
        if history.count >= 7 {
            let totalDays = min(history.count, 30)
            let monthlyData = Array(history.prefix(totalDays))
            let avgDailyCalories = monthlyData.reduce(0) { $0 + $1.totals.calories } / Double(totalDays)
            let avgMealsPerDay = monthlyData.reduce(0) { $0 + $1.mealsCount } / totalDays
            
            formatted += "\nMonthly patterns (last \(totalDays) days):\n"
            formatted += "- Average daily calories: \(Int(avgDailyCalories))\n"
            formatted += "- Average meals per day: \(String(format: "%.1f", avgMealsPerDay))\n"
            formatted += "- Total days tracked: \(totalDays)\n"
        }
        
        return formatted
    }
} 