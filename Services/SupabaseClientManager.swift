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
        guard
            let urlText = Bundle.main.object(forInfoDictionaryKey: SupabaseEnvironment.urlKey) as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: SupabaseEnvironment.anonKey) as? String,
            let url = URL(string: urlText),
            !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    var isConfigured: Bool {
        client != nil
    }
}
