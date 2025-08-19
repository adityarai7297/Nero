import SwiftUI

struct MacroChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let mealData: MacroMeal?
    
    init(content: String, isFromUser: Bool, timestamp: Date, mealData: MacroMeal? = nil) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.mealData = mealData
    }
}

struct MacroChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var macroService = MacroService()
    let userId: UUID?
    let isDarkMode: Bool
    
    @State private var messages: [MacroChatMessage] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentTaskId: String?
    @FocusState private var isTextFieldFocused: Bool
    @State private var textFieldResetId = UUID()
    @StateObject private var audioTranscription = AudioTranscriptionService()
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    
    // Date navigation
    @State private var selectedDate: Date = Date()
    @State private var currentDateMeals: [MacroMeal] = []
    @State private var currentDateTotals: MacroTotals = MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)
    
    // Edit functionality
    @State private var editingMeal: MacroMeal?
    @State private var showingManualEditSheet: Bool = false
    @State private var editPrompt: String = ""
    @State private var isEditingWithAI: Bool = false
    @State private var isAIEditingInProgress: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Date Navigation
                    DateNavigationBar(selectedDate: $selectedDate, isDarkMode: isDarkMode) {
                        loadMealsForSelectedDate()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Top summary bar
                    MacroTotalsHeader(totals: currentDateTotals, isDarkMode: isDarkMode)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                    Divider().opacity(isDarkMode ? 0.3 : 0.2)
                    
                    // Chat Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if messages.isEmpty && !isLoading {
                                    MacroChatWelcome(isDarkMode: isDarkMode)
                                }
                                                ForEach(messages) { message in
                    MacroChatBubble(
                        message: message, 
                        isDarkMode: isDarkMode,
                        onEditManual: { meal in
                            editingMeal = meal
                            showingManualEditSheet = true
                        },
                        onEditAI: { meal in
                            editingMeal = meal
                            editPrompt = ""
                            isEditingWithAI = true
                        }
                    )
                    .id(message.id)
                }
                                // (Recording UI now shows in the input field)
                                
                                if isLoading {
                                    MacroTypingIndicatorView(isDarkMode: isDarkMode)
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onAppear {
                            // Auto-scroll to bottom when view appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if let lastMessage = messages.last {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    } else if isLoading {
                                        proxy.scrollTo("typing", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: messages.count) { _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: isLoading) { loading in
                            if loading {
                                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("typing", anchor: .bottom) }
                            }
                        }
                    }
                    
                    // Input Area
                    VStack(spacing: 8) {
                        if let errorMessage = errorMessage {
                            ErrorMessageView(message: errorMessage, isDarkMode: isDarkMode) { self.errorMessage = nil }
                        }
                        HStack(spacing: 12) {
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                                    .frame(height: 40)
                                if case .recording = audioTranscription.recordingState {
                                    HStack(spacing: 10) {
                                        Image(systemName: "mic.fill").foregroundColor(.red)
                                        AudioWaveletVisualization(isDarkMode: isDarkMode)
                                            .frame(height: 18)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                } else {
                                    TextField("e.g. 2 eggs scrambled in 1 tsp butter with toast and coffee", text: $messageText, axis: .vertical)
                                        .id(textFieldResetId)
                                        .font(.body)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .lineLimit(1...5)
                                        .focused($isTextFieldFocused)
                                        .onSubmit { sendMessage() }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            // Audio recording button with shared transcription service
                            SharedAudioRecordingButton(
                                messageText: $messageText,
                                isDarkMode: isDarkMode,
                                isDisabled: isLoading,
                                transcriptionService: audioTranscription
                            )
                            
                            Button(action: sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray : Color.accentBlue)
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .background(isDarkMode ? Color.black : Color.offWhite)
                    }
                }
            }
            .navigationTitle("Macro Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentBlue)
                }
            }
        }
        .environment(\.colorScheme, isDarkMode ? .dark : .light)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            macroService.setUser(userId)
            restoreViewState()
            loadMealsForSelectedDateWithoutClearingChat()
            isTextFieldFocused = true
            checkForCompletedTasks()
            
            // Additional safety check: if still loading but no active task, clear it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if isLoading && currentTaskId == nil {
                    print("🧹 MacroChatView: Safety cleanup - clearing orphaned loading state")
                    isLoading = false
                }
            }
        }
        .onDisappear {
            saveViewState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // App became active, check for any completed background tasks
                checkForCompletedTasks()
            }
        }
        .onChange(of: messages) { _, _ in
            // Auto-save state when messages change
            saveViewState()
        }
        .onChange(of: audioTranscription.recordingState) { _, newValue in
            if case .completed(let text) = newValue {
                if !text.isEmpty {
                    messageText = messageText.isEmpty ? text : (messageText + " " + text)
                    textFieldResetId = UUID()
                }
                Task { await audioTranscription.cancelRecording() }
            }
        }
        .sheet(isPresented: $showingManualEditSheet) {
            if let editingMeal = editingMeal {
                MacroManualEditView(meal: editingMeal, isDarkMode: isDarkMode) { updated in
                    Task {
                        _ = await macroService.updateMeal(updated)
                        // Update the message in the chat
                        if let index = messages.firstIndex(where: { $0.mealData?.databaseId == editingMeal.databaseId }) {
                            messages[index] = MacroChatMessage(content: "meal_breakdown", isFromUser: false, timestamp: messages[index].timestamp, mealData: updated)
                        }
                        // Update current date meals
                        if let mealIndex = currentDateMeals.firstIndex(where: { $0.databaseId == editingMeal.databaseId }) {
                            currentDateMeals[mealIndex] = updated
                            recalculateCurrentDateTotals()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingWithAI) {
            AIEditMealSheet(
                editPrompt: $editPrompt,
                isDarkMode: isDarkMode,
                isProcessing: isAIEditingInProgress,
                onApply: {
                    Task {
                        guard let meal = editingMeal else { return }
                        await MainActor.run { isAIEditingInProgress = true }
                        if let updated = await macroService.editMealWithAI(existingMeal: meal, editRequest: editPrompt) {
                            _ = await macroService.updateMeal(updated)
                            // Update the message in the chat
                            if let index = messages.firstIndex(where: { $0.mealData?.databaseId == meal.databaseId }) {
                                await MainActor.run {
                                    messages[index] = MacroChatMessage(content: "meal_breakdown", isFromUser: false, timestamp: messages[index].timestamp, mealData: updated)
                                    // Update current date meals
                                    if let mealIndex = currentDateMeals.firstIndex(where: { $0.databaseId == meal.databaseId }) {
                                        currentDateMeals[mealIndex] = updated
                                        recalculateCurrentDateTotals()
                                    }
                                }
                            }
                        }
                        await MainActor.run { 
                            isAIEditingInProgress = false
                        }
                    }
                },
                onCancel: {
                    isEditingWithAI = false
                    editPrompt = ""
                }
            )
        }
        .overlay(alignment: .bottom) {
            if isAIEditingInProgress {
                AIEditingToast(isDarkMode: isDarkMode)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80)
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !isLoading else { return }
        
        messages.append(MacroChatMessage(content: trimmed, isFromUser: true, timestamp: Date()))
        messageText = ""
        textFieldResetId = UUID()
        isLoading = true
        errorMessage = nil
        isTextFieldFocused = true
        
        let taskId = "macro_meal_\(UUID().uuidString)"
        currentTaskId = taskId
        
        macroService.saveMealFromDescriptionInBackground(trimmed, forDate: selectedDate, taskId: taskId) { result in
            Task { @MainActor in
                switch result {
                case .success(let savedMeal):
                    let confirmation = MacroChatMessage(content: "meal_breakdown", isFromUser: false, timestamp: Date(), mealData: savedMeal)
                    messages.append(confirmation)
                    currentDateMeals.append(savedMeal)
                    recalculateCurrentDateTotals()
                    isLoading = false
                    currentTaskId = nil
                    
                case .failure(let error):
                    isLoading = false
                    currentTaskId = nil
                    
                    if let deepseekError = error as? DeepseekError {
                        switch deepseekError {
                        case .couldNotUnderstand:
                            messages.append(MacroChatMessage(content: "I couldn't understand that. Try describing your meal with ingredients and amounts (e.g., '2 eggs scrambled in 1 tsp butter with 1 slice toast').", isFromUser: false, timestamp: Date()))
                        default:
                            errorMessage = deepseekError.localizedDescription
                        }
                    } else {
                        errorMessage = "Failed to log meal: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func saveViewState() {
        ViewStatePersistenceManager.shared.saveMacroChatViewState(
            messages: messages,
            currentTaskId: currentTaskId,
            isLoading: isLoading,
            selectedDate: selectedDate
        )
        
        // Associate any active task with this view
        if let taskId = currentTaskId {
            ViewStatePersistenceManager.shared.associateTaskWithView(taskId: taskId, viewType: "MacroChatView")
        }
    }
    
    private func restoreViewState() {
        if let savedState = ViewStatePersistenceManager.shared.loadMacroChatViewState() {
            messages = savedState.messages
            currentTaskId = savedState.currentTaskId
            // Always use current date instead of restoring saved date
            selectedDate = Date()
            
            // Only restore loading state if there's actually a running task
            if let taskId = savedState.currentTaskId,
               let taskInfo = backgroundTaskManager.getTaskInfo(taskId),
               taskInfo.status == .running {
                isLoading = savedState.isLoading
                print("🔄 MacroChatView: Restored state with \(messages.count) messages, loading: \(isLoading) - task \(taskId) is still running")
            } else {
                isLoading = false  // Clear stale loading state
                if let taskId = savedState.currentTaskId {
                    print("🧹 MacroChatView: Cleared stale loading state - task \(taskId) is no longer running")
                } else {
                    print("🧹 MacroChatView: Cleared stale loading state - no current task")
                }
            }
        }
    }
    
    private func checkForCompletedTasks() {
        // First check for any orphaned tasks that might belong to this view
        for (taskId, taskInfo) in backgroundTaskManager.activeTasks {
            if let viewType = ViewStatePersistenceManager.shared.getViewForTask(taskId: taskId),
               viewType == "MacroChatView",
               taskInfo.status == .completed {
                
                // Found a completed task for this view
                if let result = ResultPersistenceManager.shared.loadMacroMealResult(taskId: taskId) {
                    let confirmation = MacroChatMessage(content: "meal_breakdown", isFromUser: false, timestamp: result.timestamp, mealData: result.meal)
                    messages.append(confirmation)
                    currentDateMeals.append(result.meal)
                    recalculateCurrentDateTotals()
                    isLoading = false
                    currentTaskId = nil
                    
                    // Clean up the association
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("✅ MacroChatView: Restored completed task result for \(taskId)")
                    return
                } else {
                    // Task completed but no result found - show error and clear loading
                    isLoading = false
                    currentTaskId = nil
                    messages.append(MacroChatMessage(
                        content: "Sorry, there was an issue retrieving the meal data. Please try again.",
                        isFromUser: false,
                        timestamp: Date()
                    ))
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("⚠️ MacroChatView: Task \(taskId) completed but no result found")
                    return
                }
            }
        }
        
        // Then check the current task if we have one
        guard let taskId = currentTaskId else { return }
        
        // Check if the task has completed while we were away
        if let taskInfo = backgroundTaskManager.getTaskInfo(taskId) {
            switch taskInfo.status {
            case .completed:
                // Try to load the persisted result
                if let result = ResultPersistenceManager.shared.loadMacroMealResult(taskId: taskId) {
                    let confirmation = MacroChatMessage(content: "meal_breakdown", isFromUser: false, timestamp: result.timestamp, mealData: result.meal)
                    messages.append(confirmation)
                    currentDateMeals.append(result.meal)
                    recalculateCurrentDateTotals()
                    isLoading = false
                    currentTaskId = nil
                    
                    // Clean up the association
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("✅ MacroChatView: Current task \(taskId) completed successfully")
                } else {
                    // Task completed but no result found - show error and clear loading
                    isLoading = false
                    currentTaskId = nil
                    messages.append(MacroChatMessage(
                        content: "Sorry, there was an issue retrieving the meal data. Please try again.",
                        isFromUser: false,
                        timestamp: Date()
                    ))
                    ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                    print("⚠️ MacroChatView: Current task \(taskId) completed but no result found")
                }
            case .failed:
                isLoading = false
                messages.append(MacroChatMessage(
                    content: "Sorry, the meal processing failed while the view was not active. Please try again.",
                    isFromUser: false,
                    timestamp: Date()
                ))
                currentTaskId = nil
                
                // Clean up the association
                ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                print("❌ MacroChatView: Current task \(taskId) failed")
            case .running:
                // Task is still running, keep the loading state
                isLoading = true
                print("⏳ MacroChatView: Task \(taskId) still running")
            }
        } else {
            // Task not found in BackgroundTaskManager - it either completed and was cleaned up, or failed
            // Check if we have a persisted result
            if let result = ResultPersistenceManager.shared.loadMacroMealResult(taskId: taskId) {
                let confirmation = MacroChatMessage(content: "meal_breakdown", isFromUser: false, timestamp: result.timestamp, mealData: result.meal)
                messages.append(confirmation)
                currentDateMeals.append(result.meal)
                recalculateCurrentDateTotals()
                isLoading = false
                currentTaskId = nil
                ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                print("✅ MacroChatView: Found persisted result for cleaned up task \(taskId)")
            } else {
                // No task and no result - task likely failed or timed out
                isLoading = false
                currentTaskId = nil
                messages.append(MacroChatMessage(
                    content: "Sorry, the meal processing timed out or failed. Please try again.",
                    isFromUser: false,
                    timestamp: Date()
                ))
                ViewStatePersistenceManager.shared.clearTaskViewAssociation(taskId: taskId)
                print("❌ MacroChatView: Task \(taskId) not found and no result - likely failed or timed out")
            }
        }
    }
    
    private func loadMealsForSelectedDate() {
        Task {
            let meals = await macroService.fetchMeals(for: selectedDate)
            await MainActor.run {
                currentDateMeals = meals
                recalculateCurrentDateTotals()
                // Clear chat messages when date changes - don't show historical meals, keep it clean
                messages = []
                print("📅 MacroChatView: Date changed, cleared chat messages and loaded \(meals.count) meals for \(selectedDate)")
            }
        }
    }
    
    private func loadMealsForSelectedDateWithoutClearingChat() {
        Task {
            let meals = await macroService.fetchMeals(for: selectedDate)
            await MainActor.run {
                currentDateMeals = meals
                recalculateCurrentDateTotals()
                // Don't clear chat messages when view appears - preserve conversation
                print("🔄 MacroChatView: View appeared, loaded \(meals.count) meals for \(selectedDate) without clearing chat")
            }
        }
    }
    
    private func recalculateCurrentDateTotals() {
        currentDateTotals = currentDateMeals.reduce(MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)) { acc, meal in
            MacroTotals(
                calories: acc.calories + meal.totals.calories,
                protein: acc.protein + meal.totals.protein,
                carbs: acc.carbs + meal.totals.carbs,
                fat: acc.fat + meal.totals.fat
            )
        }
    }
}

// MARK: - Header

struct MacroTotalsHeader: View {
    let totals: MacroTotals
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            MacroTotalPill(title: "Calories", value: Int(totals.calories), unit: "kcal", color: .red, isDarkMode: isDarkMode)
            MacroTotalPill(title: "Protein", value: Int(totals.protein), unit: "g", color: .blue, isDarkMode: isDarkMode)
            MacroTotalPill(title: "Carbs", value: Int(totals.carbs), unit: "g", color: .orange, isDarkMode: isDarkMode)
            MacroTotalPill(title: "Fat", value: Int(totals.fat), unit: "g", color: .purple, isDarkMode: isDarkMode)
        }
    }
}

struct MacroTotalPill: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
            Text("\(value)")
                .font(.headline)
                .foregroundColor(color)
            Text(unit)
                .font(.caption2)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Chat Bits

struct MacroChatWelcome: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text("Log your meals in plain English")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .primary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                Text("- greek yogurt with honey and granola")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                Text("- 6oz grilled chicken, 1 cup rice, 1 tbsp olive oil")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                Text("- 2 eggs scrambled in 1 tsp butter + toast")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15), lineWidth: 1))
        )
    }
}

