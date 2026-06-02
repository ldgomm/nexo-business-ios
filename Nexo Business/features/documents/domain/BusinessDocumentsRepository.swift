//
//  BusinessDocumentsRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol BusinessDocumentsRepository: Sendable {
    func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse

    func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse

    func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse
}
