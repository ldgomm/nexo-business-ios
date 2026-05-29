//
//  PreviewSalesHistoryRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public final class PreviewSalesHistoryRepository: SalesHistoryRepository, @unchecked Sendable {
    public init() {}

    public func searchSales(
        organizationId: String,
        request: SalesHistorySearchRequest
    ) async throws -> BusinessSalesHistoryResponse {
        let query = request.query?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredByStatus = PreviewData.salesHistoryResponse.sales.filter { sale in
            guard let status = request.status.queryValue else { return true }
            return sale.status == status
        }

        let filteredByQuery = filteredByStatus.filter { sale in
            guard let query, !query.isEmpty else { return true }
            let matchesSale = sale.id.lowercased().contains(query)
            let matchesCustomer = sale.customerId?.lowercased().contains(query) ?? false
            let matchesStatus = sale.status.lowercased().contains(query)
            return matchesSale || matchesCustomer || matchesStatus
        }

        return BusinessSalesHistoryResponse(
            sales: Array(filteredByQuery.prefix(request.limit)),
            total: filteredByQuery.count,
            hasMore: filteredByQuery.count > request.limit
        )
    }
}
