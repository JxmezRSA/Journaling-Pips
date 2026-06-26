import Combine
import Foundation
import SwiftData

struct PlanChecklistItem: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var isComplete: Bool

    init(id: UUID = UUID(), title: String, isComplete: Bool = false) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
    }
}

struct PlanGoal: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var isComplete: Bool

    init(id: UUID = UUID(), title: String, isComplete: Bool = false) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
    }
}

@MainActor
final class PlanViewModel: ObservableObject {
    @Published private(set) var plan: MorningPlan?
    @Published var bias = MorningPlan.MarketBias.neutral
    @Published var watchlist: [String] = []
    @Published var checklist: [PlanChecklistItem]
    @Published var goals: [PlanGoal] = []
    @Published var dailyNotes = ""
    @Published var maximumRiskPercent = "1"
    @Published var maximumDailyLoss = ""
    @Published var maximumTrades = "3"
    @Published var dailyProfitGoal = ""
    @Published var errorMessage: String?

    let quote: String

    private var repository: PlanRepository?
    private let calendar = Calendar.current

    init() {
        checklist = Self.defaultChecklist
        quote = Self.quotes.randomElement() ?? "Trade your plan."
    }

    var greeting: String {
        let hour = calendar.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    var completionPercentage: Int {
        guard !checklist.isEmpty else {
            return 0
        }

        let completed = checklist.filter(\.isComplete).count
        return Int((Double(completed) / Double(checklist.count) * 100).rounded())
    }

    var readinessRating: String {
        switch completionPercentage {
        case 100:
            return "Fully Prepared"
        case 75..<100:
            return "Ready"
        case 40..<75:
            return "Almost Ready"
        default:
            return "Not Ready"
        }
    }

    var watchlistCount: Int {
        watchlist.count
    }

    var hasConfiguredAnything: Bool {
        bias != .neutral
            || !watchlist.isEmpty
            || !dailyNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !goals.isEmpty
            || checklist.contains(where: \.isComplete)
            || numericValue(maximumDailyLoss) > 0
            || numericValue(dailyProfitGoal) > 0
    }

    func configure(context: ModelContext) {
        if repository == nil {
            repository = PlanRepository(context: context)
        }

        loadTodayPlan()
    }

    func loadTodayPlan() {
        guard let repository else {
            return
        }

        do {
            let fetchedPlan = try repository.fetchPlan(for: Date()) ?? repository.createPlan(for: Date())
            plan = fetchedPlan
            apply(fetchedPlan)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load today's plan."
        }
    }

    func setBias(_ newBias: MorningPlan.MarketBias) {
        bias = newBias
        plan?.bias = newBias
        save()
    }

    func addSymbol(_ symbol: String) {
        let cleaned = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty, !watchlist.contains(cleaned) else {
            return
        }

        watchlist.append(cleaned)
        persistWatchlist()
    }

    func deleteSymbol(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
        persistWatchlist()
    }

    func updateRiskPlan() {
        plan?.maximumRiskPercent = numericValue(maximumRiskPercent)
        plan?.maximumDailyLoss = numericValue(maximumDailyLoss)
        plan?.maximumTrades = Int(numericValue(maximumTrades))
        plan?.dailyProfitGoal = numericValue(dailyProfitGoal)
        save()
    }

    func toggleChecklist(_ item: PlanChecklistItem) {
        guard let index = checklist.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        checklist[index].isComplete.toggle()
        persistChecklist()
    }

    func updateNotes(_ notes: String) {
        dailyNotes = notes
        plan?.dailyNotes = notes
        save()
    }

    func addGoal(_ title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return
        }

        goals.append(PlanGoal(title: cleaned))
        persistGoals()
    }

    func toggleGoal(_ goal: PlanGoal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else {
            return
        }

        goals[index].isComplete.toggle()
        persistGoals()
    }

    func deleteGoal(_ goal: PlanGoal) {
        goals.removeAll { $0.id == goal.id }
        persistGoals()
    }

    private func apply(_ plan: MorningPlan) {
        bias = plan.bias
        watchlist = decode([String].self, from: plan.watchlistRawValue) ?? []
        checklist = decode([PlanChecklistItem].self, from: plan.checklistRawValue) ?? Self.defaultChecklist
        goals = decode([PlanGoal].self, from: plan.goalsRawValue) ?? []
        dailyNotes = plan.dailyNotes
        maximumRiskPercent = numberText(plan.maximumRiskPercent)
        maximumDailyLoss = plan.maximumDailyLoss == 0 ? "" : numberText(plan.maximumDailyLoss)
        maximumTrades = "\(max(plan.maximumTrades, 0))"
        dailyProfitGoal = plan.dailyProfitGoal == 0 ? "" : numberText(plan.dailyProfitGoal)
    }

    private func persistWatchlist() {
        plan?.watchlistRawValue = encode(watchlist)
        save()
    }

    private func persistChecklist() {
        plan?.checklistRawValue = encode(checklist)
        save()
    }

    private func persistGoals() {
        plan?.goalsRawValue = encode(goals)
        save()
    }

    private func save() {
        do {
            try repository?.save()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save today's plan."
        }
    }

    private func encode<Value: Encodable>(_ value: Value) -> String {
        guard let data = try? JSONEncoder().encode(value) else {
            return ""
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from value: String) -> Value? {
        guard let data = value.data(using: .utf8), !value.isEmpty else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    private func numericValue(_ text: String) -> Double {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private func numberText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
    }

    private static let defaultChecklist = [
        PlanChecklistItem(title: "Morning routine complete"),
        PlanChecklistItem(title: "Economic calendar checked"),
        PlanChecklistItem(title: "Daily bias confirmed"),
        PlanChecklistItem(title: "Risk calculated"),
        PlanChecklistItem(title: "Wait for A+ setup"),
        PlanChecklistItem(title: "No emotional trading")
    ]

    private static let quotes = [
        "The market rewards patience.",
        "Protect your capital.",
        "Trade your plan.",
        "Wait for the clean setup.",
        "Discipline is the edge.",
        "Clarity before execution.",
        "No trade is a position.",
        "Risk first. Profit second.",
        "Let price come to you.",
        "Calm traders last longer."
    ]
}
