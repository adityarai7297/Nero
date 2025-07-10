import SwiftUI
import Neumorphic

struct ExerciseHistoryListView: View {
    let workoutService: WorkoutService
    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [String] = []
    @State private var exerciseStats: [String: ExerciseStats] = [:]
    @State private var isLoading = true
    @State private var selectedExercise: String?
    @State private var showingExerciseDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.offWhite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        LoadingView()
                    } else if exercises.isEmpty {
                        EmptyStateView()
                    } else {
                        ExerciseListView()
                    }
                }
            }
            .navigationTitle("Exercise History")
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
        .onAppear {
            loadExercises()
        }
        .sheet(isPresented: $showingExerciseDetail) {
            if let selectedExercise = selectedExercise {
                ExerciseDetailView(
                    exerciseName: selectedExercise,
                    workoutService: workoutService
                )
            }
        }
    }
    
    @ViewBuilder
    private func LoadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Loading exercise history...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func EmptyStateView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 16) {
                Text("No Exercise History")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Complete some workouts to see your exercise history and progress")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func ExerciseListView() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(exercises, id: \.self) { exerciseName in
                    ExerciseHistoryCard(
                        exerciseName: exerciseName,
                        stats: exerciseStats[exerciseName],
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
            for exerciseName in exerciseNames {
                if let exerciseStat = await workoutService.getExerciseStats(exerciseName: exerciseName) {
                    stats[exerciseName] = exerciseStat
                }
            }
            
            await MainActor.run {
                self.exercises = exerciseNames
                self.exerciseStats = stats
                self.isLoading = false
            }
        }
    }
}

struct ExerciseHistoryCard: View {
    let exerciseName: String
    let stats: ExerciseStats?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Exercise name and chevron
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if let stats = stats {
                            Text("\(stats.totalSets) sets recorded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Stats row
                if let stats = stats {
                    HStack(alignment: .top, spacing: 0) {
                        StatItem(
                            title: "Max Weight",
                            value: "\(Int(stats.maxWeight)) lbs",
                            icon: "scalemass.fill"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        StatItem(
                            title: "Max Volume", 
                            value: "\(Int(stats.maxVolume))",
                            icon: "chart.bar.fill"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let lastWorkout = stats.lastWorkout {
                            StatItem(
                                title: "Last Workout",
                                value: relativeDateString(from: lastWorkout),
                                icon: "calendar.circle.fill"
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.offWhite)
                    .softOuterShadow()
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

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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