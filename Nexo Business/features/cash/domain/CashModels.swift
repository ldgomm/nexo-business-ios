//
//  CashModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum CashMovementType: String, Codable, CaseIterable, Identifiable, Sendable {
    case inflow
    case outflow
    case adjustment

    public var id: String { rawValue }

    public var displayName: String {
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

public struct OpenCashSessionRequest: Encodable, Equatable, Sendable {
    public let branchId: String
    public let openingAmount: String
    public let note: String?
    public let openedAt: Date?
    public let requestId: String?

    public init(
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(branchId, forKey: .branchId)
        try container.encode(MoneyAmount(amount: openingAmount), forKey: .openingBalance)
        try container.encodeIfPresent(openedAt, forKey: .openedAt)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

public struct CloseCashSessionRequest: Encodable, Equatable, Sendable {
    public let countedAmount: String
    public let note: String?
    public let reason: String
    public let closedAt: Date?
    public let requestId: String?

    public init(
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encode(MoneyAmount(amount: countedAmount), forKey: .countedCashAmount)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(closedAt, forKey: .closedAt)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

public struct RegisterCashMovementRequest: Encodable, Equatable, Sendable {
    public let type: CashMovementType
    public let amount: String
    public let note: String?
    public let occurredAt: Date?
    public let referenceId: String?
    public let requestId: String?

    public init(
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

    public func encode(to encoder: Encoder) throws {
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

public struct CashSession: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let branchId: String
    public let status: String
    public let openedAt: Date?
    public let closedAt: Date?
    public let openingAmount: MoneyAmount?
    public let countedAmount: MoneyAmount?
    public let expectedAmount: MoneyAmount?
    public let differenceAmount: MoneyAmount?

    public init(
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

    public init(from decoder: Decoder) throws {
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

public struct CashMovement: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let cashSessionId: String
    public let type: CashMovementType
    public let amount: MoneyAmount
    public let note: String?
    public let status: String?
    public let createdAt: Date?

    public init(
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

    public init(from decoder: Decoder) throws {
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

public struct CashCurrentSessionResponse: Decodable, Equatable, Sendable {
    public let session: CashSession?

    public init(session: CashSession?) {
        self.session = session
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case cashSession
        case id
    }

    public init(from decoder: Decoder) throws {
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

public struct CashSessionResponse: Decodable, Equatable, Sendable {
    public let session: CashSession
    public let idempotencyReplayed: Bool?

    public init(
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

    public init(from decoder: Decoder) throws {
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

public struct CashMovementResponse: Decodable, Equatable, Sendable {
    public let movement: CashMovement
    public let session: CashSession?
    public let idempotencyReplayed: Bool?

    public init(
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

    public init(from decoder: Decoder) throws {
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
