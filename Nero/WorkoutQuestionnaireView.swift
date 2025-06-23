//
//  WorkoutQuestionnaireView.swift
//  Nero
//
//  Created by Workout Questionnaire
//

import SwiftUI
import Neumorphic

// Comprehensive Workout Preferences Data Model
struct WorkoutPreferences {
    var primaryGoal: PrimaryGoal = .notSure
    var trainingExperience: TrainingExperience = .notSure
    var sessionFrequency: SessionFrequency = .notSure
    var sessionLength: SessionLength = .notSure
    var equipmentAccess: EquipmentAccess = .notSure
    var movementStyles: Set<MovementStyles> = []
    var weeklySplit: WeeklySplit = .notSure
    var moreFocusMuscleGroups: Set<MuscleGroup> = []
    var lessFocusMuscleGroups: Set<MuscleGroup> = []
}

// MARK: - Question Enums

enum PrimaryGoal: String, CaseIterable {
    case maximalStrength = "Maximal strength"
    case hypertrophy = "Muscle size (hypertrophy / lean bulk)"
    case bodyRecomposition = "Body recomposition – lose fat while adding muscle"
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
    case five = "5"
    case sixPlus = "6 +"
    case notSure = "Not sure / flexible"
    
    var icon: String {
        switch self {
        case .two: return "2.circle"
        case .three: return "3.circle"
        case .four: return "4.circle"
        case .five: return "5.circle"
        case .sixPlus: return "6.circle"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .two: return "A"
        case .three: return "B"
        case .four: return "C"
        case .five: return "D"
        case .sixPlus: return "E"
        case .notSure: return "F"
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
    case calisthenics = "Calisthenics & bodyweight movements"
    case noPreference = "No preference / open to anything"
    
    var icon: String {
        switch self {
        case .classicBarbell: return "figure.strengthtraining.traditional"
        case .bodybuildingIsolation: return "figure.arms.open"
        case .functionalUnilateral: return "figure.flexibility"
        case .olympicLifts: return "figure.wrestling"
        case .calisthenics: return "figure.core.training"
        case .noPreference: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .classicBarbell: return "A"
        case .bodybuildingIsolation: return "B"
        case .functionalUnilateral: return "C"
        case .olympicLifts: return "D"
        case .calisthenics: return "E"
        case .noPreference: return "F"
        }
    }
}

enum WeeklySplit: String, CaseIterable {
    case fullBody = "Full-body every workout"
    case upperLower = "Upper / Lower"
    case pushPullLegs = "Push-Pull-Legs"
    case pushPullLegsUpperLower = "Push-Pull-Legs-Upper-Lower"
    case upperLowerPushPull = "Upper-Lower-Push-Pull"
    case broSplit = "Muscle-group \"bro split\""
    case arnoldSplit = "Arnold Split (Chest/Back, Shoulders/Arms, Legs)"
    case bodyPartSpecialization = "Body Part Specialization"
    case notSure = "Not sure – coach decide"
    
    var icon: String {
        switch self {
        case .fullBody: return "figure.mixed.cardio"
        case .upperLower: return "figure.arms.open"
        case .pushPullLegs: return "arrow.3.trianglepath"
        case .pushPullLegsUpperLower: return "square.grid.2x2"
        case .upperLowerPushPull: return "rectangle.split.2x1"
        case .broSplit: return "list.bullet"
        case .arnoldSplit: return "figure.wrestling"
        case .bodyPartSpecialization: return "target"
        case .notSure: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .fullBody: return "A"
        case .upperLower: return "B"
        case .pushPullLegs: return "C"
        case .pushPullLegsUpperLower: return "D"
        case .upperLowerPushPull: return "E"
        case .broSplit: return "F"
        case .arnoldSplit: return "G"
        case .bodyPartSpecialization: return "H"
        case .notSure: return "I"
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

enum MuscleGroup: String, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms (biceps/triceps)"
    case legs = "Legs (quads/hamstrings)"
    case glutes = "Glutes"
    case calves = "Calves"
    case abs = "Abs/Core"
    case forearms = "Forearms"
    case traps = "Traps/Upper back"
    
    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.strengthtraining.traditional"
        case .shoulders: return "figure.arms.open"
        case .arms: return "figure.arms.open"
        case .legs: return "figure.walk"
        case .glutes: return "figure.core.training"
        case .calves: return "figure.walk"
        case .abs: return "figure.core.training"
        case .forearms: return "hand.raised.fill"
        case .traps: return "figure.strengthtraining.traditional"
        }
    }
    
    var letter: String {
        switch self {
        case .chest: return "A"
        case .back: return "B"
        case .shoulders: return "C"
        case .arms: return "D"
        case .legs: return "E"
        case .glutes: return "F"
        case .calves: return "G"
        case .abs: return "H"
        case .forearms: return "I"
        case .traps: return "J"
        }
    }
}

// MARK: - Main View

struct WorkoutQuestionnaireView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferencesService: WorkoutPreferencesService
    
    // Callback to show side menu after completion
    let onCompletion: (() -> Void)?
    
    @State private var currentStep = 0
    @State private var preferences = WorkoutPreferences()
    
    private let totalSteps = 9
    
    // Initialize with optional completion callback
    init(onCompletion: (() -> Void)? = nil) {
        self.onCompletion = onCompletion
    }
    
    private let questions = [
        "Primary physical goal right now?",
        "Training experience with free weights & machines?",
        "How many separate resistance sessions can you commit to each week?",
        "Typical session length you can reliably spare?",
        "Equipment you always have access to:",
        "Movement styles you most enjoy (or want emphasized):",
        "Preferred weekly split:",
        "Muscle groups you want MORE focus on:",
        "Muscle groups you want LESS focus on:"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                Color.offWhite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    ProgressView(value: Double(currentStep), total: Double(totalSteps - 1))
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.accentBlue))
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
                                MovementStylesStep(selectedStyles: $preferences.movementStyles)
                            case 6:
                                WeeklySplitStep(selectedSplit: $preferences.weeklySplit, sessionFrequency: preferences.sessionFrequency)
                            case 7:
                                MoreFocusMuscleGroupsStep(selectedGroups: $preferences.moreFocusMuscleGroups)
                            case 8:
                                LessFocusMuscleGroupsStep(selectedGroups: $preferences.lessFocusMuscleGroups)
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
                    .foregroundColor(Color.accentBlue)
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
                    .foregroundColor(Color.accentBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .softButtonStyle(
                    RoundedRectangle(cornerRadius: 12),
                    padding: 16,
                    mainColor: Color.offWhite,
                    textColor: Color.accentBlue,
                    pressedEffect: .hard
                )
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
                    // Start non-blocking background generation
                    preferencesService.startBackgroundPlanGeneration(preferences)
                    
                    // Dismiss immediately - no popup needed
                    dismiss()
                    
                    // Show side menu after completion if callback provided
                    onCompletion?()
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
            }
            .softButtonStyle(
                RoundedRectangle(cornerRadius: 12),
                padding: 16,
                mainColor: Color.accentBlue,
                textColor: .white,
                pressedEffect: .hard
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.offWhite.opacity(0.95)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        )
    }
}

