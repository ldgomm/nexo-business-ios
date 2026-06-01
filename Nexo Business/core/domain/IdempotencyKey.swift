//
//  IdempotencyKey.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct IdempotencyKey: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func generate(prefix: String) -> IdempotencyKey {
        IdempotencyKey(
            rawValue: "\(prefix)-\(UUID().uuidString.lowercased())"
        )
    }
}

public struct BusinessMutationIdentity: Codable, Equatable, Sendable {
    public let requestId: String
    public let idempotencyKey: IdempotencyKey

    public init(requestId: String, idempotencyKey: IdempotencyKey) {
        self.requestId = requestId
        self.idempotencyKey = idempotencyKey
    }

    public static func generate(prefix: String) -> BusinessMutationIdentity {
        let value = "\(prefix)-\(UUID().uuidString.lowercased())"
        return BusinessMutationIdentity(
            requestId: value,
            idempotencyKey: IdempotencyKey(rawValue: value)
        )
    }
}
