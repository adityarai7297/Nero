import SwiftUI

struct MacroChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

struct MacroChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var macroService = MacroService()
    let userId: UUID?
    let isDarkMode: Bool
    
    @State private var messages: [MacroChatMessage] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    @State private var textFieldResetId = UUID()
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color.offWhite).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top summary bar
                    MacroTotalsHeader(totals: macroService.todayTotals, isDarkMode: isDarkMode)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                    Divider().opacity(isDarkMode ? 0.3 : 0.2)
                    
                    // Chat Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if messages.isEmpty && !isLoading {
                                    MacroChatWelcome(isDarkMode: isDarkMode)
                                }
                                ForEach(messages) { message in
                                    MacroChatBubble(message: message, isDarkMode: isDarkMode)
                                        .id(message.id)
                                }
                                if isLoading {
                                    MacroTypingIndicatorView(isDarkMode: isDarkMode)
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
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
                            TextField("e.g. 2 eggs scrambled in 1 tsp butter with toast and coffee", text: $messageText, axis: .vertical)
                                .id(textFieldResetId)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .lineLimit(1...5)
                                .focused($isTextFieldFocused)
                                .onSubmit { sendMessage() }
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
        .onAppear {
            macroService.setUser(userId)
            isTextFieldFocused = true
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
        
        Task {
            do {
                _ = try await macroService.saveMealFromDescription(trimmed)
                await MainActor.run {
                    let confirmation = MacroChatMessage(content: "Logged your meal. Totals updated above.", isFromUser: false, timestamp: Date())
                    messages.append(confirmation)
                    isLoading = false
                }
            } catch let deepseekError as DeepseekError {
                await MainActor.run {
                    isLoading = false
                    switch deepseekError {
                    case .couldNotUnderstand:
                        messages.append(MacroChatMessage(content: "I couldn't understand that. Try describing your meal with ingredients and amounts (e.g., ‘2 eggs scrambled in 1 tsp butter with 1 slice toast’).", isFromUser: false, timestamp: Date()))
                    default:
                        errorMessage = deepseekError.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to log meal: \(error.localizedDescription)"
                }
            }
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
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                        .clipShape(.rect(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
                    Text(timeString(message.timestamp)).font(.caption2).foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)
                }
                .frame(maxWidth: .infinity * 0.8, alignment: .leading)
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

