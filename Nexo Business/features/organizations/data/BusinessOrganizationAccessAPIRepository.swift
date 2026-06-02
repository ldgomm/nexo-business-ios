//
//  BusinessOrganizationAccessAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessOrganizationAccessRoutes {
    static let organizations = "/api/v1/business/organizations"
}

final class BusinessOrganizationAccessAPIRepository: BusinessOrganizationAccessRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listOrganizations() async throws -> BusinessOrganizationAccessResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessOrganizationAccessRoutes.organizations
            )
        )
    }
}
