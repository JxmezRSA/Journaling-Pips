import Foundation
import SwiftData
import Supabase

struct VisionAnalysisRequest: Codable {
    struct ScreenshotPayload: Codable, Identifiable {
        let id: UUID
        let slot: String
        let exists: Bool
        let publicImageURL: String?
        let storagePath: String?
        let imageBase64: String?
        let mimeType: String?
        let byteCount: Int?
    }

    let backend: AIBackendProvider
    let prompt: String
    let responseFormat: String
    let pair: String
    let direction: String
    let entryPrice: Double
    let stopLoss: Double
    let takeProfit: Double
    let riskReward: Double
    let session: String
    let notes: String
    let coachingStyle: String
    let tradeResult: String
    let screenshots: [ScreenshotPayload]
}

struct VisionAnalysisResponse: Codable {
    var overallGrade: String?
    let marketStructure: String
    let entryQuality: String
    let riskPlacement: String
    let tradeTiming: String
    let trendAlignment: String
    let liquidity: String
    let fairValueGap: String
    let orderBlocks: String
    let breakOfStructure: String
    let changeOfCharacter: String
    let momentum: String
    let confidence: Int
    var strengths: [String]?
    var mistakes: [String]?
    var improvementPlan: [String]?
    var nextTradeChecklist: [String]?
    let finalVerdict: String
}

@MainActor
final class VisionAnalysisService {
    private let backendService: AIBackendService
    private let promptBuilder = VisionPromptBuilder()
    private let cache = VisionAnalysisCache()

    init(backendService: AIBackendService? = nil) {
        self.backendService = backendService ?? AIBackendService()
    }

