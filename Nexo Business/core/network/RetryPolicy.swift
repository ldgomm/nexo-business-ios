//
//  RetryPolicy.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct RetryPolicy: Equatable, Sendable {
    public let maxAttempts: Int
    public let baseDelayNanoseconds: UInt64
    public let retryableStatusCodes: Set<Int>

    public init(
        maxAttempts: Int,
        baseDelayNanoseconds: UInt64,
        retryableStatusCodes: Set<Int>
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelayNanoseconds = baseDelayNanoseconds
        self.retryableStatusCodes = retryableStatusCodes
    }

    public static let businessDefault = RetryPolicy(
        maxAttempts: 2,
        baseDelayNanoseconds: 350_000_000,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )

    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }

        if let apiError = error as? APIError {
            switch apiError {
            case .transport:
                return true
            case let .server(statusCode, _, _, _):
                return retryableStatusCodes.contains(statusCode)
            default:
                return false
            }
        }

        return false
    }

    public func delayNanoseconds(for attempt: Int) -> UInt64 {
        guard attempt > 1 else { return baseDelayNanoseconds }
        return baseDelayNanoseconds * UInt64(attempt)
    }
}
