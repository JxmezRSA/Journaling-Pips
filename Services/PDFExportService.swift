import Foundation

@MainActor
final class PDFExportService {
    private let generator = ReportGenerator()

    func export(payload: ReportPayload) throws -> URL {
        let fileName = "JournalingPips_\(payload.type.fileToken)_\(dateToken(payload.generatedAt)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        try generator.generate(payload: payload, to: url)
        return url
    }

    private func dateToken(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
