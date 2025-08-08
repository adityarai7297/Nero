//
//  PersonalDetailsView.swift
//  Nero
//
//  Created by Personal Details Onboarding
//

import SwiftUI

// Personal Details Data Model
struct PersonalDetails {
    var age: Int = 25
    var gender: Gender = .notSpecified
    var heightFeet: Int = 5
    var heightInches: Int = 8
    var weight: Int = 150
    var bodyFatPercentage: Int = 15
    var activityLevel: ActivityLevel = .moderatelyActive
    var primaryFitnessGoal: FitnessGoal = .general
    var injuryHistory: InjuryHistory = .none
    var sleepHours: SleepHours = .sevenToEight
    var stressLevel: StressLevel = .moderate
    var workoutHistory: WorkoutHistory = .someExperience
}

// MARK: - Personal Details Enums

enum Gender: String, CaseIterable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    case notSpecified = "Prefer not to say"
    
    var icon: String {
        switch self {
        case .male: return "person.fill"
        case .female: return "person.fill"
        case .nonBinary: return "person.fill"
        case .notSpecified: return "questionmark.circle"
        }
    }
    
    var letter: String {
        switch self {
        case .male: return "A"
        case .female: return "B"
        case .nonBinary: return "C"
        case .notSpecified: return "D"
        }
    }
}

enum ActivityLevel: String, CaseIterable {
    case sedentary = "Sedentary (little/no exercise)"
    case lightlyActive = "Lightly active (light exercise 1-3 days/week)"
    case moderatelyActive = "Moderately active (moderate exercise 3-5 days/week)"
    case veryActive = "Very active (hard exercise 6-7 days/week)"
    case superActive = "Super active (very hard exercise/physical job)"
    
    var icon: String {
        switch self {
        case .sedentary: return "figure.seated.side"
        case .lightlyActive: return "figure.walk"
        case .moderatelyActive: return "figure.run"
        case .veryActive: return "figure.strengthtraining.traditional"
        case .superActive: return "flame.fill"
        }
    }
    
    var letter: String {
        switch self {
        case .sedentary: return "A"
        case .lightlyActive: return "B"
        case .moderatelyActive: return "C"
        case .veryActive: return "D"
        case .superActive: return "E"
        }
    }
}

enum FitnessGoal: String, CaseIterable {
    case weightLoss = "Weight loss"
    case muscleGain = "Muscle gain"
    case strength = "Strength improvement"
    case endurance = "Endurance improvement"
    case general = "General fitness"
    case athletic = "Athletic performance"
    
    var icon: String {
        switch self {
        case .weightLoss: return "arrow.down.circle"
        case .muscleGain: return "figure.arms.open"
        case .strength: return "figure.strengthtraining.traditional"
        case .endurance: return "heart.fill"
        case .general: return "figure.mixed.cardio"
        case .athletic: return "trophy.fill"
        }
    }
    
    var letter: String {
        switch self {
        case .weightLoss: return "A"
        case .muscleGain: return "B"
        case .strength: return "C"
        case .endurance: return "D"
        case .general: return "E"
        case .athletic: return "F"
        }
    }
}

enum InjuryHistory: String, CaseIterable {
    case none = "No significant injuries"
    case minor = "Minor injuries (fully recovered)"
    case chronic = "Chronic pain/ongoing issues"
    case recent = "Recent injury (still recovering)"
    case multiple = "Multiple injury history"
    
    var icon: String {
        switch self {
        case .none: return "checkmark.circle"
        case .minor: return "bandage.fill"
        case .chronic: return "exclamationmark.triangle"
        case .recent: return "cross.fill"
        case .multiple: return "list.bullet.clipboard"
        }
    }
    
    var letter: String {
        switch self {
        case .none: return "A"
        case .minor: return "B"
        case .chronic: return "C"
        case .recent: return "D"
        case .multiple: return "E"
        }
    }
}

enum SleepHours: String, CaseIterable {
    case lessThanSix = "Less than 6 hours"
    case sixToSeven = "6-7 hours"
    case sevenToEight = "7-8 hours"
    case eightToNine = "8-9 hours"
    case moreThanNine = "More than 9 hours"
    
    var icon: String {
        switch self {
        case .lessThanSix: return "moon.circle"
        case .sixToSeven: return "moon.circle"
        case .sevenToEight: return "moon.fill"
        case .eightToNine: return "moon.fill"
        case .moreThanNine: return "zzz"
        }
    }
    
    var letter: String {
        switch self {
        case .lessThanSix: return "A"
        case .sixToSeven: return "B"
        case .sevenToEight: return "C"
        case .eightToNine: return "D"
        case .moreThanNine: return "E"
        }
    }
}

