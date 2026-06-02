//
//  CustomersAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessCustomersRoutes {
    static let customers = "/api/v1/business/customers"
}

final class CustomersAPIRepository: CustomersRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func search(
        organizationId: String,
        query: String,
        limit: Int = 20
    ) async throws -> CustomersSearchResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessCustomersRoutes.customers,
                queryItems: [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "limit", value: String(limit)),
                    URLQueryItem(name: "status", value: "active")
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request body: CreateCustomerRequest
    ) async throws -> CustomerResponse {
        try await apiClient.send(
            try APIRequest<CustomerResponse>.json(
                method: .post,
                path: BusinessCustomersRoutes.customers,
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
