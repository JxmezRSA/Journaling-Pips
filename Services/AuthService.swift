import AuthenticationServices
import Foundation
import Supabase

enum AuthServiceError: LocalizedError {
    case supabaseMissing
    case invalidCredentials
    case emailAlreadyRegistered
    case networkUnavailable
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .supabaseMissing:
            return "Supabase keys are missing. You can continue offline."
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyRegistered:
            return "Email already registered. Try signing in instead."
        case .networkUnavailable:
            return "Network unavailable. Your local journal still works offline."
        case .unknown(let message):
            return message
        }
    }
}

private struct SupabaseProfilePayload: Codable {
    let id: UUID
    let email: String
    let displayName: String
    let subscriptionTier: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case subscriptionTier = "subscription_tier"
        case updatedAt = "updated_at"
    }
}

@MainActor
final class AuthService {
    private let keychain = KeychainService.shared
    private let sessionKey = "jp.supabase.session"

    var isConfigured: Bool {
        SupabaseClientManager.shared.isConfigured
    }

    func login(email: String, password: String) async throws -> CloudUser {
        guard let client = SupabaseClientManager.shared.client else {
            throw AuthServiceError.supabaseMissing
        }

        do {
            debugPrint("Journaling Pips Auth Debug [login] calling supabase.auth.signIn(email:password:)")
            debugPrint("Journaling Pips Auth Debug [login] email:", email)
            let session = try await client.auth.signIn(email: email, password: password)
            logSignInResult(session)
            persistSessionMetadata(session)
            return try await profile(for: session.user, displayName: emailName(session.user.email ?? email))
        } catch {
            logAuthError(error, context: "login")
            throw error
        }
    }

    func register(email: String, password: String, displayName: String) async throws -> CloudUser {
        guard let client = SupabaseClientManager.shared.client else {
            throw AuthServiceError.supabaseMissing
        }

        do {
            debugPrint("Journaling Pips Auth Debug [signup] calling supabase.auth.signUp(email:password:)")
            debugPrint("Journaling Pips Auth Debug [signup] email:", email)
            debugPrint("Journaling Pips Auth Debug [signup] displayName metadata sent to Supabase:", false)
            let response = try await client.auth.signUp(email: email, password: password)
            logSignUpResult(response)
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailName(email) : displayName
            try? await upsertProfile(userID: response.user.id, email: response.user.email ?? email, displayName: name)
            if let session = response.session {
                persistSessionMetadata(session)
            }
            return CloudUser(id: response.user.id, email: response.user.email ?? email, displayName: name, subscriptionTier: .free)
        } catch {
            logAuthError(error, context: "signup")
            throw error
        }
    }