enum StressLevel: String, CaseIterable {
    case low = "Low stress"
    case moderate = "Moderate stress"
    case high = "High stress"
    case veryHigh = "Very high stress"
    
    var icon: String {
        switch self {
        case .low: return "leaf.fill"
        case .moderate: return "face.smiling"
        case .high: return "exclamationmark.triangle"
        case .veryHigh: return "flame.fill"
        }
    }
    
    var letter: String {
        switch self {
        case .low: return "A"
        case .moderate: return "B"
        case .high: return "C"
        case .veryHigh: return "D"
        }
    }
}

enum WorkoutHistory: String, CaseIterable {
    case beginner = "Complete beginner"
    case someExperience = "Some experience (less than 1 year)"
    case intermediate = "Intermediate (1-3 years)"
    case advanced = "Advanced (3+ years)"
    
    var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .someExperience: return "figure.run"
        case .intermediate: return "figure.strengthtraining.traditional"
        case .advanced: return "crown.fill"
        }
    }
    
    var letter: String {
        switch self {
        case .beginner: return "A"
        case .someExperience: return "B"
        case .intermediate: return "C"
        case .advanced: return "D"
        }
    }
}

// MARK: - Personal Details View

struct PersonalDetailsView: View {
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var personalDetails = PersonalDetails()
    @State private var showingSuccessAlert = false
    @StateObject private var personalDetailsService = PersonalDetailsService()
    
    private let totalSteps = 12
    
    private let questions = [
        "What's your age?",
        "What's your gender?",
        "What's your height?",
        "What's your current weight?",
        "What's your estimated body fat percentage?",
        "What's your activity level?",
        "What's your primary fitness goal?",
        "Do you have any injury history?",
        "How many hours do you typically sleep?",
        "What's your current stress level?",
        "What's your workout experience?",
        "Ready to get started?"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    VStack(spacing: 16) {
                        HStack {
                            Text("Step \(currentStep + 1) of \(totalSteps)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color.accentBlue)
                            Spacer()
                        }
                        
                        ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                            .progressViewStyle(LinearProgressViewStyle(tint: Color.accentBlue))
                            .scaleEffect(y: 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 32) {
                            // Question content
                            switch currentStep {
                            case 0:
                                AgeStep(age: $personalDetails.age, isDarkMode: isDarkMode)
                            case 1:
                                GenderStep(selectedGender: $personalDetails.gender, isDarkMode: isDarkMode)
                            case 2:
                                HeightStep(heightFeet: $personalDetails.heightFeet, heightInches: $personalDetails.heightInches, isDarkMode: isDarkMode)
                            case 3:
                                WeightStep(weight: $personalDetails.weight, isDarkMode: isDarkMode)
                            case 4:
                                BodyFatStep(bodyFatPercentage: $personalDetails.bodyFatPercentage, isDarkMode: isDarkMode)
                            case 5:
                                ActivityLevelStep(selectedLevel: $personalDetails.activityLevel, isDarkMode: isDarkMode)
                            case 6:
                                FitnessGoalStep(selectedGoal: $personalDetails.primaryFitnessGoal, isDarkMode: isDarkMode)
                            case 7:
                                InjuryHistoryStep(selectedHistory: $personalDetails.injuryHistory, isDarkMode: isDarkMode)
                            case 8:
                                SleepHoursStep(selectedHours: $personalDetails.sleepHours, isDarkMode: isDarkMode)
                            case 9:
                                StressLevelStep(selectedLevel: $personalDetails.stressLevel, isDarkMode: isDarkMode)
                            case 10:
                                WorkoutHistoryStep(selectedHistory: $personalDetails.workoutHistory, isDarkMode: isDarkMode)
                            case 11:
                                SummaryStep(personalDetails: personalDetails, isDarkMode: isDarkMode)
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
            .navigationTitle("Personal Details")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.accentBlue)
                }
            }
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            // No buttons - will auto-dismiss
        } message: {
            Text("Personal details saved successfully!")
        }
    }
    
    @ViewBuilder
    private func NavigationButtonsView() -> some View {
        HStack(spacing: 16) {
            // Back button
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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDarkMode ? Color.white.opacity(0.12) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentBlue.opacity(0.3), lineWidth: 1.5)
                        )
                )
            }
            
            // Next/Finish button
            Button(action: nextFinishAction) {
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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentBlue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentBlue.opacity(0.4), lineWidth: 1)
                    )
            )
            
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
                                .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, (isDarkMode ? Color.black.opacity(0.95) : Color.offWhite.opacity(0.95))]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                        )
    }
    
    private func nextFinishAction() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            // Save personal details
            Task {
                let success = await personalDetailsService.savePersonalDetails(personalDetails)
                if success {
                    showingSuccessAlert = true
                    // Auto-dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Question Step Views

struct AgeStep: View {
    @Binding var age: Int
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What's your age?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Text("This helps us customize your fitness recommendations")
                    .font(.body)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                Text("\(age) years old")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.accentBlue)
                
                Slider(value: Binding(
                    get: { Double(age) },
                    set: { age = Int($0) }
                ), in: 16...80, step: 1)
                .accentColor(Color.accentBlue)
                
                HStack {
                    Text("16")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    Spacer()
                    Text("80")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                }
            }
        }
    }
}

