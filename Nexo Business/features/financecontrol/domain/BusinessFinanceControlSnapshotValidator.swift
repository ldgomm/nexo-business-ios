//
//  BusinessFinanceControlSnapshotValidator.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation

enum BusinessFinanceControlSnapshotValidationError: Error, Equatable, Sendable {
    case scopeMismatch
    case authoritativeAccountingNotAllowed
    case unsafeAccountingStatus
    case missingLocale
    case missingCurrency
    case mixedCurrency
    case unmaskedExternalReference
}

struct BusinessFinanceControlSnapshotValidator: Sendable {
    func validate(
        _ snapshot: BusinessFinanceControlSnapshot,
        requestedScope: BusinessFinanceControlScope
    ) throws {
        guard snapshot.scope.organizationId == requestedScope.organizationId else {
            throw BusinessFinanceControlSnapshotValidationError.scopeMismatch
        }
        guard snapshot.authoritativeAccounting == false else {
            throw BusinessFinanceControlSnapshotValidationError.authoritativeAccountingNotAllowed
        }
        guard snapshot.accountingStatus == .operationalNotPosted else {
            throw BusinessFinanceControlSnapshotValidationError.unsafeAccountingStatus
        }
        guard !snapshot.scope.localeIdentifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw BusinessFinanceControlSnapshotValidationError.missingLocale
        }

        let functionalCurrency = normalizedCurrency(
            snapshot.scope.functionalCurrencyCode
        )
        guard !functionalCurrency.isEmpty else {
            throw BusinessFinanceControlSnapshotValidationError.missingCurrency
        }

        for amount in allAmounts(in: snapshot) {
            guard normalizedCurrency(amount.currencyCode) == functionalCurrency else {
                throw BusinessFinanceControlSnapshotValidationError.mixedCurrency
            }
        }

        for account in snapshot.cashAndBank {
            if let reference = account.maskedExternalReference,
               !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !isMasked(reference) {
                throw BusinessFinanceControlSnapshotValidationError.unmaskedExternalReference
            }
        }
    }

    private func normalizedCurrency(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func isMasked(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.contains("•") ||
            normalized.contains("*") ||
            normalized.hasPrefix("…")
    }

    private func allAmounts(
        in snapshot: BusinessFinanceControlSnapshot
    ) -> [BusinessFinanceAmount] {
        snapshot.movements.map(\.amount) +
        snapshot.openItems.map(\.outstandingAmount) +
        snapshot.cashAndBank.map(\.balance) +
        [snapshot.reconciliation.exactDifference]
    }
}

