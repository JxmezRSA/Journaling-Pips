import Charts
import Foundation
import PDFKit
import SwiftUI
import UIKit

enum ReportType: String, CaseIterable, Identifiable {
    case daily = "Daily Report"
    case weekly = "Weekly Report"
    case monthly = "Monthly Report"
    case allTime = "All-Time Report"

    var id: String { rawValue }

    var fileToken: String {
        switch self {
        case .daily: return "DailyReport"
        case .weekly: return "WeeklyReport"
        case .monthly: return "MonthlyReport"
        case .allTime: return "AllTimeReport"
        }
    }
}

struct ReportPayload {
    let type: ReportType
    let generatedAt: Date
    let trades: [Trade]
    let profile: UserProfile?
}

struct ReportMetrics {
    let netProfit: Double
    let winRate: Double
    let profitFactor: Double
    let averageRR: Double
    let averageRisk: Double
    let totalTrades: Int
    let winningTrades: Int
    let losingTrades: Int
    let breakevenTrades: Int
    let bestTrade: Double
    let worstTrade: Double
    let averageDuration: String
    let largestWinningStreak: Int
    let largestLosingStreak: Int
}

struct ReportStrategySummary {
    let mostUsedStrategy: String
    let highestWinRateStrategy: String
    let lowestWinRateStrategy: String
    let mostProfitableSession: String
    let worstSession: String
    let mostTradedInstrument: String
    let averageHoldTime: String
    let averageRRByStrategy: [(String, Double)]
}

@MainActor
final class ReportGenerator {
    private let pageSize = CGSize(width: 612, height: 792)
    private let margin: CGFloat = 42
    private let calendar = Calendar.current
    private let version = "0.5"

    func generate(payload: ReportPayload, to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let metrics = metrics(for: payload.trades)
        let strategySummary = strategySummary(for: payload.trades)
        let chartImages = chartImages(for: payload.trades)
        var page = 0

        try renderer.writePDF(to: url) { context in
            drawPage(context, page: nextPage(&page)) { drawCover(payload: payload) }
            drawPage(context, page: nextPage(&page)) { drawOverview(metrics: metrics) }
            drawPage(context, page: nextPage(&page)) { drawCharts(chartImages) }
            drawPage(context, page: nextPage(&page)) { drawCalendar(trades: payload.trades, generatedAt: payload.generatedAt) }
            drawPage(context, page: nextPage(&page)) { drawStrategy(summary: strategySummary) }
            drawPage(context, page: nextPage(&page)) { drawPsychology(trades: payload.trades, metrics: metrics) }
            drawPage(context, page: nextPage(&page)) { drawGallery(trades: payload.trades) }
            drawPage(context, page: nextPage(&page)) { drawFinalSummary(trades: payload.trades, metrics: metrics) }
        }
    }

    private func nextPage(_ page: inout Int) -> Int {
        page += 1
        return page
    }

    private func drawPage(_ context: UIGraphicsPDFRendererContext, page: Int, draw: () -> Void) {
        context.beginPage()
        drawBackground()
        draw()
        drawFooter(page: page)
    }

    private func drawCover(payload: ReportPayload) {
        let profile = payload.profile
        drawLogo(center: CGPoint(x: pageSize.width / 2, y: 158))
        drawCentered("Journaling Pips", y: 230, font: .systemFont(ofSize: 34, weight: .bold), color: .white)
        drawCentered("Performance Report", y: 275, font: .systemFont(ofSize: 22, weight: .semibold), color: UIColor.jpAccent)
        drawCentered(payload.type.rawValue, y: 308, font: .systemFont(ofSize: 16, weight: .semibold), color: UIColor.jpSecondary)
        drawCentered("Generated \(dateTime(payload.generatedAt))", y: 334, font: .systemFont(ofSize: 12, weight: .medium), color: UIColor.jpMuted)

        let rows = [
            ("User Name", emptyDash(profile?.name)),
            ("Trading Style", profile?.tradingStyle.rawValue ?? "--"),
            ("Trading Experience", profile?.tradingExperience.rawValue ?? "--"),
            ("Account Size", profile?.accountSize == 0 ? "--" : currency(profile?.accountSize ?? 0, signed: false)),
            ("Account Type", profile?.accountType.rawValue ?? "--"),
            ("Base Currency", profile?.baseCurrency.rawValue ?? "--")
        ]

        drawInfoCard(title: "Trader Profile", rows: rows, rect: CGRect(x: margin, y: 420, width: pageSize.width - margin * 2, height: 222))
    }

