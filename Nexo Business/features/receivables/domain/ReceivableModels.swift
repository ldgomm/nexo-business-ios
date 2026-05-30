//
//  ReceivableModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct CreateReceivableRequest: Encodable, Equatable, Sendable {
    public let saleId: String
    public let customerId: String?
    public let amount: String?
    public let dueDate: Date?
    public let note: String?
    public let reason: String
    public let requestId: String?
    
    public init(
        saleId: String,
        customerId: String,
        amount: String,
        dueDate: Date? = nil,
        note: String? = nil
    ) {
        self.init(
            saleId: saleId,
            customerId: customerId,
            amount: amount,
            dueAt: dueDate,
            reason: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            ?? "Cuenta por cobrar",
            note: note
        )
    }
    
    public init(
        saleId: String,
        dueAt: Date? = nil,
        reason: String,
        requestId: String? = nil
    ) {
        self.init(
            saleId: saleId,
            customerId: nil,
            amount: nil,
            dueAt: dueAt,
            reason: reason,
            note: nil,
            requestId: requestId
        )
    }
    
    private init(
        saleId: String,
        customerId: String?,
        amount: String?,
        dueAt: Date?,
        reason: String,
        note: String?,
        requestId: String? = nil
    ) {
        self.saleId = saleId
        self.customerId = customerId
        self.amount = amount
        self.dueDate = dueAt
        self.reason = reason
        self.note = note
        self.requestId = requestId
    }
    
    private enum CodingKeys: String, CodingKey {
        case requestId
        case saleId
        case dueAt
        case reason
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(saleId, forKey: .saleId)
        try container.encodeIfPresent(dueDate, forKey: .dueAt)
        try container.encode(reason, forKey: .reason)
    }
}

public struct CollectReceivableRequest: Encodable, Equatable, Sendable {
    public let receivableId: String
    public let saleId: String?
    public let cashSessionId: String?
    public let method: String
    public let amount: String
    public let reference: String?
    public let note: String?
    public let collectedAt: Date?
    public let requestId: String?
    
    public init(
        receivableId: String,
        cashSessionId: String? = nil,
        method: String,
        amount: String,
        reference: String? = nil,
        note: String? = nil
    ) {
        self.init(
            receivableId: receivableId,
            saleId: nil,
            cashSessionId: cashSessionId,
            method: method,
            amount: amount,
            reference: reference,
            note: note,
            collectedAt: nil,
            requestId: nil
        )
    }
    
    public init(
        receivableId: String,
        saleId: String? = nil,
        cashSessionId: String? = nil,
        method: String,
        amount: String,
        reference: String? = nil,
        note: String? = nil,
        collectedAt: Date? = nil,
        requestId: String? = nil
    ) {
        self.receivableId = receivableId
        self.saleId = saleId
        self.cashSessionId = cashSessionId
        self.method = method
        self.amount = amount
        self.reference = reference
        self.note = note
        self.collectedAt = collectedAt
        self.requestId = requestId
    }
    
    private enum CodingKeys: String, CodingKey {
        case requestId
        case receivableId
        case saleId
        case cashSessionId
        case amount
        case method
        case collectedAt
        case reference
        case notes
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(receivableId, forKey: .receivableId)
        try container.encodeIfPresent(saleId, forKey: .saleId)
        try container.encodeIfPresent(cashSessionId, forKey: .cashSessionId)
        try container.encode(MoneyAmount(amount: amount), forKey: .amount)
        try container.encode(method, forKey: .method)
        try container.encodeIfPresent(collectedAt, forKey: .collectedAt)
        try container.encodeIfPresent(reference, forKey: .reference)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

public struct ReceivableRecord: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let saleId: String
    public let customerId: String?
    public let customerName: String?
    public let branchId: String?
    public let status: String
    public let amount: MoneyAmount
    public let balance: MoneyAmount?
    public let originalAmount: MoneyAmount?
    public let paidAmount: MoneyAmount?
    public let remainingAmount: MoneyAmount?
    public let dueDate: Date?
    public let createdAt: Date?
    
