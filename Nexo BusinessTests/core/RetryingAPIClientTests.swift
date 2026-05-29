//
//  RetryingAPIClientTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class RetryingAPIClientTests: XCTestCase {
    func testRetriesRetriableServerErrorAndReturnsResponse() async throws {
        let wrapped = FlakyAPIClient(
            failuresBeforeSuccess: 1,
            error: APIError.server(statusCode: 503, code: "unavailable", message: "Down", requestId: "req_1")
        )
        let client = RetryingAPIClient(
            wrapping: wrapped,
            policy: RetryPolicy(maxAttempts: 2, baseDelayNanoseconds: 1, retryableStatusCodes: [503])
        )

        let request = APIRequest<EmptyResponse>(
            method: .get,
            path: "/health",
            requiresAuth: false
        )

        _ = try await client.send(request)

        XCTAssertEqual(wrapped.attempts, 2)
    }

    func testDoesNotRetryValidationError() async {
        let wrapped = FlakyAPIClient(
            failuresBeforeSuccess: 99,
            error: APIError.server(statusCode: 422, code: "validation", message: "Invalid", requestId: "req_1")
        )
        let client = RetryingAPIClient(
            wrapping: wrapped,
            policy: RetryPolicy(maxAttempts: 3, baseDelayNanoseconds: 1, retryableStatusCodes: [503])
        )

        let request = APIRequest<EmptyResponse>(
            method: .get,
            path: "/validation",
            requiresAuth: false
        )

        do {
            _ = try await client.send(request)
            XCTFail("Expected request to fail")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 422)
            XCTAssertEqual(wrapped.attempts, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class FlakyAPIClient: APIClient, @unchecked Sendable {
    private let failuresBeforeSuccess: Int
    private let error: Error
    private(set) var attempts = 0

    init(failuresBeforeSuccess: Int, error: Error) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
        self.error = error
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        attempts += 1

        if attempts <= failuresBeforeSuccess {
            throw error
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        fatalError("This test client only supports EmptyResponse")
    }
}
