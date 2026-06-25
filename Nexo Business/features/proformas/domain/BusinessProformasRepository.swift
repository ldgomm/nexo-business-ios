//
//  BusinessProformasRepository.swift
//  Nexo Business
//
//  21J.10 — Business iOS Proformas MVP
//

import Foundation

protocol BusinessProformasRepository: Sendable {
    func listProformas(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        status: BusinessProformaStatus?,
        search: String,
        limit: Int
    ) async throws -> [BusinessProforma]

    func getProforma(
        organizationId: String,
        proformaId: String
    ) async throws -> BusinessProforma

    func createProforma(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CreateBusinessProformaRequest
    ) async throws -> BusinessProforma

    func updateDraft(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: UpdateDraftBusinessProformaRequest
    ) async throws -> BusinessProforma

    func send(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProforma

    func accept(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProforma

    func reject(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        reason: String
    ) async throws -> BusinessProforma

    func expire(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProforma

    func createRevision(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CreateBusinessProformaRevisionRequest
    ) async throws -> BusinessProforma

    func convertToSale(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProformaConvertToSaleResponse

    func downloadDocumentHtml(
        organizationId: String,
        proformaId: String
    ) async throws -> BusinessProformaDownloadedDocument
}

final class PreviewBusinessProformasRepository: BusinessProformasRepository, @unchecked Sendable {
    private var storage: [BusinessProforma]

    init(storage: [BusinessProforma] = []) {
        self.storage = storage
    }

    func listProformas(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        status: BusinessProformaStatus?,
        search: String,
        limit: Int
    ) async throws -> [BusinessProforma] {
        let normalized = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return storage
            .filter { status == nil || $0.status == status }
            .filter { normalized.isEmpty || $0.proformaNumber.lowercased().contains(normalized) || $0.customerDisplayName.lowercased().contains(normalized) }
            .prefix(limit)
            .map { $0 }
    }

    func getProforma(organizationId: String, proformaId: String) async throws -> BusinessProforma {
        guard let proforma = storage.first(where: { $0.id == proformaId }) else {
            throw APIError.transport("Proforma no encontrada en preview.")
        }
        return proforma
    }

    func createProforma(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CreateBusinessProformaRequest
    ) async throws -> BusinessProforma {
        throw APIError.transport("PreviewBusinessProformasRepository no crea proformas.")
    }

    func updateDraft(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: UpdateDraftBusinessProformaRequest
    ) async throws -> BusinessProforma {
        throw APIError.transport("PreviewBusinessProformasRepository no edita proformas.")
    }

    func send(organizationId: String, proformaId: String, revisions: BusinessRevisions, idempotencyKey: IdempotencyKey) async throws -> BusinessProforma {
        try await getProforma(organizationId: organizationId, proformaId: proformaId)
    }

    func accept(organizationId: String, proformaId: String, revisions: BusinessRevisions, idempotencyKey: IdempotencyKey) async throws -> BusinessProforma {
        try await getProforma(organizationId: organizationId, proformaId: proformaId)
    }

    func reject(organizationId: String, proformaId: String, revisions: BusinessRevisions, idempotencyKey: IdempotencyKey, reason: String) async throws -> BusinessProforma {
        try await getProforma(organizationId: organizationId, proformaId: proformaId)
    }

    func expire(organizationId: String, proformaId: String, revisions: BusinessRevisions, idempotencyKey: IdempotencyKey) async throws -> BusinessProforma {
        try await getProforma(organizationId: organizationId, proformaId: proformaId)
    }

    func createRevision(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CreateBusinessProformaRevisionRequest
    ) async throws -> BusinessProforma {
        try await getProforma(organizationId: organizationId, proformaId: proformaId)
    }

    func convertToSale(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProformaConvertToSaleResponse {
        let data = #"{"saleId":"sale_preview","wasAlreadyConverted":false,"calledSri":false}"#.data(using: .utf8)!
        return try JSONDecoder.nexoDefault.decode(BusinessProformaConvertToSaleResponse.self, from: data)
    }

    func downloadDocumentHtml(organizationId: String, proformaId: String) async throws -> BusinessProformaDownloadedDocument {
        throw APIError.transport("PreviewBusinessProformasRepository no descarga documentos.")
    }
}
