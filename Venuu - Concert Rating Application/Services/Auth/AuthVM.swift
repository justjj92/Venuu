import Foundation
import Supabase

@MainActor
final class AuthVM: ObservableObject {
    @Published var session: Session?
    @Published var profile: ProfileRead?
    @Published var error: String?

    var isSignedIn: Bool { session != nil }

    init() {
        Task {
            await loadInitialSession()
            await listenForAuth()
        }
    }

    // MARK: - Session + Profile

    private func loadInitialSession() async {
        let sess = try? await supa.auth.session
        self.session = sess
        if sess != nil {
            await refreshProfile()
        }
    }

    private func listenForAuth() async {
        for await change in supa.auth.authStateChanges {
            switch change.event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                self.session = change.session
                await refreshProfile()
            case .signedOut, .userDeleted:
                self.session = nil
                self.profile = nil
            default:
                break
            }
        }
    }

    @discardableResult
    func refreshProfile() async -> ProfileRead? {
        do {
            let p = try await CloudStore.shared.fetchMyProfile()
            self.profile = p
            return p
        } catch {
            // Non-fatal; keep going
            return nil
        }
    }

    // MARK: - Sign In / Up / Out

    /// Sign in with **email OR username**
    func signIn(emailOrUsername: String, password: String) async throws {
        self.error = nil
        let identifier = emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeEmail = identifier.contains("@")

        var emailToUse = identifier
        if !looksLikeEmail {
            guard let resolved = try await CloudStore.shared.emailForUsername(identifier),
                  !resolved.isEmpty else {
                let e = NSError(domain: "auth", code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "We couldn’t find an account for that username."])
                self.error = e.localizedDescription
                throw e
            }
            emailToUse = resolved
        }

        do {
            _ = try await supa.auth.signIn(email: emailToUse, password: password)
            try? await CloudStore.shared.upsertProfileAfterAuth(username: looksLikeEmail ? nil : identifier)
            await refreshProfile()
        } catch {
            self.error = (error as NSError).localizedDescription
            throw error
        }
    }

    /// Sign up (username required)
    func signUp(email: String, password: String, username: String) async throws {
        self.error = nil

        // Validate username
        let uname = username.replacingOccurrences(of: " ", with: "")
        let regex = try! NSRegularExpression(pattern: "^[A-Za-z0-9_]{3,20}$")
        let r = NSRange(location: 0, length: uname.utf16.count)
        guard regex.firstMatch(in: uname, options: [], range: r) != nil else {
            let e = NSError(domain: "auth", code: 422,
                            userInfo: [NSLocalizedDescriptionKey: "Username must be 3–20 characters and use only letters, numbers, or underscores."])
            self.error = e.localizedDescription
            throw e
        }

        // (Best-effort) availability check
        do {
            let free = try await CloudStore.shared.isUsernameAvailable(uname)
            if !free {
                let e = NSError(domain: "auth", code: 409,
                                userInfo: [NSLocalizedDescriptionKey: "That username is already taken. Please choose another."])
                self.error = e.localizedDescription
                throw e
            }
        } catch {
            // continue; DB will still enforce uniqueness
        }

        // Build user_metadata as [String: AnyJSON]
        var meta: [String: AnyJSON] = [:]
        meta["username"] = .string(uname)

        do {
            _ = try await supa.auth.signUp(email: email, password: password, data: meta)
            // If a session exists immediately, seed/refresh profile now.
            try? await CloudStore.shared.upsertProfileAfterAuth(username: uname)
            await refreshProfile()
        } catch {
            let ns = error as NSError
            let msg = ns.localizedDescription.lowercased()
            if ns.code == 409 || msg.contains("duplicate key") || msg.contains("already exists") || msg.contains("23505") {
                self.error = "That username is already taken. Please choose another."
            } else {
                self.error = ns.localizedDescription
            }
            throw error
        }
    }

    func signOut() async {
        self.error = nil
        do {
            try await supa.auth.signOut()
            self.session = nil
            self.profile = nil
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

extension AuthVM {
    func changePassword(to newPassword: String) async throws {
        // Supabase Swift: update the current user attributes
        try await supa.auth.update(user: .init(password: newPassword))
    }
}
