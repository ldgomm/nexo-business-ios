//
//  BusinessContextAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

final class BusinessContextAPIRepository: BusinessContextRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func getContext(
        organizationId: String
    ) async throws -> BusinessContextResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: "/api/v1/business/context",
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }
}