    private func drawOverview(metrics: ReportMetrics) {
        drawPageTitle("Performance Overview", subtitle: "Premium metrics from saved trades")
        let cards = [
            ("Net Profit", currency(metrics.netProfit), UIColor.tint(for: metrics.netProfit)),
            ("Win Rate", percentage(metrics.winRate), UIColor.jpGold),
            ("Profit Factor", metrics.profitFactor.isInfinite ? "∞" : String(format: "%.2f", metrics.profitFactor), UIColor.jpAccent),
            ("Average RR", String(format: "1:%.2f", metrics.averageRR), UIColor.jpBlue),
            ("Average Risk %", String(format: "%.2f%%", metrics.averageRisk), UIColor.jpPurple),
            ("Total Trades", "\(metrics.totalTrades)", UIColor.jpText),
            ("Winning Trades", "\(metrics.winningTrades)", UIColor.jpGreen),
            ("Losing Trades", "\(metrics.losingTrades)", UIColor.jpRed),
            ("Break-even Trades", "\(metrics.breakevenTrades)", UIColor.jpGold),
            ("Best Trade", currency(metrics.bestTrade), UIColor.jpGreen),
            ("Worst Trade", currency(metrics.worstTrade), UIColor.jpRed),
            ("Avg Duration", metrics.averageDuration, UIColor.jpSecondary),
            ("Largest Win Streak", "\(metrics.largestWinningStreak)", UIColor.jpGreen),
            ("Largest Loss Streak", "\(metrics.largestLosingStreak)", UIColor.jpRed)
        ]
        drawMetricGrid(cards, startY: 126)
    }

    private func drawCharts(_ images: [UIImage]) {
        drawPageTitle("Charts", subtitle: "Equity, distribution, and performance trends")
        let rects = [
            CGRect(x: margin, y: 116, width: 250, height: 162),
            CGRect(x: 320, y: 116, width: 250, height: 162),
            CGRect(x: margin, y: 304, width: 250, height: 162),
            CGRect(x: 320, y: 304, width: 250, height: 162),
            CGRect(x: margin, y: 492, width: 250, height: 162),
            CGRect(x: 320, y: 492, width: 250, height: 162)
        ]

        for (index, rect) in rects.enumerated() {
            drawRoundedCard(rect)
            if index < images.count {
                images[index].draw(in: rect.insetBy(dx: 12, dy: 12))
            }
        }
    }

