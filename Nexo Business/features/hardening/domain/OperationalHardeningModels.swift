//
//  OperationalHardeningModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum OperationalHardeningCheckStatus: String, Codable, Equatable, Sendable {
    case passed
    case warning
    case failed

    var displayName: String {
        switch self {
        case .passed:
            return "OK"
        case .warning:
            return "Revisar"
        case .failed:
            return "Bloqueante"
        }
    }

    var sortOrder: Int {
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

struct OperationalHardeningCheck: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let status: OperationalHardeningCheckStatus
    let isBlocking: Bool

    init(
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

struct OperationalHardeningReport: Equatable, Sendable {
    let checkedAt: Date
    let checks: [OperationalHardeningCheck]

    init(
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

    var blockers: [OperationalHardeningCheck] {
        checks.filter { $0.isBlocking && $0.status == .failed }
    }

    var warnings: [OperationalHardeningCheck] {
        checks.filter { $0.status == .warning }
    }

    var passed: [OperationalHardeningCheck] {
        checks.filter { $0.status == .passed }
    }

    var isReadyForPilot: Bool {
        blockers.isEmpty
    }
}
