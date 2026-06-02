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
public final class LoginViewModel {
    public var email = ""
    public var password = ""
    public var isLoading = false
    public var errorMessage: String?
    public var didLogin = false

    private let repository: AuthRepository
    private let onLoginSucceeded: (() async -> Void)?

    public init(
        authRepository: AuthRepository,
        onLoginSucceeded: (() async -> Void)? = nil
    ) {
        self.repository = authRepository
        self.onLoginSucceeded = onLoginSucceeded
    }

    public func login() async {
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
