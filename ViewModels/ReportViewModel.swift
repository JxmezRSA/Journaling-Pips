import Combine
import Foundation
import SwiftData
import UIKit

struct ShareExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var shareItem: ShareExportItem?
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private var modelContext: ModelContext?
    private let exportService = PDFExportService()
    private let calendar = Calendar.current

    func configure(context: ModelContext) {
        modelContext = context
    }

    func export(_ type: ReportType) {
        guard let modelContext else {
            errorMessage = "Report storage is still loading."
            return
        }

        isGenerating = true

        do {
            let allTrades = try modelContext.fetch(FetchDescriptor<Trade>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
            let profile = try modelContext.fetch(FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])).first
            let generatedAt = Date()
            let payload = ReportPayload(
                type: type,
                generatedAt: generatedAt,
                trades: filteredTrades(allTrades, for: type, generatedAt: generatedAt),
                profile: profile
            )
            let url = try exportService.export(payload: payload)
            DisciplineTracker(context: modelContext).recordPDFReportExported()
            IntelligenceEngine(context: modelContext).observe(.pdfExported)
            shareItem = ShareExportItem(url: url)
            errorMessage = nil
            JPHaptics.notify(.success)
        } catch {
            errorMessage = "Unable to generate \(type.rawValue.lowercased())."
        }

        isGenerating = false
    }

    private func filteredTrades(_ trades: [Trade], for type: ReportType, generatedAt: Date) -> [Trade] {
        switch type {
        case .daily:
            return trades.filter { calendar.isDate($0.date, inSameDayAs: generatedAt) }
        case .weekly:
            return trades.filter { calendar.isDate($0.date, equalTo: generatedAt, toGranularity: .weekOfYear) }
        case .monthly:
            return trades.filter { calendar.isDate($0.date, equalTo: generatedAt, toGranularity: .month) }
        case .allTime:
            return trades
        }
    }
}
