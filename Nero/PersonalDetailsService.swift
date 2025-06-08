import Foundation
import Supabase
import SwiftUI

class PersonalDetailsService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Save Personal Details
    
    func savePersonalDetails(_ details: PersonalDetails) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Get current user
            let user = try await supabase.auth.user()
            
            // Convert PersonalDetails to database format
            let updateData = UserPersonalDetailsUpdate(
                age: details.age,
                gender: details.gender.rawValue,
                height_feet: details.heightFeet,
                height_inches: details.heightInches,
                weight: details.weight,
                body_fat_percentage: details.bodyFatPercentage,
                activity_level: details.activityLevel.rawValue,
                primary_fitness_goal: details.primaryFitnessGoal.rawValue,
                injury_history: details.injuryHistory.rawValue,
                sleep_hours: details.sleepHours.rawValue,
                stress_level: details.stressLevel.rawValue,
                workout_history: details.workoutHistory.rawValue,
                personal_details_updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // Update user's personal details
            try await supabase
                .from("users")
                .update(updateData)
                .eq("id", value: user.id)
                .execute()
            
            await MainActor.run {
                self.isLoading = false
            }
            
            print("✅ Personal details saved successfully")
            return true
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save personal details: \(error.localizedDescription)"
                self.isLoading = false
            }
            
            print("❌ Failed to save personal details: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Load Personal Details
    
    func loadPersonalDetails() async -> PersonalDetails? {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Get current user
            let user = try await supabase.auth.user()
            
            // Fetch user's personal details
            let response: [UserPersonalDetails] = try await supabase
                .from("users")
                .select("""
                    age,
                    gender,
                    height_feet,
                    height_inches,
                    weight,
                    body_fat_percentage,
                    activity_level,
                    primary_fitness_goal,
                    injury_history,
                    sleep_hours,
                    stress_level,
                    workout_history
                """)
                .eq("id", value: user.id)
                .execute()
                .value
            
            await MainActor.run {
                self.isLoading = false
            }
            
            guard let userDetails = response.first else {
                print("ℹ️ No personal details found for user")
                return nil
            }
            
            // Convert database format to PersonalDetails
            let personalDetails = PersonalDetails(
                age: userDetails.age ?? 25,
                gender: Gender(rawValue: userDetails.gender ?? "") ?? .notSpecified,
                heightFeet: userDetails.height_feet ?? 5,
                heightInches: userDetails.height_inches ?? 8,
                weight: userDetails.weight ?? 150,
                bodyFatPercentage: userDetails.body_fat_percentage ?? 15,
                activityLevel: ActivityLevel(rawValue: userDetails.activity_level ?? "") ?? .moderatelyActive,
                primaryFitnessGoal: FitnessGoal(rawValue: userDetails.primary_fitness_goal ?? "") ?? .general,
                injuryHistory: InjuryHistory(rawValue: userDetails.injury_history ?? "") ?? .none,
                sleepHours: SleepHours(rawValue: userDetails.sleep_hours ?? "") ?? .sevenToEight,
                stressLevel: StressLevel(rawValue: userDetails.stress_level ?? "") ?? .moderate,
                workoutHistory: WorkoutHistory(rawValue: userDetails.workout_history ?? "") ?? .someExperience
            )
            
            print("✅ Personal details loaded successfully")
            return personalDetails
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load personal details: \(error.localizedDescription)"
                self.isLoading = false
            }
            
            print("❌ Failed to load personal details: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Check if Personal Details Exist
    
    func hasPersonalDetails() async -> Bool {
        do {
            let user = try await supabase.auth.user()
            
            let response: [UserPersonalDetailsCheck] = try await supabase
                .from("users")
                .select("personal_details_updated_at")
                .eq("id", value: user.id)
                .execute()
                .value
            
            guard let userCheck = response.first else {
                return false
            }
            
            return userCheck.personal_details_updated_at != nil
            
        } catch {
            print("❌ Failed to check personal details existence: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Database Models

struct UserPersonalDetails: Codable {
    let age: Int?
    let gender: String?
    let height_feet: Int?
    let height_inches: Int?
    let weight: Int?
    let body_fat_percentage: Int?
    let activity_level: String?
    let primary_fitness_goal: String?
    let injury_history: String?
    let sleep_hours: String?
    let stress_level: String?
    let workout_history: String?
}

struct UserPersonalDetailsUpdate: Codable {
    let age: Int
    let gender: String
    let height_feet: Int
    let height_inches: Int
    let weight: Int
    let body_fat_percentage: Int
    let activity_level: String
    let primary_fitness_goal: String
    let injury_history: String
    let sleep_hours: String
    let stress_level: String
    let workout_history: String
    let personal_details_updated_at: String
}

struct UserPersonalDetailsCheck: Codable {
    let personal_details_updated_at: String?
} 