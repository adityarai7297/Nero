//
//  WorkoutQuestionnaireView.swift
//  Nero
//
//  Created by Workout Questionnaire
//

import SwiftUI

// Comprehensive Workout Preferences Data Model
struct WorkoutPreferences {
    var primaryGoal: PrimaryGoal = .notSure
    var trainingExperience: TrainingExperience = .notSure
    var sessionFrequency: SessionFrequency = .notSure
    var sessionLength: SessionLength = .notSure
    var equipmentAccess: EquipmentAccess = .notSure
    var movementStyles: MovementStyles = .noPreference
    var weeklySplit: WeeklySplit = .notSure
    var volumeTolerance: VolumeTolerance = .notSure
    var repRanges: RepRanges = .noPreference
    var effortLevel: EffortLevel = .notSure
    var eatingApproach: EatingApproach = .notSure
    var injuryConsiderations: InjuryConsiderations = .noneSignificant
    var mobilityTime: MobilityTime = .notSure
    var busyEquipmentPreference: BusyEquipmentPreference = .noPreference
    var restPeriods: RestPeriods = .notSure
    var progressionStyle: ProgressionStyle = .noPreference
    var exerciseMenuChange: ExerciseMenuChange = .notSure
    var recoveryResources: RecoveryResources = .notSure
    var programmingFormat: ProgrammingFormat = .noPreference
}

// MARK: - Question Enums

enum PrimaryGoal: String, CaseIterable {
    case maximalStrength = "Maximal strength"
    case hypertrophy = "Muscle size (hypertrophy / lean bulk)"
    case bodyRecomposition = "Body recomposition – lose fat while adding/maintaining muscle"
    case muscularEndurance = "Muscular endurance / conditioning"
    case explosivePower = "Explosive power / athleticism"
    case notSure = "Not sure / need guidance"
    
    var icon: String {
        switch self {
        case .maximalStrength: return "figure.strengthtraining.traditional"
        case .hypertrophy: return "figure.arms.open"
        case .bodyRecomposition: return "arrow.2.circlepath"
        case .muscularEndurance: return "heart.fill"
        case .explosivePower: return "bolt.fill"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .maximalStrength: return "A"
        case .hypertrophy: return "B"
        case .bodyRecomposition: return "C"
        case .muscularEndurance: return "D"
        case .explosivePower: return "E"
        case .notSure: return "F"
        }
    }
}

enum TrainingExperience: String, CaseIterable {
    case newbie = "< 6 months (new)"
    case novice = "6 – 18 months (novice)"
    case intermediate = "18 – 48 months (intermediate)"
    case advanced = "> 4 years of structured lifting (advanced)"
    case notSure = "Not sure"
    
    var icon: String {
        switch self {
        case .newbie: return "figure.walk"
        case .novice: return "figure.run"
        case .intermediate: return "figure.strengthtraining.traditional"
        case .advanced: return "crown.fill"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .newbie: return "A"
        case .novice: return "B"
        case .intermediate: return "C"
        case .advanced: return "D"
        case .notSure: return "E"
        }
    }
}

enum SessionFrequency: String, CaseIterable {
    case two = "2"
    case three = "3"
    case four = "4"
    case fivePlus = "5 +"
    case notSure = "Not sure / flexible"
    
    var icon: String {
        switch self {
        case .two: return "2.circle"
        case .three: return "3.circle"
        case .four: return "4.circle"
        case .fivePlus: return "5.circle"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .two: return "A"
        case .three: return "B"
        case .four: return "C"
        case .fivePlus: return "D"
        case .notSure: return "E"
        }
    }
}

enum SessionLength: String, CaseIterable {
    case thirtyMin = "≤ 30 min"
    case thirtyToFortyFive = "31 – 45 min"
    case fortyFiveToSixty = "46 – 60 min"
    case overSixty = "> 60 min"
    case notSure = "Not sure / varies"
    
