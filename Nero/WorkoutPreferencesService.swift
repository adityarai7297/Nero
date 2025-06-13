import Foundation
import Supabase

struct WorkoutPreferencesUpdate: Encodable {
    let primary_goal: String
    let training_experience: String
    let session_frequency: String
    let session_length: String
    let equipment_access: String
    let movement_styles: String
    let weekly_split: String
    let more_focus_muscle_groups: String
    let less_focus_muscle_groups: String
    let workout_preferences_updated_at: String
}

struct UserPreferencesResponse: Codable {
    let primary_goal: String?
    let training_experience: String?
    let session_frequency: String?
    let session_length: String?
    let equipment_access: String?
    let movement_styles: String?
    let weekly_split: String?
    let more_focus_muscle_groups: String?
    let less_focus_muscle_groups: String?
}

class WorkoutPreferencesService: ObservableObject {
    @Published var isSaving = false
    @Published var isGeneratingPlan = false
    @Published var errorMessage: String?
    
    func saveWorkoutPreferences(_ preferences: WorkoutPreferences) async -> Bool {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let updates = WorkoutPreferencesUpdate(
                primary_goal: preferences.primaryGoal.rawValue,
                training_experience: preferences.trainingExperience.rawValue,
                session_frequency: preferences.sessionFrequency.rawValue,
                session_length: preferences.sessionLength.rawValue,
                equipment_access: preferences.equipmentAccess.rawValue,
                movement_styles: preferences.movementStyles.map { $0.rawValue }.joined(separator: ","),
                weekly_split: preferences.weeklySplit.rawValue,
                more_focus_muscle_groups: preferences.moreFocusMuscleGroups.map { $0.rawValue }.joined(separator: ","),
                less_focus_muscle_groups: preferences.lessFocusMuscleGroups.map { $0.rawValue }.joined(separator: ","),
                workout_preferences_updated_at: Date().ISO8601String()
            )
            
            try await supabase
                .from("users")
                .update(updates)
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                self.isSaving = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save workout preferences: \(error.localizedDescription)"
                self.isSaving = false
            }
            return false
        }
    }
    
    func loadWorkoutPreferences() async -> WorkoutPreferences? {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let response: UserPreferencesResponse = try await supabase
                .from("users")
                .select("primary_goal, training_experience, session_frequency, session_length, equipment_access, movement_styles, weekly_split, more_focus_muscle_groups, less_focus_muscle_groups")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            var preferences = WorkoutPreferences()
            
            if let primaryGoal = response.primary_goal {
                preferences.primaryGoal = PrimaryGoal(rawValue: primaryGoal) ?? .notSure
            }
            if let trainingExperience = response.training_experience {
                preferences.trainingExperience = TrainingExperience(rawValue: trainingExperience) ?? .notSure
            }
            if let sessionFrequency = response.session_frequency {
                preferences.sessionFrequency = SessionFrequency(rawValue: sessionFrequency) ?? .notSure
            }
            if let sessionLength = response.session_length {
                preferences.sessionLength = SessionLength(rawValue: sessionLength) ?? .notSure
            }
            if let equipmentAccess = response.equipment_access {
                preferences.equipmentAccess = EquipmentAccess(rawValue: equipmentAccess) ?? .notSure
            }
            if let movementStyles = response.movement_styles, !movementStyles.isEmpty {
                let styleStrings = movementStyles.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                preferences.movementStyles = Set(styleStrings.compactMap { MovementStyles(rawValue: $0) })
            }
            if let weeklySplit = response.weekly_split {
                preferences.weeklySplit = WeeklySplit(rawValue: weeklySplit) ?? .notSure
            }
            if let moreFocusMuscleGroups = response.more_focus_muscle_groups, !moreFocusMuscleGroups.isEmpty {
                let groupStrings = moreFocusMuscleGroups.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                preferences.moreFocusMuscleGroups = Set(groupStrings.compactMap { MuscleGroup(rawValue: $0) })
            }
            if let lessFocusMuscleGroups = response.less_focus_muscle_groups, !lessFocusMuscleGroups.isEmpty {
                let groupStrings = lessFocusMuscleGroups.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                preferences.lessFocusMuscleGroups = Set(groupStrings.compactMap { MuscleGroup(rawValue: $0) })
            }
            
            return preferences
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load workout preferences: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // Save generated workout plan to Supabase
    func saveWorkoutPlan(_ plan: DeepseekWorkoutPlan) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // Create a proper encodable struct for Supabase insertion
            struct WorkoutPlanInsert: Encodable {
                let user_id: UUID
                let plan_json: DeepseekWorkoutPlan
                let created_at: String
                let updated_at: String
            }
            
            let insertData = WorkoutPlanInsert(
                user_id: userId,
                plan_json: plan,
                created_at: Date().ISO8601String(),
                updated_at: Date().ISO8601String()
            )
            
            _ = try await supabase
                .from("workout_plans")
                .insert(insertData)
                .execute()
            return true
        } catch {
            print("Failed to save workout plan: \(error.localizedDescription)")
            return false
        }
    }
    
    // Add this new method to handle the complete workflow
    func savePreferencesAndGeneratePlan(_ preferences: WorkoutPreferences) async -> Bool {
        // Step 1: Save preferences
        let preferencesSuccess = await saveWorkoutPreferences(preferences)
        if !preferencesSuccess {
            return false
        }
        
        // Step 2: Generate and save workout plan
        await MainActor.run {
            self.isGeneratingPlan = true
        }
        
        do {
            // Fetch personal details
            let personalDetailsService = PersonalDetailsService()
            guard let personalDetails = await personalDetailsService.loadPersonalDetails() else {
                await MainActor.run {
                    self.errorMessage = "Personal details not found. Please complete your personal details onboarding."
                    self.isGeneratingPlan = false
                }
                return false
            }
            
            // Call Deepseek API
            let plan = try await DeepseekAPIClient.shared.generateWorkoutPlan(personalDetails: personalDetails, preferences: preferences)
            
            // Save plan to Supabase
            let planSaved = await saveWorkoutPlan(plan)
            
            await MainActor.run {
                self.isGeneratingPlan = false
            }
            
            if !planSaved {
                await MainActor.run {
                    self.errorMessage = "Failed to save generated workout plan."
                }
                return false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate workout plan: \(error.localizedDescription)"
                self.isGeneratingPlan = false
            }
            return false
        }
    }
}

extension Date {
    func ISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
} 