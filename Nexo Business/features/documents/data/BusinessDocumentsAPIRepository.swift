//
//  BusinessDocumentsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessDocumentsRoutes {
    static func list(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/documents"
    }

    static func internalTicket(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/documents/internal-ticket"
    }

    static func physicalSaleNote(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/documents/physical-sale-note"
    }
}

final class BusinessDocumentsAPIRepository: BusinessDocumentsRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDocumentsRoutes.list(saleId: saleId),
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request body: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse {
        try await apiClient.send(
            try APIRequest<BusinessDocumentResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.internalTicket(saleId: saleId),
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }

    func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request body: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse {
        try await apiClient.send(
            try APIRequest<BusinessDocumentResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.physicalSaleNote(saleId: saleId),
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
