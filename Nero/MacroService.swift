import Foundation
import Supabase
import SwiftUI

// MARK: - Domain Models

struct MacroTotals: Equatable, Codable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct MacroItem: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var quantityDescription: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    
    init(id: UUID = UUID(), name: String, quantityDescription: String, calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.id = id
        self.name = name
        self.quantityDescription = quantityDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

struct MacroMeal: Identifiable, Equatable, Codable {
    let id: UUID
    var databaseId: Int?
    var title: String
    var createdAt: Date
    var items: [MacroItem]
    
    var totals: MacroTotals {
        let calories = items.reduce(0) { $0 + $1.calories }
        let protein = items.reduce(0) { $0 + $1.protein }
        let carbs = items.reduce(0) { $0 + $1.carbs }
        let fat = items.reduce(0) { $0 + $1.fat }
        return MacroTotals(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
    
    init(id: UUID = UUID(), databaseId: Int? = nil, title: String, createdAt: Date, items: [MacroItem]) {
        self.id = id
        self.databaseId = databaseId
        self.title = title
        self.createdAt = createdAt
        self.items = items
    }
}

struct MacroDaySummary: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let totals: MacroTotals
    let mealsCount: Int
}

// MARK: - Supabase Models

struct DBMacroMeal: Codable {
    let id: Int?
    let userId: UUID
    let title: String
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case createdAt = "created_at"
    }
}

struct DBMacroMealItem: Codable {
    let id: Int?
    let mealId: Int
    let name: String
    let quantityDescription: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case name
        case quantityDescription = "quantity_description"
        case calories
        case protein
        case carbs
        case fat
        case createdAt = "created_at"
    }
}

// Lightweight type for selecting totals from DB without items
struct DBMacroMealTotals: Codable {
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case createdAt = "created_at"
    }
}

// MARK: - Service

class MacroService: ObservableObject {
    @Published var todayMeals: [MacroMeal] = []
    @Published var todayTotals: MacroTotals = MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var currentUserId: UUID?
    
