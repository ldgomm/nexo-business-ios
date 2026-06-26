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

    static func updateCustomer(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/customer"
    }

    static func updateServiceType(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/service-type"
    }

    static func bulkAdd(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/items/bulk-add"
    }

    static func bulkUpdate(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/items/bulk-update"
    }

    static func bulkRemove(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/items/bulk-remove"
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

    func bulkAddItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: BulkAddSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        let resolvedRevisions = await revisionRegistry.latestRevisions(
            organizationId: organizationId,
            branchId: nil,
            activityId: nil,
            fallback: revisions
        )
        let resolvedBody = BulkAddSaleItemsRequest(
            requestId: body.requestId,
            catalogRevision: resolvedRevisions.catalogRevision,
            taxConfigurationRevision: resolvedRevisions.taxConfigurationRevision,
            items: body.items
        )
        return try await apiClient.send(
            try APIRequest<QuickSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.bulkAdd(saleId: saleId),
                body: resolvedBody,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: resolvedRevisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func bulkUpdateItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: BulkUpdateSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        let resolvedRevisions = await revisionRegistry.latestRevisions(
            organizationId: organizationId,
            branchId: nil,
            activityId: nil,
            fallback: revisions
        )
        let resolvedBody = BulkUpdateSaleItemsRequest(
            requestId: body.requestId,
            reason: body.reason,
            catalogRevision: resolvedRevisions.catalogRevision,
            taxConfigurationRevision: resolvedRevisions.taxConfigurationRevision,
            items: body.items
        )
        return try await apiClient.send(
            try APIRequest<QuickSaleResponse>.json(
                method: .put,
                path: BusinessSalesRoutes.bulkUpdate(saleId: saleId),
                body: resolvedBody,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: resolvedRevisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func bulkRemoveItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: BulkRemoveSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        let resolvedRevisions = await revisionRegistry.latestRevisions(
            organizationId: organizationId,
            branchId: nil,
            activityId: nil,
            fallback: revisions
        )
        let resolvedBody = BulkRemoveSaleItemsRequest(
            requestId: body.requestId,
            reason: body.reason,
            catalogRevision: resolvedRevisions.catalogRevision,
            taxConfigurationRevision: resolvedRevisions.taxConfigurationRevision,
            saleItemIds: body.saleItemIds
        )
        return try await apiClient.send(
            try APIRequest<QuickSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.bulkRemove(saleId: saleId),
                body: resolvedBody,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: resolvedRevisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func updateCustomer(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: UpdateSaleCustomerRequest
    ) async throws -> QuickSaleResponse {
        try await apiClient.send(
            try APIRequest<QuickSaleResponse>.json(
                method: .put,
                path: BusinessSalesRoutes.updateCustomer(saleId: saleId),
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

    func updateServiceType(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: UpdateSaleServiceTypeRequest
    ) async throws -> QuickSaleResponse {
        try await apiClient.send(
            try APIRequest<QuickSaleResponse>.json(
                method: .put,
                path: BusinessSalesRoutes.updateServiceType(saleId: saleId),
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
        let saleContext = try? await getSale(
            organizationId: organizationId,
            saleId: saleId
        ).sale

        let resolvedRevisions = await revisionRegistry.latestRevisions(
            organizationId: organizationId,
            branchId: saleContext?.branchId,
            activityId: saleContext?.activityId,
            fallback: revisions
        )

        do {
            return try await sendConfirm(
                organizationId: organizationId,
                saleId: saleId,
                branchId: saleContext?.branchId,
                activityId: saleContext?.activityId,
                revisions: resolvedRevisions,
                idempotencyKey: idempotencyKey,
                body: body
            )
        } catch let error as APIError {
            guard let currentCatalogRevision = currentCatalogRevision(from: error) else {
                throw error
            }

            let recoveredRevisions = BusinessRevisions(
                catalogRevision: currentCatalogRevision,
                taxConfigurationRevision: resolvedRevisions.taxConfigurationRevision
            )

            if let branchId = saleContext?.branchId, let activityId = saleContext?.activityId {
                await revisionRegistry.observeRevisions(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    revisions: recoveredRevisions
                )
            }

            return try await sendConfirm(
                organizationId: organizationId,
                saleId: saleId,
                branchId: saleContext?.branchId,
                activityId: saleContext?.activityId,
                revisions: recoveredRevisions,
                idempotencyKey: idempotencyKey,
                body: body
            )
        }
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

    private func sendConfirm(
        organizationId: String,
        saleId: String,
        branchId: String?,
        activityId: String?,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        body: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse {
        try await apiClient.send(
            try APIRequest<ConfirmSaleResponse>.json(
                method: .post,
                path: BusinessSalesRoutes.confirm(saleId: saleId),
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    private func currentCatalogRevision(from error: APIError) -> String? {
        guard error.statusCode == 409 || error.statusCode == 428 else { return nil }

        let candidates = revisionConflictCandidateMessages(from: error)
        for candidate in candidates {
            if let parsed = parseCurrentCatalogRevision(from: candidate) {
                return parsed
            }
        }
        return nil
    }

    private func revisionConflictCandidateMessages(from error: APIError) -> [String] {
        var messages = [
            error.userMessage,
            String(describing: error),
            String(reflecting: error)
        ]

        messages.append(contentsOf: mirrorStrings(from: error))

        var seen = Set<String>()
        return messages.filter { message in
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return false }
            seen.insert(trimmed)
            return true
        }
    }

    private func mirrorStrings(from value: Any, depth: Int = 0) -> [String] {
        guard depth < 5 else { return [] }

        if let string = value as? String {
            return [string]
        }

        if let optional = Mirror(reflecting: value).children.first, Mirror(reflecting: value).displayStyle == .optional {
            return mirrorStrings(from: optional.value, depth: depth + 1)
        }

        let mirror = Mirror(reflecting: value)
        return mirror.children.flatMap { child in
            mirrorStrings(from: child.value, depth: depth + 1)
        }
    }

    private func parseCurrentCatalogRevision(from text: String) -> String? {
        let patterns = [
            "Current revision is ",
            "current revision is ",
            "currentRevision=",
            "catalogRevision=",
            "current catalog revision is "
        ]

        for pattern in patterns {
            guard let range = text.range(of: pattern, options: [.caseInsensitive]) else { continue }
            let suffix = text[range.upperBound...]
            let token = suffix
                .split { character in
                    character.isWhitespace || character == "." || character == "," || character == ";"
                }
                .first
                .map(String.init)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'{}[]()"))

            if let token, !token.isEmpty, token.lowercased().contains("catrev") {
                return token
            }
        }

        return nil
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
