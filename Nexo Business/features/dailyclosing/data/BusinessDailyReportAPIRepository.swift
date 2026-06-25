//
//  BusinessDailyReportAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessDailyReportRoutes {
    static let daily = "/api/v1/business/reports/daily"
}

class BusinessDailyReportAPIRepository: BusinessDailyReportRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func dailyReport(
        organizationId: String,
        branchId: String,
        businessDate: String
    ) async throws -> BusinessDailyReportResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDailyReportRoutes.daily,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId),
                    URLQueryItem(name: "date", value: businessDate)
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }
}
