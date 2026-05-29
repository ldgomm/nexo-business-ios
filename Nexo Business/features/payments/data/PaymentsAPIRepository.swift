//
//  PaymentsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessPaymentsRoutes {
    public static let register = "/api/v1/business/payments"
}

public final class PaymentsAPIRepository: PaymentsRepository, @unchecked Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func register(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request body: RegisterPaymentRequest
    ) async throws -> PaymentResponse {
        try await apiClient.send(
            try APIRequest<PaymentResponse>.json(
                method: .post,
                path: BusinessPaymentsRoutes.register,
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