struct MacroChatBubble: View {
    let message: MacroChatMessage
    let isDarkMode: Bool
    let onEditManual: (MacroMeal) -> Void
    let onEditAI: (MacroMeal) -> Void
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accentBlue)
                        .clipShape(.rect(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16))
                    Text(timeString(message.timestamp)).font(.caption2).foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                }
                .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if message.content == "meal_breakdown", let meal = message.mealData {
                        // Show meal breakdown instead of text
                        MacroMealBreakdownView(meal: meal, isDarkMode: isDarkMode, onEditManual: onEditManual, onEditAI: onEditAI)
                    } else {
                        // Show regular text message
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(isDarkMode ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                            .clipShape(.rect(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
                    }
                    Text(timeString(message.timestamp)).font(.caption2).foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                }
                .frame(maxWidth: .infinity * 0.85, alignment: .leading)
                Spacer()
            }
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.timeStyle = .short; return fmt.string(from: date)
    }
}

struct MacroTypingIndicatorView: View {
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(0.8)
                    
                    Text("Calculating macros…")
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Spacer()
        }
    }
}

// MARK: - Meal Breakdown Component

struct MacroMealBreakdownView: View {
    let meal: MacroMeal
    let isDarkMode: Bool
    let onEditManual: (MacroMeal) -> Void
    let onEditAI: (MacroMeal) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Success message and calories badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meal logged successfully!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text(meal.title.titleCased)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white : .primary)
                }
                Spacer()
                Text("\(Int(meal.totals.calories)) kcal")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.red.opacity(0.08)))
            }

            Divider().padding(.vertical, 2)

            // Items list
            VStack(spacing: 8) {
                ForEach(meal.items) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(isDarkMode ? .white : .primary)
                            Text(item.quantityDescription)
                                .font(.caption)
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(item.calories)) kcal")
                                .font(.caption)
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                            HStack(spacing: 6) {
                                Text("P \(Int(item.protein))g").font(.caption2).foregroundColor(.blue)
                                Text("C \(Int(item.carbs))g").font(.caption2).foregroundColor(.orange)
                                Text("F \(Int(item.fat))g").font(.caption2).foregroundColor(.purple)
                            }
                        }
                    }
                    if item.id != meal.items.last?.id {
                        Divider().padding(.leading, 0)
                    }
                }
            }

            // Totals row
            HStack {
                Text("Totals")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                Spacer()
                Text("P \(Int(meal.totals.protein)) C \(Int(meal.totals.carbs)) F \(Int(meal.totals.fat))")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
            }

            // Action buttons
            HStack(spacing: 8) {
                ChatActionButton(title: "Edit Manually", systemImage: "pencil", color: Color.accentBlue, isDarkMode: isDarkMode) {
                    onEditManual(meal)
                }
                ChatActionButton(title: "Edit with AI", systemImage: "sparkles", color: .orange, isDarkMode: isDarkMode) {
                    onEditAI(meal)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct ChatActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.08))
                    .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Date Navigation

