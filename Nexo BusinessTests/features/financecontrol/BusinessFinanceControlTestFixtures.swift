//
//  BusinessFinanceControlTestFixtures.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation
@testable import Nexo_Business

enum BusinessFinanceControlTestFixtures {
    static func snapshot(
        organizationId: String = "org_synthetic",
        accountingStatus: BusinessFinanceAccountingStatus = .operationalNotPosted,
        authoritativeAccounting: Bool = false,
        functionalCurrency: String = "EUR",
        amountCurrency: String = "EUR",
        maskedExternalReference: String? = "•••• 9012",
        capabilities: BusinessFinanceControlCapabilities = .init()
    ) -> BusinessFinanceControlSnapshot {
        let amount = BusinessFinanceAmount(
            decimalValue: "125.50",
            currencyCode: amountCurrency
        )

        return BusinessFinanceControlSnapshot(
            scope: BusinessFinanceResolvedScope(
                organizationId: organizationId,
                legalEntityId: "entity_1",
                ledgerId: "ledger_1",
                periodId: "period_2026_07",
                periodLabel: "July 2026",
                localeIdentifier: "fr_FR",
                functionalCurrencyCode: functionalCurrency
            ),
            availability: .available,
            accountingStatus: accountingStatus,
            authoritativeAccounting: authoritativeAccounting,
            configuration: BusinessFinanceConfigurationSummary(
                organizationName: "Synthetic Retail",
                legalEntityName: "Synthetic Retail Entity",
                ledgerName: "Operating ledger",
                periodStatus: "OPEN",
                policyVersion: "policy-v1"
            ),
            movements: [
                BusinessFinanceMovementSummary(
                    id: "movement_1",
                    businessDate: "2026-07-29",
                    title: "Customer collection",
                    subtitle: "Operational source",
                    direction: .inflow,
                    amount: amount,
                    lifecycleStatus: "ACTIVE",
                    evidenceCount: 1,
                    sourceFactId: "fact_1"
                )
            ],
            openItems: [
                BusinessFinanceOpenItemSummary(
                    id: "open_item_1",
                    side: .receivable,
                    partyDisplayName: "Customer",
                    dueDate: "2026-08-15",
                    outstandingAmount: amount,
                    status: "OPEN",
                    evidenceCount: 1
                )
            ],
            cashAndBank: [
                BusinessFinanceCashBankSummary(
                    id: "account_1",
                    displayName: "Operating account",
                    kind: .bank,
                    balance: amount,
                    asOf: "2026-07-29",
                    maskedExternalReference: maskedExternalReference,
                    reconciliationStatus: "UNRECONCILED"
                )
            ],
            historicalImports: [
                BusinessFinanceHistoricalImportSummary(
                    id: "import_1",
                    fileDisplayName: "history.csv",
                    status: "READY_FOR_REVIEW",
                    acceptedRows: 10,
                    rejectedRows: 1,
                    checksumPrefix: "ab12cd34"
                )
            ],
            reconciliation: BusinessFinanceReconciliationSummary(
                status: "PARTIAL",
                matchedCount: 4,
                unmatchedCount: 1,
                duplicateCount: 0,
                exactDifference: BusinessFinanceAmount(
                    decimalValue: "0.00",
                    currencyCode: amountCurrency
                )
            ),
            coverage: BusinessFinanceCoverageSummary(
                status: "PARTIAL",
                cutoverDate: "2026-07-01",
                requiredRubrics: 8,
                reconciledRubrics: 6,
                unresolvedCount: 2,
                readinessDecision: "BLOCKED"
            ),
            unresolvedItems: [
                BusinessFinanceUnresolvedItem(
                    id: "unresolved_1",
                    title: "Missing source",
                    explanation: "A required source has not been reconciled.",
                    severity: "BLOCKING",
                    evidenceIds: ["evidence_1"]
                )
            ],
            capabilities: capabilities,
            generatedAt: "2026-07-29T16:00:00Z",
            sourceRevision: "revision_1"
        )
    }
}

