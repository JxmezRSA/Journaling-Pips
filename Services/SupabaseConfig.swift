import Foundation
import Supabase

enum SupabaseEnvironment {
    static let urlKey = "SUPABASE_URL"
    static let anonKey = "SUPABASE_ANON_KEY"
}

final class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    private init() {}

    var client: SupabaseClient? {
        let environment = ProcessInfo.processInfo.environment
        let configuredURL = Bundle.main.object(forInfoDictionaryKey: SupabaseEnvironment.urlKey) as? String
        let configuredKey = Bundle.main.object(forInfoDictionaryKey: SupabaseEnvironment.anonKey) as? String

        guard
            let urlText = (environment[SupabaseEnvironment.urlKey] ?? configuredURL)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let anonKey = (environment[SupabaseEnvironment.anonKey] ?? configuredKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let url = URL(string: urlText),
            !urlText.isEmpty,
            !anonKey.isEmpty
        else {
            return nil
        }

        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    var isConfigured: Bool {
        client != nil
    }
}

enum SupabaseConfig {
    static var client: SupabaseClient? {
        SupabaseClientManager.shared.client
    }
}
