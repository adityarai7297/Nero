import SwiftUI

struct MacroHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var macroService = MacroService()
    let userId: UUID?
    
    @State private var summaries: [MacroDaySummary] = []
    @State private var isLoading: Bool = true
    @State private var selectedDate: Date?
    @State private var showingDayDetail: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.offWhite.ignoresSafeArea()
                if isLoading {
                    ProgressView().scaleEffect(1.2)
                } else if summaries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie.fill").font(.system(size: 48)).foregroundColor(.gray)
                        Text("No macro history yet").font(.title2).fontWeight(.semibold)
                        Text("Log some meals to see daily totals here.").font(.body).foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(summaries) { summary in
                                MacroDayCard(summary: summary) {
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
                MacroDayDetailView(date: selectedDate, macroService: macroService)
            }
        }
    }
}

struct MacroDayCard: View {
    let summary: MacroDaySummary
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Date chip
                VStack(spacing: 6) {
                    Text(shortWeekday(summary.date)).font(.caption2).foregroundColor(.secondary)
                    Text(dayNumber(summary.date)).font(.title3).fontWeight(.bold)
                }
                .frame(width: 46, height: 56)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(dateString(summary.date))
                        .font(.headline)
                        .foregroundColor(.primary)
                    HStack(spacing: 12) {
                        MacroInlineStat(label: "kcal", value: Int(summary.totals.calories), color: .red)
                        MacroInlineStat(label: "P", value: Int(summary.totals.protein), color: .blue)
                        MacroInlineStat(label: "C", value: Int(summary.totals.carbs), color: .orange)
                        MacroInlineStat(label: "F", value: Int(summary.totals.fat), color: .purple)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife").font(.caption).foregroundColor(.secondary)
                        Text("\(summary.mealsCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
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
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text("\(value)").font(.subheadline).fontWeight(.semibold).foregroundColor(color)
        }
    }
}

struct MacroDayDetailView: View {
    let date: Date
    @ObservedObject var macroService: MacroService
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
                Color.offWhite.ignoresSafeArea()
                if isLoading {
                    ProgressView().scaleEffect(1.2)
                } else if meals.isEmpty {
                    Text("No meals for this day").foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(meals) { meal in
                            Section(header: Text(meal.title).font(.headline)) {
                                ForEach(meal.items) { item in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(item.name).font(.body).fontWeight(.medium)
                                            Text(item.quantityDescription).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("\(Int(item.calories)) kcal").font(.caption)
                                            HStack(spacing: 8) {
                                                Text("P \(Int(item.protein))g").font(.caption2).foregroundColor(.blue)
                                                Text("C \(Int(item.carbs))g").font(.caption2).foregroundColor(.orange)
                                                Text("F \(Int(item.fat))g").font(.caption2).foregroundColor(.purple)
                                            }
                                        }
                                    }
                                }
                                HStack {
                                    Text("Totals").font(.subheadline).fontWeight(.semibold)
                                    Spacer()
                                    Text("\(Int(meal.totals.calories)) kcal | P \(Int(meal.totals.protein)) C \(Int(meal.totals.carbs)) F \(Int(meal.totals.fat))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                ActionButtonsRow(
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
                        .listRowBackground(Color.white)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle(dateString(date))
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
                MacroManualEditView(meal: editingMeal) { updated in
                    Task {
                        _ = await macroService.updateMeal(updated)
                        await load()
                    }
                }
            }
        }
        .alert("Edit Meal with AI", isPresented: $isEditingWithAI) {
            TextField("e.g. I used 1 tbsp butter instead of 2 tsp", text: $editPrompt)
            Button("Apply") {
                Task {
                    guard let meal = editingMeal else { return }
                    await MainActor.run { isAIEditingInProgress = true }
                    if let updated = await macroService.editMealWithAI(existingMeal: meal, editRequest: editPrompt) {
                        _ = await macroService.updateMeal(updated)
                    }
                    await load()
                    await MainActor.run { isAIEditingInProgress = false }
                }
            }
            Button("Cancel", role: .cancel) { isEditingWithAI = false }
        } message: {
            Text("Describe your change. The AI will adjust the items and totals.")
        }
        .overlay(alignment: .bottom) {
            if isAIEditingInProgress {
                AIEditingToast()
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
    let onSave: (MacroMeal) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Meal Title") { TextField("Title", text: $meal.title) }
                Section("Items") {
                    ForEach(meal.items.indices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $meal.items[idx].name)
                            TextField("Quantity", text: $meal.items[idx].quantityDescription)
                            HStack { Text("Calories"); Spacer(); NumberField(value: $meal.items[idx].calories) }
                            HStack { Text("Protein (g)"); Spacer(); NumberField(value: $meal.items[idx].protein) }
                            HStack { Text("Carbs (g)"); Spacer(); NumberField(value: $meal.items[idx].carbs) }
                            HStack { Text("Fat (g)"); Spacer(); NumberField(value: $meal.items[idx].fat) }
                        }
                    }
                    .onDelete { indexSet in meal.items.remove(atOffsets: indexSet) }
                    Button("Add Item") {
                        meal.items.append(MacroItem(name: "", quantityDescription: "", calories: 0, protein: 0, carbs: 0, fat: 0))
                    }
                }
                Section("Totals") {
                    Text("Calculated: \(Int(meal.totals.calories)) kcal | P \(Int(meal.totals.protein)) C \(Int(meal.totals.carbs)) F \(Int(meal.totals.fat))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Meal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { onSave(meal); dismiss() }.fontWeight(.semibold) }
            }
        }
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
    let onEditManual: () -> Void
    let onEditAI: () -> Void
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            CapsuleButton(title: "Edit Manually", systemImage: "pencil", color: .accentBlue, action: onEditManual)
            CapsuleButton(title: "Edit with AI", systemImage: "sparkles", color: .orange, action: onEditAI)
            CapsuleButton(title: "Delete", systemImage: "trash", color: .red, action: onDelete)
        }
        .padding(.top, 6)
    }
}

struct CapsuleButton: View {
    let title: String
    let systemImage: String
    let color: Color
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
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .orange))
            Text("Editing macros with AI…")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
        )
    }
}


