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
                VStack(spacing: 12) {
                    // Title
                    VStack {
                        Text("Bench Press")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .padding(.top, 65)
                            .padding(.bottom, 5)
                    }
                    
                    // Three rows of weight selectors
                    VStack(spacing: 18) {
                        ForEach(0..<3, id: \.self) { index in
                            WeightSelectorRow(weight: $weights[index])
                                .environmentObject(themeManager)
                        }
                    }
                    .padding(.horizontal, 0)
                    .padding(.vertical, 8)
                    
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
                    .padding(.vertical, 10)
                    .padding(.bottom, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white)
                )
                .padding(.horizontal, 0)
                .ignoresSafeArea(edges: [.top, .bottom])
            }
        }
    }
}

struct WeightSelectorRow: View {
    @Binding var weight: CGFloat
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Weight viewport 
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
                    .contentTransition(.numericText())
                    .animation(.bouncy(duration: 0.3), value: weight)
            }
            .padding(.top, 5)
            
            // Edge-to-edge wheel picker for weight selection
            WheelPicker(
                config: WheelPicker.Config(
                    count: 198, // 20 to 2000 lbs (1980 range / 10 = 198 major intervals)
                    steps: 10,  // 10 units between major ticks (major ticks every 10 lbs)
                    spacing: 8, // Spacing between ticks
                    multiplier: 10, // Each major tick represents 10 lbs
                    showsText: true
                ),
                value: .init(
                    get: { weight - 20 }, // Convert weight to picker value (start from 20)
                    set: { newValue in
                        weight = newValue + 20 // Convert picker value back to weight
                    }
                )
            )
            .frame(height: 70)
            .background(Color.white)
            .environmentObject(themeManager)
            
            // Three weight preset buttons
            HStack(spacing: 15) {
                WeightButton(value: 30, currentWeight: $weight)
                WeightButton(value: 50, currentWeight: $weight)
                WeightButton(value: 70, currentWeight: $weight)
            }
            .padding(.horizontal, 20)
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
                        
                        Rectangle()
                            .fill(themeManager.wheelPickerColor)
                            .frame(width: 0.6, height: remainder == 0 ? 20 : 10, alignment: .center)
                            .frame(maxHeight: 20, alignment: .bottom)
                            .overlay(alignment: .bottom) {
                                if remainder == 0 && config.showsText {
                                    Text("\(20 + (index / config.steps) * config.multiplier)")
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
                .frame(height: size.height)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: .init(get: {
                let position: Int? = isLoaded ? Int(value) : nil
                return position
            }, set: { newValue in
                if let newValue {
                    value = CGFloat(newValue)

                    // Trigger haptic feedback when scrolling past major dividers
                    if abs(value - lastHapticValue) >= CGFloat(config.multiplier) {
                        feedbackGenerator.impactOccurred()
                        lastHapticValue = value
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
    }
}

#Preview {
    ContentView()
}