struct GenderStep: View {
    @Binding var selectedGender: Gender
    let isDarkMode: Bool
    
    var body: some View {
        PersonalDetailsQuestionStepView(
            title: "What's your gender?",
            subtitle: "This helps us provide more accurate health insights",
            options: Gender.allCases,
            selectedOption: $selectedGender,
            isDarkMode: isDarkMode
        )
    }
}

struct HeightStep: View {
    @Binding var heightFeet: Int
    @Binding var heightInches: Int
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What's your height?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isDarkMode ? .white : .primary)
            }
            
            VStack(spacing: 20) {
                Text("\(heightFeet)' \(heightInches)\"")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.accentBlue)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("Feet")
                            .font(.caption)
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                        
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(4...7, id: \.self) { feet in
                                Text("\(feet)'").tag(feet)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 120)
                    }
                    
                    VStack {
                        Text("Inches")
                            .font(.caption)
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                        
                        Picker("Inches", selection: $heightInches) {
                            ForEach(0...11, id: \.self) { inches in
                                Text("\(inches)\"").tag(inches)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 120)
                    }
                }
            }
        }
    }
}

struct WeightStep: View {
    @Binding var weight: Int
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What's your current weight?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isDarkMode ? .white : .primary)
            }
            
            VStack(spacing: 16) {
                Text("\(weight) lbs")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.accentBlue)
                
                Slider(value: Binding(
                    get: { Double(weight) },
                    set: { weight = Int($0) }
                ), in: 80...400, step: 1)
                .accentColor(Color.accentBlue)
                
                HStack {
                    Text("80 lbs")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    Spacer()
                    Text("400 lbs")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                }
            }
        }
    }
}

struct BodyFatStep: View {
    @Binding var bodyFatPercentage: Int
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What's your estimated body fat percentage?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Text("Don't worry if you're not sure - just give your best estimate")
                    .font(.body)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                Text("\(bodyFatPercentage)%")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.accentBlue)
                
                Slider(value: Binding(
                    get: { Double(bodyFatPercentage) },
                    set: { bodyFatPercentage = Int($0) }
                ), in: 5...40, step: 1)
                .accentColor(Color.accentBlue)
                
                HStack {
                    Text("5%")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    Spacer()
                    Text("40%")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                }
            }
        }
    }
}

struct ActivityLevelStep: View {
    @Binding var selectedLevel: ActivityLevel
    let isDarkMode: Bool
    
    var body: some View {
        PersonalDetailsQuestionStepView(
            title: "What's your activity level?",
            subtitle: "Consider your daily activities and current exercise routine",
            options: ActivityLevel.allCases,
            selectedOption: $selectedLevel,
            isDarkMode: isDarkMode
        )
    }
}

struct FitnessGoalStep: View {
    @Binding var selectedGoal: FitnessGoal
    let isDarkMode: Bool
    
    var body: some View {
        PersonalDetailsTileSelectionView(
            title: "What's your primary fitness goal?",
            subtitle: "This will help us tailor your workout recommendations",
            options: FitnessGoal.allCases,
            selectedOption: $selectedGoal,
            isDarkMode: isDarkMode
        )
    }
}

struct InjuryHistoryStep: View {
    @Binding var selectedHistory: InjuryHistory
    let isDarkMode: Bool
    
    var body: some View {
        PersonalDetailsQuestionStepView(
            title: "Do you have any injury history?",
            subtitle: "This helps us recommend safer exercises for you",
            options: InjuryHistory.allCases,
            selectedOption: $selectedHistory,
            isDarkMode: isDarkMode
        )
    }
}

struct SleepHoursStep: View {
    @Binding var selectedHours: SleepHours
    let isDarkMode: Bool
    
    var body: some View {
        PersonalDetailsQuestionStepView(
            title: "How many hours do you typically sleep?",
            subtitle: "Sleep is crucial for recovery and performance",
            options: SleepHours.allCases,
            selectedOption: $selectedHours,
            isDarkMode: isDarkMode
        )
    }
}

