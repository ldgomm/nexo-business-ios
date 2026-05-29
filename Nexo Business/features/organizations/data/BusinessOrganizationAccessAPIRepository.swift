//
//  BusinessOrganizationAccessAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessOrganizationAccessRoutes {
    public static let organizations = "/api/v1/business/organizations"
}

public final class BusinessOrganizationAccessAPIRepository: BusinessOrganizationAccessRepository, @unchecked Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func listOrganizations() async throws -> BusinessOrganizationAccessResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessOrganizationAccessRoutes.organizations
            )
        )
    }
}
