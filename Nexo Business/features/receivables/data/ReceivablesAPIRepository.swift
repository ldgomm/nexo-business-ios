//
//  ReceivablesAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessReceivablesRoutes {
    static let create = "/api/v1/business/receivables"
    static let collect = "/api/v1/business/receivables/collect"
}

final class ReceivablesAPIRepository: ReceivablesRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
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
