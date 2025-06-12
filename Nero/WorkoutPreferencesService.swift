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
    let volume_tolerance: String
    let rep_ranges: String
    let effort_level: String
    let eating_approach: String
    let injury_considerations: String
    let mobility_time: String
    let busy_equipment_preference: String
    let rest_periods: String
    let progression_style: String
    let exercise_menu_change: String
    let recovery_resources: String
    let programming_format: String
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
    let volume_tolerance: String?
    let rep_ranges: String?
    let effort_level: String?
    let eating_approach: String?
    let injury_considerations: String?
    let mobility_time: String?
    let busy_equipment_preference: String?
    let rest_periods: String?
    let progression_style: String?
    let exercise_menu_change: String?
    let recovery_resources: String?
    let programming_format: String?
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
                movement_styles: preferences.movementStyles.rawValue,
                weekly_split: preferences.weeklySplit.rawValue,
                volume_tolerance: preferences.volumeTolerance.rawValue,
                rep_ranges: preferences.repRanges.rawValue,
                effort_level: preferences.effortLevel.rawValue,
                eating_approach: preferences.eatingApproach.rawValue,
                injury_considerations: preferences.injuryConsiderations.rawValue,
                mobility_time: preferences.mobilityTime.rawValue,
                busy_equipment_preference: preferences.busyEquipmentPreference.rawValue,
                rest_periods: preferences.restPeriods.rawValue,
                progression_style: preferences.progressionStyle.rawValue,
                exercise_menu_change: preferences.exerciseMenuChange.rawValue,
                recovery_resources: preferences.recoveryResources.rawValue,
                programming_format: preferences.programmingFormat.rawValue,
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
                .select("primary_goal, training_experience, session_frequency, session_length, equipment_access, movement_styles, weekly_split, volume_tolerance, rep_ranges, effort_level, eating_approach, injury_considerations, mobility_time, busy_equipment_preference, rest_periods, progression_style, exercise_menu_change, recovery_resources, programming_format")
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
            if let movementStyles = response.movement_styles {
                preferences.movementStyles = MovementStyles(rawValue: movementStyles) ?? .noPreference
            }
            if let weeklySplit = response.weekly_split {
                preferences.weeklySplit = WeeklySplit(rawValue: weeklySplit) ?? .notSure
            }
            if let volumeTolerance = response.volume_tolerance {
                preferences.volumeTolerance = VolumeTolerance(rawValue: volumeTolerance) ?? .notSure
            }
            if let repRanges = response.rep_ranges {
                preferences.repRanges = RepRanges(rawValue: repRanges) ?? .noPreference
            }
            if let effortLevel = response.effort_level {
                preferences.effortLevel = EffortLevel(rawValue: effortLevel) ?? .notSure
            }
            if let eatingApproach = response.eating_approach {
                preferences.eatingApproach = EatingApproach(rawValue: eatingApproach) ?? .notSure
            }
            if let injuryConsiderations = response.injury_considerations {
                preferences.injuryConsiderations = InjuryConsiderations(rawValue: injuryConsiderations) ?? .noneSignificant
            }
            if let mobilityTime = response.mobility_time {
                preferences.mobilityTime = MobilityTime(rawValue: mobilityTime) ?? .notSure
            }
            if let busyEquipmentPreference = response.busy_equipment_preference {
                preferences.busyEquipmentPreference = BusyEquipmentPreference(rawValue: busyEquipmentPreference) ?? .noPreference
            }
            if let restPeriods = response.rest_periods {
                preferences.restPeriods = RestPeriods(rawValue: restPeriods) ?? .notSure
            }
            if let progressionStyle = response.progression_style {
                preferences.progressionStyle = ProgressionStyle(rawValue: progressionStyle) ?? .noPreference
            }
            if let exerciseMenuChange = response.exercise_menu_change {
                preferences.exerciseMenuChange = ExerciseMenuChange(rawValue: exerciseMenuChange) ?? .notSure
            }
            if let recoveryResources = response.recovery_resources {
                preferences.recoveryResources = RecoveryResources(rawValue: recoveryResources) ?? .notSure
            }
            if let programmingFormat = response.programming_format {
                preferences.programmingFormat = ProgrammingFormat(rawValue: programmingFormat) ?? .noPreference
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
            let planData = try JSONEncoder().encode(plan)
            guard let planJSON = try JSONSerialization.jsonObject(with: planData) as? [String: Any] else {
                throw NSError(domain: "WorkoutPlan", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode plan to JSON"])
            }
            let insertData: [String: Any] = [
                "user_id": userId,
                "plan_json": planJSON,
                "created_at": Date().ISO8601String(),
                "updated_at": Date().ISO8601String()
            ]
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