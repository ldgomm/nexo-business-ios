//
//  LoginViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var isRecoveringSessions = false
    var errorMessage: String?
    var sessionLimitMessage: String?
    var didLogin = false

    var isSessionLimitReached: Bool {
        sessionLimitMessage != nil
    }

    private let repository: AuthRepository
    private let onLoginSucceeded: (() async -> Void)?

    init(
        authRepository: AuthRepository,
        onLoginSucceeded: (() async -> Void)? = nil
    ) {
        self.repository = authRepository
        self.onLoginSucceeded = onLoginSucceeded
    }

    func login() async {
        errorMessage = nil
        sessionLimitMessage = nil
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            _ = try await repository.login(
                email: normalizedEmail,
                password: password
            )
            didLogin = true
            await onLoginSucceeded?()
        } catch let error as APIError {
            print("❌ Preview APIError:", error)
            handleLoginError(error)
        } catch {
            print("❌ Preview Error:", error)
            errorMessage = error.localizedDescription
        }
    }

    func recoverSessionsAndLogin() async {
        errorMessage = nil
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Ingresa correo y contraseña para cerrar sesiones anteriores."
            return
        }

        isRecoveringSessions = true
        defer { isRecoveringSessions = false }

        do {
            _ = try await repository.recoverSessions(
                email: normalizedEmail,
                password: password
            )
            sessionLimitMessage = nil
            didLogin = true
            await onLoginSucceeded?()
        } catch let error as APIError {
            handleLoginError(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleLoginError(_ error: APIError) {
        if error.isMaxSessionsReached {
            sessionLimitMessage = error.userMessage
            errorMessage = nil
            return
        }

        if error.isLockedByTooManyAttempts {
            sessionLimitMessage = nil
            errorMessage = error.userMessage
            return
        }

        sessionLimitMessage = nil
        errorMessage = error.userMessage
    }
}