    var icon: String {
        switch self {
        case .thirtyMin: return "clock.badge.checkmark"
        case .thirtyToFortyFive: return "clock"
        case .fortyFiveToSixty: return "clock.badge"
        case .overSixty: return "clock.badge.plus"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .thirtyMin: return "A"
        case .thirtyToFortyFive: return "B"
        case .fortyFiveToSixty: return "C"
        case .overSixty: return "D"
        case .notSure: return "E"
        }
    }
}

enum EquipmentAccess: String, CaseIterable {
    case fullGym = "Full commercial gym (free weights + machines)"
    case homeGym = "Home gym w/ barbell, rack & dumbbells"
    case adjustableDumbbells = "Adjustable dumbbells + bands / suspension trainer"
    case bodyweightOnly = "Body-weight only"
    case notSure = "Not sure / equipment still in flux"
    
    var icon: String {
        switch self {
        case .fullGym: return "building.2.fill"
        case .homeGym: return "house.fill"
        case .adjustableDumbbells: return "dumbbell.fill"
        case .bodyweightOnly: return "figure.core.training"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .fullGym: return "A"
        case .homeGym: return "B"
        case .adjustableDumbbells: return "C"
        case .bodyweightOnly: return "D"
        case .notSure: return "E"
        }
    }
}

enum MovementStyles: String, CaseIterable {
    case classicBarbell = "Classic barbell compounds"
    case bodybuildingIsolation = "Bodybuilding isolation work"
    case functionalUnilateral = "Functional / unilateral & core-centric moves"
    case olympicLifts = "Olympic-style lifts or power derivatives"
    case noPreference = "No preference / open to anything"
    
    var icon: String {
        switch self {
        case .classicBarbell: return "figure.strengthtraining.traditional"
        case .bodybuildingIsolation: return "figure.arms.open"
        case .functionalUnilateral: return "figure.flexibility"
        case .olympicLifts: return "figure.wrestling"
        case .noPreference: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .classicBarbell: return "A"
        case .bodybuildingIsolation: return "B"
        case .functionalUnilateral: return "C"
        case .olympicLifts: return "D"
        case .noPreference: return "E"
        }
    }
}

enum WeeklySplit: String, CaseIterable {
    case fullBody = "Full-body every workout"
    case upperLower = "Upper / Lower"
    case pushPullLegs = "Push-Pull-Legs"
    case broSplit = "Muscle-group \"bro split\""
    case notSure = "Not sure – coach decide"
    
    var icon: String {
        switch self {
        case .fullBody: return "figure.mixed.cardio"
        case .upperLower: return "figure.arms.open"
        case .pushPullLegs: return "arrow.3.trianglepath"
        case .broSplit: return "list.bullet"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .fullBody: return "A"
        case .upperLower: return "B"
        case .pushPullLegs: return "C"
        case .broSplit: return "D"
        case .notSure: return "E"
        }
    }
}

enum VolumeTolerance: String, CaseIterable {
    case sixOrLess = "≤ 6"
    case sevenToTwelve = "7 – 12"
    case thirteenToEighteen = "13 – 18"
    case nineteenPlus = "19 +"
    case notSure = "Not sure"
    
    var icon: String {
        switch self {
        case .sixOrLess: return "1.circle"
        case .sevenToTwelve: return "2.circle"
        case .thirteenToEighteen: return "3.circle"
        case .nineteenPlus: return "4.circle"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .sixOrLess: return "A"
        case .sevenToTwelve: return "B"
        case .thirteenToEighteen: return "C"
        case .nineteenPlus: return "D"
        case .notSure: return "E"
        }
    }
}

enum RepRanges: String, CaseIterable {
    case heavy = "Heavy 1 – 5"
    case moderate = "Moderate 6 – 10"
    case higher = "Higher 11 – 15"
    case mixed = "Mixed range"
    case noPreference = "No preference"
    
