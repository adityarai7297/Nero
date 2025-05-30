//
//  ContentView.swift
//  Nero
//
//  Created by Aditya Rai on 5/19/25.
//

import Supabase
import SwiftUI
import UIKit

// Exercise model with name and default preferences
struct Exercise {
    let name: String
    let defaultWeight: CGFloat
    let defaultReps: CGFloat
    let defaultRPE: CGFloat
    var setsCompleted: Int = 0
    
    static let allExercises: [Exercise] = [
        Exercise(name: "Bench Press", defaultWeight: 50, defaultReps: 8, defaultRPE: 60),
        Exercise(name: "Squat", defaultWeight: 80, defaultReps: 10, defaultRPE: 70),
        Exercise(name: "Deadlift", defaultWeight: 100, defaultReps: 6, defaultRPE: 80),
        Exercise(name: "Overhead Press", defaultWeight: 35, defaultReps: 8, defaultRPE: 65),
        Exercise(name: "Pull-ups", defaultWeight: 0, defaultReps: 12, defaultRPE: 70),
        Exercise(name: "Barbell Row", defaultWeight: 60, defaultReps: 10, defaultRPE: 75),
        Exercise(name: "Incline Bench", defaultWeight: 40, defaultReps: 8, defaultRPE: 65),
        Exercise(name: "Dips", defaultWeight: 0, defaultReps: 15, defaultRPE: 70),
        Exercise(name: "Romanian Deadlift", defaultWeight: 70, defaultReps: 12, defaultRPE: 70),
        Exercise(name: "Leg Press", defaultWeight: 120, defaultReps: 15, defaultRPE: 75)
    ]
}

// Simple ThemeManager for the WheelPicker
class ThemeManager: ObservableObject {
    @Published var wheelPickerColor: Color = .gray
}

struct ContentView: View {
    var body: some View {
        ExerciseView()
    }
}

struct ExerciseView: View {
    @State private var exercises = Exercise.allExercises
    @State private var currentExerciseIndex: Int = 0
    @State private var weights: [CGFloat] = [50, 8, 60] // Will be updated based on current exercise
    @StateObject private var themeManager = ThemeManager()
    @State private var isSetButtonPressed: Bool = false
    @State private var showRadialBurst: Bool = false
    
    // Haptic feedback generators
    private let setButtonFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let navigationFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private var currentExercise: Exercise {
        exercises[currentExerciseIndex]
    }
    
