//
//  WorkoutQuestionnaireView.swift
//  Nero
//
//  Created by Workout Questionnaire
//

import SwiftUI

// Workout Preferences Data Model
struct WorkoutPreferences {
    var experienceLevel: ExperienceLevel = .beginner
    var workoutGoal: WorkoutGoal = .buildMuscle
    var workoutFrequency: WorkoutFrequency = .threeTimes
    var timePerWorkout: TimePerWorkout = .thirtyMinutes
    var availableEquipment: Set<Equipment> = []
    var preferredExercises: Set<String> = []
    var injuryLimitations: String = ""
}

enum ExperienceLevel: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    var description: String {
        switch self {
        case .beginner:
            return "New to weightlifting"
        case .intermediate:
            return "1-2 years experience"
        case .advanced:
            return "3+ years experience"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner:
            return "figure.walk"
        case .intermediate:
            return "figure.run"
        case .advanced:
            return "figure.strengthtraining.traditional"
        }
    }
}

enum WorkoutGoal: String, CaseIterable {
    case buildMuscle = "Build Muscle"
    case loseWeight = "Lose Weight"
    case gainStrength = "Gain Strength"
    case improveEndurance = "Improve Endurance"
    case generalFitness = "General Fitness"
    
    var description: String {
        switch self {
        case .buildMuscle:
            return "Increase muscle mass and size"
        case .loseWeight:
            return "Burn fat and lose weight"
        case .gainStrength:
            return "Increase maximum strength"
        case .improveEndurance:
            return "Build cardiovascular fitness"
        case .generalFitness:
            return "Overall health and wellness"
        }
    }
    
    var icon: String {
        switch self {
        case .buildMuscle:
            return "figure.strengthtraining.traditional"
        case .loseWeight:
            return "flame.fill"
        case .gainStrength:
            return "dumbbell.fill"
        case .improveEndurance:
            return "heart.fill"
        case .generalFitness:
            return "figure.mixed.cardio"
        }
    }
}

enum WorkoutFrequency: String, CaseIterable {
    case twoTimes = "2x per week"
    case threeTimes = "3x per week"
    case fourTimes = "4x per week"
    case fiveTimes = "5x per week"
    case sixTimes = "6x per week"
    
    var description: String {
        switch self {
        case .twoTimes:
            return "Moderate commitment"
        case .threeTimes:
            return "Balanced routine"
        case .fourTimes:
            return "Active lifestyle"
        case .fiveTimes:
            return "High commitment"
        case .sixTimes:
            return "Very high commitment"
        }
    }
    
    var icon: String {
        switch self {
        case .twoTimes:
            return "calendar.badge.plus"
        case .threeTimes:
            return "calendar"
        case .fourTimes:
            return "calendar.badge.clock"
        case .fiveTimes:
            return "calendar.circle.fill"
        case .sixTimes:
            return "calendar.badge.exclamationmark"
        }
    }
}

enum TimePerWorkout: String, CaseIterable {
    case thirtyMinutes = "30 minutes"
    case fortyFiveMinutes = "45 minutes"
    case sixtyMinutes = "60 minutes"
    case ninetyMinutes = "90 minutes"
    
    var description: String {
        switch self {
        case .thirtyMinutes:
            return "Quick and efficient"
        case .fortyFiveMinutes:
            return "Moderate duration"
        case .sixtyMinutes:
            return "Standard workout"
        case .ninetyMinutes:
            return "Extended session"
        }
    }
    
    var icon: String {
        switch self {
        case .thirtyMinutes:
            return "clock.badge.checkmark"
        case .fortyFiveMinutes:
            return "clock"
        case .sixtyMinutes:
            return "clock.badge"
        case .ninetyMinutes:
            return "clock.badge.plus"
        }
    }
}

enum Equipment: String, CaseIterable {
    case barbell = "Barbell"
    case dumbbells = "Dumbbells"
    case machines = "Machines"
    case cables = "Cables"
    case bodyweight = "Bodyweight"
    case kettlebells = "Kettlebells"
    
    var icon: String {
        switch self {
        case .barbell:
            return "figure.strengthtraining.traditional"
        case .dumbbells:
            return "dumbbell.fill"
        case .machines:
            return "gearshape.fill"
        case .cables:
            return "cable.connector"
        case .bodyweight:
            return "figure.core.training"
        case .kettlebells:
            return "sportscourt.fill"
        }
    }
}