    var icon: String {
        switch self {
        case .heavy: return "minus.circle"
        case .moderate: return "equal.circle"
        case .higher: return "plus.circle"
        case .mixed: return "arrow.up.arrow.down.circle"
        case .noPreference: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .heavy: return "A"
        case .moderate: return "B"
        case .higher: return "C"
        case .mixed: return "D"
        case .noPreference: return "E"
        }
    }
}

enum EffortLevel: String, CaseIterable {
    case rpe67 = "RPE 6-7 (3-4 reps in reserve)"
    case rpe78 = "RPE 7-8 (2-3 RIR)"
    case rpe89 = "RPE 8-9 (1-2 RIR)"
    case rpe910 = "RPE 9-10 (near failure)"
    case notSure = "Not sure – need coaching cues"
    
    var icon: String {
        switch self {
        case .rpe67: return "gauge.low"
        case .rpe78: return "gauge.medium"
        case .rpe89: return "gauge.high"
        case .rpe910: return "gauge.max"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .rpe67: return "A"
        case .rpe78: return "B"
        case .rpe89: return "C"
        case .rpe910: return "D"
        case .notSure: return "E"
        }
    }
}

enum EatingApproach: String, CaseIterable {
    case surplus = "Caloric surplus (mass gain)"
    case mildDeficit = "Mild deficit with high protein (recomp focus)"
    case aggressiveDeficit = "Aggressive deficit (cut)"
    case maintenance = "Eat at maintenance, let training drive change"
    case notSure = "Not sure / need nutrition guidance"
    
    var icon: String {
        switch self {
        case .surplus: return "arrow.up.circle"
        case .mildDeficit: return "arrow.down.circle"
        case .aggressiveDeficit: return "arrow.down.to.line.circle"
        case .maintenance: return "equal.circle"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .surplus: return "A"
        case .mildDeficit: return "B"
        case .aggressiveDeficit: return "C"
        case .maintenance: return "D"
        case .notSure: return "E"
        }
    }
}

enum InjuryConsiderations: String, CaseIterable {
    case noneSignificant = "None significant"
    case shoulderUpper = "Shoulder / upper-body issues"
    case kneeHipAnkle = "Knee / hip / ankle issues"
    case spineCore = "Spine / core restrictions"
    case notSure = "Not sure"
    
    var icon: String {
        switch self {
        case .noneSignificant: return "checkmark.circle"
        case .shoulderUpper: return "figure.arms.open"
        case .kneeHipAnkle: return "figure.walk"
        case .spineCore: return "figure.core.training"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .noneSignificant: return "A"
        case .shoulderUpper: return "B"
        case .kneeHipAnkle: return "C"
        case .spineCore: return "D"
        case .notSure: return "E"
        }
    }
}

enum MobilityTime: String, CaseIterable {
    case quickWarmup = "0-2 min quick warm-ups"
    case fiveMinPrep = "~5 min dynamic prep"
    case tenMinMobility = "~10 min dedicated mobility"
    case whateverRequired = "Whatever is required"
    case notSure = "Not sure"
    
    var icon: String {
        switch self {
        case .quickWarmup: return "timer"
        case .fiveMinPrep: return "clock.badge"
        case .tenMinMobility: return "clock.badge.plus"
        case .whateverRequired: return "infinity"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .quickWarmup: return "A"
        case .fiveMinPrep: return "B"
        case .tenMinMobility: return "C"
        case .whateverRequired: return "D"
        case .notSure: return "E"
        }
    }
}

enum BusyEquipmentPreference: String, CaseIterable {
    case waitForIt = "Wait for it"
    case swapSimilar = "Swap to similar dumbbell/barbell move"
    case swapBodyweight = "Swap to bands/body-weight version"
    case resequence = "Re-sequence the workout"
    case noPreference = "No preference"
    
    var icon: String {
        switch self {
        case .waitForIt: return "clock"
        case .swapSimilar: return "arrow.triangle.swap"
        case .swapBodyweight: return "figure.core.training"
        case .resequence: return "arrow.up.arrow.down"
        case .noPreference: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .waitForIt: return "A"
        case .swapSimilar: return "B"
        case .swapBodyweight: return "C"
        case .resequence: return "D"
        case .noPreference: return "E"
        }
    }
}

