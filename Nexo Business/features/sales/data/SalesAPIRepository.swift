//
//  SalesAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessSalesRoutes {
    public static let preview = "/api/v1/business/sales/preview"
    public static let quickSale = "/api/v1/business/sales/quick"

    public static func detail(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)"
    }

    public static func confirm(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/confirm"
    }

    public static func cancel(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/cancel"
    }
}

public final class SalesAPIRepository: SalesRepository, @unchecked Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request body: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        let headers = contextHeaders(
            organizationId: organizationId,
            branchId: body.branchId,
            activityId: body.activityId,
            revisions: revisions
        )

        return try await apiClient.send(
            try APIRequest<SalesPreviewResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.preview,
                body: body,
                headers: headers
            )
        )
    }

    public func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        let headers = mutationHeaders(
            organizationId: organizationId,
            branchId: body.branchId,
            activityId: body.activityId,
            revisions: revisions,
            idempotencyKey: idempotencyKey
        )

        return try await apiClient.send(
            try APIRequest<QuickSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.quickSale,
                body: body,
                headers: headers
            )
        )
    }

    public func getSale(
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

    public func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse {
        let headers = mutationHeaders(
            organizationId: organizationId,
            branchId: nil,
            activityId: nil,
            revisions: revisions,
            idempotencyKey: idempotencyKey
        )

        return try await apiClient.send(
            try APIRequest<ConfirmSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.confirm(saleId: saleId),
                body: body,
                headers: headers
            )
        )
    }

    public func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: CancelSaleRequest
    ) async throws -> CancelSaleResponse {
        let headers = mutationHeaders(
            organizationId: organizationId,
            branchId: nil,
            activityId: nil,
            revisions: revisions,
            idempotencyKey: idempotencyKey
        )

        return try await apiClient.send(
            try APIRequest<CancelSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.cancel(saleId: saleId),
                body: body,
                headers: headers
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
