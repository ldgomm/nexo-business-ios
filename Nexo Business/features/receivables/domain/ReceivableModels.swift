//
//  ReceivableModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct CreateReceivableRequest: Encodable, Equatable, Sendable {
    let saleId: String
    let customerId: String?
    let amount: String?
    let dueDate: Date?
    let note: String?
    let reason: String
    let requestId: String?
    
    init(
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
    
    init(
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(saleId, forKey: .saleId)
        try container.encodeIfPresent(dueDate, forKey: .dueAt)
        try container.encode(reason, forKey: .reason)
    }
}

struct CollectReceivableRequest: Encodable, Equatable, Sendable {
    let receivableId: String
    let saleId: String?
    let cashSessionId: String?
    let method: String
    let amount: String
    let reference: String?
    let note: String?
    let collectedAt: Date?
    let requestId: String?
    
    init(
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
    
    init(
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
    
    func encode(to encoder: Encoder) throws {
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

struct ReceivableRecord: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let saleId: String
    let customerId: String?
    let customerName: String?
    let branchId: String?
    let status: String
    let amount: MoneyAmount
    let balance: MoneyAmount?
    let originalAmount: MoneyAmount?
    let paidAmount: MoneyAmount?
    let remainingAmount: MoneyAmount?
    let dueDate: Date?
    let createdAt: Date?
    
    init(
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
    
    init(from decoder: Decoder) throws {
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

struct ReceivableResponse: Decodable, Equatable, Sendable {
    let receivable: ReceivableRecord
    let idempotencyReplayed: Bool?
    
    init(receivable: ReceivableRecord, idempotencyReplayed: Bool? = nil) {
        self.receivable = receivable
        self.idempotencyReplayed = idempotencyReplayed
    }
    
    private enum CodingKeys: String, CodingKey {
        case receivable
        case idempotencyReplayed
    }
    
    init(from decoder: Decoder) throws {
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

struct ReceivableCollectionResponse: Decodable, Equatable, Sendable {
    let receivable: ReceivableRecord
    let payment: PaymentRecord?
    let idempotencyReplayed: Bool?
    
    init(
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
    
    init(from decoder: Decoder) throws {
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

struct ReceivablesListResponse: Decodable, Equatable, Sendable {
    let receivables: [ReceivableRecord]
    let total: Int?
    let hasMore: Bool?
    let nextCursor: String?
    
    init(
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

    private enum CodingKeys: String, CodingKey {
        case receivables
        case items
        case results
        case data
        case total
        case hasMore
        case nextCursor
    }

    init(from decoder: Decoder) throws {
        if let array = try? [ReceivableRecord](from: decoder) {
            self.receivables = array
            self.total = array.count
            self.hasMore = false
            self.nextCursor = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.receivables = try container.decodeIfPresent([ReceivableRecord].self, forKey: .receivables)
        ?? container.decodeIfPresent([ReceivableRecord].self, forKey: .items)
        ?? container.decodeIfPresent([ReceivableRecord].self, forKey: .results)
        ?? container.decodeIfPresent([ReceivableRecord].self, forKey: .data)
        ?? []
        self.total = try container.decodeIfPresent(Int.self, forKey: .total)
        self.hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
        self.nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

extension ReceivableRecord {
    var effectiveBalance: MoneyAmount {
        balance ?? remainingAmount ?? amount
    }

    var displayCustomerName: String {
        if let customerName = customerName?.trimmingCharacters(in: .whitespacesAndNewlines), !customerName.isEmpty {
            return customerName
        }

        if let customerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            return "Cliente identificado"
        }

        return "Sin cliente identificado"
    }

    var isMissingCustomer: Bool {
        customerId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
    }

    var isSettled: Bool {
        let normalizedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["paid", "collected", "closed", "settled"].contains(normalizedStatus) {
            return true
        }

        guard let value = Decimal(
            string: effectiveBalance.amount.replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return false
        }

        return value <= Decimal.zero
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