    func resetPassword(email: String) async throws {
        guard let client = SupabaseClientManager.shared.client else {
            throw AuthServiceError.supabaseMissing
        }

        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            logAuthError(error, context: "password reset")
            throw error
        }
    }

    func currentUser(syncProfile: Bool = true) async throws -> CloudUser? {
        guard let client = SupabaseClientManager.shared.client else {
            return nil
        }

        do {
            let session = try await client.auth.session
            persistSessionMetadata(session)
            if syncProfile {
                return try await profile(for: session.user, displayName: emailName(session.user.email ?? "trader@journalingpips.local"))
            }
            let email = session.user.email ?? ""
            return CloudUser(id: session.user.id, email: email, displayName: emailName(email), subscriptionTier: .free)
        } catch {
            logAuthError(error, context: "current user")
            return nil
        }
    }

    func signInWithApple() async throws -> CloudUser {
        // The request UI and nonce flow are intentionally prepared for a later hardening pass.
        // Until Supabase keys and Apple service IDs are configured, keep the app local-first.
        offlineUser(email: "apple@journalingpips.local", displayName: "Apple Trader")
    }

    func signInWithGoogle() async throws -> CloudUser {
        offlineUser(email: "google@journalingpips.local", displayName: "Google Trader")
    }

    func logout() async {
        if let client = SupabaseClientManager.shared.client {
            try? await client.auth.signOut()
        }
        keychain.delete(sessionKey)
        keychain.delete("\(sessionKey).refresh")
        UserDefaults.standard.set(false, forKey: "jp.isCloudAuthenticated")
    }

    private func offlineUser(email: String, displayName: String) -> CloudUser {
        CloudUser(email: email, displayName: displayName, subscriptionTier: .free)
    }

    private func profile(for user: User, displayName: String) async throws -> CloudUser {
        let email = user.email ?? ""
        try? await upsertProfile(userID: user.id, email: email, displayName: displayName)
        return CloudUser(id: user.id, email: email, displayName: displayName, subscriptionTier: .free)
    }

    private func upsertProfile(userID: UUID, email: String, displayName: String) async throws {
        guard let client = SupabaseClientManager.shared.client else {
            throw AuthServiceError.supabaseMissing
        }

        let payload = SupabaseProfilePayload(
            id: userID,
            email: email,
            displayName: displayName,
            subscriptionTier: CloudUser.SubscriptionTier.free.rawValue,
            updatedAt: Date()
        )
        _ = try await client
            .from("profiles")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    private func persistSessionMetadata(_ session: Session) {
        keychain.save(session.accessToken, for: sessionKey)
        keychain.save(session.refreshToken, for: "\(sessionKey).refresh")
        UserDefaults.standard.set(true, forKey: "jp.isCloudAuthenticated")
        UserDefaults.standard.set(Date(), forKey: "jp.lastAuthDate")
    }

    private func emailName(_ email: String) -> String {
        email.split(separator: "@").first.map(String.init) ?? "Trader"
    }

    private func logAuthError(_ error: Error, context: String) {
        let localized = error.localizedDescription
        let described = String(describing: error)
        debugPrint("Journaling Pips Auth Error [\(context)]")
        debugPrint("localizedDescription:", localized)
        debugPrint("raw error:", described)
        debugPrint("statusCode:", authStatusCode(from: error).map(String.init) ?? "not available")

        if let authError = error as? AuthError {
            debugPrint("authError.message:", authError.message)
            debugPrint("authError.errorCode:", authError.errorCode.rawValue)
            switch authError {
            case .api(_, _, let underlyingData, let underlyingResponse):
                debugPrint("authError.underlyingResponse.statusCode:", underlyingResponse.statusCode)
                debugPrint("authError.underlyingResponse.url:", underlyingResponse.url?.absoluteString ?? "nil")
                debugPrint("authError.underlyingResponse.headers:", underlyingResponse.allHeaderFields)
                debugPrint("authError.underlyingData:", String(data: underlyingData, encoding: .utf8) ?? "\(underlyingData.count) bytes")
            case .weakPassword(_, let reasons):
                debugPrint("authError.weakPassword.reasons:", reasons)
            default:
                break
            }
        }
    }

    private func logSignInResult(_ session: Session) {
        debugPrint("Journaling Pips Auth Debug [login] supabase.auth.signIn returned successfully")
        debugPrint("statusCode:", "not exposed by Supabase Swift AuthResponse/Session")
        debugPrint("hasUser:", true)
        debugPrint("hasSession:", true)
        debugPrint("user.id:", session.user.id.uuidString)
        debugPrint("user.email:", session.user.email ?? "nil")
        debugPrint("session.expiresAt:", session.expiresAt)
        debugPrint("session.tokenType:", session.tokenType)
    }

    private func logSignUpResult(_ response: AuthResponse) {
        debugPrint("Journaling Pips Auth Debug [signup] supabase.auth.signUp returned successfully")
        debugPrint("Journaling Pips Auth Debug [signup] raw response:", String(describing: response))
        debugPrint("statusCode:", "not exposed by Supabase Swift AuthResponse")
        debugPrint("hasUser:", true)
        debugPrint("hasSession:", response.session != nil)
        debugPrint("user.id:", response.user.id.uuidString)
        debugPrint("user.email:", response.user.email ?? "nil")
        debugPrint("user.aud:", response.user.aud)
        debugPrint("user.createdAt:", response.user.createdAt)
        debugPrint("user.confirmedAt:", response.user.confirmedAt as Any)
        debugPrint("user.emailConfirmedAt:", response.user.emailConfirmedAt as Any)
        debugPrint("user.confirmationSentAt:", response.user.confirmationSentAt as Any)
        if let session = response.session {
            debugPrint("session returned:", true)
            debugPrint("session.expiresAt:", session.expiresAt)
            debugPrint("session.tokenType:", session.tokenType)
        } else {
            debugPrint("session returned:", false)
            debugPrint("signup note:", "A nil session can be expected when Supabase email confirmation is enabled.")
        }
    }

    private func authStatusCode(from error: Error) -> Int? {
        guard let authError = error as? AuthError else { return nil }
        if case .api(_, _, _, let underlyingResponse) = authError {
            return underlyingResponse.statusCode
        }
        return nil
    }
}