    public init(
        id: String,
        saleId: String,
        customerId: String? = nil,
        customerName: String? = nil,
        branchId: String? = nil,
        status: String,
        amount: MoneyAmount,
        balance: MoneyAmount? = nil,
        originalAmount: MoneyAmount? = nil,
        paidAmount: MoneyAmount? = nil,
        remainingAmount: MoneyAmount? = nil,
        dueDate: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.saleId = saleId
        self.customerId = customerId
        self.customerName = customerName
        self.branchId = branchId
        self.status = status
        self.amount = amount
        self.balance = balance
        self.originalAmount = originalAmount
        self.paidAmount = paidAmount
        self.remainingAmount = remainingAmount
        self.dueDate = dueDate
        self.createdAt = createdAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case saleId
        case customerId
        case customerName
        case branchId
        case status
        case amount
        case balance
        case originalAmount
        case paidAmount
        case remainingAmount
        case dueDate
        case dueAt
        case createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        saleId = try container.decodeIfPresent(String.self, forKey: .saleId) ?? ""
        customerId = try container.decodeIfPresent(String.self, forKey: .customerId)
        customerName = try container.decodeIfPresent(String.self, forKey: .customerName)
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "open"
        originalAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .originalAmount)
        paidAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .paidAmount)
        remainingAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .remainingAmount)
        amount = try container.decodeIfPresent(MoneyAmount.self, forKey: .amount)
        ?? originalAmount
        ?? remainingAmount
        ?? MoneyAmount(amount: "0.00")
        balance = try container.decodeIfPresent(MoneyAmount.self, forKey: .balance)
        ?? remainingAmount
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        ?? container.decodeIfPresent(Date.self, forKey: .dueAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

public struct ReceivableResponse: Decodable, Equatable, Sendable {
    public let receivable: ReceivableRecord
    public let idempotencyReplayed: Bool?
    
    public init(receivable: ReceivableRecord, idempotencyReplayed: Bool? = nil) {
        self.receivable = receivable
        self.idempotencyReplayed = idempotencyReplayed
    }
    
    private enum CodingKeys: String, CodingKey {
        case receivable
        case idempotencyReplayed
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let receivable = try? container.decode(ReceivableRecord.self, forKey: .receivable) {
            self.receivable = receivable
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }
        
        self.receivable = try ReceivableRecord(from: decoder)
        self.idempotencyReplayed = nil
    }
}

public struct ReceivableCollectionResponse: Decodable, Equatable, Sendable {
    public let receivable: ReceivableRecord
    public let payment: PaymentRecord?
    public let idempotencyReplayed: Bool?
    
    public init(
        receivable: ReceivableRecord,
        payment: PaymentRecord? = nil,
        idempotencyReplayed: Bool? = nil
    ) {
        self.receivable = receivable
        self.payment = payment
        self.idempotencyReplayed = idempotencyReplayed
    }
    
    private enum CodingKeys: String, CodingKey {
        case receivable
        case payment
        case idempotencyReplayed
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let receivable = try? container.decode(ReceivableRecord.self, forKey: .receivable) {
            self.receivable = receivable
            self.payment = try container.decodeIfPresent(PaymentRecord.self, forKey: .payment)
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }
        
        self.receivable = try ReceivableRecord(from: decoder)
        self.payment = nil
        self.idempotencyReplayed = nil
    }
}

public struct ReceivablesListResponse: Decodable, Equatable, Sendable {
    public let receivables: [ReceivableRecord]
    public let total: Int?
    public let hasMore: Bool?
    public let nextCursor: String?
    
    public init(
        receivables: [ReceivableRecord],
        total: Int? = nil,
        hasMore: Bool? = nil,
        nextCursor: String? = nil
    ) {
        self.receivables = receivables
        self.total = total
        self.hasMore = hasMore
        self.nextCursor = nextCursor
    }
}


private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