    private func drawCalendar(trades: [Trade], generatedAt: Date) {
        drawPageTitle("Trade Calendar", subtitle: generatedAt.formatted(.dateTime.month(.wide).year()))
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: generatedAt)) ?? generatedAt
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        let dayProfits = Dictionary(grouping: trades) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.profitLoss } }

        let startX = margin
        let startY: CGFloat = 140
        let cell: CGFloat = 72
        let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
        for (index, day) in weekdays.enumerated() {
            drawText(day, rect: CGRect(x: startX + CGFloat(index) * cell, y: 112, width: cell, height: 20), font: .systemFont(ofSize: 12, weight: .bold), color: UIColor.jpSecondary, alignment: .center)
        }

        for day in range {
            let position = firstWeekday + day - 1
            let row = position / 7
            let column = position % 7
            let rect = CGRect(x: startX + CGFloat(column) * cell, y: startY + CGFloat(row) * cell, width: 58, height: 58)
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
            let profit = dayProfits[calendar.startOfDay(for: date)]
            let color: UIColor = {
                guard let profit else { return UIColor.jpGraphite }
                if profit > 0 { return UIColor.jpGreen }
                if profit < 0 { return UIColor.jpRed }
                return UIColor.jpGold
            }()
            drawRoundedCard(rect, fill: color.withAlphaComponent(profit == nil ? 0.46 : 0.20), stroke: color.withAlphaComponent(profit == nil ? 0.12 : 0.42), radius: 18)
            drawText("\(day)", rect: rect.insetBy(dx: 0, dy: 16), font: .systemFont(ofSize: 18, weight: .bold), color: profit == nil ? UIColor.jpSecondary : color, alignment: .center)
        }
    }

    private func drawStrategy(summary: ReportStrategySummary) {
        drawPageTitle("Strategy Analysis", subtitle: "Setup, session, and instrument performance")
        drawInfoCard(
            title: "Highlights",
            rows: [
                ("Most Used Strategy", summary.mostUsedStrategy),
                ("Highest Win Rate Strategy", summary.highestWinRateStrategy),
                ("Lowest Win Rate Strategy", summary.lowestWinRateStrategy),
                ("Most Profitable Session", summary.mostProfitableSession),
                ("Worst Session", summary.worstSession),
                ("Most Traded Instrument", summary.mostTradedInstrument),
                ("Average Hold Time", summary.averageHoldTime)
            ],
            rect: CGRect(x: margin, y: 116, width: pageSize.width - margin * 2, height: 290)
        )

        drawText("Average RR by Strategy", rect: CGRect(x: margin, y: 444, width: 300, height: 26), font: .systemFont(ofSize: 18, weight: .bold), color: .white)
        var y: CGFloat = 486
        for item in summary.averageRRByStrategy.prefix(6) {
            let width = min(max(CGFloat(item.1 / 3.0) * 420, 18), 420)
            drawText(item.0, rect: CGRect(x: margin, y: y - 3, width: 150, height: 20), font: .systemFont(ofSize: 11, weight: .semibold), color: UIColor.jpSecondary)
            drawPill(rect: CGRect(x: 206, y: y, width: 420, height: 12), color: UIColor.jpGraphite)
            drawPill(rect: CGRect(x: 206, y: y, width: width, height: 12), color: UIColor.jpAccent)
            drawText(String(format: "1:%.2f", item.1), rect: CGRect(x: 490, y: y - 5, width: 80, height: 20), font: .systemFont(ofSize: 11, weight: .bold), color: UIColor.jpText, alignment: .right)
            y += 34
        }
    }

    private func drawPsychology(trades: [Trade], metrics: ReportMetrics) {
        drawPageTitle("Psychology Review", subtitle: "Deterministic insights from journal behavior")
        let insights = psychologyInsights(trades: trades, metrics: metrics)
        drawBullets(insights, title: "Insights", tint: UIColor.jpGold, y: 132)
    }

    private func drawGallery(trades: [Trade]) {
        drawPageTitle("Trade Gallery", subtitle: "Screenshots from the visual journal")
        let screenshots: [(String, Data)] = trades.flatMap { trade in
            [
                ("Before Entry", trade.beforeEntryImageData),
                ("During Trade", trade.duringTradeImageData),
                ("After Exit", trade.afterExitImageData)
            ].compactMap { title, data -> (String, Data)? in
                guard let data else { return nil }
                return ("\(trade.pair) • \(title)", data)
            }
        }

        guard !screenshots.isEmpty else {
            drawEmptyState("No screenshots yet", subtitle: "Add chart screenshots to trades to build a visual report gallery.", y: 260)
            return
        }

        let rects = [
            CGRect(x: margin, y: 120, width: 250, height: 170),
            CGRect(x: 320, y: 120, width: 250, height: 170),
            CGRect(x: margin, y: 328, width: 250, height: 170),
            CGRect(x: 320, y: 328, width: 250, height: 170),
            CGRect(x: margin, y: 536, width: 250, height: 140),
            CGRect(x: 320, y: 536, width: 250, height: 140)
        ]

        for (index, item) in screenshots.prefix(6).enumerated() {
            let rect = rects[index]
            drawRoundedCard(rect)
            if let image = UIImage(data: item.1) {
                drawText(item.0, rect: CGRect(x: rect.minX + 14, y: rect.minY + 12, width: rect.width - 28, height: 18), font: .systemFont(ofSize: 11, weight: .bold), color: UIColor.jpText)
                image.draw(in: rect.insetBy(dx: 14, dy: 38))
            }
        }
    }

    private func drawFinalSummary(trades: [Trade], metrics: ReportMetrics) {
        drawPageTitle("Weekly Summary", subtitle: "Placeholder coaching summary")
        let grade = grade(for: metrics)
        drawRoundedCard(CGRect(x: margin, y: 130, width: pageSize.width - margin * 2, height: 430), fill: UIColor.jpSurface, stroke: UIColor.jpBorder, radius: 30)
        drawCentered("Overall Grade", y: 170, font: .systemFont(ofSize: 15, weight: .bold), color: UIColor.jpSecondary)
        drawCentered(grade, y: 205, font: .systemFont(ofSize: 64, weight: .black), color: gradeColor(grade))
        drawBullets(summaryStrengths(trades: trades, metrics: metrics), title: "Strengths", tint: UIColor.jpGreen, y: 308)
        drawBullets(summaryFocus(trades: trades), title: "Focus Next Week", tint: UIColor.jpGold, y: 474)
    }

    private func chartImages(for trades: [Trade]) -> [UIImage] {
        [
            renderChart(ReportChartView(title: "Equity Curve", points: equityCurve(for: trades), style: .line)),
            renderChart(ReportChartView(title: "Monthly Profit", points: groupedProfit(for: trades, components: [.year, .month], label: "MMM"), style: .bar)),
            renderChart(ReportChartView(title: "Weekly Profit", points: groupedProfit(for: trades, components: [.yearForWeekOfYear, .weekOfYear], label: "'W'w"), style: .bar)),
            renderChart(ReportChartView(title: "Win Rate Trend", points: winRateTrend(for: trades), style: .line)),
            renderChart(ReportChartView(title: "Risk Distribution", points: riskDistribution(for: trades), style: .bar)),
            renderChart(ReportChartView(title: "Session Distribution", points: sessionDistribution(for: trades), style: .bar))
        ]
    }

    private func renderChart(_ view: ReportChartView) -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: 226, height: 138))
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }

    private func metrics(for trades: [Trade]) -> ReportMetrics {
        let wins = trades.filter { $0.status == .win }
        let losses = trades.filter { $0.status == .loss }
        let breakeven = trades.filter { $0.status == .breakeven }
        return ReportMetrics(
            netProfit: trades.reduce(0) { $0 + $1.profitLoss },
            winRate: winRate(for: trades),
            profitFactor: profitFactor(for: trades),
            averageRR: trades.isEmpty ? 0 : trades.reduce(0) { $0 + $1.riskReward } / Double(trades.count),
            averageRisk: average(trades.map(\.riskPercent).filter { $0 > 0 }),
            totalTrades: trades.count,
            winningTrades: wins.count,
            losingTrades: losses.count,
            breakevenTrades: breakeven.count,
            bestTrade: trades.map(\.profitLoss).max() ?? 0,
            worstTrade: trades.map(\.profitLoss).min() ?? 0,
            averageDuration: averageDuration(for: trades),
            largestWinningStreak: largestStreak(for: trades, status: .win),
            largestLosingStreak: largestStreak(for: trades, status: .loss)
        )
    }

    private func strategySummary(for trades: [Trade]) -> ReportStrategySummary {
        let strategyGroups = Dictionary(grouping: trades, by: \.strategy)
        let sessionGroups = Dictionary(grouping: trades, by: \.session)
        let instrumentGroups = Dictionary(grouping: trades, by: \.pair)

        let mostUsed = strategyGroups.max { $0.value.count < $1.value.count }?.key.rawValue ?? "--"
        let highest = strategyGroups.max { winRate(for: $0.value) < winRate(for: $1.value) }?.key.rawValue ?? "--"
        let lowest = strategyGroups.min { winRate(for: $0.value) < winRate(for: $1.value) }?.key.rawValue ?? "--"
        let bestSession = sessionGroups.max { netProfit($0.value) < netProfit($1.value) }?.key.rawValue ?? "--"
        let worstSession = sessionGroups.min { netProfit($0.value) < netProfit($1.value) }?.key.rawValue ?? "--"
        let instrument = instrumentGroups.max { $0.value.count < $1.value.count }?.key ?? "--"
        let rrByStrategy = strategyGroups.map { ($0.key.rawValue, average($0.value.map(\.riskReward))) }.sorted { $0.1 > $1.1 }

        return ReportStrategySummary(
            mostUsedStrategy: mostUsed,
            highestWinRateStrategy: highest,
            lowestWinRateStrategy: lowest,
            mostProfitableSession: bestSession,
            worstSession: worstSession,
            mostTradedInstrument: instrument,
            averageHoldTime: averageDuration(for: trades),
            averageRRByStrategy: rrByStrategy
        )
    }

    private func filteredMonthDays(from trades: [Trade], generatedAt: Date) -> [Trade] {
        trades.filter { calendar.isDate($0.date, equalTo: generatedAt, toGranularity: .month) }
    }

    private func equityCurve(for trades: [Trade]) -> [ReportChartPoint] {
        var running = 0.0
        return trades.sorted { $0.date < $1.date }.map {
            running += $0.profitLoss
            return ReportChartPoint(label: shortDate($0.date), value: running)
        }
    }

    private func groupedProfit(for trades: [Trade], components: Set<Calendar.Component>, label: String) -> [ReportChartPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = label
        return Dictionary(grouping: trades) {
            calendar.date(from: calendar.dateComponents(components, from: $0.date)) ?? $0.date
        }
        .map { date, groupedTrades in ReportChartPoint(label: formatter.string(from: date), value: netProfit(groupedTrades)) }
        .sorted { $0.label < $1.label }
    }

    private func winRateTrend(for trades: [Trade]) -> [ReportChartPoint] {
        groupedProfit(for: trades, components: [.year, .month], label: "MMM").map { point in
            let monthTrades = trades.filter { shortMonth($0.date) == point.label }
            return ReportChartPoint(label: point.label, value: winRate(for: monthTrades))
        }
    }

    private func riskDistribution(for trades: [Trade]) -> [ReportChartPoint] {
        [
            ReportChartPoint(label: "<1%", value: Double(trades.filter { $0.riskPercent > 0 && $0.riskPercent < 1 }.count)),
            ReportChartPoint(label: "1-2%", value: Double(trades.filter { $0.riskPercent >= 1 && $0.riskPercent <= 2 }.count)),
            ReportChartPoint(label: ">2%", value: Double(trades.filter { $0.riskPercent > 2 }.count))
        ]
    }

    private func sessionDistribution(for trades: [Trade]) -> [ReportChartPoint] {
        Trade.Session.allCases.map { session in
            ReportChartPoint(label: session.rawValue, value: Double(trades.filter { $0.session == session }.count))
        }
    }

    private func psychologyInsights(trades: [Trade], metrics: ReportMetrics) -> [String] {
        var items: [String] = []
        if metrics.winRate >= 55 { items.append("Win rate increased into a strong execution range.") }
        if metrics.averageRisk <= 2 || metrics.averageRisk == 0 { items.append("You respected risk.") }
        if trades.filter(\.followedPlan).count >= max(1, trades.count / 2) { items.append("Excellent discipline.") }
        if trades.contains(where: { $0.mistakeTags.contains(.closedEarly) }) { items.append("Still closing winners early.") }
        if trades.contains(where: { $0.mistakeTags.contains(.revengeTrade) }) { items.append("Revenge trading appeared in the journal.") }
        if metrics.largestLosingStreak >= 2 { items.append("Protect confidence after consecutive losses.") }
        return items.isEmpty ? ["Add more trades and reviews to unlock richer psychology patterns."] : items
    }

    private func summaryStrengths(trades: [Trade], metrics: ReportMetrics) -> [String] {
        [
            metrics.winRate >= 50 ? "Great discipline" : "Consistent review habit",
            metrics.averageRR >= 1.5 ? "Strong execution" : "Clear setup tracking",
            trades.contains { $0.followedPlan } ? "Good patience" : "Growing self-awareness"
        ]
    }

    private func summaryFocus(trades: [Trade]) -> [String] {
        var items = ["Stay patient after losses"]
        if trades.contains(where: { $0.mistakeTags.contains(.closedEarly) }) { items.insert("Hold winners longer", at: 0) }
        if trades.contains(where: { $0.mistakeTags.contains(.revengeTrade) }) { items.insert("Reduce revenge trading", at: min(1, items.count)) }
        if items.count < 3 { items.append("Keep screenshots attached") }
        return items
    }

    private func grade(for metrics: ReportMetrics) -> String {
        let score = min(max(Int(metrics.winRate * 0.45 + min(metrics.profitFactor.isInfinite ? 100 : metrics.profitFactor * 28, 35) + min(metrics.averageRR * 8, 20)), 0), 100)
        switch score {
        case 90...100: return "A+"
        case 80...89: return "A-"
        case 70...79: return "B"
        case 60...69: return "C"
        default: return "D"
        }
    }

    private func gradeColor(_ grade: String) -> UIColor {
        grade.hasPrefix("A") ? UIColor.jpGreen : grade == "B" ? UIColor.jpGold : UIColor.jpRed
    }

    private func winRate(for trades: [Trade]) -> Double {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        guard !resolved.isEmpty else { return 0 }
        return Double(resolved.filter { $0.status == .win }.count) / Double(resolved.count) * 100
    }

    private func profitFactor(for trades: [Trade]) -> Double {
        let wins = trades.map(\.profitLoss).filter { $0 > 0 }.reduce(0, +)
        let losses = abs(trades.map(\.profitLoss).filter { $0 < 0 }.reduce(0, +))
        if losses == 0 { return wins > 0 ? .infinity : 0 }
        return wins / losses
    }

    private func netProfit(_ trades: [Trade]) -> Double {
        trades.reduce(0) { $0 + $1.profitLoss }
    }

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func averageDuration(for trades: [Trade]) -> String {
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime, close > open else { return nil }
            return close.timeIntervalSince(open)
        }
        guard !durations.isEmpty else { return "--" }
        let seconds = durations.reduce(0, +) / Double(durations.count)
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func largestStreak(for trades: [Trade], status: Trade.Status) -> Int {
        var best = 0
        var current = 0
        for trade in trades.sorted(by: { $0.date < $1.date }) {
            if trade.status == status {
                current += 1
                best = max(best, current)
            } else if trade.status == .win || trade.status == .loss {
                current = 0
            }
        }
        return best
    }

    private func drawBackground() {
        UIColor.jpBackground.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: pageSize)).fill()
        let glow = UIBezierPath(ovalIn: CGRect(x: -130, y: -120, width: 320, height: 320))
        UIColor.jpAccent.withAlphaComponent(0.10).setFill()
        glow.fill()
    }

    private func drawPageTitle(_ title: String, subtitle: String) {
        drawText(title, rect: CGRect(x: margin, y: 46, width: pageSize.width - margin * 2, height: 34), font: .systemFont(ofSize: 27, weight: .bold), color: .white)
        drawText(subtitle, rect: CGRect(x: margin, y: 82, width: pageSize.width - margin * 2, height: 20), font: .systemFont(ofSize: 12, weight: .semibold), color: UIColor.jpSecondary)
    }

    private func drawFooter(page: Int) {
        let text = "Generated by Journaling Pips • Version \(version)"
        drawText(text, rect: CGRect(x: margin, y: pageSize.height - 38, width: 360, height: 16), font: .systemFont(ofSize: 9, weight: .semibold), color: UIColor.jpMuted)
        drawText("Page \(page)", rect: CGRect(x: pageSize.width - margin - 80, y: pageSize.height - 38, width: 80, height: 16), font: .systemFont(ofSize: 9, weight: .semibold), color: UIColor.jpMuted, alignment: .right)
    }

    private func drawLogo(center: CGPoint) {
        drawRoundedCard(CGRect(x: center.x - 44, y: center.y - 44, width: 88, height: 88), fill: UIColor.jpAccent, stroke: UIColor.jpAccent, radius: 28)
        drawCentered("JP", y: center.y - 18, font: .systemFont(ofSize: 28, weight: .black), color: UIColor.jpBackground)
    }

    private func drawMetricGrid(_ cards: [(String, String, UIColor)], startY: CGFloat) {
        let width: CGFloat = 166
        let height: CGFloat = 72
        for (index, card) in cards.enumerated() {
            let column = index % 3
            let row = index / 3
            let rect = CGRect(x: margin + CGFloat(column) * (width + 15), y: startY + CGFloat(row) * (height + 16), width: width, height: height)
            drawRoundedCard(rect)
            drawText(card.0, rect: CGRect(x: rect.minX + 14, y: rect.minY + 13, width: rect.width - 28, height: 16), font: .systemFont(ofSize: 9, weight: .bold), color: UIColor.jpSecondary)
            drawText(card.1, rect: CGRect(x: rect.minX + 14, y: rect.minY + 34, width: rect.width - 28, height: 26), font: .systemFont(ofSize: 18, weight: .bold), color: card.2)
        }
    }

    private func drawInfoCard(title: String, rows: [(String, String)], rect: CGRect) {
        drawRoundedCard(rect, fill: UIColor.jpSurface, stroke: UIColor.jpBorder, radius: 26)
        drawText(title, rect: CGRect(x: rect.minX + 20, y: rect.minY + 20, width: rect.width - 40, height: 24), font: .systemFont(ofSize: 18, weight: .bold), color: .white)
        var y = rect.minY + 62
        for row in rows {
            drawText(row.0, rect: CGRect(x: rect.minX + 20, y: y, width: 190, height: 20), font: .systemFont(ofSize: 11, weight: .semibold), color: UIColor.jpSecondary)
            drawText(row.1, rect: CGRect(x: rect.minX + 222, y: y, width: rect.width - 242, height: 20), font: .systemFont(ofSize: 11, weight: .bold), color: UIColor.jpText, alignment: .right)
            y += 25
        }
    }

    private func drawBullets(_ bullets: [String], title: String, tint: UIColor, y: CGFloat) {
        drawText(title, rect: CGRect(x: margin, y: y, width: 300, height: 24), font: .systemFont(ofSize: 18, weight: .bold), color: tint)
        var currentY = y + 38
        for bullet in bullets.prefix(6) {
            drawText("•", rect: CGRect(x: margin, y: currentY, width: 16, height: 20), font: .systemFont(ofSize: 18, weight: .bold), color: tint)
            drawText(bullet, rect: CGRect(x: margin + 24, y: currentY, width: pageSize.width - margin * 2 - 24, height: 42), font: .systemFont(ofSize: 14, weight: .semibold), color: UIColor.jpText)
            currentY += 38
        }
    }

    private func drawEmptyState(_ title: String, subtitle: String, y: CGFloat) {
        drawRoundedCard(CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 160), fill: UIColor.jpSurface, stroke: UIColor.jpBorder, radius: 28)
        drawCentered(title, y: y + 46, font: .systemFont(ofSize: 22, weight: .bold), color: .white)
        drawCentered(subtitle, y: y + 82, font: .systemFont(ofSize: 12, weight: .semibold), color: UIColor.jpSecondary)
    }

    private func drawRoundedCard(_ rect: CGRect, fill: UIColor? = nil, stroke: UIColor? = nil, radius: CGFloat = 22) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        (fill ?? UIColor.jpSurface).setFill()
        path.fill()
        (stroke ?? UIColor.jpBorder).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawPill(rect: CGRect, color: UIColor) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
    }

    private func drawCentered(_ text: String, y: CGFloat, font: UIFont, color: UIColor) {
        drawText(text, rect: CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 44), font: font, color: color, alignment: .center)
    }

    private func drawText(_ text: String, rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        text.draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }

    private func currency(_ value: Double, signed: Bool = true) -> String {
        let sign = signed ? (value >= 0 ? "+" : "-") : ""
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percentage(_ value: Double) -> String { "\(Int(value.rounded()))%" }
    private func emptyDash(_ value: String?) -> String { (value ?? "").isEmpty ? "--" : value ?? "--" }
    private func dateTime(_ date: Date) -> String { date.formatted(.dateTime.year().month().day().hour().minute()) }
    private func shortDate(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day()) }
    private func shortMonth(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated)) }
}

