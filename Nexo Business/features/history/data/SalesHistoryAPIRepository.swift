//
//  SalesHistoryAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessSalesHistoryRoutes {
    static let sales = "/api/v1/business/sales"
}

final class SalesHistoryAPIRepository: SalesHistoryRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let dateFormatter: DateFormatter

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.dateFormatter = DateFormatter()
        self.dateFormatter.calendar = Calendar(identifier: .iso8601)
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    func searchSales(
        organizationId: String,
        request: SalesHistorySearchRequest
    ) async throws -> BusinessSalesHistoryResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessSalesHistoryRoutes.sales,
                queryItems: queryItems(for: request),
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func queryItems(for request: SalesHistorySearchRequest) -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "branchId", value: request.branchId),
            URLQueryItem(name: "limit", value: String(request.limit)),
            URLQueryItem(name: "timezone", value: TimeZone.current.identifier)
        ]

        if let query = request.query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }

        if let statusValues = request.statusValues, !statusValues.isEmpty {
            items.append(URLQueryItem(name: "status", value: statusValues.joined(separator: ",")))
        } else if let status = request.status.queryValue {
            items.append(URLQueryItem(name: "status", value: status))
        }

        if let date = request.date {
            items.append(URLQueryItem(name: "date", value: dateFormatter.string(from: date)))
        }

        return items
    }
}
