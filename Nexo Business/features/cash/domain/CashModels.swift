//
//  CashModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum CashMovementType: String, Codable, CaseIterable, Identifiable, Sendable {
    case inflow
    case outflow
    case adjustment

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inflow:
            return "Ingreso"
        case .outflow:
            return "Egreso"
        case .adjustment:
            return "Ajuste"
        }
    }

    var backendType: String {
        switch self {
        case .inflow, .outflow:
            return "manual"
        case .adjustment:
            return "adjustment"
        }
    }

    var backendDirection: String {
        rawValue
    }
}

struct OpenCashSessionRequest: Encodable, Equatable, Sendable {
    let branchId: String
    let openingAmount: String
    let note: String?
    let openedAt: Date?
    let requestId: String?

    init(
        branchId: String,
        openingAmount: String,
        note: String? = nil,
        openedAt: Date? = nil,
        requestId: String? = nil
    ) {
        self.branchId = branchId
        self.openingAmount = openingAmount
        self.note = note
        self.openedAt = openedAt
        self.requestId = requestId
    }

    private enum CodingKeys: String, CodingKey {
        case requestId
        case branchId
        case openingBalance
        case openedAt
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(branchId, forKey: .branchId)
        try container.encode(MoneyAmount(amount: openingAmount), forKey: .openingBalance)
        try container.encodeIfPresent(openedAt, forKey: .openedAt)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

struct CloseCashSessionRequest: Encodable, Equatable, Sendable {
    let countedAmount: String
    let note: String?
    let reason: String
    let closedAt: Date?
    let requestId: String?

    init(
        countedAmount: String,
        note: String? = nil,
        reason: String? = nil,
        closedAt: Date? = nil,
        requestId: String? = nil
    ) {
        self.countedAmount = countedAmount
        self.note = note
        self.reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            ?? note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            ?? "Cierre diario"
        self.closedAt = closedAt
        self.requestId = requestId
    }

    private enum CodingKeys: String, CodingKey {
        case requestId
        case countedCashAmount
        case reason
        case closedAt
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(MoneyAmount(amount: countedAmount), forKey: .countedCashAmount)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(closedAt, forKey: .closedAt)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

struct RegisterCashMovementRequest: Encodable, Equatable, Sendable {
    let type: CashMovementType
    let amount: String
    let note: String?
    let occurredAt: Date?
    let referenceId: String?
    let requestId: String?

    init(
        type: CashMovementType,
        amount: String,
        note: String? = nil,
        occurredAt: Date? = nil,
        referenceId: String? = nil,
        requestId: String? = nil
    ) {
        self.type = type
        self.amount = amount
        self.note = note
        self.occurredAt = occurredAt
        self.referenceId = referenceId
        self.requestId = requestId
    }

    private enum CodingKeys: String, CodingKey {
        case requestId
        case type
        case direction
        case amount
        case occurredAt
        case referenceId
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(type.backendType, forKey: .type)
        try container.encode(type.backendDirection, forKey: .direction)
        try container.encode(MoneyAmount(amount: amount), forKey: .amount)
        try container.encodeIfPresent(occurredAt, forKey: .occurredAt)
        try container.encodeIfPresent(referenceId, forKey: .referenceId)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

struct CashSession: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String
    let status: String
    let openedAt: Date?
    let closedAt: Date?
    let openingAmount: MoneyAmount?
    let countedAmount: MoneyAmount?
    let expectedAmount: MoneyAmount?
    let differenceAmount: MoneyAmount?