struct ReportChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct ReportChartView: View {
    enum Style { case line, bar }

    let title: String
    let points: [ReportChartPoint]
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)

            if points.isEmpty {
                Text("No data")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(points) { point in
                    switch style {
                    case .line:
                        LineMark(x: .value("Label", point.label), y: .value("Value", point.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color(red: 0.18, green: 0.86, blue: 0.67))
                        AreaMark(x: .value("Label", point.label), y: .value("Value", point.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.18, green: 0.86, blue: 0.67).opacity(0.26), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    case .bar:
                        BarMark(x: .value("Label", point.label), y: .value("Value", point.value))
                            .foregroundStyle(point.value >= 0 ? Color(red: 0.20, green: 0.88, blue: 0.48) : Color(red: 1.00, green: 0.32, blue: 0.39))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(10)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
    }
}

private extension UIColor {
    static let jpBackground = UIColor(red: 0.015, green: 0.018, blue: 0.026, alpha: 1)
    static let jpSurface = UIColor(red: 0.075, green: 0.083, blue: 0.105, alpha: 1)
    static let jpGraphite = UIColor(red: 0.125, green: 0.135, blue: 0.160, alpha: 1)
    static let jpBorder = UIColor.white.withAlphaComponent(0.12)
    static let jpText = UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1)
    static let jpSecondary = UIColor(red: 0.58, green: 0.63, blue: 0.70, alpha: 1)
    static let jpMuted = UIColor(red: 0.38, green: 0.43, blue: 0.50, alpha: 1)
    static let jpAccent = UIColor(red: 0.18, green: 0.86, blue: 0.67, alpha: 1)
    static let jpGreen = UIColor(red: 0.20, green: 0.88, blue: 0.48, alpha: 1)
    static let jpRed = UIColor(red: 1.00, green: 0.32, blue: 0.39, alpha: 1)
    static let jpGold = UIColor(red: 1.00, green: 0.72, blue: 0.28, alpha: 1)
    static let jpBlue = UIColor(red: 0.28, green: 0.56, blue: 1.00, alpha: 1)
    static let jpPurple = UIColor(red: 0.58, green: 0.44, blue: 1.00, alpha: 1)

    static func tint(for value: Double) -> UIColor {
        if value > 0 { return .jpGreen }
        if value < 0 { return .jpRed }
        return .jpSecondary
    }
}
