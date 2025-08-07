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
    
    @State private var messages: [MacroChatMessage] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.offWhite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top summary bar
                    MacroTotalsHeader(totals: macroService.todayTotals)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                    Divider().opacity(0.2)
                    
                    // Chat Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if messages.isEmpty && !isLoading {
                                    MacroChatWelcome()
                                }
                                ForEach(messages) { message in
                                    MacroChatBubble(message: message)
                                        .id(message.id)
                                }
                                if isLoading {
                                    MacroTypingIndicatorView()
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
                            ErrorMessageView(message: errorMessage) { self.errorMessage = nil }
                        }
                        HStack(spacing: 12) {
                            TextField("e.g. 2 eggs scrambled in 1 tsp butter with toast and coffee", text: $messageText, axis: .vertical)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .lineLimit(1...5)
                            Button(action: sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray : Color.accentBlue)
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .background(Color.offWhite)
                    }
                }
            }
            .navigationTitle("Macro Tracker")
            .navigationBarTitleDisplayMode(.large)
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
        }
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !isLoading else { return }
        
        messages.append(MacroChatMessage(content: trimmed, isFromUser: true, timestamp: Date()))
        messageText = ""
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await macroService.saveMealFromDescription(trimmed)
                await MainActor.run {
                    let confirmation = MacroChatMessage(content: "Logged your meal. Totals updated above.", isFromUser: false, timestamp: Date())
                    messages.append(confirmation)
                    isLoading = false
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
    
    var body: some View {
        HStack(spacing: 12) {
            MacroTotalPill(title: "Calories", value: Int(totals.calories), unit: "kcal", color: .red)
            MacroTotalPill(title: "Protein", value: Int(totals.protein), unit: "g", color: .blue)
            MacroTotalPill(title: "Carbs", value: Int(totals.carbs), unit: "g", color: .orange)
            MacroTotalPill(title: "Fat", value: Int(totals.fat), unit: "g", color: .purple)
        }
    }
}

struct MacroTotalPill: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.headline)
                .foregroundColor(color)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Chat Bits

struct MacroChatWelcome: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text("Log your meals in plain English")
                .font(.title3)
                .fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 6) {
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("- greek yogurt with honey and granola")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("- 6oz grilled chicken, 1 cup rice, 1 tbsp olive oil")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("- 2 eggs scrambled in 1 tsp butter + toast")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.15), lineWidth: 1))
        )
    }
}

struct MacroChatBubble: View {
    let message: MacroChatMessage
    
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
                    Text(timeString(message.timestamp)).font(.caption2).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(.rect(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
                    Text(timeString(message.timestamp)).font(.caption2).foregroundColor(.secondary)
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
    @State private var animationOffset: CGFloat = 0
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Calculating macros…")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    Spacer()
                }
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationOffset == CGFloat(index) ? 1.3 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(
                    .rect(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 16
                    )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity * 0.8, alignment: .leading)
            Spacer()
        }
        .onAppear { animationOffset = 0 }
    }
}

