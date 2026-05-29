//
//  PaymentsRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol PaymentsRepository: Sendable {
    func register(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPaymentRequest
    ) async throws -> PaymentResponse
}
