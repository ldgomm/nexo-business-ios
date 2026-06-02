//
//  SalesAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessSalesRoutes {
    static let preview = "/api/v1/business/sales/preview"
    static let quickSale = "/api/v1/business/sales/quick"

    static func detail(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)"
    }

    static func confirm(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/confirm"
    }

    static func cancel(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/cancel"
    }
}

final class SalesAPIRepository: SalesRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let revisionRegistry: BusinessRevisionRegistry

    init(
        apiClient: APIClient,
        revisionRegistry: BusinessRevisionRegistry = .shared
    ) {
        self.apiClient = apiClient
        self.revisionRegistry = revisionRegistry
    }

    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request body: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        let resolvedRevisions = await revisionRegistry.latestRevisions(
            organizationId: organizationId,
            branchId: body.branchId,
            activityId: body.activityId,
            fallback: revisions
        )

        let resolvedBody = SalesPreviewRequest(
            branchId: body.branchId,
            activityId: body.activityId,
            customerId: body.customerId,
            customerSnapshot: body.customerSnapshot,
            catalogRevision: resolvedRevisions.catalogRevision,
            taxConfigurationRevision: resolvedRevisions.taxConfigurationRevision,
            items: body.items
        )

        return try await apiClient.send(
            try APIRequest<SalesPreviewResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.preview,
                body: resolvedBody,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: body.branchId,
                    activityId: body.activityId,
                    revisions: resolvedRevisions
                )
            )
        )
    }

    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        let resolvedRevisions = await revisionRegistry.latestRevisions(
            organizationId: organizationId,
            branchId: body.branchId,
            activityId: body.activityId,
            fallback: revisions
        )

        let resolvedBody = QuickSaleRequest(
            requestId: body.requestId,
            branchId: body.branchId,
            activityId: body.activityId,
            customerId: body.customerId,
            customerSnapshot: body.customerSnapshot,
            cashSessionId: body.cashSessionId,
            autoConfirm: body.autoConfirm,
            catalogRevision: resolvedRevisions.catalogRevision,
            taxConfigurationRevision: resolvedRevisions.taxConfigurationRevision,
            items: body.items,
            notes: body.notes
        )

        return try await apiClient.send(
            try APIRequest<QuickSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.quickSale,
                body: resolvedBody,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: body.branchId,
                    activityId: body.activityId,
                    revisions: resolvedRevisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessSalesRoutes.detail(saleId: saleId),
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse {
        return try await apiClient.send(
            try APIRequest<ConfirmSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.confirm(saleId: saleId),
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: CancelSaleRequest
    ) async throws -> CancelSaleResponse {
        return try await apiClient.send(
            try APIRequest<CancelSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.cancel(saleId: saleId),
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    private func contextHeaders(
        organizationId: String,
        branchId: String?,
        activityId: String?,
        revisions: BusinessRevisions
    ) -> [String: String] {
        var headers = revisions.headers
        headers[BusinessHeaders.organizationId] = organizationId

        if let branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines), !branchId.isEmpty {
            headers[BusinessHeaders.branchId] = branchId
        }

        if let activityId = activityId?.trimmingCharacters(in: .whitespacesAndNewlines), !activityId.isEmpty {
            headers[BusinessHeaders.activityId] = activityId
        }

        return headers
    }

    private func mutationHeaders(
        organizationId: String,
        branchId: String?,
        activityId: String?,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) -> [String: String] {
        var headers = contextHeaders(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            revisions: revisions
        )
        headers[BusinessHeaders.idempotencyKey] = idempotencyKey.rawValue
        return headers
    }
}
