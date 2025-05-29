//
//  ContentView.swift
//  Nero
//
//  Created by Aditya Rai on 5/19/25.
//

import Supabase
import SwiftUI
import UIKit

// Simple ThemeManager for the WheelPicker
class ThemeManager: ObservableObject {
    @Published var wheelPickerColor: Color = .gray
}

struct ContentView: View {
    @State private var weights: [CGFloat] = [50, 50, 50] // Weight values for each row
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main container with dark gray background
                VStack(spacing: 20) {
                    // Title
                    VStack {
                        Text("Bench Press")
                            .font(.largeTitle)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.top, 30)
                        
                        // Divider line
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                    }
                    
                    // Three rows of weight selectors
                    VStack(spacing: 30) {
                        ForEach(0..<3, id: \.self) { index in
                            WeightSelectorRow(weight: $weights[index])
                                .environmentObject(themeManager)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    
                    // Bottom divider
                    Rectangle()
                        .fill(Color.gray)
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                    
                    // Green SET button
                    Button(action: {
                        // SET button action
                        print("SET pressed with weights: \(weights)")
                    }) {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("SET")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                            )
                    }
                    .padding(.vertical, 30)
                }
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.gray.opacity(0.3))
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
            }
        }
    }
}

struct WeightSelectorRow: View {
    @Binding var weight: CGFloat
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 15) {
            // Weight viewport and wheel picker
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(height: 100)
                
                VStack(spacing: 0) {
                    // Top viewport window showing current weight
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 100, height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        
                        Text("\(Int(weight))")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding(.top, 10)
                    
                    // Wheel picker for weight selection
                    WheelPicker(
                        config: WheelPicker.Config(
                            count: 16, // 20 to 100 (80 range / 5 step = 16)
                            steps: 5,  // 5 units between major ticks
                            spacing: 8, // Spacing between ticks
                            multiplier: 5, // Each major tick represents 5kg
                            showsText: true
                        ),
                        value: .init(
                            get: { (weight - 20) / 5 }, // Convert weight to picker value (start from 20)
                            set: { newValue in
                                weight = (newValue * 5) + 20 // Convert picker value back to weight
                            }
                        )
                    )
                    .frame(height: 40)
                    .environmentObject(themeManager)
                }
            }
            
            // Three weight preset buttons
            HStack(spacing: 15) {
                WeightButton(value: 30, currentWeight: $weight)
                WeightButton(value: 50, currentWeight: $weight)
                WeightButton(value: 70, currentWeight: $weight)
            }
        }
    }
}

struct WeightButton: View {
    let value: Int
    @Binding var currentWeight: CGFloat
    
    var body: some View {
        Button(action: {
            currentWeight = CGFloat(value)
        }) {
            RoundedRectangle(cornerRadius: 8)
                .fill(currentWeight == CGFloat(value) ? Color.blue : Color.blue.opacity(0.7))
                .frame(width: 70, height: 50)
                .overlay(
                    Text("\(value)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
        }
        .scaleEffect(currentWeight == CGFloat(value) ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: currentWeight)
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
                        let weightValue = 20 + (index * config.multiplier / config.steps)
                        
                        Rectangle()
                            .fill(themeManager.wheelPickerColor)
                            .frame(width: 0.6, height: remainder == 0 ? 20 : 10, alignment: .center)
                            .frame(maxHeight: 20, alignment: .bottom)
                            .overlay(alignment: .bottom) {
                                if remainder == 0 && config.showsText {
                                    Text("\(Int(weightValue))")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(themeManager.wheelPickerColor)
                                        .fixedSize()
                                        .offset(y: 25)
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
                // Center indicator line - using VStack for proper centering
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 2, height: 30)
                    Spacer()
                }
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
    }
}

#Preview {
    ContentView()
}

