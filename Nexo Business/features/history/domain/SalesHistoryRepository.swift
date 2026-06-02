//
//  SalesHistoryRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol SalesHistoryRepository: Sendable {
    func searchSales(
        organizationId: String,
        request: SalesHistorySearchRequest
    ) async throws -> BusinessSalesHistoryResponse
}
