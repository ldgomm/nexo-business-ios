//
//  BusinessFinanceControlAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 30/7/26.
//

import Foundation

final class BusinessFinanceControlAPIRepository:
    BusinessFinanceControlRepository,
    @unchecked Sendable
{
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadSnapshot(
        scope: BusinessFinanceControlScope
    ) async throws -> BusinessFinanceControlSnapshot {
        var queryItems: [URLQueryItem] = []
        if let branchId = normalized(scope.branchId) {
            queryItems.append(
                URLQueryItem(name: "branchId", value: branchId)
            )
        }
        if let activityId = normalized(scope.activityId) {
            queryItems.append(
                URLQueryItem(name: "activityId", value: activityId)
            )
        }

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: "/api/v1/business/finance/control/snapshot",
                queryItems: queryItems,
                headers: [
                    BusinessHeaders.organizationId: scope.organizationId
                ]
            )
        )
    }

    private func normalized(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
