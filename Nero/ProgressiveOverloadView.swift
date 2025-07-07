import SwiftUI
import Neumorphic

struct ProgressiveOverloadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationService: NotificationService
    @State private var showingImplementConfirmation = false
    
    let analysisResult: ProgressiveOverloadResponse
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.offWhite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        HeaderView()
                        SummaryCard()
                        SuggestionsList()
                        ActionButtons()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Progressive Overload")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentBlue)
                }
            }
        }
        .alert("Implement Suggestions?", isPresented: $showingImplementConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Implement") {
                // TODO: Implement the suggestions by updating the workout plan
                implementSuggestions()
            }
        } message: {
            Text("This will update your current workout plan with the AI's progressive overload suggestions. You can always revert changes later.")
        }
    }
    
    @ViewBuilder
    private func HeaderView() -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.offWhite)
                    .softOuterShadow(
                        darkShadow: Color.black.opacity(0.2),
                        lightShadow: Color.white.opacity(0.9),
                        offset: 6,
                        radius: 8
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.accentBlue)
            }
            
            Text("📊 Analysis Complete")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Based on your last 12 weeks of training data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private func SummaryCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.title3)
                    .foregroundColor(Color.accentBlue)
                
                Text("Analysis Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Text(analysisResult.summary)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.offWhite)
                .softOuterShadow(
                    darkShadow: Color.black.opacity(0.15),
                    lightShadow: Color.white.opacity(0.9),
                    offset: 4,
                    radius: 6
                )
        )
    }
    
    @ViewBuilder
    private func SuggestionsList() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(Color.accentBlue)
                
                Text("Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(analysisResult.suggestions.count) exercises")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                    )
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(analysisResult.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
    
    @ViewBuilder
    private func ActionButtons() -> some View {
        VStack(spacing: 12) {
            // Primary action button
            Button(action: {
                showingImplementConfirmation = true
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    
                    Text("Implement Suggestions")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentBlue)
                        .softOuterShadow(
                            darkShadow: Color.accentBlue.opacity(0.3),
                            lightShadow: Color.white.opacity(0.8),
                            offset: 4,
                            radius: 6
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Secondary action button
            Button(action: {
                // TODO: Allow user to manually review and select which suggestions to implement
                print("Manual review not implemented yet")
            }) {
                HStack {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.title3)
                    
                    Text("Review Manually")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.accentBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.offWhite)
                        .softOuterShadow(
                            darkShadow: Color.black.opacity(0.15),
                            lightShadow: Color.white.opacity(0.9),
                            offset: 4,
                            radius: 6
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 8)
    }
    
    private func implementSuggestions() {
        // TODO: Implement the logic to apply suggestions to the workout plan
        print("🔄 Implementing progressive overload suggestions...")
        print("📝 Suggestions to implement: \(analysisResult.suggestions)")
        
        // This would involve:
        // 1. Loading current workout plan
        // 2. Applying the suggested changes (sets +/- X, reps +/- X, weight +/- X)
        // 3. Saving the updated workout plan
        // 4. Notifying the user of success
        
        // For now, just dismiss the view
        dismiss()
    }
}

struct SuggestionCard: View {
    let suggestion: ProgressiveOverloadSuggestion
    
    private var hasChanges: Bool {
        !suggestion.suggestions.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name header
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .foregroundColor(hasChanges ? Color.accentBlue : Color.green)
                
                Text(suggestion.exerciseName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if hasChanges {
                    Text("\(suggestion.suggestions.count) \(suggestion.suggestions.count == 1 ? "change" : "changes")")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                        )
                } else {
                    Text("No changes")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                }
            }
            
            // Content based on whether there are changes or not
            if hasChanges {
                // Suggestions list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(suggestion.suggestions.enumerated()), id: \.offset) { index, change in
                        ChangeRow(change: change)
                    }
                }
            } else {
                // No changes needed - show reasoning
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Continue Current Training")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(suggestion.reasoning ?? "This exercise is progressing well and doesn't need changes at this time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.offWhite)
                .softInnerShadow(
                    RoundedRectangle(cornerRadius: 12),
                    darkShadow: Color.black.opacity(0.1),
                    lightShadow: Color.white.opacity(0.9),
                    spread: 0.5,
                    radius: 2
                )
        )
    }
}

struct ChangeRow: View {
    let change: OverloadChange
    
    private var changeIcon: String {
        switch change.changeType.lowercased() {
        case "sets":
            return change.changeValue > 0 ? "plus.rectangle.on.rectangle" : "minus.rectangle"
        case "reps":
            return change.changeValue > 0 ? "arrow.up.circle" : "arrow.down.circle"
        case "weight":
            return change.changeValue > 0 ? "plus.circle" : "minus.circle"
        default:
            return "questionmark.circle"
        }
    }
    
    private var changeColor: Color {
        return change.changeValue > 0 ? Color.green : Color.orange
    }
    
    private var changeText: String {
        let symbol = change.changeValue > 0 ? "+" : ""
        let unit = change.changeType.lowercased() == "weight" ? " lbs" : ""
        return "\(symbol)\(change.changeValue)\(unit)"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Change icon
            ZStack {
                Circle()
                    .fill(changeColor.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                Image(systemName: changeIcon)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(changeColor)
            }
            
            // Change details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(change.changeType.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(changeText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(changeColor)
                }
                
                Text(change.reasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

#Preview {
    let sampleResult = ProgressiveOverloadResponse(
        suggestions: [
            ProgressiveOverloadSuggestion(
                exerciseName: "Bench Press",
                suggestions: [
                    OverloadChange(
                        changeType: "weight",
                        changeValue: 5,
                        reasoning: "RPE consistently 65-70% - ready for weight increase"
                    ),
                    OverloadChange(
                        changeType: "reps",
                        changeValue: 2,
                        reasoning: "Low RPE indicates capacity for additional volume"
                    ),
                    OverloadChange(
                        changeType: "sets",
                        changeValue: 1,
                        reasoning: "Strong progression trend supports volume increase"
                    )
                ],
                reasoning: nil
            ),
            ProgressiveOverloadSuggestion(
                exerciseName: "Squat",
                suggestions: [
                    OverloadChange(
                        changeType: "weight",
                        changeValue: -10,
                        reasoning: "RPE trending 88-95% indicates overreaching"
                    ),
                    OverloadChange(
                        changeType: "reps",
                        changeValue: -1,
                        reasoning: "Reduce volume to aid recovery"
                    )
                ],
                reasoning: nil
            ),
            ProgressiveOverloadSuggestion(
                exerciseName: "Deadlift",
                suggestions: [
                    OverloadChange(
                        changeType: "sets",
                        changeValue: 1,
                        reasoning: "RPE 75% with good form - ready for volume increase"
                    )
                ],
                reasoning: nil
            ),
            ProgressiveOverloadSuggestion(
                exerciseName: "Pull-ups",
                suggestions: [],
                reasoning: "RPE stable at 75-80% range with recent form improvements. Optimal training stimulus - no changes needed."
            ),
            ProgressiveOverloadSuggestion(
                exerciseName: "Overhead Press",
                suggestions: [],
                reasoning: "Recent 10lb increase brought RPE from 70% to 85%. Allow 2-3 weeks adaptation before progressing."
            )
        ],
        summary: "Analysis shows mixed RPE patterns: bench press ready for multi-parameter progression (low RPE), squat needs deload (high RPE), deadlift ready for volume increase, while pull-ups and overhead press are in optimal training zones."
    )
    
    ProgressiveOverloadView(analysisResult: sampleResult)
        .environmentObject(NotificationService.shared)
} 