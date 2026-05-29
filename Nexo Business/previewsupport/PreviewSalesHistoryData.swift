//
//  PreviewSalesHistoryData.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public extension PreviewData {
    static let paidHistorySale = BusinessSale(
        id: "sale_paid_preview_001",
        organizationId: businessContext.organization.id,
        branchId: businessContext.branches[0].id,
        activityId: businessContext.activities[0].id,
        customerId: "cus_preview",
        status: "closed",
        paymentStatus: "paid",
        documentStatus: "generated",
        totals: totals,
        items: previewResponse.items,
        createdAt: Date().addingTimeInterval(-7200),
        confirmedAt: Date().addingTimeInterval(-7000),
        closedAt: Date().addingTimeInterval(-6500)
    )

    static let salesHistoryResponse = BusinessSalesHistoryResponse(
        sales: [
            quickSaleResponse.sale,
            confirmedSaleResponse.sale,
            paidHistorySale
        ],
        total: 3,
        hasMore: false
    )
}