struct DateNavigationBar: View {
    @Binding var selectedDate: Date
    let isDarkMode: Bool
    let onDateChanged: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    onDateChanged()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentBlue)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                            .overlay(Circle().stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15), lineWidth: 1))
                    )
            }
            
            VStack(spacing: 4) {
                Text(dateTitle(selectedDate))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                    .animation(.easeInOut(duration: 0.2), value: selectedDate)
                
                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.08)))
                } else {
                    Text(weekdayString(selectedDate))
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    onDateChanged()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentBlue)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                            .overlay(Circle().stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15), lineWidth: 1))
                    )
            }
        }
        .padding(.vertical, 8)
    }
    
    private func dateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func weekdayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// Extension for title case
private extension String {
    var titleCased: String { self.localizedCapitalized }
}

// MARK: - AI Edit Meal Sheet

struct AIEditMealSheet: View {
    @Binding var editPrompt: String
    let isDarkMode: Bool
    let isProcessing: Bool
    let onApply: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Edit Meal with AI")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white : .primary)
                    
                    Text("Describe your change. The AI will adjust the items and totals.")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                    
                    TextField("e.g. I used 1 tbsp butter instead of 2 tsp", text: $editPrompt, axis: .vertical)
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .lineLimit(3...6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.1))
                    )
                    
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(editPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.orange)
                    )
                    .disabled(editPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    .opacity(isProcessing ? 0.6 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(isDarkMode ? Color.black : Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
}

