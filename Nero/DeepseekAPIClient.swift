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

class DeepseekAPIClient {
    static let shared = DeepseekAPIClient()
    private let apiKey = "YOUR_DEEPSEEK_API_KEY" // Replace with your actual key
    private let endpoint = URL(string: "https://api.deepseek.com/v1/generate-workout-plan")!

    private init() {}

    func generateWorkoutPlan(personalDetails: PersonalDetails, preferences: WorkoutPreferences) async throws -> DeepseekWorkoutPlan {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = "Generate a 4 week workout plan for the user based on their preferences and personal details. The plan should be an array of objects with: Day of the week, Exercise Name, Sets, Reps."

        let payload: [String: Any] = [
            "personal_details": personalDetails.asDictionary(),
            "workout_preferences": preferences.asDictionary(),
            "prompt": prompt
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "DeepseekAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get valid response from Deepseek API"])
        }

        let plan = try JSONDecoder().decode(DeepseekWorkoutPlan.self, from: data)
        return plan
    }
}

// MARK: - Helpers for converting models to dictionary

extension PersonalDetails {
    func asDictionary() -> [String: Any] {
        return [
            "age": age,
            "gender": gender.rawValue,
            "height_feet": heightFeet,
            "height_inches": heightInches,
            "weight": weight,
            "body_fat_percentage": bodyFatPercentage,
            "activity_level": activityLevel.rawValue,
            "primary_fitness_goal": primaryFitnessGoal.rawValue,
            "injury_history": injuryHistory.rawValue,
            "sleep_hours": sleepHours.rawValue,
            "stress_level": stressLevel.rawValue,
            "workout_history": workoutHistory.rawValue
        ]
    }
}

extension WorkoutPreferences {
    func asDictionary() -> [String: Any] {
        return [
            "primary_goal": primaryGoal.rawValue,
            "training_experience": trainingExperience.rawValue,
            "session_frequency": sessionFrequency.rawValue,
            "session_length": sessionLength.rawValue,
            "equipment_access": equipmentAccess.rawValue,
            "movement_styles": movementStyles.rawValue,
            "weekly_split": weeklySplit.rawValue,
            "volume_tolerance": volumeTolerance.rawValue,
            "rep_ranges": repRanges.rawValue,
            "effort_level": effortLevel.rawValue,
            "eating_approach": eatingApproach.rawValue,
            "injury_considerations": injuryConsiderations.rawValue,
            "mobility_time": mobilityTime.rawValue,
            "busy_equipment_preference": busyEquipmentPreference.rawValue,
            "rest_periods": restPeriods.rawValue,
            "progression_style": progressionStyle.rawValue,
            "exercise_menu_change": exerciseMenuChange.rawValue,
            "recovery_resources": recoveryResources.rawValue,
            "programming_format": programmingFormat.rawValue
        ]
    }
} 