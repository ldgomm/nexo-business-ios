//
//  RetryingAPIClient.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

final class RetryingAPIClient: APIClient, @unchecked Sendable {
    private let wrapped: APIClient
    private let policy: RetryPolicy
    private let logger: AppLogging?

    init(
        wrapping wrapped: APIClient,
        policy: RetryPolicy = .businessDefault,
        logger: AppLogging? = nil
    ) {
        self.wrapped = wrapped
        self.policy = policy
        self.logger = logger
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        var attempt = 1
        var lastError: Error?

        while attempt <= policy.maxAttempts {
            do {
                return try await wrapped.send(request)
            } catch {
                lastError = error

                guard policy.shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }

                logger?.warning(
                    "Retrying request attempt=\(attempt + 1) path=\(SecureLogSanitizer.sanitize(request.path)) error=\(SecureLogSanitizer.sanitize(String(describing: error)))"
                )

                try await Task.sleep(nanoseconds: policy.delayNanoseconds(for: attempt))
                attempt += 1
            }
        }

        throw lastError ?? APIError.transport("No se pudo completar la solicitud.")
    }
}
