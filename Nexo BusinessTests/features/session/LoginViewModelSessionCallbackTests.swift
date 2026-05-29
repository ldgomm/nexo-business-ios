//
//  LoginViewModelSessionCallbackTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class LoginViewModelSessionCallbackTests: XCTestCase {
    func testLoginSuccessCallsSessionCallback() async {
        let repository = TestAuthRepository(result: .success(
            LoginResponse(
                accessToken: "access-token",
                refreshToken: "refresh-token",
                expiresAt: Date().addingTimeInterval(3600),
                user: AuthenticatedUser(
                    id: "usr_test",
                    email: "operador@nexo.test",
                    displayName: "Operador Test"
                )
            )
        ))
        var didCallCallback = false
        let viewModel = LoginViewModel(
            authRepository: repository,
            onLoginSucceeded: {
                didCallCallback = true
            }
        )
        viewModel.email = "operador@nexo.test"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertTrue(viewModel.didLogin)
        XCTAssertTrue(didCallCallback)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoginFailureDoesNotCallSessionCallback() async {
        let repository = TestAuthRepository(result: .failure(
            APIError.server(
                statusCode: 401,
                code: "invalid_credentials",
                message: "Invalid credentials",
                requestId: "req_login"
            )
        ))
        var didCallCallback = false
        let viewModel = LoginViewModel(
            authRepository: repository,
            onLoginSucceeded: {
                didCallCallback = true
            }
        )
        viewModel.email = "operador@nexo.test"
        viewModel.password = "bad-secret"

        await viewModel.login()

        XCTAssertFalse(viewModel.didLogin)
        XCTAssertFalse(didCallCallback)
        XCTAssertEqual(viewModel.errorMessage, "Tu sesión caducó. Vuelve a iniciar sesión.")
    }
}

private final class TestAuthRepository: AuthRepository, @unchecked Sendable {
    private let result: Result<LoginResponse, Error>

    init(result: Result<LoginResponse, Error>) {
        self.result = result
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        try result.get()
    }

    func logout() async throws {}
}
