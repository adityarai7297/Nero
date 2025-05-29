//
//  ContentView.swift
//  Nero
//
//  Created by Aditya Rai on 5/19/25.
//

import Supabase
import SwiftUI

struct ContentView: View {
    @State private var weights: [Double] = [50, 50, 50] // Weight values for each row
    
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
    @Binding var weight: Double
    
    private let minWeight: Double = 20
    private let maxWeight: Double = 100
    private let tickInterval: Double = 5
    
    var body: some View {
        VStack(spacing: 15) {
            // Ruler-style weight selector with magnifying window
            VStack(spacing: 0) {
                // Large weight display window (magnifying effect)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 120, height: 60)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Text("\(Int(weight))")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                }
                .zIndex(1)
                
                // Ruler slider
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(height: 80)
                    
                    // Ruler with tick marks and numbers
                    GeometryReader { geometry in
                        let sliderWidth = geometry.size.width - 40 // Account for padding
                        let weightRange = maxWeight - minWeight
                        let pixelsPerUnit = sliderWidth / weightRange
                        
                        ZStack {
                            // Tick marks and numbers
                            ForEach(Int(minWeight)...Int(maxWeight), id: \.self) { tickWeight in
                                let position = CGFloat(Double(tickWeight) - minWeight) * pixelsPerUnit
                                let isMajorTick = tickWeight % 10 == 0
                                let isMinorTick = tickWeight % 5 == 0
                                
                                VStack(spacing: 2) {
                                    if isMinorTick {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.6))
                                            .frame(width: 1, height: isMajorTick ? 20 : 12)
                                    }
                                    
                                    if isMajorTick {
                                        Text("\(tickWeight)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .position(x: position + 20, y: 40) // +20 for padding offset
                            }
                            
                            // Center indicator line (shows current position)
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 2, height: 30)
                                .position(x: geometry.size.width / 2, y: 25)
                        }
                    }
                    .frame(height: 80)
                    
                    // Invisible slider for interaction
                    Slider(value: $weight, in: minWeight...maxWeight, step: 1)
                        .opacity(0.01) // Nearly invisible but still interactive
                        .padding(.horizontal, 20)
                }
                .padding(.top, -30) // Overlap with the magnifying window
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
    @Binding var currentWeight: Double
    
    var body: some View {
        Button(action: {
            currentWeight = Double(value)
        }) {
            RoundedRectangle(cornerRadius: 8)
                .fill(currentWeight == Double(value) ? Color.blue : Color.blue.opacity(0.7))
                .frame(width: 70, height: 50)
                .overlay(
                    Text("\(value)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
        }
        .scaleEffect(currentWeight == Double(value) ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: currentWeight)
    }
}

#Preview {
    ContentView()
}