    func setUser(_ userId: UUID?) {
        currentUserId = userId
        if userId != nil {
            loadTodayMeals()
        } else {
            todayMeals = []
            todayTotals = MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)
        }
    }
    
    // MARK: - Loaders
    
    func loadTodayMeals() {
        guard let userId = currentUserId else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let (start, end) = Self.dayBounds(Date())
                // Fetch meals for today
                let meals: [DBMacroMeal] = try await supabase
                    .from("macro_meals")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .gte("created_at", value: start.ISO8601Format())
                    .lt("created_at", value: end.ISO8601Format())
                    .order("created_at", ascending: true)
                    .execute()
                    .value
                
                var loadedMeals: [MacroMeal] = []
                for meal in meals {
                    guard let mealId = meal.id else { continue }
                    let items: [DBMacroMealItem] = try await supabase
                        .from("macro_meal_items")
                        .select()
                        .eq("meal_id", value: mealId)
                        .order("created_at", ascending: true)
                        .execute()
                        .value
                    
                    let macroItems = items.map { db in
                        MacroItem(
                            name: db.name,
                            quantityDescription: db.quantityDescription,
                            calories: db.calories,
                            protein: db.protein,
                            carbs: db.carbs,
                            fat: db.fat
                        )
                    }
                    let createdAt = meal.createdAt ?? Date()
                    let macroMeal = MacroMeal(
                        databaseId: meal.id,
                        title: meal.title,
                        createdAt: createdAt,
                        items: macroItems
                    )
                    loadedMeals.append(macroMeal)
                }
                
                await MainActor.run {
                    self.todayMeals = loadedMeals
                    self.recalculateTodayTotals()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load today's meals: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func fetchHistoryDays(limitDays: Int = 60) async -> [MacroDaySummary] {
        guard let userId = currentUserId else { return [] }
        do {
            // Pull recent meals and aggregate locally
            let startDate = Calendar.current.date(byAdding: .day, value: -limitDays, to: Date()) ?? Date.distantPast
            let meals: [DBMacroMealTotals] = try await supabase
                .from("macro_meals")
                .select("total_calories,total_protein,total_carbs,total_fat,created_at")
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: startDate.ISO8601Format())
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Group by day
            let grouped = Dictionary(grouping: meals) { db -> Date in
                let startOfDay = Calendar.current.startOfDay(for: db.createdAt)
                return startOfDay
            }
            
            let summaries: [MacroDaySummary] = grouped.map { (day, rows) in
                let totals = rows.reduce(MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)) { acc, row in
                    MacroTotals(
                        calories: acc.calories + row.totalCalories,
                        protein: acc.protein + row.totalProtein,
                        carbs: acc.carbs + row.totalCarbs,
                        fat: acc.fat + row.totalFat
                    )
                }
                return MacroDaySummary(date: day, totals: totals, mealsCount: rows.count)
            }
            
            return summaries.sorted { $0.date > $1.date }
        } catch {
            print("❌ MacroService: Failed to fetch history days: \(error)")
            return []
        }
    }
    
    func fetchMeals(for date: Date) async -> [MacroMeal] {
        guard let userId = currentUserId else { return [] }
        do {
            let (start, end) = Self.dayBounds(date)
            let meals: [DBMacroMeal] = try await supabase
                .from("macro_meals")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: start.ISO8601Format())
                .lt("created_at", value: end.ISO8601Format())
                .order("created_at", ascending: true)
                .execute()
                .value
            
            var result: [MacroMeal] = []
            for meal in meals {
                guard let mealId = meal.id else { continue }
                let items: [DBMacroMealItem] = try await supabase
                    .from("macro_meal_items")
                    .select()
                    .eq("meal_id", value: mealId)
                    .order("created_at", ascending: true)
                    .execute()
                    .value
                let macroItems = items.map { db in
                    MacroItem(
                        name: db.name,
                        quantityDescription: db.quantityDescription,
                        calories: db.calories,
                        protein: db.protein,
                        carbs: db.carbs,
                        fat: db.fat
                    )
                }
                let createdAt = meal.createdAt ?? Date()
                let macroMeal = MacroMeal(
                    databaseId: meal.id,
                    title: meal.title,
                    createdAt: createdAt,
                    items: macroItems
                )
                result.append(macroMeal)
            }
            return result
        } catch {
            print("❌ MacroService: Failed to fetch meals for date: \(error)")
            return []
        }
    }
    
    // MARK: - Save / Update
    
    func saveMealFromDescription(_ userText: String, forDate date: Date = Date()) async throws -> MacroMeal {
        guard let userId = currentUserId else {
            throw NSError(domain: "MacroService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Use Deepseek to parse into a meal
        let deepseekMeal = try await DeepseekAPIClient.shared.getMealFromDescription(userText: userText)
        let title = deepseekMeal.mealTitle.isEmpty ? "Meal" : deepseekMeal.mealTitle
        let createdAt = date
        
        // Insert meal
        let dbMeal = DBMacroMeal(
            id: nil,
            userId: userId,
            title: title,
            totalCalories: deepseekMeal.totals.calories,
            totalProtein: deepseekMeal.totals.protein,
            totalCarbs: deepseekMeal.totals.carbs,
            totalFat: deepseekMeal.totals.fat,
            createdAt: createdAt
        )
        
        let savedMeal: DBMacroMeal = try await supabase
            .from("macro_meals")
            .insert(dbMeal)
            .select()
            .single()
            .execute()
            .value
        
        guard let mealId = savedMeal.id else {
            throw NSError(domain: "MacroService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert meal"])
        }
        
        // Insert items
        let dbItems = deepseekMeal.items.map { item in
            DBMacroMealItem(
                id: nil,
                mealId: mealId,
                name: item.name,
                quantityDescription: item.quantity,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                createdAt: createdAt
            )
        }
        
        // Bulk insert
        let _: [DBMacroMealItem] = try await supabase
            .from("macro_meal_items")
            .insert(dbItems)
            .select()
            .execute()
            .value
        
        let macroItems = deepseekMeal.items.map { MacroItem(name: $0.name, quantityDescription: $0.quantity, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat) }
        let newMeal = MacroMeal(databaseId: mealId, title: title, createdAt: createdAt, items: macroItems)
        
        // Only update todayMeals if the date is today
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            await MainActor.run {
                self.todayMeals.append(newMeal)
                self.recalculateTodayTotals()
            }
        }
        
        // Notify listeners that macro data changed
        NotificationCenter.default.post(name: NSNotification.Name("MacroDataChanged"), object: nil)
        
        return newMeal
    }
    
    func updateMeal(_ meal: MacroMeal) async -> Bool {
        guard let databaseId = meal.databaseId, let userId = currentUserId else { return false }
        do {
            // Update meal totals and title
            struct UpdatePayload: Encodable {
                let title: String
                let total_calories: Double
                let total_protein: Double
                let total_carbs: Double
                let total_fat: Double
            }
            let tp = meal.totals
            let payload = UpdatePayload(title: meal.title, total_calories: tp.calories, total_protein: tp.protein, total_carbs: tp.carbs, total_fat: tp.fat)
            try await supabase
                .from("macro_meals")
                .update(payload)
                .eq("id", value: databaseId)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            // Simplest approach: delete existing items then re-insert current ones
            try await supabase
                .from("macro_meal_items")
                .delete()
                .eq("meal_id", value: databaseId)
                .execute()
            
            let createdAt = meal.createdAt
            let dbItems: [DBMacroMealItem] = meal.items.map { item in
                DBMacroMealItem(
                    id: nil,
                    mealId: databaseId,
                    name: item.name,
                    quantityDescription: item.quantityDescription,
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                    createdAt: createdAt
                )
            }
            let _: [DBMacroMealItem] = try await supabase
                .from("macro_meal_items")
                .insert(dbItems)
                .select()
                .execute()
                .value
            
            await MainActor.run {
                if let index = self.todayMeals.firstIndex(where: { $0.id == meal.id }) {
                    self.todayMeals[index] = meal
                }
                self.recalculateTodayTotals()
            }
            // Notify listeners that macro data changed
            NotificationCenter.default.post(name: NSNotification.Name("MacroDataChanged"), object: nil)
            return true
        } catch {
            await MainActor.run { self.errorMessage = "Failed to update meal: \(error.localizedDescription)" }
            return false
        }
    }
    
    func deleteMeal(_ meal: MacroMeal) async -> Bool {
        guard let databaseId = meal.databaseId else { return false }
        do {
            try await supabase
                .from("macro_meal_items")
                .delete()
                .eq("meal_id", value: databaseId)
                .execute()
            
            try await supabase
                .from("macro_meals")
                .delete()
                .eq("id", value: databaseId)
                .execute()
            
            await MainActor.run {
                self.todayMeals.removeAll { $0.id == meal.id }
                self.recalculateTodayTotals()
            }
            // Notify listeners that macro data changed
            NotificationCenter.default.post(name: NSNotification.Name("MacroDataChanged"), object: nil)
            return true
        } catch {
            await MainActor.run { self.errorMessage = "Failed to delete meal: \(error.localizedDescription)" }
            return false
        }
    }
    
    // MARK: - AI Assisted Edits
    
    func editMealWithAI(existingMeal: MacroMeal, editRequest: String) async -> MacroMeal? {
        guard let databaseId = existingMeal.databaseId else { return nil }
        do {
            let adjusted = try await DeepseekAPIClient.shared.editMealFromRequest(editRequest: editRequest, currentMeal: existingMeal)
            var updated = MacroMeal(databaseId: databaseId, title: adjusted.mealTitle.isEmpty ? existingMeal.title : adjusted.mealTitle, createdAt: existingMeal.createdAt, items: adjusted.items.map { MacroItem(name: $0.name, quantityDescription: $0.quantity, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat) })
            let success = await updateMeal(updated)
            return success ? updated : nil
        } catch {
            await MainActor.run { self.errorMessage = "Failed to edit meal with AI: \(error.localizedDescription)" }
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func recalculateTodayTotals() {
        let totals = todayMeals.reduce(MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)) { acc, meal in
            MacroTotals(
                calories: acc.calories + meal.totals.calories,
                protein: acc.protein + meal.totals.protein,
                carbs: acc.carbs + meal.totals.carbs,
                fat: acc.fat + meal.totals.fat
            )
        }
        todayTotals = totals
    }
    
    static func dayBounds(_ date: Date) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
        return (start, end)
    }
}

