//
//  ReceivablesAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessReceivablesRoutes {
    static let list = "/api/v1/business/receivables"
    static let create = "/api/v1/business/receivables"
    static let collect = "/api/v1/business/receivables/collect"
}

final class ReceivablesAPIRepository: ReceivablesRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func list(
        organizationId: String,
        customerId: String?,
        status: String?,
        limit: Int
    ) async throws -> ReceivablesListResponse {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let customerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            queryItems.append(URLQueryItem(name: "customerId", value: customerId))
        }

        if let status = status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessReceivablesRoutes.list,
                queryItems: queryItems,
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request body: CreateReceivableRequest
    ) async throws -> ReceivableResponse {
        try await apiClient.send(
            try APIRequest<ReceivableResponse>.json(
                method: .post,
                path: BusinessReceivablesRoutes.create,
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }

    func collect(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request body: CollectReceivableRequest
    ) async throws -> ReceivableCollectionResponse {
        try await apiClient.send(
            try APIRequest<ReceivableCollectionResponse>.json(
                method: .post,
                path: BusinessReceivablesRoutes.collect,
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