    init(
        id: String,
        branchId: String,
        status: String,
        openedAt: Date?,
        closedAt: Date?,
        openingAmount: MoneyAmount?,
        countedAmount: MoneyAmount?,
        expectedAmount: MoneyAmount? = nil,
        differenceAmount: MoneyAmount? = nil
    ) {
        self.id = id
        self.branchId = branchId
        self.status = status
        self.openedAt = openedAt
        self.closedAt = closedAt
        self.openingAmount = openingAmount
        self.countedAmount = countedAmount
        self.expectedAmount = expectedAmount
        self.differenceAmount = differenceAmount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case branchId
        case status
        case openedAt
        case closedAt
        case openingAmount
        case openingBalance
        case countedAmount
        case countedCashAmount
        case expectedAmount
        case expectedCashAmount
        case differenceAmount
        case cashDifferenceAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "open"
        openedAt = try container.decodeIfPresent(Date.self, forKey: .openedAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        openingAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .openingAmount)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .openingBalance)
        countedAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .countedAmount)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .countedCashAmount)
        expectedAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .expectedAmount)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .expectedCashAmount)
        differenceAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .differenceAmount)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .cashDifferenceAmount)
    }
}

struct CashMovement: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let cashSessionId: String
    let type: CashMovementType
    let amount: MoneyAmount
    let note: String?
    let status: String?
    let createdAt: Date?

    init(
        id: String,
        cashSessionId: String,
        type: CashMovementType,
        amount: MoneyAmount,
        note: String?,
        status: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.cashSessionId = cashSessionId
        self.type = type
        self.amount = amount
        self.note = note
        self.status = status
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case cashSessionId
        case type
        case direction
        case amount
        case note
        case notes
        case status
        case createdAt
        case occurredAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        cashSessionId = try container.decodeIfPresent(String.self, forKey: .cashSessionId) ?? ""
        let rawDirection = try container.decodeIfPresent(String.self, forKey: .direction)
        let rawType = try container.decodeIfPresent(String.self, forKey: .type)
        type = CashMovementType(rawValue: rawDirection ?? rawType ?? "") ?? .adjustment
        amount = try container.decode(MoneyAmount.self, forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
            ?? container.decodeIfPresent(String.self, forKey: .notes)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
            ?? container.decodeIfPresent(Date.self, forKey: .occurredAt)
    }
}

struct CashCurrentSessionResponse: Decodable, Equatable, Sendable {
    let session: CashSession?

    init(session: CashSession?) {
        self.session = session
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case cashSession
        case id
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let session = try? container.decodeIfPresent(CashSession.self, forKey: .session) {
                self.session = session
                return
            }

            if let session = try? container.decodeIfPresent(CashSession.self, forKey: .cashSession) {
                self.session = session
                return
            }

            if container.contains(.id) {
                self.session = try CashSession(from: decoder)
                return
            }
        }

        self.session = nil
    }
}

struct CashSessionResponse: Decodable, Equatable, Sendable {
    let session: CashSession
    let idempotencyReplayed: Bool?

    init(
        session: CashSession,
        idempotencyReplayed: Bool? = nil
    ) {
        self.session = session
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case cashSession
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)

            if let session = try? container.decode(CashSession.self, forKey: .session) {
                self.session = session
                return
            }

            if let session = try? container.decode(CashSession.self, forKey: .cashSession) {
                self.session = session
                return
            }
        } else {
            idempotencyReplayed = nil
        }

        self.session = try CashSession(from: decoder)
    }
}

struct CashMovementResponse: Decodable, Equatable, Sendable {
    let movement: CashMovement
    let session: CashSession?
    let idempotencyReplayed: Bool?

    init(
        movement: CashMovement,
        session: CashSession? = nil,
        idempotencyReplayed: Bool? = nil
    ) {
        self.movement = movement
        self.session = session
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case movement
        case cashMovement
        case session
        case cashSession
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            session = try container.decodeIfPresent(CashSession.self, forKey: .session)
                ?? container.decodeIfPresent(CashSession.self, forKey: .cashSession)

            if let movement = try? container.decode(CashMovement.self, forKey: .movement) {
                self.movement = movement
                return
            }

            if let movement = try? container.decode(CashMovement.self, forKey: .cashMovement) {
                self.movement = movement
                return
            }
        } else {
            idempotencyReplayed = nil
            session = nil
        }

        self.movement = try CashMovement(from: decoder)
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
