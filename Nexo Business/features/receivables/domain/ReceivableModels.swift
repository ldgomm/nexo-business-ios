//
//  ReceivableModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct CreateReceivableRequest: Encodable, Equatable, Sendable {
    public let saleId: String
    public let customerId: String
    public let amount: String
    public let dueDate: Date?
    public let note: String?

    public init(
        saleId: String,
        customerId: String,
        amount: String,
        dueDate: Date? = nil,
        note: String? = nil
    ) {
        self.saleId = saleId
        self.customerId = customerId
        self.amount = amount
        self.dueDate = dueDate
        self.note = note
    }
}

public struct CollectReceivableRequest: Encodable, Equatable, Sendable {
    public let receivableId: String
    public let cashSessionId: String?
    public let method: String
    public let amount: String
    public let reference: String?
    public let note: String?

    public init(
        receivableId: String,
        cashSessionId: String? = nil,
        method: String,
        amount: String,
        reference: String? = nil,
        note: String? = nil
    ) {
        self.receivableId = receivableId
        self.cashSessionId = cashSessionId
        self.method = method
        self.amount = amount
        self.reference = reference
        self.note = note
    }
}

public struct ReceivableRecord: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let saleId: String
    public let customerId: String?
    public let status: String
    public let amount: MoneyAmount
    public let balance: MoneyAmount?
    public let dueDate: Date?
    public let createdAt: Date?

    public init(
        id: String,
        saleId: String,
        customerId: String? = nil,
        status: String,
        amount: MoneyAmount,
        balance: MoneyAmount? = nil,
        dueDate: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.saleId = saleId
        self.customerId = customerId
        self.status = status
        self.amount = amount
        self.balance = balance
        self.dueDate = dueDate
        self.createdAt = createdAt
    }
}

public struct ReceivableResponse: Decodable, Equatable, Sendable {
    public let receivable: ReceivableRecord
    public let sale: BusinessSale?
    public let idempotencyReplayed: Bool?

    public init(
        receivable: ReceivableRecord,
        sale: BusinessSale? = nil,
        idempotencyReplayed: Bool?
    ) {
        self.receivable = receivable
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }
}

public struct ReceivableCollectionResponse: Decodable, Equatable, Sendable {
    public let receivable: ReceivableRecord
    public let payment: PaymentRecord?
    public let sale: BusinessSale?
    public let idempotencyReplayed: Bool?

    public init(
        receivable: ReceivableRecord,
        payment: PaymentRecord? = nil,
        sale: BusinessSale? = nil,
        idempotencyReplayed: Bool?
    ) {
        self.receivable = receivable
        self.payment = payment
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }
}

public enum ReceivableStatusPresentation {
    public static func displayName(_ status: String) -> String {
        switch status {
        case "pending":
            return "Pendiente"
        case "partially_collected":
            return "Abonado"
        case "collected":
            return "Cobrado"
        case "overdue":
            return "Vencido"
        case "uncollectible":
            return "Incobrable"
        case "canceled":
            return "Cancelado"
        default:
            return status
        }
    }
}
