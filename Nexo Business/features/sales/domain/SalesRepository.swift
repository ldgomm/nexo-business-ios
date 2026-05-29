//
//  SalesRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol SalesRepository: Sendable {
    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse

    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse

    func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse

    func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse

    func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CancelSaleRequest
    ) async throws -> CancelSaleResponse
}
