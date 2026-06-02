//
//  PaymentModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessPaymentMethod: String, CaseIterable, Identifiable, Sendable, Hashable, Codable {
    case cash = "CASH"
    case transfer = "BANK_TRANSFER"
    case card = "CARD_MANUAL"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
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

    var requiresReference: Bool {
        switch self {
        case .cash:
            return false
        case .transfer, .card, .other:
            return true
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = BusinessPaymentMethod.resolve(value)
    }

    func encode(to encoder: Encoder) throws {
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

struct RegisterPaymentRequest: Encodable, Equatable, Sendable {
    let saleId: String
    let cashSessionId: String?
    let method: String
    let amount: String
    let reference: String?
    let note: String?
    let paidAt: Date?
    let markRemainingAsReceivable: Bool
    let receivableDueAt: Date?
    let requestId: String?

    init(
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

    func encode(to encoder: Encoder) throws {
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

struct PaymentRecord: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let saleId: String
    let status: String
    let method: String
    let amount: MoneyAmount
    let reference: String?
    let note: String?
    let registeredAt: Date?

    init(
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

    init(from decoder: Decoder) throws {
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

struct PaymentResponse: Decodable, Equatable, Sendable {
    let payment: PaymentRecord
    let sale: BusinessSale?
    let saleId: String?
    let salePaymentStatus: String?
    let salePaidAmount: MoneyAmount?
    let cashSession: CashSession?
    let cashMovement: CashMovement?
    let receivable: ReceivableRecord?
    let idempotencyReplayed: Bool?

    init(
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

    init(from decoder: Decoder) throws {
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
