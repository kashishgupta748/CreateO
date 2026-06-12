///
//  AuthManager.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import Foundation
import Supabase

// MARK: - Auth State

enum AuthState: Equatable {
    case loading
    case guest          // skipped login — local only
    case pendingEmailConfirmation // account created, but email not confirmed yet
    case authenticated  // signed-in user
}

enum SignUpResult: Equatable {
    case authenticated
    case needsEmailConfirmation
}

// MARK: - AuthManager

/// Manages authentication state for the app.
/// Annotated @MainActor so all property mutations happen on the main thread —
/// no need for scattered `await MainActor.run { }` call sites.
@Observable
@MainActor
final class AuthManager {

    // MARK: - State

    var state: AuthState = .loading

    /// True once the user has interacted with the auth screen (Skip / Sign In / Sign Up).
    /// Stored var (not computed) so @Observable tracks mutations and triggers view updates.
    /// Persisted across launches via UserDefaults.
    var hasSeenAuthScreen: Bool = UserDefaults.standard.bool(forKey: "hasSeenAuthScreen") {
        didSet { UserDefaults.standard.set(hasSeenAuthScreen, forKey: "hasSeenAuthScreen") }
    }

    var isLoggedIn: Bool { state == .authenticated }
    var needsEmailConfirmation: Bool { state == .pendingEmailConfirmation }
    var hasAccountContext: Bool { state == .authenticated || state == .pendingEmailConfirmation }

    var currentUserEmail: String? { _email }

    /// The UUID of the currently authenticated user (needed to set `user_id` in DTOs).
    var currentUserID: UUID? { _userID }

    // MARK: - Private

    private var _email: String?
    private var _userID: UUID?

    private let client = SupabaseManager.shared.client
    private let pendingEmailKey = "pendingEmailConfirmation"

    private var pendingEmailConfirmation: String? {
        get { UserDefaults.standard.string(forKey: pendingEmailKey) }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: pendingEmailKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingEmailKey)
            }
        }
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func applyGuestState(hasSeenAuthScreen: Bool) {
        _email = nil
        _userID = nil
        pendingEmailConfirmation = nil
        self.hasSeenAuthScreen = hasSeenAuthScreen
        state = .guest
    }

    // MARK: - Init

    init() {
        // Resolve synchronously from the cached session so the first frame
        // already shows the correct state (no stale .loading flash).
        // AuthManager is always created on the main thread, so @MainActor
        // isolation applies here without needing nonisolated.
        if let session = SupabaseManager.shared.client.auth.currentSession {
            _email  = session.user.email
            _userID = session.user.id
            state   = .authenticated
            pendingEmailConfirmation = nil
        } else if let pending = pendingEmailConfirmation {
            _email  = pending
            _userID = nil
            hasSeenAuthScreen = true
            state = .pendingEmailConfirmation
        } else {
            applyGuestState(hasSeenAuthScreen: false)
        }
    }

    // MARK: - Session Restore

    /// Call once at app startup to verify the cached session is still valid.
    func restoreSession() async {
        guard client.auth.currentSession != nil else {
            if let pending = pendingEmailConfirmation {
                _email  = pending
                _userID = nil
                hasSeenAuthScreen = true
                state = .pendingEmailConfirmation
            } else {
                applyGuestState(hasSeenAuthScreen: false)
            }
            return
        }
        do {
            let session = try await client.auth.session
            _email  = session.user.email
            _userID = session.user.id
            state   = .authenticated
            pendingEmailConfirmation = nil
        } catch {
            applyGuestState(hasSeenAuthScreen: false)
        }
    }

    // MARK: - Auth Actions

    func signUp(email: String, password: String) async throws -> SignUpResult {
        let normalizedEmail = normalizedEmail(email)
        let response = try await client.auth.signUp(email: normalizedEmail, password: password)

        if let session = response.session {
            _email            = session.user.email
            _userID           = session.user.id
            hasSeenAuthScreen = true
            state             = .authenticated
            pendingEmailConfirmation = nil
            return .authenticated
        }

        _email = normalizedEmail
        _userID = nil
        pendingEmailConfirmation = normalizedEmail
        hasSeenAuthScreen = true
        state = .pendingEmailConfirmation
        return .needsEmailConfirmation
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(
            email: normalizedEmail(email),
            password: password
        )
        _email            = session.user.email
        _userID           = session.user.id
        hasSeenAuthScreen = true
        state             = .authenticated
        pendingEmailConfirmation = nil
    }

    func signOut() async throws {
        if client.auth.currentSession != nil {
            do {
                try await client.auth.signOut()
            } catch {
                if state == .pendingEmailConfirmation {
                    applyGuestState(hasSeenAuthScreen: false)
                    return
                }
                throw error
            }
        }

        applyGuestState(hasSeenAuthScreen: false)
    }

    func updateDisplayName(_ displayName: String) async throws {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        _ = try await client.auth.update(
            user: UserAttributes(
                data: ["full_name": .string(trimmed)]
            )
        )
    }

    func resendConfirmationEmail() async throws {
        guard let email = currentUserEmail, !email.isEmpty else { return }
        try await client.auth.resend(email: email, type: .signup)
    }

    func sendPasswordReset() async throws {
        guard let email = currentUserEmail, !email.isEmpty else { return }
        try await client.auth.resetPasswordForEmail(email)
    }

    func sendPasswordReset(email: String) async throws {
        let normalizedEmail = normalizedEmail(email)
        guard !normalizedEmail.isEmpty else { return }
        try await client.auth.resetPasswordForEmail(normalizedEmail)
    }

    func refreshCurrentUser() async throws {
        let user = try await client.auth.user()
        _email = user.email
        _userID = user.id
    }

    /// User taps "Skip" — enters local-only guest mode.
    func continueAsGuest() {
        applyGuestState(hasSeenAuthScreen: true)
    }

    // MARK: - Auth State Listener

    /// Call once from the app entry point to react to token refreshes / sign-outs.
    func startAuthStateListener() {
        Task { [weak self] in
            guard let self else { return }
            for await (event, session) in client.auth.authStateChanges {
                switch event {
                case .signedIn:
                    self.pendingEmailConfirmation = nil
                    self._email  = session?.user.email
                    self._userID = session?.user.id
                    self.state   = .authenticated
                case .signedOut:
                    self.applyGuestState(hasSeenAuthScreen: false)
                default:
                    break
                }
            }
        }
    }
}