    var body: some View {
        ZStack {
            // White background that extends to all edges
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main container content
                VStack(spacing: 12) {
                    // Title with set counter
                    VStack {
                        HStack(spacing: 8) {
                            Text(currentExercise.name)
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .animation(.easeInOut(duration: 0.3), value: currentExercise.name)
                            
                            // Green circular set counter - only visible after first set
                            if currentExercise.setsCompleted > 0 {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text("\(currentExercise.setsCompleted)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.bouncy(duration: 0.3), value: currentExercise.setsCompleted)
                            }
                        }
                        .padding(.top, 35)
                        .padding(.bottom, 5)
                    }
                    
                    // Three rows of different components
                    VStack(spacing: 32) {
                        ExerciseComponent(value: $weights[0], type: .weight)
                            .environmentObject(themeManager)
                        ExerciseComponent(value: $weights[1], type: .repetitions)
                            .environmentObject(themeManager)
                        ExerciseComponent(value: $weights[2], type: .rpe)
                            .environmentObject(themeManager)
                    }
                    .padding(.horizontal, 0)
                    .padding(.vertical, 8)
                    
                    // Navigation buttons with SET button in the center
                    HStack(spacing: 20) {
                        // Left navigation button
                        Button(action: {
                            saveCurrentExerciseData()
                            navigationFeedback.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentExerciseIndex = (currentExerciseIndex - 1 + exercises.count) % exercises.count
                                loadExerciseData()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        // Green SET button
                        Button(action: {
                            // Increment set counter for current exercise
                            exercises[currentExerciseIndex].setsCompleted += 1
                            
                            // SET button action with haptic feedback and animation
                            setButtonFeedback.impactOccurred()
                            
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isSetButtonPressed = true
                            }
                            
                            // Show radial burst effect
                            withAnimation(.easeOut(duration: 0.15)) {
                                showRadialBurst = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isSetButtonPressed = false
                                }
                            }
                            
                            // Hide burst after short delay for quick pulse
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    showRadialBurst = false
                                }
                            }
                            
                            print("SET pressed for \(currentExercise.name) with weights: \(weights), Sets completed: \(currentExercise.setsCompleted)")
                        }) {
                            Circle()
                                .fill(Color.green.opacity(isSetButtonPressed ? 0.9 : 0.8))
                                .frame(width: 70, height: 70)
                                .shadow(color: Color.green.opacity(isSetButtonPressed ? 0.8 : 0.6), radius: 8, x: 0, y: 0)
                                .shadow(color: Color.green.opacity(isSetButtonPressed ? 0.6 : 0.4), radius: 16, x: 0, y: 0)
                                .shadow(color: Color.green.opacity(isSetButtonPressed ? 0.4 : 0.2), radius: 24, x: 0, y: 0)
                                .overlay(
                                    Text("SET")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                )
                                .scaleEffect(isSetButtonPressed ? 0.95 : 1.0)
                        }
                        
                        // Right navigation button
                        Button(action: {
                            saveCurrentExerciseData()
                            navigationFeedback.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentExerciseIndex = (currentExerciseIndex + 1) % exercises.count
                                loadExerciseData()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .onAppear {
                        setButtonFeedback.prepare()
                        navigationFeedback.prepare()
                        loadExerciseData() // Load initial exercise data
                    }
                    .padding(.top, 25)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 0)
            }
        }
        .overlay(
            // Radial burst effect overlay - doesn't affect layout
            Group {
                if showRadialBurst {
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(
                            Color.green,
                            lineWidth: showRadialBurst ? 8 : 2
                        )
                        .blur(radius: 8)
                        .opacity(showRadialBurst ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.15), value: showRadialBurst)
                        .allowsHitTesting(false)
                        .zIndex(999)
                        .ignoresSafeArea(.all)
                }
            }
        )
    }
    
    // Save current exercise data when switching exercises
    private func saveCurrentExerciseData() {
        // The weights array is automatically maintained through bindings
        // Set counts are already saved in the exercises array
    }
    
    // Load exercise data when switching to a new exercise
    private func loadExerciseData() {
        let exercise = currentExercise
        weights = [exercise.defaultWeight, exercise.defaultReps, exercise.defaultRPE]
    }
}

enum ExerciseComponentType {
    case weight
    case repetitions
    case rpe
    
    var label: String {
        switch self {
        case .weight: return "lbs"
        case .repetitions: return "reps"
        case .rpe: return "% RPE"
        }
    }
    
    var wheelConfig: WheelPicker.Config {
        switch self {
        case .weight:
            return WheelPicker.Config(
                count: 200, // 0 to 2000 lbs (200 intervals of 10)
                steps: 10,   // 10 small ticks between major ticks
                spacing: 8,
                multiplier: 10, // Each major tick represents 10 lbs
                showsText: true
            )
        case .repetitions:
            return WheelPicker.Config(
                count: 100,  // 0 to 100 reps
                steps: 1,    // Single increments
                spacing: 35, // Same spacing as RPE scale
                multiplier: 1, // Each tick represents 1 rep
                showsText: true,
                showTextOnlyOnEven: true // New property for reps
            )
        case .rpe:
            return WheelPicker.Config(
                count: 10,   // 0 to 100 (10 intervals of 10)
                steps: 1,    // 1 interval between ticks
                spacing: 35, // Much bigger spacing for RPE
                multiplier: 10,
                showsText: true,
                showTextOnlyOnEven: true, // Will show on 0, 20, 40, 60, 80, 100
                evenInterval: 20 // Show text every 20 units
            )
        }
    }
    
    var presetValues: [Int] {
        switch self {
        case .weight: return [30, 50, 70]
        case .repetitions: return [5, 10, 15]
        case .rpe: return [70, 80, 90]
        }
    }
    
    var minValue: CGFloat {
        return 0
    }
}