enum RestPeriods: String, CaseIterable {
    case sixtyOrLess = "≤ 60 s"
    case sixtyToNinety = "60-90 s"
    case ninetyToOneEighty = "90-180 s"
    case variesByLift = "Varies by lift"
    case notSure = "Not sure"
    
    var icon: String {
        switch self {
        case .sixtyOrLess: return "timer"
        case .sixtyToNinety: return "clock"
        case .ninetyToOneEighty: return "clock.badge"
        case .variesByLift: return "clock.arrow.circlepath"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .sixtyOrLess: return "A"
        case .sixtyToNinety: return "B"
        case .ninetyToOneEighty: return "C"
        case .variesByLift: return "D"
        case .notSure: return "E"
        }
    }
}

enum ProgressionStyle: String, CaseIterable {
    case addWeightWeekly = "Add weight weekly"
    case addRepsThenWeight = "Add reps then bump weight"
    case addSetsFrequency = "Add sets / extra frequency"
    case structuredPeriodization = "Structured periodization blocks"
    case noPreference = "No preference"
    
    var icon: String {
        switch self {
        case .addWeightWeekly: return "plus.circle"
        case .addRepsThenWeight: return "arrow.up.circle"
        case .addSetsFrequency: return "rectangle.stack"
        case .structuredPeriodization: return "calendar.badge.clock"
        case .noPreference: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .addWeightWeekly: return "A"
        case .addRepsThenWeight: return "B"
        case .addSetsFrequency: return "C"
        case .structuredPeriodization: return "D"
        case .noPreference: return "E"
        }
    }
}

enum ExerciseMenuChange: String, CaseIterable {
    case everyTwoWeeks = "Every 2 weeks"
    case everyFourWeeks = "Every 4 weeks"
    case everySixToEight = "Every 6-8 weeks"
    case stickWithStaples = "Stick with staples; tweak rarely"
    case notSure = "Not sure / up to coach"
    
    var icon: String {
        switch self {
        case .everyTwoWeeks: return "calendar.badge.clock"
        case .everyFourWeeks: return "calendar"
        case .everySixToEight: return "calendar.badge.plus"
        case .stickWithStaples: return "lock.circle"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .everyTwoWeeks: return "A"
        case .everyFourWeeks: return "B"
        case .everySixToEight: return "C"
        case .stickWithStaples: return "D"
        case .notSure: return "E"
        }
    }
}

enum RecoveryResources: String, CaseIterable {
    case poor = "< 6 h sleep, inconsistent diet"
    case fair = "6-7 h sleep, mostly balanced diet"
    case good = "7-8 h sleep, solid protein & calories"
    case excellent = "8 + h sleep, dialed-in macros/supplementation"
    case notSure = "Not sure"
    
    var icon: String {
        switch self {
        case .poor: return "moon.circle"
        case .fair: return "moon.circle.fill"
        case .good: return "bed.double.circle"
        case .excellent: return "bed.double.circle.fill"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .poor: return "A"
        case .fair: return "B"
        case .good: return "C"
        case .excellent: return "D"
        case .notSure: return "E"
        }
    }
}

enum ProgrammingFormat: String, CaseIterable {
    case strictTemplate = "Strict written template with numbers laid out"
    case appBased = "App-based logging & auto-progression"
    case coachGuided = "Coach-guided (in-person or online)"
    case flexibleChoice = "Flexible \"choose-from-list\" each day"
    case noPreference = "No preference"
    
    var icon: String {
        switch self {
        case .strictTemplate: return "doc.text"
        case .appBased: return "iphone"
        case .coachGuided: return "person.circle"
        case .flexibleChoice: return "list.bullet.circle"
        case .noPreference: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .strictTemplate: return "A"
        case .appBased: return "B"
        case .coachGuided: return "C"
        case .flexibleChoice: return "D"
        case .noPreference: return "E"
        }
    }
}