struct StressLevelStep: View {
    @Binding var selectedLevel: StressLevel
    let isDarkMode: Bool
    
    var body: some View {
        PersonalDetailsQuestionStepView(
            title: "What's your current stress level?",
            subtitle: "Stress affects recovery and training capacity",
            options: StressLevel.allCases,
            selectedOption: $selectedLevel,
            isDarkMode: isDarkMode
        )
    }
}

struct WorkoutHistoryStep: View {
    @Binding var selectedHistory: WorkoutHistory
    let isDarkMode: Bool
    
    var body: some View {
        PersonalDetailsQuestionStepView(
            title: "What's your workout experience?",
            subtitle: "This helps us set appropriate training intensity",
            options: WorkoutHistory.allCases,
            selectedOption: $selectedHistory,
            isDarkMode: isDarkMode
        )
    }
}

struct SummaryStep: View {
    let personalDetails: PersonalDetails
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Text("Here's what we've learned about you")
                    .font(.body)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                SummaryRow(title: "Age", value: "\(personalDetails.age) years", isDarkMode: isDarkMode)
                SummaryRow(title: "Gender", value: personalDetails.gender.rawValue, isDarkMode: isDarkMode)
                SummaryRow(title: "Height", value: "\(personalDetails.heightFeet)' \(personalDetails.heightInches)\"", isDarkMode: isDarkMode)
                SummaryRow(title: "Weight", value: "\(personalDetails.weight) lbs", isDarkMode: isDarkMode)
                SummaryRow(title: "Body Fat", value: "\(personalDetails.bodyFatPercentage)%", isDarkMode: isDarkMode)
                SummaryRow(title: "Activity Level", value: personalDetails.activityLevel.rawValue, isDarkMode: isDarkMode)
                SummaryRow(title: "Primary Goal", value: personalDetails.primaryFitnessGoal.rawValue, isDarkMode: isDarkMode)
            }
            .padding(.vertical, 16)
            .background(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isDarkMode ? .white : .primary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(Color.accentBlue)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Generic Question Step View for Personal Details

struct PersonalDetailsQuestionStepView<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String, T: PersonalDetailsQuestionOption {
    let title: String
    let subtitle: String
    let options: [T]
    @Binding var selectedOption: T
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    QuestionnaireOptionButton(
                        title: option.rawValue,
                        subtitle: "",
                        icon: option.icon,
                        letter: option.letter,
                        isSelected: selectedOption == option,
                        color: Color.accentBlue,
                        isDarkMode: isDarkMode
                    ) {
                        selectedOption = option
                    }
                }
            }
        }
    }
}

// MARK: - Tile Selection View for Personal Details

struct PersonalDetailsTileSelectionView<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String, T: PersonalDetailsQuestionOption {
    let title: String
    let subtitle: String
    let options: [T]
    @Binding var selectedOption: T
    let isDarkMode: Bool
    
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
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(options, id: \.self) { option in
                    PersonalDetailsTileButton(
                        title: option.rawValue,
                        icon: option.icon,
                        letter: option.letter,
                        isSelected: selectedOption == option,
                        color: Color.accentBlue,
                        isDarkMode: isDarkMode
                    ) {
                        selectedOption = option
                    }
                }
            }
        }
    }
}

// MARK: - Personal Details Tile Button

struct PersonalDetailsTileButton: View {
    let title: String
    let icon: String
    let letter: String
    let isSelected: Bool
    let color: Color
    let isDarkMode: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    // Computed properties to simplify complex expressions
    private var textColor: Color {
        isDarkMode ? .white : .primary
    }
    
    private var backgroundColor: Color {
        isSelected ? color.opacity(0.08) : (isDarkMode ? Color.white.opacity(0.12) : Color.white)
    }
    
    private var borderColor: Color {
        isSelected ? color.opacity(0.4) : (isDarkMode ? Color.white.opacity(0.25) : Color.gray.opacity(0.2))
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 1.5 : 1
    }
    
    var body: some View {
        Button(action: action) {
            // Title only
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor, lineWidth: borderWidth)
                        )
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

// MARK: - Protocol for Personal Details Question Options

protocol PersonalDetailsQuestionOption {
    var icon: String { get }
    var letter: String { get }
}

extension Gender: PersonalDetailsQuestionOption {}
extension ActivityLevel: PersonalDetailsQuestionOption {}
extension FitnessGoal: PersonalDetailsQuestionOption {}
extension InjuryHistory: PersonalDetailsQuestionOption {}
extension SleepHours: PersonalDetailsQuestionOption {}
extension StressLevel: PersonalDetailsQuestionOption {}
extension WorkoutHistory: PersonalDetailsQuestionOption {} 