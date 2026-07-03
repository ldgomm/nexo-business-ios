//
//  BusinessSupportNotificationsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/7/26.
//

import Foundation

protocol BusinessSupportNotificationsRepository: Sendable {
    func listNotifications(
        organizationId: String,
        branchId: String,
        limit: Int,
        unreadOnly: Bool?
    ) async throws -> BusinessSupportNotificationsResponse
}

enum BusinessSupportNotificationRoutes {
    static let list = "/api/v1/business/support/notifications"
}

final class BusinessSupportNotificationsAPIRepository: BusinessSupportNotificationsRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listNotifications(
        organizationId: String,
        branchId: String,
        limit: Int = 20,
        unreadOnly: Bool? = nil
    ) async throws -> BusinessSupportNotificationsResponse {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(max(1, min(limit, 50))))
        ]

        if let unreadOnly {
            queryItems.append(URLQueryItem(name: "unreadOnly", value: unreadOnly ? "true" : "false"))
        }

        return try await apiClient.send(
            APIRequest<BusinessSupportNotificationsResponse>(
                method: .get,
                path: BusinessSupportNotificationRoutes.list,
                queryItems: queryItems,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.branchId: branchId
                ]
            )
        )
    }
}