// MARK: - Main View

struct WorkoutQuestionnaireView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var preferences = WorkoutPreferences()
    @State private var showingSuccessAlert = false
    @StateObject private var preferencesService = WorkoutPreferencesService()
    
    private let totalSteps = 19
    
    private let questions = [
        "Primary physical goal right now?",
        "Training experience with free weights & machines?",
        "How many separate resistance sessions can you commit to each week?",
        "Typical session length you can reliably spare?",
        "Equipment you always have access to:",
        "Movement styles you most enjoy (or want emphasized):",
        "Preferred weekly split:",
        "Volume tolerance—working sets per muscle per session:",
        "Rep ranges you respond best to (or prefer):",
        "Usual effort level (finish most sets at):",
        "Current body-composition eating approach you're willing to follow:",
        "Past or present injury considerations:",
        "Mobility / warm-up time you'll actually do each session:",
        "When equipment is busy, you prefer to:",
        "Rest periods that feel best:",
        "Progression style you enjoy tracking:",
        "How often should the main exercise menu change?",
        "Recovery resources you consistently get:",
        "Programming format that keeps you motivated:"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    ProgressView(value: Double(currentStep), total: Double(totalSteps - 1))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 32) {
                            // Question content
                            switch currentStep {
                            case 0:
                                PrimaryGoalStep(selectedGoal: $preferences.primaryGoal)
                            case 1:
                                TrainingExperienceStep(selectedExperience: $preferences.trainingExperience)
                            case 2:
                                SessionFrequencyStep(selectedFrequency: $preferences.sessionFrequency)
                            case 3:
                                SessionLengthStep(selectedLength: $preferences.sessionLength)
                            case 4:
                                EquipmentAccessStep(selectedEquipment: $preferences.equipmentAccess)
                            case 5:
                                MovementStylesStep(selectedStyle: $preferences.movementStyles)
                            case 6:
                                WeeklySplitStep(selectedSplit: $preferences.weeklySplit)
                            case 7:
                                VolumeToleranceStep(selectedVolume: $preferences.volumeTolerance)
                            case 8:
                                RepRangesStep(selectedRange: $preferences.repRanges)
                            case 9:
                                EffortLevelStep(selectedEffort: $preferences.effortLevel)
                            case 10:
                                EatingApproachStep(selectedApproach: $preferences.eatingApproach)
                            case 11:
                                InjuryConsiderationsStep(selectedConsideration: $preferences.injuryConsiderations)
                            case 12:
                                MobilityTimeStep(selectedTime: $preferences.mobilityTime)
                            case 13:
                                BusyEquipmentStep(selectedPreference: $preferences.busyEquipmentPreference)
                            case 14:
                                RestPeriodsStep(selectedPeriod: $preferences.restPeriods)
                            case 15:
                                ProgressionStyleStep(selectedStyle: $preferences.progressionStyle)
                            case 16:
                                ExerciseMenuChangeStep(selectedChange: $preferences.exerciseMenuChange)
                            case 17:
                                RecoveryResourcesStep(selectedResources: $preferences.recoveryResources)
                            case 18:
                                ProgrammingFormatStep(selectedFormat: $preferences.programmingFormat)
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 120) // Space for navigation buttons
                    }
                }
                
                // Navigation buttons overlay
                VStack {
                    Spacer()
                    NavigationButtonsView()
                }
            }
            .navigationTitle("Workout Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            // No buttons - will auto-dismiss
        } message: {
            Text("Exercise preferences saved successfully!")
        }
        .overlay {
            if preferencesService.isSaving {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        
                        Text("Saving preferences...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
        .alert("Error", isPresented: .constant(preferencesService.errorMessage != nil)) {
            Button("OK") {
                preferencesService.errorMessage = nil
            }
        } message: {
            Text(preferencesService.errorMessage ?? "An error occurred")
        }
    }
    
    @ViewBuilder
    private func NavigationButtonsView() -> some View {
        HStack(spacing: 20) {
            // Back Button
            if currentStep > 0 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep -= 1
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Back")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    )
                }
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }
            
            // Next/Finish Button
            Button(action: {
                if currentStep < totalSteps - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                } else {
                    // Directly save preferences without confirmation
                    Task {
                        let success = await preferencesService.saveWorkoutPreferences(preferences)
                        if success {
                            showingSuccessAlert = true
                            // Auto-dismiss after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                dismiss()
                            }
                        }
                    }
                }
            }) {
                HStack {
                    Text(currentStep < totalSteps - 1 ? "Next" : "Finish")
                        .font(.headline)
                        .fontWeight(.semibold)
                    if currentStep < totalSteps - 1 {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.95)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        )
    }
}

