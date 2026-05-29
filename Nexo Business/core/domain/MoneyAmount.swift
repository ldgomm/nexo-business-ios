//
//  MoneyAmount.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct MoneyAmount: Codable, Equatable, Hashable, Sendable {
    public let amount: String
    public let currency: String

    public init(amount: String, currency: String = "USD") {
        self.amount = amount
        self.currency = currency
    }
}
