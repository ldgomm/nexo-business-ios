//
//  PaymentModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessPaymentMethod: String, CaseIterable, Identifiable, Sendable, Hashable, Codable {
    case cash = "CASH"
    case transfer = "BANK_TRANSFER"
    case card = "CARD_MANUAL"
    case other = "OTHER"

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = BusinessPaymentMethod.resolve(value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func resolve(_ value: String) -> BusinessPaymentMethod {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "CASH", "EFECTIVO":
            return .cash
        case "TRANSFER", "TRANSFERENCIA", "BANK_TRANSFER":
            return .transfer
        case "CARD", "CARD_MANUAL", "CARD_GATEWAY", "TARJETA":
            return .card
        default:
            return .other
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
        method = try container.decodeIfPresent(String.self, forKey: .method) ?? BusinessPaymentMethod.cash.rawValue
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
    public let saleId: String?
    public let salePaymentStatus: String?
    public let salePaidAmount: MoneyAmount?
    public let cashSession: CashSession?
    public let cashMovement: CashMovement?
    public let receivable: ReceivableRecord?
    public let idempotencyReplayed: Bool?

    public init(
        payment: PaymentRecord,
        sale: BusinessSale? = nil,
        saleId: String? = nil,
        salePaymentStatus: String? = nil,
        salePaidAmount: MoneyAmount? = nil,
        cashSession: CashSession? = nil,
        cashMovement: CashMovement? = nil,
        receivable: ReceivableRecord? = nil,
        idempotencyReplayed: Bool? = nil
    ) {
        self.payment = payment
        self.sale = sale
        self.saleId = saleId
        self.salePaymentStatus = salePaymentStatus
        self.salePaidAmount = salePaidAmount
        self.cashSession = cashSession
        self.cashMovement = cashMovement
        self.receivable = receivable
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case payment
        case sale
        case saleId
        case salePaymentStatus
        case salePaidAmount
        case cashSession
        case cashMovement
        case receivable
        case idempotencyReplayed
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let payment = try? container.decode(PaymentRecord.self, forKey: .payment) {
            self.payment = payment
            self.sale = try container.decodeIfPresent(BusinessSale.self, forKey: .sale)
            self.saleId = try container.decodeIfPresent(String.self, forKey: .saleId)
            self.salePaymentStatus = try container.decodeIfPresent(String.self, forKey: .salePaymentStatus)
            self.salePaidAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .salePaidAmount)
            self.cashSession = try container.decodeIfPresent(CashSession.self, forKey: .cashSession)
            self.cashMovement = try container.decodeIfPresent(CashMovement.self, forKey: .cashMovement)
            self.receivable = try container.decodeIfPresent(ReceivableRecord.self, forKey: .receivable)
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.payment = try PaymentRecord(from: decoder)
        self.sale = nil
        self.saleId = nil
        self.salePaymentStatus = nil
        self.salePaidAmount = nil
        self.cashSession = nil
        self.cashMovement = nil
        self.receivable = nil
        self.idempotencyReplayed = nil
    }
}
