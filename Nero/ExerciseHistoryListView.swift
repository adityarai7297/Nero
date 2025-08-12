import SwiftUI

struct ExerciseHistoryListView: View {
    let workoutService: WorkoutService
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [String] = []
    @State private var exerciseStats: [String: ExerciseStats] = [:]
    @State private var isLoading = true
    @State private var selectedExercise: String?
    @State private var showingExerciseDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        LoadingView(isDarkMode: isDarkMode)
                    } else if exercises.isEmpty {
                        EmptyStateView(isDarkMode: isDarkMode)
                    } else {
                        ExerciseListView(isDarkMode: isDarkMode)
                    }
                }
            }
            .navigationTitle("Exercise History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .preferredColorScheme(isDarkMode ? .dark : .light)
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
        .onAppear {
            loadExercises()
        }
        .sheet(isPresented: $showingExerciseDetail, onDismiss: {
            // Refresh the exercise list when returning from detail view
            // This ensures that exercises with no remaining sets are removed
            loadExercises()
        }) {
            if let selectedExercise = selectedExercise {
                ExerciseDetailView(
                    exerciseName: selectedExercise,
                    workoutService: workoutService,
                    isDarkMode: isDarkMode
                )
            }
        }
    }
    
    @ViewBuilder
    private func LoadingView(isDarkMode: Bool) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Loading exercise history...")
                .font(.headline)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func EmptyStateView(isDarkMode: Bool) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray.opacity(0.6))
            
            VStack(spacing: 16) {
                Text("No Exercise History")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Text("Complete some workouts to see your exercise history and progress")
                    .font(.body)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func ExerciseListView(isDarkMode: Bool) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(exercises, id: \.self) { exerciseName in
                    ExerciseHistoryCard(
                        exerciseName: exerciseName,
                        stats: exerciseStats[exerciseName],
                        isDarkMode: isDarkMode,
                        onTap: {
                            selectedExercise = exerciseName
                            showingExerciseDetail = true
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func loadExercises() {
        Task {
            let exerciseNames = await workoutService.fetchAllUserExercises()
            
            // Load stats for each exercise
            var stats: [String: ExerciseStats] = [:]
            var validExercises: [String] = []
            
            for exerciseName in exerciseNames {
                if let exerciseStat = await workoutService.getExerciseStats(exerciseName: exerciseName) {
                    stats[exerciseName] = exerciseStat
                    validExercises.append(exerciseName)
                }
                // If getExerciseStats returns nil, it means no sets exist for this exercise
                // so we don't include it in the list to avoid ghost data
            }
            
            await MainActor.run {
                self.exercises = validExercises
                self.exerciseStats = stats
                self.isLoading = false
            }
        }
    }
}

struct ExerciseHistoryCard: View {
    let exerciseName: String
    let stats: ExerciseStats?
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 20) {
                // Header section with exercise name and chevron
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exerciseName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(isDarkMode ? .white : .primary)
                            .multilineTextAlignment(.leading)
                        
                        if let stats = stats {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet.clipboard.fill")
                                    .font(.caption2)
                                    .foregroundColor(Color.accentBlue)
                                Text("\(stats.totalSets) sets recorded")
                                    .font(.subheadline)
                                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        .padding(.top, 4)
                }
                
                // Stats section with better organization
                if let stats = stats {
                    VStack(spacing: 16) {
                        // Top row: Max Weight and Max Volume
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Max Weight",
                                value: "\(Int(stats.maxWeight)) lbs",
                                icon: "scalemass.fill",
                                color: Color.accentBlue,
                                isDarkMode: isDarkMode
                            )
                            
                            StatCard(
                                title: "Max Volume", 
                                value: "\(Int(stats.maxVolume))",
                                icon: "chart.bar.fill",
                                color: Color.accentBlue,
                                isDarkMode: isDarkMode
                            )
                        }
                        
                        // Bottom section: Last Workout (if available)
                        if let lastWorkout = stats.lastWorkout {
                            HStack {
                                StatCard(
                                    title: "Last Workout",
                                    value: relativeDateString(from: lastWorkout),
                                    icon: "calendar.circle.fill",
                                    color: Color.accentBlue,
                                    isDarkMode: isDarkMode
                                )
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.12) : Color.white)
                    .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon container
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDarkMode ? Color.white.opacity(0.15) : Color.gray.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(Color.accentBlue)
                    .frame(width: 10, height: 10)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
} 