// MARK: - Question Step Views

struct PrimaryGoalStep: View {
    @Binding var selectedGoal: PrimaryGoal
    
    var body: some View {
        QuestionStepView(
            title: "Primary physical goal right now?",
            options: PrimaryGoal.allCases,
            selectedOption: $selectedGoal
        )
    }
}

struct TrainingExperienceStep: View {
    @Binding var selectedExperience: TrainingExperience
    
    var body: some View {
        QuestionStepView(
            title: "Training experience with free weights & machines?",
            options: TrainingExperience.allCases,
            selectedOption: $selectedExperience
        )
    }
}

struct SessionFrequencyStep: View {
    @Binding var selectedFrequency: SessionFrequency
    
    var body: some View {
        QuestionStepView(
            title: "How many separate resistance sessions can you commit to each week?",
            options: SessionFrequency.allCases,
            selectedOption: $selectedFrequency
        )
    }
}

struct SessionLengthStep: View {
    @Binding var selectedLength: SessionLength
    
    var body: some View {
        QuestionStepView(
            title: "Typical session length you can reliably spare?",
            options: SessionLength.allCases,
            selectedOption: $selectedLength
        )
    }
}

struct EquipmentAccessStep: View {
    @Binding var selectedEquipment: EquipmentAccess
    
    var body: some View {
        QuestionStepView(
            title: "Equipment you always have access to:",
            options: EquipmentAccess.allCases,
            selectedOption: $selectedEquipment
        )
    }
}

struct MovementStylesStep: View {
    @Binding var selectedStyle: MovementStyles
    
    var body: some View {
        QuestionStepView(
            title: "Movement styles you most enjoy (or want emphasized):",
            options: MovementStyles.allCases,
            selectedOption: $selectedStyle
        )
    }
}

struct WeeklySplitStep: View {
    @Binding var selectedSplit: WeeklySplit
    
    var body: some View {
        QuestionStepView(
            title: "Preferred weekly split:",
            options: WeeklySplit.allCases,
            selectedOption: $selectedSplit
        )
    }
}

struct VolumeToleranceStep: View {
    @Binding var selectedVolume: VolumeTolerance
    
    var body: some View {
        QuestionStepView(
            title: "Volume tolerance—working sets per muscle per session:",
            options: VolumeTolerance.allCases,
            selectedOption: $selectedVolume
        )
    }
}

struct RepRangesStep: View {
    @Binding var selectedRange: RepRanges
    
    var body: some View {
        QuestionStepView(
            title: "Rep ranges you respond best to (or prefer):",
            options: RepRanges.allCases,
            selectedOption: $selectedRange
        )
    }
}

struct EffortLevelStep: View {
    @Binding var selectedEffort: EffortLevel
    
    var body: some View {
        QuestionStepView(
            title: "Usual effort level (finish most sets at):",
            options: EffortLevel.allCases,
            selectedOption: $selectedEffort
        )
    }
}

struct EatingApproachStep: View {
    @Binding var selectedApproach: EatingApproach
    
    var body: some View {
        QuestionStepView(
            title: "Current body-composition eating approach you're willing to follow:",
            options: EatingApproach.allCases,
            selectedOption: $selectedApproach
        )
    }
}

struct InjuryConsiderationsStep: View {
    @Binding var selectedConsideration: InjuryConsiderations
    
