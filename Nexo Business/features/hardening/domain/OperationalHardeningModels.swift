//
//  OperationalHardeningModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum OperationalHardeningCheckStatus: String, Codable, Equatable, Sendable {
    case passed
    case warning
    case failed

    public var displayName: String {
        switch self {
        case .passed:
            return "OK"
        case .warning:
            return "Revisar"
        case .failed:
            return "Bloqueante"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .failed:
            return 0
        case .warning:
            return 1
        case .passed:
            return 2
        }
    }
}

public struct OperationalHardeningCheck: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let status: OperationalHardeningCheckStatus
    public let isBlocking: Bool

    public init(
        id: String,
        title: String,
        detail: String,
        status: OperationalHardeningCheckStatus,
        isBlocking: Bool
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.isBlocking = isBlocking
    }
}

public struct OperationalHardeningReport: Equatable, Sendable {
    public let checkedAt: Date
    public let checks: [OperationalHardeningCheck]

    public init(
        checkedAt: Date = Date(),
        checks: [OperationalHardeningCheck]
    ) {
        self.checkedAt = checkedAt
        self.checks = checks.sorted { lhs, rhs in
            if lhs.status.sortOrder == rhs.status.sortOrder {
                return lhs.title < rhs.title
            }
            return lhs.status.sortOrder < rhs.status.sortOrder
        }
    }

    public var blockers: [OperationalHardeningCheck] {
        checks.filter { $0.isBlocking && $0.status == .failed }
    }

    public var warnings: [OperationalHardeningCheck] {
        checks.filter { $0.status == .warning }
    }

    public var passed: [OperationalHardeningCheck] {
        checks.filter { $0.status == .passed }
    }

    public var isReadyForPilot: Bool {
        blockers.isEmpty
    }
}
