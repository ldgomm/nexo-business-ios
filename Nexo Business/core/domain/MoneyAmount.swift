//
//  MoneyAmount.swift
//  Nexo Business
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
    
    private enum CodingKeys: String, CodingKey {
        case amount
        case currency
        case decimal = "$numberDecimal"
    }
    
    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer() {
            if let string = try? single.decode(String.self) {
                self.amount = string
                self.currency = "USD"
                return
            }
            
            if let double = try? single.decode(Double.self) {
                self.amount = MoneyAmount.format(double)
                self.currency = "USD"
                return
            }
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        
        if let amount = try? container.decode(String.self, forKey: .amount) {
            self.amount = amount
            return
        }
        
        if let amount = try? container.decode(Double.self, forKey: .amount) {
            self.amount = MoneyAmount.format(amount)
            return
        }
        
        if let nested = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .amount),
           let decimal = try? nested.decode(String.self, forKey: .decimal) {
            self.amount = decimal
            return
        }
        
        if let decimal = try? container.decode(String.self, forKey: .decimal) {
            self.amount = decimal
            return
        }
        
        self.amount = "0.00"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
    }
    
    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
