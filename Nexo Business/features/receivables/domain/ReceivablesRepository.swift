//
//  ReceivablesRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol ReceivablesRepository: Sendable {
    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateReceivableRequest
    ) async throws -> ReceivableResponse

    func collect(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CollectReceivableRequest
    ) async throws -> ReceivableCollectionResponse
}