struct WorkoutQuestionnaireView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var preferences = WorkoutPreferences()
    @State private var showingConfirmation = false
    
    private let totalSteps = 6
    
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
                                ExperienceLevelStep(selectedLevel: $preferences.experienceLevel)
                            case 1:
                                WorkoutGoalStep(selectedGoal: $preferences.workoutGoal)
                            case 2:
                                WorkoutFrequencyStep(selectedFrequency: $preferences.workoutFrequency)
                            case 3:
                                TimePerWorkoutStep(selectedTime: $preferences.timePerWorkout)
                            case 4:
                                EquipmentStep(selectedEquipment: $preferences.availableEquipment)
                            case 5:
                                SummaryStep(preferences: preferences)
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
        .alert("Save Preferences", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                // TODO: Save preferences to user profile
                dismiss()
            }
        } message: {
            Text("This will update your workout plan based on your preferences. You can always change these settings later.")
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
                    showingConfirmation = true
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
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
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
            .frame(height: 100)
        )
    }
}

// MARK: - Question Steps

struct ExperienceLevelStep: View {
    @Binding var selectedLevel: ExperienceLevel
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What's your experience level?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("This helps us recommend the right exercises and intensity for you.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    QuestionnaireOptionButton(
                        title: level.rawValue,
                        subtitle: level.description,
                        icon: level.icon,
                        isSelected: selectedLevel == level,
                        color: .blue
                    ) {
                        selectedLevel = level
                    }
                }
            }
        }
    }
}

struct WorkoutGoalStep: View {
    @Binding var selectedGoal: WorkoutGoal
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What's your primary goal?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("We'll tailor your workout plan to help you achieve this goal.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(WorkoutGoal.allCases, id: \.self) { goal in
                    QuestionnaireOptionButton(
                        title: goal.rawValue,
                        subtitle: goal.description,
                        icon: goal.icon,
                        isSelected: selectedGoal == goal,
                        color: .green
                    ) {
                        selectedGoal = goal
                    }
                }
            }
        }
    }
}

struct WorkoutFrequencyStep: View {
    @Binding var selectedFrequency: WorkoutFrequency
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("How often do you want to workout?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Choose a frequency that fits your schedule and lifestyle.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(WorkoutFrequency.allCases, id: \.self) { frequency in
                    QuestionnaireOptionButton(
                        title: frequency.rawValue,
                        subtitle: frequency.description,
                        icon: frequency.icon,
                        isSelected: selectedFrequency == frequency,
                        color: .orange
                    ) {
                        selectedFrequency = frequency
                    }
                }
            }
        }
    }
}

struct TimePerWorkoutStep: View {
    @Binding var selectedTime: TimePerWorkout
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("How long per workout?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("This helps us plan the right amount of exercises for each session.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(TimePerWorkout.allCases, id: \.self) { time in
                    QuestionnaireOptionButton(
                        title: time.rawValue,
                        subtitle: time.description,
                        icon: time.icon,
                        isSelected: selectedTime == time,
                        color: .purple
                    ) {
                        selectedTime = time
                    }
                }
            }
        }
    }
}

struct EquipmentStep: View {
    @Binding var selectedEquipment: Set<Equipment>
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What equipment do you have access to?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Select all that apply. We'll only recommend exercises you can actually do.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    QuestionnaireOptionButton(
                        title: equipment.rawValue,
                        subtitle: "",
                        icon: equipment.icon,
                        isSelected: selectedEquipment.contains(equipment),
                        color: .cyan
                    ) {
                        if selectedEquipment.contains(equipment) {
                            selectedEquipment.remove(equipment)
                        } else {
                            selectedEquipment.insert(equipment)
                        }
                    }
                }
            }
        }
    }
}

struct SummaryStep: View {
    let preferences: WorkoutPreferences
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Your Workout Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Here's what we've set up for you based on your preferences.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                SummaryRow(
                    title: "Experience Level",
                    value: preferences.experienceLevel.rawValue,
                    icon: preferences.experienceLevel.icon,
                    color: .blue
                )
                
                SummaryRow(
                    title: "Primary Goal",
                    value: preferences.workoutGoal.rawValue,
                    icon: preferences.workoutGoal.icon,
                    color: .green
                )
                
                SummaryRow(
                    title: "Workout Frequency",
                    value: preferences.workoutFrequency.rawValue,
                    icon: preferences.workoutFrequency.icon,
                    color: .orange
                )
                
                SummaryRow(
                    title: "Time Per Workout",
                    value: preferences.timePerWorkout.rawValue,
                    icon: preferences.timePerWorkout.icon,
                    color: .purple
                )
                
                if !preferences.availableEquipment.isEmpty {
                    SummaryRow(
                        title: "Available Equipment",
                        value: "\(preferences.availableEquipment.count) selected",
                        icon: "checkmark.circle.fill",
                        color: .cyan
                    )
                }
            }
            
            // Motivational message
            VStack(spacing: 8) {
                Text("🎯")
                    .font(.system(size: 40))
                
                Text("You're all set!")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Your personalized workout plan is ready. Let's start building your best self!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Helper Views

struct QuestionnaireOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Icon with background
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isSelected ? color : color.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(color, lineWidth: isSelected ? 0 : 2)
                            )
                    )
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
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
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
} 