import Foundation
import Supabase
import UIKit

// MARK: - Generation Status Tracking
enum WorkoutPlanGenerationStatus: Equatable {
    case idle
    case savingPreferences
    case fetchingPersonalDetails
    case generatingPlan
    case savingPlan
    case editingPlan
    case completed
    case failed(String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .savingPreferences:
            return "Saving preferences..."
        case .fetchingPersonalDetails:
            return "Loading personal details..."
        case .generatingPlan:
            return "Generating plan..."
        case .editingPlan:
            return "Editing workout plan..."
        case .savingPlan:
            return "Saving plan..."
        case .completed:
            return "Plan ready!"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
}

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
    @Published var generationStatus: WorkoutPlanGenerationStatus = .idle
    
    // Background task identifier for iOS background processing
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
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
    
    // Save generated workout plan to Supabase (overwrites existing plan if one exists)
    func saveWorkoutPlan(_ plan: DeepseekWorkoutPlan) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // First, check if user already has a workout plan
            let existingPlans: [DBWorkoutPlan] = try await supabase
                .from("workout_plans")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            if let existingPlan = existingPlans.first {
                // Update existing plan
                print("🔄 Updating existing workout plan for user: \(userId)")
                
                struct WorkoutPlanUpdate: Encodable {
                    let plan_json: DeepseekWorkoutPlan
                    let updated_at: String
                }
                
                let updateData = WorkoutPlanUpdate(
                    plan_json: plan,
                    updated_at: Date().ISO8601String()
                )
                
                _ = try await supabase
                    .from("workout_plans")
                    .update(updateData)
                    .eq("id", value: existingPlan.id!)
                    .execute()
                
                print("✅ Workout plan updated successfully")
            } else {
                // Insert new plan
                print("➕ Creating new workout plan for user: \(userId)")
                
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
                
                print("✅ New workout plan created successfully")
            }
            