// MARK: - Generic Step Views

struct QuestionStepView<T: RawRepresentable & CaseIterable & Hashable & QuestionOption>: View where T.RawValue == String {
    let title: String
    let options: [T]
    @Binding var selectedOption: T
    
    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
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

// MARK: - Individual Step Views

struct PrimaryGoalStep: View {
    @Binding var selectedGoal: PrimaryGoal
    
    var body: some View {
        TileSelectionView(
            title: "Primary physical goal right now?",
            subtitle: nil,
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
        TileSelectionView(
            title: "How many separate resistance sessions can you commit to each week?",
            subtitle: nil,
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
    @Binding var selectedStyles: Set<MovementStyles>
    
    var body: some View {
        MultiTileSelectionView(
            title: "Movement styles you most enjoy (or want emphasized):",
            subtitle: nil,
            options: MovementStyles.allCases,
            selectedOptions: $selectedStyles
        )
    }
}

struct WeeklySplitStep: View {
    @Binding var selectedSplit: WeeklySplit
    let sessionFrequency: SessionFrequency
    
    var body: some View {
        TileSelectionView(
            title: "Preferred weekly split:",
            subtitle: nil,
            options: WeeklySplit.allCases,
            selectedOption: $selectedSplit
        )
    }
}

struct MoreFocusMuscleGroupsStep: View {
    @Binding var selectedGroups: Set<MuscleGroup>
    
    var body: some View {
        MuscleGroupTileSelectionView(
            title: "Muscle groups you want MORE focus on:",
            options: MuscleGroup.allCases,
            selectedOptions: $selectedGroups
        )
    }
}

struct LessFocusMuscleGroupsStep: View {
    @Binding var selectedGroups: Set<MuscleGroup>
    
    var body: some View {
        MuscleGroupTileSelectionView(
            title: "Muscle groups you want LESS focus on:",
            options: MuscleGroup.allCases,
            selectedOptions: $selectedGroups
        )
    }
}

// MARK: - Muscle Group Tile Selection View

struct MuscleGroupTileSelectionView: View {
    let title: String
    let options: [MuscleGroup]
    @Binding var selectedOptions: Set<MuscleGroup>
    
    // Grid layout with 2 columns
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Select all that apply")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(options, id: \.self) { option in
                    MuscleGroupTileButton(
                        title: option.rawValue,
                        isSelected: selectedOptions.contains(option),
                        color: .blue
                    ) {
                        if selectedOptions.contains(option) {
                            selectedOptions.remove(option)
                        } else {
                            selectedOptions.insert(option)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Muscle Group Tile Button

struct MuscleGroupTileButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? color.opacity(0.1) : Color.offWhite)
                        .softOuterShadow(
                            darkShadow: Color.black.opacity(isPressed ? 0.3 : 0.15),
                            lightShadow: Color.white.opacity(0.9),
                            offset: isPressed ? 1 : 2,
                            radius: isPressed ? 2 : 4
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? color : Color.clear, lineWidth: isSelected ? 2 : 0)
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Generic Question Step View

struct MultipleSelectionQuestionStepView<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String, T: QuestionOption {
    let title: String
    let options: [T]
    @Binding var selectedOptions: Set<T>
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Select all that apply")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    QuestionnaireOptionButton(
                        title: option.rawValue,
                        subtitle: "",
                        icon: option.icon,
                        letter: option.letter,
                        isSelected: selectedOptions.contains(option),
                        color: .blue
                    ) {
                        if selectedOptions.contains(option) {
                            selectedOptions.remove(option)
                        } else {
                            selectedOptions.insert(option)
                        }
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

// MARK: - QuestionOption Protocol Extensions
extension PrimaryGoal: QuestionOption {}
extension TrainingExperience: QuestionOption {}
extension SessionFrequency: QuestionOption {}
extension SessionLength: QuestionOption {}
extension EquipmentAccess: QuestionOption {}
extension MovementStyles: QuestionOption {}
extension WeeklySplit: QuestionOption {}
extension MuscleGroup: QuestionOption {}
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
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
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
                    .fill(isSelected ? color.opacity(0.05) : Color.offWhite)
                    .softOuterShadow(
                        darkShadow: Color.black.opacity(isPressed ? 0.3 : 0.15),
                        lightShadow: Color.white.opacity(0.9),
                        offset: isPressed ? 1 : 3,
                        radius: isPressed ? 2 : 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Color Extensions

extension Color {
    /// Global accent blue used across the app (matches number panels)
    static let accentBlue = Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255) // Same as system blue, centralised

    /// Slightly tinted white for better Neumorphic contrast
    static let offWhite = Color(red: 240 / 255, green: 240 / 255, blue: 245 / 255)
}

// MARK: - Tile Selection Views

struct TileSelectionView<T: RawRepresentable & CaseIterable & Hashable & QuestionOption>: View where T.RawValue == String {
    let title: String
    let subtitle: String?
    let options: [T]
    @Binding var selectedOption: T
    
    // Grid layout with 2 columns for better space utilization
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(options, id: \.self) { option in
                    TileOptionButton(
                        title: option.rawValue,
                        icon: option.icon,
                        letter: option.letter,
                        isSelected: selectedOption == option,
                        color: Color.accentBlue
                    ) {
                        selectedOption = option
                    }
                }
            }
        }
    }
}

struct MultiTileSelectionView<T: RawRepresentable & CaseIterable & Hashable & QuestionOption>: View where T.RawValue == String {
    let title: String
    let subtitle: String?
    let options: [T]
    @Binding var selectedOptions: Set<T>
    
    // Grid layout with 2 columns
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Select all that apply")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(options, id: \.self) { option in
                    TileOptionButton(
                        title: option.rawValue,
                        icon: option.icon,
                        letter: option.letter,
                        isSelected: selectedOptions.contains(option),
                        color: Color.accentBlue
                    ) {
                        if selectedOptions.contains(option) {
                            selectedOptions.remove(option)
                        } else {
                            selectedOptions.insert(option)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tile Option Button

struct TileOptionButton: View {
    let title: String
    let icon: String
    let letter: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            // Title only
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? color.opacity(0.1) : Color.offWhite)
                        .softOuterShadow(
                            darkShadow: Color.black.opacity(isPressed ? 0.3 : 0.15),
                            lightShadow: Color.white.opacity(0.9),
                            offset: isPressed ? 1 : 2,
                            radius: isPressed ? 2 : 4
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? color : Color.clear, lineWidth: isSelected ? 2 : 0)
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
} 
