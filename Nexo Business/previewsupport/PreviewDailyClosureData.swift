//
//  PreviewDailyClosureData.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public extension PreviewData {
    static let pendingSalesResponse = PendingSalesResponse(
        sales: [
            confirmedSaleResponse.sale
        ],
        total: 1
    )

    static let pendingReceivablesResponse = PendingReceivablesResponse(
        receivables: [
            receivableResponse.receivable
        ],
        total: 1
    )

    static let pendingDocumentsResponse = PendingDocumentsResponse(
        documents: businessDocumentsResponse.documents,
        total: businessDocumentsResponse.documents.count
    )

    static let dailyReport = BusinessDailyReport(
        businessDate: BusinessDayFormatter.string(from: Date()),
        branchId: businessContext.branches[0].id,
        salesCount: 3,
        salesTotal: MoneyAmount(amount: "68.50"),
        paymentsCount: 2,
        paymentsTotal: MoneyAmount(amount: "48.50"),
        cashExpectedAmount: MoneyAmount(amount: "48.50"),
        receivablesPendingCount: pendingReceivablesResponse.total,
        receivablesPendingTotal: receivableResponse.receivable.balance ?? receivableResponse.receivable.amount,
        pendingSalesCount: pendingSalesResponse.total,
        pendingDocumentsCount: pendingDocumentsResponse.total,
        cashStatus: "open",
        generatedAt: Date()
    )
}
