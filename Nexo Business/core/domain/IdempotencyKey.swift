//
//  IdempotencyKey.swift
//  Nexo Admin
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
