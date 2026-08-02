//
//  BusinessFinanceControlAccessPolicy.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation

enum BusinessFinanceControlPermission {
    static let configurationView = "finance.configuration.view"
    static let movementsView = "finance.movements.view"
    static let receivablesPayablesView = "finance.open_items.view"
    static let cashBankView = "finance.cash_bank.view"
    static let historicalImportView = "finance.import.view"
    static let historicalImportUpload = "finance.import.upload"
    static let historicalImportPreview = "finance.import.preview"
    static let reconciliationView = "finance.reconciliation.view"
    static let reconciliationReview = "finance.reconciliation.review"
    static let coverageView = "finance.coverage.view"
    static let unresolvedView = "finance.unresolved.view"

    static let surfaceReadPermissions: Set<String> = [
        configurationView,
        movementsView,
        receivablesPayablesView,
        cashBankView,
        historicalImportView,
        reconciliationView,
        coverageView,
        unresolvedView
    ]
}

enum BusinessFinanceControlAction: Equatable, Sendable {
    case uploadHistoricalImport
    case previewHistoricalImport
    case reviewReconciliation
}

struct BusinessFinanceControlAccessPolicy: Equatable, Sendable {
    private let effectivePermissions: Set<String>

    init(effectivePermissions: Set<String>) {
        self.effectivePermissions = Set(
            effectivePermissions.compactMap { permission in
                let normalized = permission.trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized.isEmpty ? nil : normalized
            }
        )
    }

    var canViewSurface: Bool {
        isSuperuser ||
        !effectivePermissions.isDisjoint(
            with: BusinessFinanceControlPermission.surfaceReadPermissions
        )
    }

    func canView(_ surface: BusinessFinanceControlSurface) -> Bool {
        guard !isSuperuser else { return true }
        return allows(permission(for: surface))
    }

    func allows(
        _ action: BusinessFinanceControlAction,
        capabilities: BusinessFinanceControlCapabilities
    ) -> Bool {
        switch action {
        case .uploadHistoricalImport:
            return allows(BusinessFinanceControlPermission.historicalImportUpload) &&
                capabilities.canUploadHistoricalImport
        case .previewHistoricalImport:
            return allows(BusinessFinanceControlPermission.historicalImportPreview) &&
                capabilities.canPreviewHistoricalImport
        case .reviewReconciliation:
            return allows(BusinessFinanceControlPermission.reconciliationReview) &&
                capabilities.canReviewReconciliation
        }
    }

    private var isSuperuser: Bool {
        effectivePermissions.contains("*")
    }

    private func allows(_ permission: String) -> Bool {
        isSuperuser || effectivePermissions.contains(permission)
    }

    private func permission(for surface: BusinessFinanceControlSurface) -> String {
        switch surface {
        case .configuration:
            return BusinessFinanceControlPermission.configurationView
        case .movements:
            return BusinessFinanceControlPermission.movementsView
        case .receivablesAndPayables:
            return BusinessFinanceControlPermission.receivablesPayablesView
        case .cashAndBank:
            return BusinessFinanceControlPermission.cashBankView
        case .historicalImport:
            return BusinessFinanceControlPermission.historicalImportView
        case .reconciliation:
            return BusinessFinanceControlPermission.reconciliationView
        case .coverageAndCutover:
            return BusinessFinanceControlPermission.coverageView
        case .unresolvedItems:
            return BusinessFinanceControlPermission.unresolvedView
        }
    }
}

