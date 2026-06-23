//
//  PaymentsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessPaymentsRoutes {
    static let payments = "/api/v1/business/payments"
    static let register = "/api/v1/business/payments/register"
}

final class PaymentsAPIRepository: PaymentsRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func list(
        organizationId: String,
        branchId: String? = nil,
        limit: Int = 20
    ) async throws -> PaymentsListResponse {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let branchId, !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "branchId", value: branchId))
        }

        var headers = [BusinessHeaders.organizationId: organizationId]
        if let branchId, !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers[BusinessHeaders.branchId] = branchId
        }

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessPaymentsRoutes.payments,
                queryItems: queryItems,
                headers: headers
            )
        )
    }

    func register(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request body: RegisterPaymentRequest
    ) async throws -> PaymentResponse {
        try await apiClient.send(
            try APIRequest<PaymentResponse>.json(
                method: .post,
                path: BusinessPaymentsRoutes.payments,
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
