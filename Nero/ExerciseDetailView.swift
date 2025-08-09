import SwiftUI

struct ExerciseDetailView: View {
    let exerciseName: String
    let workoutService: WorkoutService
    let isDarkMode: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeframe: ExerciseHistoryTimeframe = .all
    @State private var selectedChartType: ExerciseChartType = .volume
    @State private var exerciseHistory: [WorkoutSet] = []
    @State private var isLoading = true
    @State private var editingSet: WorkoutSet?
    @State private var showingEditSheet = false
    @State private var deletingSetIds: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        LoadingView(isDarkMode: isDarkMode)
                    } else {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Controls section
                                ControlsSection(isDarkMode: isDarkMode)
                                
                                // Chart section
                                ChartSection(isDarkMode: isDarkMode)
                                
                                // History list section
                                HistorySection(isDarkMode: isDarkMode)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .onAppear {
            loadHistory()
        }
        .onChange(of: selectedTimeframe) { oldValue, newValue in
            loadHistory()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let editingSet = editingSet {
                EditSetView(
                    set: editingSet,
                    workoutService: workoutService,
                    isDarkMode: isDarkMode,
                    onSave: { updatedSet in
                        updateSet(updatedSet)
                        showingEditSheet = false
                    },
                    onCancel: {
                        showingEditSheet = false
                    }
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
    private func ControlsSection(isDarkMode: Bool) -> some View {
        VStack(spacing: 16) {
            // Timeframe selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Timeframe")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ExerciseHistoryTimeframe.allCases, id: \.self) { timeframe in
                            TimeframeButton(
                                timeframe: timeframe,
                                isSelected: selectedTimeframe == timeframe,
                                isDarkMode: isDarkMode,
                                action: {
                                    selectedTimeframe = timeframe
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
            
            // Chart type selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Chart Type")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                HStack(spacing: 12) {
                    ForEach(ExerciseChartType.allCases, id: \.self) { chartType in
                        ChartTypeButton(
                            chartType: chartType,
                            isSelected: selectedChartType == chartType,
                            isDarkMode: isDarkMode,
                            action: {
                                selectedChartType = chartType
                            }
                        )
                    }
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.white)
                .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func ChartSection(isDarkMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Chart")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .primary)
            
            if exerciseHistory.isEmpty {
                EmptyChartView(isDarkMode: isDarkMode)
            } else {
                ExerciseChart(
                    data: exerciseHistory,
                    chartType: selectedChartType,
                    timeframe: selectedTimeframe,
                    isDarkMode: isDarkMode
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.white)
                .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func HistorySection(isDarkMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workout History")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Spacer()
                
                Text("\(exerciseHistory.count) sets")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
            }
            
            if exerciseHistory.isEmpty {
                EmptyHistoryView(isDarkMode: isDarkMode)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(exerciseHistory.sorted(by: { $0.timestamp > $1.timestamp })) { set in
                        ExerciseHistoryRow(
                            set: set,
                            isDeleting: deletingSetIds.contains(set.id),
                            isDarkMode: isDarkMode,
                            onEdit: {
                                editingSet = set
                                showingEditSheet = true
                            },
                            onDelete: {
                                deleteSet(set)
                            }
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.white)
                .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func EmptyChartView(isDarkMode: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray.opacity(0.6))
            
            Text("No data for selected timeframe")
                .font(.subheadline)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func EmptyHistoryView(isDarkMode: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray.opacity(0.6))
            
            Text("No workout history for selected timeframe")
                .font(.subheadline)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    private func loadHistory() {
        Task {
            let history = await workoutService.fetchExerciseHistory(
                exerciseName: exerciseName,
                timeframe: selectedTimeframe
            )
            
            await MainActor.run {
                self.exerciseHistory = history
                self.isLoading = false
            }
        }
    }
    
    private func deleteSet(_ set: WorkoutSet) {
        withAnimation(.easeInOut(duration: 0.3)) {
            deletingSetIds.insert(set.id)
        }
        
        Task {
            let success = await workoutService.deleteWorkoutSet(set)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    deletingSetIds.remove(set.id)
                }
                
                if success {
                    // Reload history to refresh chart
                    loadHistory()
                }
            }
        }
    }
    
    private func updateSet(_ updatedSet: WorkoutSet) {
        Task {
            let success = await workoutService.updateWorkoutSet(updatedSet)
            if success {
                // Reload history to refresh chart
                loadHistory()
            }
        }
    }
}

// MARK: - Supporting Views

struct TimeframeButton: View {
    let timeframe: ExerciseHistoryTimeframe
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeframe.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : Color.accentBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentBlue : (isDarkMode ? Color.white.opacity(0.06) : Color.white))
                .shadow(
                    color: isSelected ? Color.accentBlue.opacity(0.3) : (isDarkMode ? Color.clear : Color.black.opacity(0.1)),
                    radius: isSelected ? 8 : 2,
                    x: 0,
                    y: isSelected ? 4 : 1
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ChartTypeButton: View {
    let chartType: ExerciseChartType
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(chartType.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : Color.accentBlue)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentBlue : (isDarkMode ? Color.white.opacity(0.06) : Color.white))
                .shadow(
                    color: isSelected ? Color.accentBlue.opacity(0.3) : (isDarkMode ? Color.clear : Color.black.opacity(0.1)),
                    radius: isSelected ? 8 : 2,
                    x: 0,
                    y: isSelected ? 4 : 1
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ExerciseHistoryRow: View {
    let set: WorkoutSet
    let isDeleting: Bool
    let isDarkMode: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    // Computed properties to simplify complex expressions
    private var primaryTextColor: Color {
        isDeleting ? .gray : (isDarkMode ? .white : .primary)
    }
    
    private var secondaryTextColor: Color {
        isDarkMode ? .white.opacity(0.7) : .secondary
    }
    
    private var statsBackgroundColor: Color {
        isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.05)
    }
    
    private var statsStrokeColor: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15)
    }
    
    private var cardBackgroundColor: Color {
        isDarkMode ? Color.white.opacity(0.06) : Color.white
    }
    
    private var cardShadowColor: Color {
        isDarkMode ? Color.clear : Color.black.opacity(0.05)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Date and time row
            HStack {
                Text(formatDate(set.timestamp))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
                
                Text(formatTime(set.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(Color.accentBlue)
                            .frame(width: 32, height: 32)
                            .background(Color.accentBlue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.3 : 1.0)
                    
                    Button(action: onDelete) {
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isDeleting)
                }
            }
            
            // Main data row with left boxed stats and right volume
            HStack(alignment: .center, spacing: 20) {
                // Left side: Boxed vertical stats
                VStack(spacing: 12) {
                    // Weight
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .font(.caption)
                            .foregroundColor(Color.accentBlue)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weight")
                                .font(.caption2)
                                .foregroundColor(secondaryTextColor)
                            HStack(spacing: 4) {
                                Text("\(Int(set.weight))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(primaryTextColor)
                                Text("lbs")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }
                    
                    // Reps
                    HStack {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(Color.accentBlue)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(set.exerciseType == "static_hold" ? "Duration" : "Reps")
                                .font(.caption2)
                                .foregroundColor(secondaryTextColor)
                            HStack(spacing: 4) {
                                Text("\(Int(set.reps))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(primaryTextColor)
                                Text(set.exerciseType == "static_hold" ? "sec" : "reps")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }
                    
                    // RPE
                    HStack {
                        Image(systemName: "gauge.high")
                            .font(.caption)
                            .foregroundColor(Color.accentBlue)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RPE")
                                .font(.caption2)
                                .foregroundColor(secondaryTextColor)
                            HStack(spacing: 4) {
                                Text("\(Int(set.rpe))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(primaryTextColor)
                                Text("%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(statsBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(statsStrokeColor, lineWidth: 1)
                        )
                )
                
                Spacer()
                
                // Right side: Volume display
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title2)
                        .foregroundColor(Color.accentBlue)
                    
                    VStack(spacing: 4) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                        Text("\(Int(set.weight * set.reps))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(primaryTextColor)
                    }
                }
                .frame(minWidth: 80)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 4, x: 0, y: 2)
        )
        .opacity(isDeleting ? 0.6 : 1.0)
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isDeleting)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 