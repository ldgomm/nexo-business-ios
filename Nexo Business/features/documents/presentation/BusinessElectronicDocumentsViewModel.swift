//
//  BusinessElectronicDocumentsViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessElectronicDocumentsViewModel {
    private(set) var documents: [BusinessDocument] = []
    private(set) var isLoading = false
    private(set) var isRetryingDocumentId: String?
    var statusFilter = ""
    var environmentFilter = ""
    var saleIdFilter = ""
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let effectivePermissions: Set<String>
    private let repository: BusinessDocumentsRepository

    init(
        organizationId: String,
        effectivePermissions: Set<String>,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.organizationId = organizationId
        self.effectivePermissions = effectivePermissions
        self.repository = documentsRepository
    }

    var shouldLoadOnAppear: Bool {
        documents.isEmpty && !isLoading
    }

    var canList: Bool {
        hasPermission([
            "documents.electronic_invoice.list",
            "documents.electronic_invoice.view",
            "business.documents.view",
            "documents.view"
        ])
    }

    var activeFiltersDescription: String {
        var parts: [String] = []
        if !normalized(statusFilter).isEmpty { parts.append("Estado: \(normalized(statusFilter))") }
        if !normalized(environmentFilter).isEmpty { parts.append("Ambiente: \(normalized(environmentFilter))") }
        if !normalized(saleIdFilter).isEmpty { parts.append("Venta: \(normalized(saleIdFilter))") }
        return parts.isEmpty ? "Sin filtros" : parts.joined(separator: " · ")
    }

    func load() async {
        guard canList else {
            errorMessage = "No tienes permiso para consultar comprobantes electrónicos."
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer { isLoading = false }

        do {
            let response = try await repository.listElectronicDocuments(
                organizationId: organizationId,
                filters: BusinessElectronicDocumentFilters(
                    saleId: emptyToNil(saleIdFilter),
                    status: emptyToNil(statusFilter),
                    environment: emptyToNil(environmentFilter),
                    limit: 100
                )
            )
            documents = BusinessDocument.mergeUniquePreferBest(response.documents)
            infoMessage = response.documents.isEmpty ? "No hay comprobantes electrónicos para mostrar." : nil
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearFiltersAndReload() async {
        statusFilter = ""
        environmentFilter = ""
        saleIdFilter = ""
        await load()
    }

    func resetMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func sortDocuments(_ lhs: BusinessDocument, _ rhs: BusinessDocument) -> Bool {
        BusinessDocument.businessSort(lhs, rhs)
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage
        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ value: String) -> String? {
        let value = normalized(value)
        return value.isEmpty ? nil : value
    }
}