    var body: some View {
        QuestionStepView(
            title: "Past or present injury considerations:",
            options: InjuryConsiderations.allCases,
            selectedOption: $selectedConsideration
        )
    }
}

struct MobilityTimeStep: View {
    @Binding var selectedTime: MobilityTime
    
    var body: some View {
        QuestionStepView(
            title: "Mobility / warm-up time you'll actually do each session:",
            options: MobilityTime.allCases,
            selectedOption: $selectedTime
        )
    }
}

struct BusyEquipmentStep: View {
    @Binding var selectedPreference: BusyEquipmentPreference
    
    var body: some View {
        QuestionStepView(
            title: "When equipment is busy, you prefer to:",
            options: BusyEquipmentPreference.allCases,
            selectedOption: $selectedPreference
        )
    }
}

struct RestPeriodsStep: View {
    @Binding var selectedPeriod: RestPeriods
    
    var body: some View {
        QuestionStepView(
            title: "Rest periods that feel best:",
            options: RestPeriods.allCases,
            selectedOption: $selectedPeriod
        )
    }
}

struct ProgressionStyleStep: View {
    @Binding var selectedStyle: ProgressionStyle
    
    var body: some View {
        QuestionStepView(
            title: "Progression style you enjoy tracking:",
            options: ProgressionStyle.allCases,
            selectedOption: $selectedStyle
        )
    }
}

struct ExerciseMenuChangeStep: View {
    @Binding var selectedChange: ExerciseMenuChange
    
    var body: some View {
        QuestionStepView(
            title: "How often should the main exercise menu change?",
            options: ExerciseMenuChange.allCases,
            selectedOption: $selectedChange
        )
    }
}

struct RecoveryResourcesStep: View {
    @Binding var selectedResources: RecoveryResources
    
    var body: some View {
        QuestionStepView(
            title: "Recovery resources you consistently get:",
            options: RecoveryResources.allCases,
            selectedOption: $selectedResources
        )
    }
}

struct ProgrammingFormatStep: View {
    @Binding var selectedFormat: ProgrammingFormat
    
    var body: some View {
        QuestionStepView(
            title: "Programming format that keeps you motivated:",
            options: ProgrammingFormat.allCases,
            selectedOption: $selectedFormat
        )
    }
}

// MARK: - Generic Question Step View

struct QuestionStepView<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String, T: QuestionOption {
    let title: String
    let options: [T]
    @Binding var selectedOption: T
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    QuestionnaireOptionButton(
                        title: option.rawValue,
                        subtitle: "",
                        icon: option.icon,
                        letter: option.letter,
                        isSelected: selectedOption == option,
                        color: .blue
                    ) {
                        selectedOption = option
                    }
                }
            }
        }
    }
}

// MARK: - Protocol for Question Options

protocol QuestionOption {
    var icon: String { get }
    var letter: String { get }
}

extension PrimaryGoal: QuestionOption {}
extension TrainingExperience: QuestionOption {}
extension SessionFrequency: QuestionOption {}
extension SessionLength: QuestionOption {}
extension EquipmentAccess: QuestionOption {}
extension MovementStyles: QuestionOption {}
extension WeeklySplit: QuestionOption {}
extension VolumeTolerance: QuestionOption {}
extension RepRanges: QuestionOption {}
extension EffortLevel: QuestionOption {}
extension EatingApproach: QuestionOption {}
extension InjuryConsiderations: QuestionOption {}
extension MobilityTime: QuestionOption {}
extension BusyEquipmentPreference: QuestionOption {}
extension RestPeriods: QuestionOption {}
extension ProgressionStyle: QuestionOption {}
extension ExerciseMenuChange: QuestionOption {}
extension RecoveryResources: QuestionOption {}
extension ProgrammingFormat: QuestionOption {}

// MARK: - Helper Views

struct QuestionnaireOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let letter: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Letter indicator
                Text(letter)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? color : color.opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(color)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
} 
