import SwiftUI

struct MacroHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var macroService = MacroService()
    let userId: UUID?
    let isDarkMode: Bool
    
    @State private var summaries: [MacroDaySummary] = []
    @State private var isLoading: Bool = true
    @State private var selectedDate: Date?
    @State private var showingDayDetail: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                if isLoading {
                    ProgressView().scaleEffect(1.2)
                } else if summaries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie.fill").font(.system(size: 48)).foregroundColor(.gray)
                        Text("No macro history yet").font(.title2).fontWeight(.semibold).foregroundColor(isDarkMode ? .white : .primary)
                        Text("Log some meals to see daily totals here.").font(.body).foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(summaries) { summary in
                                MacroDayCard(summary: summary, isDarkMode: isDarkMode) {
                                    selectedDate = summary.date
                                    showingDayDetail = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Macro History")
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
        .onAppear {
            macroService.setUser(userId)
            Task {
                let data = await macroService.fetchHistoryDays()
                await MainActor.run {
                    self.summaries = data
                    self.isLoading = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MacroDataChanged"))) { _ in
            Task {
                let data = await macroService.fetchHistoryDays()
                await MainActor.run { self.summaries = data }
            }
        }
        .sheet(isPresented: $showingDayDetail) {
            if let selectedDate = selectedDate {
                MacroDayDetailView(date: selectedDate, macroService: macroService, isDarkMode: isDarkMode)
            }
        }
    }
}

struct MacroDayCard: View {
    let summary: MacroDaySummary
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                    // Date chip
                    VStack(spacing: 6) {
                        Text(shortWeekday(summary.date)).font(.caption2).foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        Text(dayNumber(summary.date)).font(.title3).fontWeight(.bold)
                    }
                    .frame(width: 46, height: 56)
                    .background(RoundedRectangle(cornerRadius: 10).fill(isDarkMode ? Color.white.opacity(0.08) : Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15), lineWidth: 1))

                    // Center: date and meals
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dateString(summary.date))
                            .font(.headline)
                            .foregroundColor(isDarkMode ? .white : .primary)
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife").font(.caption).foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                            Text("\(summary.mealsCount) meals")
                                .font(.caption)
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    // Right: vertical stats list (Protein, Carbs, Fat, Calories)
                    VStack(alignment: .leading, spacing: 10) {
                        MacroInlineStat(label: "Protein", value: Int(summary.totals.protein), color: .blue, isDarkMode: isDarkMode)
                        MacroInlineStat(label: "Carbs", value: Int(summary.totals.carbs), color: .orange, isDarkMode: isDarkMode)
                        MacroInlineStat(label: "Fat", value: Int(summary.totals.fat), color: .purple, isDarkMode: isDarkMode)
                        MacroInlineStat(label: "Calories", value: Int(summary.totals.calories), color: .red, isDarkMode: isDarkMode)
                    }
                    .padding(.trailing, 4)

                    // Dedicated space for chevron
                    Image(systemName: "chevron.right")
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        .frame(width: 16)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                        .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateStyle = .medium; return fmt.string(from: date)
    }
    private func shortWeekday(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date).uppercased() }
    private func dayNumber(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date) }
}

struct MacroInlineStat: View {
    let label: String
    let value: Int
    let color: Color
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Text("\(value)")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 1))
        )
        .fixedSize(horizontal: true, vertical: true)
    }
}

// Removed old StatsPanel in favor of single vertical stack

struct MacroDayDetailView: View {
    let date: Date
    @ObservedObject var macroService: MacroService
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var meals: [MacroMeal] = []
    @State private var isLoading: Bool = true
    @State private var editingMeal: MacroMeal?
    @State private var showingManualEditSheet: Bool = false
    @State private var editPrompt: String = ""
    @State private var isEditingWithAI: Bool = false
    @State private var isAIEditingInProgress: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                if isLoading {
                    ProgressView().scaleEffect(1.2)
                } else if meals.isEmpty {
                    Text("No meals for this day").foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(meals) { meal in
                                MealCard(
                                    meal: meal,
                                    isDarkMode: isDarkMode,
                                    onEditManual: { editingMeal = meal; showingManualEditSheet = true },
                                    onEditAI: {
                                        editingMeal = meal
                                        editPrompt = ""
                                        isEditingWithAI = true
                                    },
                                    onDelete: {
                                        Task { _ = await macroService.deleteMeal(meal); await load() }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle(dateString(date))
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
        }
        .onAppear { Task { await load() } }
        .onDisappear {
            // When closing detail view, notify parent to refresh summaries
            NotificationCenter.default.post(name: NSNotification.Name("MacroDataChanged"), object: nil)
        }
        .sheet(isPresented: $showingManualEditSheet) {
            if let editingMeal = editingMeal {
                MacroManualEditView(meal: editingMeal, isDarkMode: isDarkMode) { updated in
                    Task {
                        _ = await macroService.updateMeal(updated)
                        await load()
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
                        }
                        await load()
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
                    .padding(.bottom, 20)
            }
        }
    }
    
    private func load() async {
        let data = await macroService.fetchMeals(for: date)
        await MainActor.run { self.meals = data; self.isLoading = false }
    }
    
    private func dateString(_ date: Date) -> String { let fmt = DateFormatter(); fmt.dateStyle = .medium; return fmt.string(from: date) }
}

struct MacroManualEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var meal: MacroMeal
    let isDarkMode: Bool
    let onSave: (MacroMeal) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    MealTitleSection(meal: $meal, isDarkMode: isDarkMode)
                    FoodItemsSection(meal: $meal, isDarkMode: isDarkMode)
                    TotalsSection(meal: meal, isDarkMode: isDarkMode)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(isDarkMode ? Color.black : Color(.systemGroupedBackground))
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave(meal); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentBlue)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct MealTitleSection: View {
    @Binding var meal: MacroMeal
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Title")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .primary)
            
            TextField("Enter meal title", text: $meal.title)
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
        }
    }
}

