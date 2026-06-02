//
//  PendingOperationsRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol PendingOperationsRepository: Sendable {
    func pendingSales(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingSalesResponse

    func pendingReceivables(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingReceivablesResponse

    func pendingDocuments(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingDocumentsResponse
}
