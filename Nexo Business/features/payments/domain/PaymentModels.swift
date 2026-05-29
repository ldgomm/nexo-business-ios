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

    public init(
        saleId: String,
        cashSessionId: String? = nil,
        method: String,
        amount: String,
        reference: String? = nil,
        note: String? = nil
    ) {
        self.saleId = saleId
        self.cashSessionId = cashSessionId
        self.method = method
        self.amount = amount
        self.reference = reference
        self.note = note
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
}

public struct PaymentResponse: Decodable, Equatable, Sendable {
    public let payment: PaymentRecord
    public let sale: BusinessSale?
    public let idempotencyReplayed: Bool?

    public init(
        payment: PaymentRecord,
        sale: BusinessSale? = nil,
        idempotencyReplayed: Bool?
    ) {
        self.payment = payment
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }
}

public enum PaymentStatusPresentation {
    public static func displayName(_ status: String?) -> String {
        switch status {
        case "unpaid":
            return "Pendiente"
        case "partially_paid":
            return "Pago parcial"
        case "paid":
            return "Pagado"
        case "overpaid":
            return "Sobrepagado"
        case "refunded":
            return "Devuelto"
        case "voided":
            return "Anulado"
        case let value?:
            return value
        case nil:
            return "Sin estado"
        }
    }

    public static func canCollect(status: String?) -> Bool {
        switch status {
        case "paid", "overpaid", "refunded", "voided":
            return false
        default:
            return true
        }
    }
}