            return true
        } catch {
            print("❌ Failed to save workout plan: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Non-blocking Generation Methods
    
    /// Starts background workout plan generation - non-blocking
    func startBackgroundPlanGeneration(_ preferences: WorkoutPreferences) {
        // Immediately update status and close any modals
        DispatchQueue.main.async {
            self.generationStatus = .savingPreferences
            self.errorMessage = nil
        }
        
        // Start background task to prevent iOS from killing the process
        startBackgroundTask()
        
        // Perform generation asynchronously without blocking UI
        Task.detached(priority: .background) {
            await self.performBackgroundGeneration(preferences)
        }
    }
    
    private func performBackgroundGeneration(_ preferences: WorkoutPreferences) async {
        print("🎯 Starting background workflow: Save preferences and generate plan")
        
        // Step 1: Save preferences
        await updateStatus(.savingPreferences)
        print("📝 Step 1: Saving workout preferences...")
        
        let preferencesSuccess = await saveWorkoutPreferences(preferences)
        if !preferencesSuccess {
            print("❌ Failed to save preferences, aborting workflow")
            await updateStatus(.failed("Failed to save preferences"))
            endBackgroundTask()
            return
        }
        print("✅ Preferences saved successfully")
        
        // Step 2: Fetch personal details
        await updateStatus(.fetchingPersonalDetails)
        print("👤 Step 2: Fetching personal details...")
        
        let personalDetailsService = PersonalDetailsService()
        guard let personalDetails = await personalDetailsService.loadPersonalDetails() else {
            print("❌ Personal details not found")
            await updateStatus(.failed("Personal details not found"))
            endBackgroundTask()
            return
        }
        print("✅ Personal details loaded successfully")
        
        // Step 3: Generate workout plan
        await updateStatus(.generatingPlan)
        print("🤖 Step 3: Calling DeepSeek API...")
        
        do {
            let plan = try await DeepseekAPIClient.shared.generateWorkoutPlan(
                personalDetails: personalDetails, 
                preferences: preferences
            )
            print("✅ Workout plan generated successfully")
            
            // Step 4: Save plan to database
            await updateStatus(.savingPlan)
            print("💾 Step 4: Saving plan to database...")
            
            let planSaved = await saveWorkoutPlan(plan)
            
            if planSaved {
                print("🎉 Workflow completed successfully!")
                await updateStatus(.completed)
                
                // Notify that workout plan has been updated
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WorkoutPlanUpdated"), 
                        object: nil
                    )
                }
                
                // Auto-reset status after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.generationStatus = .idle
                }
            } else {
                print("❌ Failed to save workout plan to database")
                await updateStatus(.failed("Failed to save plan"))
            }
        } catch {
            print("❌ Workflow failed with error: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            await updateStatus(.failed("Generation failed"))
        }
        
        endBackgroundTask()
    }
    
    private func updateStatus(_ status: WorkoutPlanGenerationStatus) async {
        await MainActor.run {
            self.generationStatus = status
        }
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "WorkoutPlanGeneration") {
            // This block is called if the system needs to terminate the background task
            print("⚠️ Background task expired - cleaning up")
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
    
    // MARK: - Workout Plan Loading
    
    /// Load the current user's workout plan
    func loadCurrentWorkoutPlan() async -> DeepseekWorkoutPlan? {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let response: [DBWorkoutPlan] = try await supabase
                .from("workout_plans")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            return response.first?.planJson
        } catch {
            print("Failed to load workout plan: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load workout plan: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Workout Plan Editing
    
    /// Starts background workout plan editing - non-blocking
    func startWorkoutPlanEdit(editRequest: String, currentPlan: DeepseekWorkoutPlan, personalDetails: PersonalDetails, preferences: WorkoutPreferences) async {
        // Immediately update status
        await MainActor.run {
            self.generationStatus = .editingPlan
            self.errorMessage = nil
        }
        
        // Start background task to prevent iOS from killing the process
        startBackgroundTask()
        
        // Perform editing asynchronously without blocking UI
        Task.detached(priority: .background) {
            await self.performBackgroundEdit(
                editRequest: editRequest,
                currentPlan: currentPlan,
                personalDetails: personalDetails,
                preferences: preferences
            )
        }
    }
    
    private func performBackgroundEdit(editRequest: String, currentPlan: DeepseekWorkoutPlan, personalDetails: PersonalDetails, preferences: WorkoutPreferences) async {
        print("🎯 Starting background edit workflow")
        
        await updateStatus(.editingPlan)
        print("✏️ Editing workout plan...")
        
        do {
            let editedPlan = try await DeepseekAPIClient.shared.editWorkoutPlan(
                editRequest: editRequest,
                currentPlan: currentPlan,
                personalDetails: personalDetails,
                preferences: preferences
            )
            print("✅ Workout plan edited successfully")
            
            // Save the edited plan to database
            await updateStatus(.savingPlan)
            print("💾 Saving edited plan to database...")
            
            let planSaved = await saveWorkoutPlan(editedPlan)
            
            if planSaved {
                print("🎉 Edit workflow completed successfully!")
                await updateStatus(.completed)
                
                // Notify that workout plan has been updated
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WorkoutPlanUpdated"), 
                        object: nil
                    )
                }
                
                // Note: For editing workflow, we keep the completion status persistent
                // so the "View Updated Plan" button stays visible
            } else {
                print("❌ Failed to save edited workout plan to database")
                await updateStatus(.failed("Failed to save plan"))
            }
        } catch {
            print("❌ Edit workflow failed with error: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            await updateStatus(.failed("Edit failed"))
        }
        
        endBackgroundTask()
    }
    
    // MARK: - Legacy Blocking Method (kept for backwards compatibility)
    
    func savePreferencesAndGeneratePlan(_ preferences: WorkoutPreferences) async -> Bool {
        // This method is now deprecated - use startBackgroundPlanGeneration instead
        startBackgroundPlanGeneration(preferences)
        return true // Return immediately since we're now non-blocking
    }
}

extension Date {
    func ISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
} 