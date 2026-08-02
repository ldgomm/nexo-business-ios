//
//  BusinessFinanceControlModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation

struct BusinessFinanceControlScope: Codable, Equatable, Sendable {
    let organizationId: String
    let branchId: String?
    let activityId: String?

    init(
        organizationId: String,
        branchId: String? = nil,
        activityId: String? = nil
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
    }
}

struct BusinessFinanceResolvedScope: Codable, Equatable, Sendable {
    let organizationId: String
    let legalEntityId: String
    let ledgerId: String
    let periodId: String
    let periodLabel: String
    let localeIdentifier: String
    let functionalCurrencyCode: String
}

enum BusinessFinanceAccountingStatus: String, Codable, Equatable, Sendable {
    case operationalNotPosted = "OPERATIONAL_NOT_POSTED"
    case accountingPosted = "ACCOUNTING_POSTED"
    case unknown = "UNKNOWN"

    var safeDisplayTitle: String {
        switch self {
        case .operationalNotPosted:
            return "Operativo · no contabilizado"
        case .accountingPosted, .unknown:
            return "Estado no disponible"
        }
    }
}

enum BusinessFinanceAvailability: String, Codable, Equatable, Sendable {
    case available = "AVAILABLE"
    case partial = "PARTIAL"
    case blocked = "BLOCKED"
    case runtimePending = "RUNTIME_PENDING"
}

struct BusinessFinanceAmount: Codable, Equatable, Sendable {
    let decimalValue: String
    let currencyCode: String

    init(decimalValue: String, currencyCode: String) {
        self.decimalValue = decimalValue
        self.currencyCode = currencyCode
    }
}

struct BusinessFinanceConfigurationSummary: Codable, Equatable, Sendable {
    let organizationName: String
    let legalEntityName: String
    let ledgerName: String
    let periodStatus: String
    let policyVersion: String
}

enum BusinessFinanceMovementDirection: String, Codable, Equatable, Sendable {
    case inflow = "INFLOW"
    case outflow = "OUTFLOW"
    case transfer = "TRANSFER"
}

struct BusinessFinanceMovementSummary: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let businessDate: String
    let title: String
    let subtitle: String?
    let direction: BusinessFinanceMovementDirection
    let amount: BusinessFinanceAmount
    let lifecycleStatus: String
    let evidenceCount: Int
    let sourceFactId: String?
}

enum BusinessFinanceOpenItemSide: String, Codable, Equatable, Sendable {
    case receivable = "RECEIVABLE"
    case payable = "PAYABLE"
}

struct BusinessFinanceOpenItemSummary: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let side: BusinessFinanceOpenItemSide
    let partyDisplayName: String
    let dueDate: String?
    let outstandingAmount: BusinessFinanceAmount
    let status: String
    let evidenceCount: Int
}

enum BusinessFinanceAccountKind: String, Codable, Equatable, Sendable {
    case cash = "CASH"
    case bank = "BANK"
}

struct BusinessFinanceCashBankSummary: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let kind: BusinessFinanceAccountKind
    let balance: BusinessFinanceAmount
    let asOf: String
    let maskedExternalReference: String?
    let reconciliationStatus: String
}

struct BusinessFinanceHistoricalImportSummary: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let fileDisplayName: String
    let status: String
    let acceptedRows: Int
    let rejectedRows: Int
    let checksumPrefix: String
}

struct BusinessFinanceReconciliationSummary: Codable, Equatable, Sendable {
    let status: String
    let matchedCount: Int
    let unmatchedCount: Int
    let duplicateCount: Int
    let exactDifference: BusinessFinanceAmount
}

struct BusinessFinanceCoverageSummary: Codable, Equatable, Sendable {
    let status: String
    let cutoverDate: String?
    let requiredRubrics: Int
    let reconciledRubrics: Int
    let unresolvedCount: Int
    let readinessDecision: String
}

struct BusinessFinanceUnresolvedItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let severity: String
    let evidenceIds: [String]
}

struct BusinessFinanceControlCapabilities: Codable, Equatable, Sendable {
    let canUploadHistoricalImport: Bool
    let canPreviewHistoricalImport: Bool
    let canReviewReconciliation: Bool

    init(
        canUploadHistoricalImport: Bool = false,
        canPreviewHistoricalImport: Bool = false,
        canReviewReconciliation: Bool = false
    ) {
        self.canUploadHistoricalImport = canUploadHistoricalImport
        self.canPreviewHistoricalImport = canPreviewHistoricalImport
        self.canReviewReconciliation = canReviewReconciliation
    }
}

struct BusinessFinanceControlSnapshot: Codable, Equatable, Sendable {
    let scope: BusinessFinanceResolvedScope
    let availability: BusinessFinanceAvailability
    let accountingStatus: BusinessFinanceAccountingStatus
    let authoritativeAccounting: Bool
    let configuration: BusinessFinanceConfigurationSummary
    let movements: [BusinessFinanceMovementSummary]
    let openItems: [BusinessFinanceOpenItemSummary]
    let cashAndBank: [BusinessFinanceCashBankSummary]
    let historicalImports: [BusinessFinanceHistoricalImportSummary]
    let reconciliation: BusinessFinanceReconciliationSummary
    let coverage: BusinessFinanceCoverageSummary
    let unresolvedItems: [BusinessFinanceUnresolvedItem]
    let capabilities: BusinessFinanceControlCapabilities
    let generatedAt: String
    let sourceRevision: String
}

enum BusinessFinanceControlSurface: String, CaseIterable, Equatable, Hashable, Sendable {
    case configuration
    case movements
    case receivablesAndPayables
    case cashAndBank
    case historicalImport
    case reconciliation
    case coverageAndCutover
    case unresolvedItems
}
