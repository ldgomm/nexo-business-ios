//
//  PaymentModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessPaymentMethod: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case cash
    case transfer
    case card
    case other
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .cash:
            return "Efectivo"
        case .transfer:
            return "Transferencia"
        case .card:
            return "Tarjeta"
        case .other:
            return "Otro"
        }
    }
    
    public var requiresReference: Bool {
        switch self {
        case .cash:
            return false
        case .transfer, .card, .other:
            return true
        }
    }
}

public struct RegisterPaymentRequest: Encodable, Equatable, Sendable {
    public let saleId: String
    public let cashSessionId: String?
    public let method: String
    public let amount: String
    public let reference: String?
    public let note: String?
    public let paidAt: Date?
    public let markRemainingAsReceivable: Bool
    public let receivableDueAt: Date?
    public let requestId: String?
    
    public init(
        saleId: String,
        cashSessionId: String? = nil,
        method: String,
        amount: String,
        reference: String? = nil,
        note: String? = nil,
        paidAt: Date? = nil,
        markRemainingAsReceivable: Bool = false,
        receivableDueAt: Date? = nil,
        requestId: String? = nil
    ) {
        self.saleId = saleId
        self.cashSessionId = cashSessionId
        self.method = method
        self.amount = amount
        self.reference = reference
        self.note = note
        self.paidAt = paidAt
        self.markRemainingAsReceivable = markRemainingAsReceivable
        self.receivableDueAt = receivableDueAt
        self.requestId = requestId
    }
    
    private enum CodingKeys: String, CodingKey {
        case requestId
        case saleId
        case cashSessionId
        case amount
        case method
        case paidAt
        case reference
        case notes
        case markRemainingAsReceivable
        case receivableDueAt
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(saleId, forKey: .saleId)
        try container.encodeIfPresent(cashSessionId, forKey: .cashSessionId)
        try container.encode(MoneyAmount(amount: amount), forKey: .amount)
        try container.encode(method, forKey: .method)
        try container.encodeIfPresent(paidAt, forKey: .paidAt)
        try container.encodeIfPresent(reference, forKey: .reference)
        try container.encodeIfPresent(note, forKey: .notes)
        try container.encode(markRemainingAsReceivable, forKey: .markRemainingAsReceivable)
        try container.encodeIfPresent(receivableDueAt, forKey: .receivableDueAt)
    }
}

public struct PaymentRecord: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let saleId: String
    public let status: String
    public let method: String
    public let amount: MoneyAmount
    public let reference: String?
    public let note: String?
    public let registeredAt: Date?
    
    public init(
        id: String,
        saleId: String,
        status: String,
        method: String,
        amount: MoneyAmount,
        reference: String? = nil,
        note: String? = nil,
        registeredAt: Date? = nil
    ) {
        self.id = id
        self.saleId = saleId
        self.status = status
        self.method = method
        self.amount = amount
        self.reference = reference
        self.note = note
        self.registeredAt = registeredAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case saleId
        case status
        case method
        case amount
        case reference
        case note
        case notes
        case registeredAt
        case paidAt
        case createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        saleId = try container.decodeIfPresent(String.self, forKey: .saleId) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "registered"
        method = try container.decodeIfPresent(String.self, forKey: .method) ?? "cash"
        amount = try container.decodeIfPresent(MoneyAmount.self, forKey: .amount) ?? MoneyAmount(amount: "0.00")
        reference = try container.decodeIfPresent(String.self, forKey: .reference)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        ?? container.decodeIfPresent(String.self, forKey: .notes)
        registeredAt = try container.decodeIfPresent(Date.self, forKey: .registeredAt)
        ?? container.decodeIfPresent(Date.self, forKey: .paidAt)
        ?? container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

public struct PaymentResponse: Decodable, Equatable, Sendable {
    public let payment: PaymentRecord
    public let sale: BusinessSale?
    public let idempotencyReplayed: Bool?
    
    public init(
        payment: PaymentRecord,
        sale: BusinessSale? = nil,
        idempotencyReplayed: Bool? = nil
    ) {
        self.payment = payment
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }
    
    private enum CodingKeys: String, CodingKey {
        case payment
        case sale
        case idempotencyReplayed
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let payment = try? container.decode(PaymentRecord.self, forKey: .payment) {
            self.payment = payment
            self.sale = try container.decodeIfPresent(BusinessSale.self, forKey: .sale)
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }
        
        self.payment = try PaymentRecord(from: decoder)
        self.sale = nil
        self.idempotencyReplayed = nil
    }
}
