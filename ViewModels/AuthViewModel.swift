import Combine
import Foundation
import SwiftData

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var isLogin = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var cloudUser: CloudUser?
    @Published var isCloudAuthenticated = false

    private let authService = AuthService()
    private var modelContext: ModelContext?

    var isConfigured: Bool { authService.isConfigured }

    func configure(context: ModelContext) {
        modelContext = context
        loadLocalUser()
        detectCurrentUser()
    }

    func submit() {
        Task {
            await authenticate()
        }
    }

    func signInWithApple() {
        Task {
            await runAuth {
                try await self.authService.signInWithApple()
            }
        }
    }

    func signInWithGoogle() {
        Task {
            await runAuth {
                try await self.authService.signInWithGoogle()
            }
        }
    }

    func resetPassword() {
        Task {
            do {
                try await authService.resetPassword(email: email)
                successMessage = "Password reset email sent if the account exists."
                errorMessage = nil
            } catch {
                logAuthError(error, context: "password reset")
                errorMessage = friendlyMessage(for: error)
                successMessage = nil
            }
        }
    }

    func logout() {
        Task {
            await authService.logout()
            clearLocalUser()
            cloudUser = nil
            isCloudAuthenticated = false
            successMessage = "Logged out. Offline mode is still available."
        }
    }

    func continueOffline() {
        cloudUser = nil
        isCloudAuthenticated = false
        errorMessage = nil
        successMessage = "Offline mode enabled."
    }

    private func authenticate() async {
        await runAuth {
            if self.isLogin {
                debugPrint("Journaling Pips Auth Debug [submit] mode: login -> AuthService.login -> supabase.auth.signIn")
                return try await self.authService.login(email: self.email, password: self.password)
            }

            debugPrint("Journaling Pips Auth Debug [submit] mode: register -> AuthService.register -> supabase.auth.signUp")
            return try await self.authService.register(email: self.email, password: self.password, displayName: self.displayName)
        }
    }

    private func runAuth(_ operation: @escaping () async throws -> CloudUser) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await operation()
            persist(user)
            cloudUser = user
            isCloudAuthenticated = authService.isConfigured
            errorMessage = nil
            successMessage = "Signed in successfully."
        } catch {
            logAuthError(error, context: isLogin ? "login" : "signup")
            errorMessage = friendlyMessage(for: error)
            successMessage = nil
        }
    }

    private func loadLocalUser() {
        guard let modelContext else { return }
        isCloudAuthenticated = UserDefaults.standard.bool(forKey: "jp.isCloudAuthenticated")
        cloudUser = isCloudAuthenticated ? (try? modelContext.fetch(FetchDescriptor<CloudUser>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])).first) : nil
    }

    private func detectCurrentUser() {
        guard authService.isConfigured else {
            isCloudAuthenticated = false
            cloudUser = nil
            return
        }

        Task {
            debugPrint("BEGIN STARTUP AUTH")
            defer { debugPrint("END STARTUP AUTH") }

            do {
                let user = try await withJPTimeout(seconds: 2.0) {
                    try await self.authService.currentUser(syncProfile: false)
                }

                guard let user else {
                    if !UserDefaults.standard.bool(forKey: "jp.isCloudAuthenticated") {
                        cloudUser = nil
                        isCloudAuthenticated = false
                    }
                    return
                }

                persist(user)
                cloudUser = user
                isCloudAuthenticated = true
            } catch JPAsyncTimeoutError.timedOut {
                debugPrint("BEGIN STARTUP AUTH timeout fallback")
                debugPrint("Supabase session restore timed out. Continuing in local/offline mode.")
                cloudUser = nil
                isCloudAuthenticated = false
            } catch {
                logAuthError(error, context: "startup auth")
                if !UserDefaults.standard.bool(forKey: "jp.isCloudAuthenticated") {
                    cloudUser = nil
                    isCloudAuthenticated = false
                }
            }
        }
    }

    private func persist(_ user: CloudUser) {
        guard let modelContext else { return }
        if let existing = ((try? modelContext.fetch(FetchDescriptor<CloudUser>())) ?? []).first(where: { $0.id == user.id }) {
            existing.email = user.email
            existing.displayName = user.displayName
            existing.subscriptionTier = user.subscriptionTier
        } else {
            modelContext.insert(user)
        }
        try? modelContext.save()
    }

    private func clearLocalUser() {
        guard let modelContext else { return }
        let users = (try? modelContext.fetch(FetchDescriptor<CloudUser>())) ?? []
        users.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    private func friendlyMessage(for error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }

        let localizedDescription = error.localizedDescription
        if !localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localizedDescription
        }

        return String(describing: error)
    }

    private func logAuthError(_ error: Error, context: String) {
        debugPrint("Journaling Pips AuthViewModel Error [\(context)]")
        debugPrint("localizedDescription:", error.localizedDescription)
        debugPrint("raw error:", String(describing: error))
    }
}
