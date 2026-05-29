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
}

public struct OpenCashSessionRequest: Encodable, Equatable, Sendable {
    public let branchId: String
    public let openingAmount: String
    public let note: String?

    public init(
        branchId: String,
        openingAmount: String,
        note: String? = nil
    ) {
        self.branchId = branchId
        self.openingAmount = openingAmount
        self.note = note
    }
}

public struct CloseCashSessionRequest: Encodable, Equatable, Sendable {
    public let countedAmount: String
    public let note: String?

    public init(
        countedAmount: String,
        note: String? = nil
    ) {
        self.countedAmount = countedAmount
        self.note = note
    }
}

public struct RegisterCashMovementRequest: Encodable, Equatable, Sendable {
    public let type: CashMovementType
    public let amount: String
    public let note: String?

    public init(
        type: CashMovementType,
        amount: String,
        note: String? = nil
    ) {
        self.type = type
        self.amount = amount
        self.note = note
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
}

public struct CashCurrentSessionResponse: Decodable, Equatable, Sendable {
    public let session: CashSession?

    public init(session: CashSession?) {
        self.session = session
    }
}

public struct CashSessionResponse: Decodable, Equatable, Sendable {
    public let session: CashSession
    public let idempotencyReplayed: Bool?

    public init(
        session: CashSession,
        idempotencyReplayed: Bool?
    ) {
        self.session = session
        self.idempotencyReplayed = idempotencyReplayed
    }
}

public struct CashMovementResponse: Decodable, Equatable, Sendable {
    public let movement: CashMovement
    public let session: CashSession?
    public let idempotencyReplayed: Bool?

    public init(
        movement: CashMovement,
        session: CashSession? = nil,
        idempotencyReplayed: Bool?
    ) {
        self.movement = movement
        self.session = session
        self.idempotencyReplayed = idempotencyReplayed
    }
}