struct FoodItemsSection: View {
    @Binding var meal: MacroMeal
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Food Items")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Spacer()
                
                Button("Add Item") {
                    meal.items.append(MacroItem(name: "", quantityDescription: "", calories: 0, protein: 0, carbs: 0, fat: 0))
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.accentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.accentBlue.opacity(0.08))
                        .overlay(Capsule().stroke(Color.accentBlue.opacity(0.25), lineWidth: 1))
                )
            }
            
            ForEach(meal.items.indices, id: \.self) { idx in
                FoodItemEditCard(
                    item: $meal.items[idx],
                    isDarkMode: isDarkMode,
                    onDelete: {
                        meal.items.remove(at: idx)
                    }
                )
            }
        }
    }
}

struct TotalsSection: View {
    let meal: MacroMeal
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calculated Totals")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .primary)
            
            HStack {
                Text("\(Int(meal.totals.calories)) kcal")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Text("P \(Int(meal.totals.protein))g").font(.caption).foregroundColor(.blue)
                    Text("C \(Int(meal.totals.carbs))g").font(.caption).foregroundColor(.orange)
                    Text("F \(Int(meal.totals.fat))g").font(.caption).foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

struct FoodItemEditCard: View {
    @Binding var item: MacroItem
    let isDarkMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with delete button
            HStack {
                Text("Food Item")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .primary)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.08))
                                .overlay(Circle().stroke(Color.red.opacity(0.25), lineWidth: 1))
                        )
                }
            }
            
            // Name and Quantity
            VStack(spacing: 10) {
                CustomTextField(
                    title: "Name",
                    text: $item.name,
                    placeholder: "e.g. Chicken breast",
                    isDarkMode: isDarkMode
                )
                
                CustomTextField(
                    title: "Quantity",
                    text: $item.quantityDescription,
                    placeholder: "e.g. 6 oz",
                    isDarkMode: isDarkMode
                )
            }
            
            // Macro fields
            VStack(spacing: 8) {
                HStack {
                    Text("Calories")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                    Spacer()
                    DarkModeNumberField(value: $item.calories, isDarkMode: isDarkMode)
                }
                
                HStack {
                    Text("Protein (g)")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                    Spacer()
                    DarkModeNumberField(value: $item.protein, isDarkMode: isDarkMode)
                }
                
                HStack {
                    Text("Carbs (g)")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                    Spacer()
                    DarkModeNumberField(value: $item.carbs, isDarkMode: isDarkMode)
                }
                
                HStack {
                    Text("Fat (g)")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                    Spacer()
                    DarkModeNumberField(value: $item.fat, isDarkMode: isDarkMode)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundColor(isDarkMode ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

struct DarkModeNumberField: View {
    @Binding var value: Double
    let isDarkMode: Bool
    
    var body: some View {
        TextField("0", value: $value, formatter: numberFormatter)
            .font(.body)
            .foregroundColor(isDarkMode ? .white : .primary)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .frame(width: 80)
    }
    
    private var numberFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 1
        return nf
    }
}

struct NumberField: View {
    @Binding var value: Double
    var body: some View {
        TextField("0", value: $value, formatter: numberFormatter)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 120)
    }
    private var numberFormatter: NumberFormatter { let nf = NumberFormatter(); nf.minimumFractionDigits = 0; nf.maximumFractionDigits = 1; return nf }
}

// MARK: - Styled Buttons / Toast

struct ActionButtonsRow: View {
    let isDarkMode: Bool
    let onEditManual: () -> Void
    let onEditAI: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            CapsuleButton(title: "Edit Manually", systemImage: "pencil", color: .accentBlue, isDarkMode: isDarkMode, action: onEditManual)
            CapsuleButton(title: "Edit with AI", systemImage: "sparkles", color: .orange, isDarkMode: isDarkMode, action: onEditAI)
            CapsuleButton(title: "Delete", systemImage: "trash", color: .red, isDarkMode: isDarkMode, action: onDelete)
        }
        .padding(.top, 6)
    }
}

struct CapsuleButton: View {
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

struct AIEditingToast: View {
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .orange))
            Text("Editing macros with AI…")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isDarkMode ? .white : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
        )
    }
}

// MARK: - Meal Card Component

private extension String {
    var titleCased: String { self.localizedCapitalized }
}

struct MealCard: View {
    let meal: MacroMeal
    let isDarkMode: Bool
    let onEditManual: () -> Void
    let onEditAI: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with title-cased meal name and calories badge
            HStack {
                Text(meal.title.titleCased)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .white : .primary)
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
            VStack(spacing: 10) {
                ForEach(meal.items) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
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
                            HStack(spacing: 8) {
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
                Text("\(Int(meal.totals.calories)) kcal | P \(Int(meal.totals.protein)) C \(Int(meal.totals.carbs)) F \(Int(meal.totals.fat))")
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
            }

            // Actions
            ActionButtonsRow(isDarkMode: isDarkMode, onEditManual: onEditManual, onEditAI: onEditAI, onDelete: onDelete)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                .shadow(color: isDarkMode ? Color.clear : Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }
}