    func createRequest(
        for trade: Trade,
        context: ModelContext,
        backend: AIBackendProvider? = nil
    ) async -> VisionAnalysisRequest {
        debugPrint("VISION REQUEST CREATED")
        debugPrint("VISION REQUEST START")
        let provider = backend ?? backendService.provider
        let screenshots = await screenshotPayloads(for: trade)
        debugPrint("VISION SCREENSHOTS FOUND:", screenshots.count)
        let style = coachingStyle(context: context)

        let request = VisionAnalysisRequest(
            backend: provider,
            prompt: promptBuilder.buildPrompt(for: trade, provider: provider, screenshotSlots: screenshots.map(\.slot), coachingStyle: style),
            responseFormat: "structured_json",
            pair: trade.pair,
            direction: trade.direction.rawValue,
            entryPrice: trade.entryPrice,
            stopLoss: trade.stopLoss,
            takeProfit: trade.takeProfit,
            riskReward: trade.riskReward,
            session: trade.session.rawValue,
            notes: [
                trade.notes,
                trade.tradeThesis,
                trade.marketContext,
                trade.executionReview,
                trade.lessonsLearned
            ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n"),
            coachingStyle: style,
            tradeResult: trade.status.rawValue,
            screenshots: screenshots
        )

        debugPrint("VISION PAYLOAD READY")
        return request
    }

    func analyze(
        trade: Trade,
        context: ModelContext,
        backend: AIBackendProvider? = nil
    ) async -> VisionAnalysisResponse {
        let request = await createRequest(for: trade, context: context, backend: backend)

        do {
            let response: VisionAnalysisResponse = try await backendService.post(
                request,
                endpoint: .chartAnalysis,
                responseType: VisionAnalysisResponse.self
            )
            cache.save(response, for: trade)
            debugPrint("VISION RESPONSE RECEIVED")
            debugPrint("VISION ANALYSIS COMPLETE")
            return response
        } catch {
            debugPrint("VISION BACKEND FAILED:", String(describing: error))
            if let cached = cache.response(for: trade) {
                debugPrint("VISION CACHE HIT")
                debugPrint("VISION ANALYSIS COMPLETE")
                return cached
            }

            let response = offlineResponse(for: trade)
            debugPrint("VISION ANALYSIS COMPLETE")
            return response
        }
    }

    private func screenshotPayloads(for trade: Trade) async -> [VisionAnalysisRequest.ScreenshotPayload] {
        let userID = try? await SupabaseClientManager.shared.client?.auth.session.user.id.uuidString.lowercased()
        let tradeRemoteID = trade.remoteId?.lowercased()
        var payloads: [VisionAnalysisRequest.ScreenshotPayload] = []

        for slot in Trade.ScreenshotSlot.allCases {
            let data = imageData(for: slot, trade: trade)
            guard data != nil else { continue }
            let path = cloudReadyPath(for: slot, userID: userID, tradeRemoteID: tradeRemoteID)

            payloads.append(VisionAnalysisRequest.ScreenshotPayload(
                id: UUID(),
                slot: slot.rawValue,
                exists: true,
                publicImageURL: publicURL(for: path),
                storagePath: path,
                imageBase64: publicURL(for: path) == nil ? data?.base64EncodedString() : nil,
                mimeType: "image/jpeg",
                byteCount: data?.count
            ))
        }

        return payloads
    }

    private func offlineResponse(for trade: Trade) -> VisionAnalysisResponse {
        let hasBefore = trade.beforeEntryImageData != nil
        let hasDuring = trade.duringTradeImageData != nil
        let hasAfter = trade.afterExitImageData != nil
        let screenshotCount = [hasBefore, hasDuring, hasAfter].filter { $0 }.count
        let confidence = min(92, 48 + screenshotCount * 14 + (trade.riskReward >= 2 ? 10 : 0) + (trade.followedPlan ? 8 : 0))

        return VisionAnalysisResponse(
            overallGrade: localGrade(confidence),
            marketStructure: hasBefore ? "Structure ready for backend vision review. Local preview sees enough context to evaluate swing points and setup framing." : "Attach a before-entry screenshot to review structure.",
            entryQuality: trade.followedPlan ? "Entry appears aligned with the documented plan." : "Entry quality needs review because the trade was not marked as plan-following.",
            riskPlacement: trade.riskReward >= 2 ? "Reward profile supports disciplined risk placement." : "Risk placement may need refinement to improve reward profile.",
            tradeTiming: trade.mistakeTags.contains(.enteredEarly) ? "Timing warning: marked as entered early." : trade.mistakeTags.contains(.enteredLate) ? "Timing warning: marked as entered late." : "No major timing issue detected locally.",
            trendAlignment: "Trend alignment will be confirmed by the future vision backend.",
            liquidity: trade.strategy == .liquiditySweep ? "Liquidity sweep strategy selected. Screenshot context is prepared for future validation." : "Liquidity context pending visual backend review.",
            fairValueGap: trade.strategy == .fairValueGap ? "FVG strategy selected. Future vision can inspect mitigation and displacement." : "No FVG conclusion without backend vision.",
            orderBlocks: trade.strategy == .orderBlock ? "Order block strategy selected. Future vision can assess reaction quality." : "Order block context pending visual backend review.",
            breakOfStructure: "BOS detection is prepared for the future vision provider.",
            changeOfCharacter: "CHOCH detection is prepared for the future vision provider.",
            momentum: trade.status == .win ? "Outcome suggests momentum supported the idea." : "Review whether momentum weakened before or after entry.",
            confidence: confidence,
            strengths: localStrengths(for: trade),
            mistakes: trade.mistakeTags.map(\.rawValue),
            improvementPlan: localImprovementPlan(for: trade),
            nextTradeChecklist: localChecklist(for: trade),
            finalVerdict: screenshotCount == 0 ? "Add chart screenshots to unlock visual trade coaching." : "Chart context is ready. Offline preview is active until a vision backend is connected."
        )
    }

    private func localGrade(_ confidence: Int) -> String {
        switch confidence {
        case 90...100: return "A"
        case 78...89: return "B"
        case 64...77: return "C"
        case 50...63: return "D"
        default: return "F"
        }
    }

    private func localStrengths(for trade: Trade) -> [String] {
        var strengths: [String] = []
        if trade.followedPlan { strengths.append("Trade was marked as plan-following.") }
        if trade.riskReward >= 2 { strengths.append("Reward profile is strong enough for professional review.") }
        if trade.beforeEntryImageData != nil { strengths.append("Before-entry chart context is available.") }
        if trade.afterExitImageData != nil { strengths.append("After-exit chart context is available for review.") }
        return strengths.isEmpty ? ["Chart review context was prepared successfully."] : strengths
    }

    private func localImprovementPlan(for trade: Trade) -> [String] {
        var plan: [String] = []
        if trade.beforeEntryImageData == nil { plan.append("Add a before-entry screenshot to verify market structure and confluence.") }
        if trade.duringTradeImageData == nil { plan.append("Add a during-trade screenshot to review management decisions.") }
        if trade.afterExitImageData == nil { plan.append("Add an after-exit screenshot to evaluate exit quality.") }
        if trade.riskReward < 2 { plan.append("Review whether the target provides enough reward for the risk.") }
        if trade.mistakeTags.contains(.enteredEarly) { plan.append("Wait for confirmation before executing the next trade.") }
        return plan.isEmpty ? ["Keep capturing screenshots and compare the setup against your written plan."] : plan
    }

    private func localChecklist(for trade: Trade) -> [String] {
        [
            "Confirm trend and market structure before entry.",
            "Mark liquidity, FVG, order block, BOS, and CHOCH before risk is placed.",
            "Validate stop placement against the invalidation point.",
            "Confirm the take-profit target offers acceptable RR.",
            trade.strategy == .other ? "Define the exact strategy before entering." : "Confirm the \(trade.strategy.rawValue) setup is still valid."
        ]
    }

    private func imageData(for slot: Trade.ScreenshotSlot, trade: Trade) -> Data? {
        switch slot {
        case .beforeEntry:
            return trade.beforeEntryImageData
        case .duringTrade:
            return trade.duringTradeImageData
        case .afterExit:
            return trade.afterExitImageData
        }
    }

    private func cloudReadyPath(for slot: Trade.ScreenshotSlot, userID: String?, tradeRemoteID: String?) -> String? {
        guard let userID, let tradeRemoteID else {
            return nil
        }

        return "\(userID)/\(tradeRemoteID)/\(slotFileName(slot))"
    }

    private func publicURL(for path: String?) -> String? {
        guard
            let path,
            let baseURL = ProcessInfo.processInfo.environment[SupabaseEnvironment.urlKey] ?? Bundle.main.object(forInfoDictionaryKey: SupabaseEnvironment.urlKey) as? String,
            !baseURL.isEmpty
        else {
            return nil
        }

        return "\(baseURL)/storage/v1/object/public/trade-screenshots/\(path)"
    }

    private func slotFileName(_ slot: Trade.ScreenshotSlot) -> String {
        switch slot {
        case .beforeEntry:
            return "before-entry.jpg"
        case .duringTrade:
            return "during-trade.jpg"
        case .afterExit:
            return "after-exit.jpg"
        }
    }

    private func coachingStyle(context: ModelContext) -> String {
        let profile = try? context.fetch(FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])).first
        return profile?.coachingStyle.rawValue ?? UserProfile.CoachingStyle.professionalMentor.rawValue
    }
}

private struct VisionAnalysisCache {
    private let keyPrefix = "jp.vision.analysis."

    func response(for trade: Trade) -> VisionAnalysisResponse? {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + trade.id.uuidString) else {
            return nil
        }

        return try? JSONDecoder().decode(VisionAnalysisResponse.self, from: data)
    }

    func save(_ response: VisionAnalysisResponse, for trade: Trade) {
        guard let data = try? JSONEncoder().encode(response) else {
            return
        }

        UserDefaults.standard.set(data, forKey: keyPrefix + trade.id.uuidString)
    }
}
