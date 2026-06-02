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
    var errorMessage: String?
    var didLogin = false

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
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            _ = try await repository.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            didLogin = true
            await onLoginSucceeded?()
        } catch let error as APIError {
            print("❌ Preview APIError:", error)
            errorMessage = error.userMessage
        } catch {
            print("❌ Preview Error:", error)
            errorMessage = error.localizedDescription
        }
    }
}