struct ExerciseComponent: View {
    @Binding var value: CGFloat
    let type: ExerciseComponentType
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Value viewport with label
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 60, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                
                Text("\(Int(value))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .contentTransition(.numericText())
                    .animation(.bouncy(duration: 0.3), value: value)
            }
            .overlay(alignment: .leading) {
                Text(type.label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .offset(x: 70) // 60px (box width) + 10px spacing
            }
            .padding(.top, 5)
            
            // Edge-to-edge wheel picker
            WheelPicker(
                config: type.wheelConfig,
                value: .init(
                    get: { value - type.minValue },
                    set: { newValue in
                        value = newValue + type.minValue
                    }
                )
            )
            .frame(height: 70)
            .background(Color.white)
            .environmentObject(themeManager)
            
            // Three preset buttons
            HStack(spacing: 15) {
                ForEach(type.presetValues, id: \.self) { presetValue in
                    PresetButton(value: presetValue, currentValue: $value)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct PresetButton: View {
    let value: Int
    @Binding var currentValue: CGFloat
    
    var body: some View {
        Button(action: {
            currentValue = CGFloat(value)
        }) {
            RoundedRectangle(cornerRadius: 8)
                .fill(currentValue == CGFloat(value) ? Color.blue : Color.blue.opacity(0.7))
                .frame(width: 60, height: 40)
                .overlay(
                    Text("\(value)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
        }
        .scaleEffect(currentValue == CGFloat(value) ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: currentValue)
    }
}

struct WheelPicker: View {
    /// Config
    var config: Config
    @Binding var value: CGFloat
    /// View Properties
    @State private var isLoaded: Bool = false
    @State private var lastHapticValue: CGFloat = 0
    @EnvironmentObject var themeManager: ThemeManager
    // Store the last value to detect when to trigger haptics

    // Haptic feedback generator
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader {
            let size = $0.size
            let horizontalPadding = size.width / 2
            
            ScrollView(.horizontal) {
                HStack(spacing: config.spacing) {
                    let totalSteps = config.steps * config.count
                    
                    ForEach(0...totalSteps, id: \.self) { index in
                        let remainder = index % config.steps
                        
                        Rectangle()
                            .fill(themeManager.wheelPickerColor)
                            .frame(width: 0.6, height: remainder == 0 ? 20 : 10, alignment: .center)
                            .frame(maxHeight: 20, alignment: .bottom)
                            .overlay(alignment: .bottom) {
                                if remainder == 0 && config.showsText {
                                    let value = (index / config.steps) * config.multiplier
                                    let shouldShowText = config.showTextOnlyOnEven ? 
                                        (value % (config.evenInterval > 0 ? config.evenInterval : 2) == 0) : true
                                    
                                    if shouldShowText {
                                        Text("\(value)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.black)
                                            .textScale(.secondary)
                                            .fixedSize()
                                            .offset(y: 20)
                                    }
                                }
                            }
                    }
                }
                .frame(height: size.height)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: .init(get: {
                let position: Int? = isLoaded ? Int(value * CGFloat(config.steps)) / config.multiplier : nil
                return position
            }, set: { newValue in
                if let newValue {
                    value = (CGFloat(newValue) / CGFloat(config.steps)) * CGFloat(config.multiplier)

                    // Trigger more frequent haptic feedback when scrolling past smaller dividers
                    if abs(value - lastHapticValue) >= CGFloat(config.multiplier) / CGFloat(config.steps) {
                        feedbackGenerator.impactOccurred() // Trigger haptic feedback
                        lastHapticValue = value // Update last haptic value
                    }
                }
            }))
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2, height: 40)
                    .padding(.bottom, 20)
            }
            .safeAreaPadding(.horizontal, horizontalPadding)
            .onAppear {
                if !isLoaded {
                    isLoaded = true
                    feedbackGenerator.prepare() // Prepare the haptic feedback generator
                }
            }
        }
        /// Optional
        .onChange(of: config) { oldValue, newValue in
            value = 0
        }
    }
    
    /// Picker Configuration
    struct Config: Equatable {
        var count: Int
        var steps: Int
        var spacing: CGFloat
        var multiplier: Int
        var showsText: Bool = true
        var showTextOnlyOnEven: Bool = false
        var evenInterval: Int = 0
    }
}

#Preview {
    ContentView()
}

