//
//  IdempotencyKey.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct IdempotencyKey: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static func generate(prefix: String) -> IdempotencyKey {
        IdempotencyKey(
            rawValue: "\(prefix)-\(UUID().uuidString.lowercased())"
        )
    }
}

struct BusinessMutationIdentity: Codable, Equatable, Sendable {
    let requestId: String
    let idempotencyKey: IdempotencyKey

    init(requestId: String, idempotencyKey: IdempotencyKey) {
        self.requestId = requestId
        self.idempotencyKey = idempotencyKey
    }

    static func generate(prefix: String) -> BusinessMutationIdentity {
        let value = "\(prefix)-\(UUID().uuidString.lowercased())"
        return BusinessMutationIdentity(
            requestId: value,
            idempotencyKey: IdempotencyKey(rawValue: value)
        )
    }
}
