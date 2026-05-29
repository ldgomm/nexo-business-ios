//
//  BusinessDocumentsViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class BusinessDocumentsViewModel {
    public private(set) var documents: [BusinessDocument] = []
    public private(set) var isLoading = false
    public private(set) var isGeneratingInternalTicket = false
    public private(set) var isRegisteringPhysicalSaleNote = false
    public var physicalSaleNoteNumber = ""
    public var note = ""
    public var errorMessage: String?
    public var infoMessage: String?

    public let organizationId: String
    public let sale: BusinessSale
    public let effectivePermissions: Set<String>

    private let repository: BusinessDocumentsRepository

    public init(
        organizationId: String,
        sale: BusinessSale,
        effectivePermissions: Set<String>,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.organizationId = organizationId
        self.sale = sale
        self.effectivePermissions = effectivePermissions
        self.repository = documentsRepository
    }

    public var shouldLoadOnAppear: Bool {
        documents.isEmpty && !isLoading
    }

    public var canViewDocuments: Bool {
        hasPermission([
            "business.documents.view",
            "documents.view",
            "business.documents.issue_internal_ticket",
            "documents.issue_internal_ticket",
            "business.documents.register_physical_sale_note",
            "documents.register_physical_sale_note"
        ])
    }

    public var canGenerateInternalTicket: Bool {
        !sale.id.isEmpty &&
        !isBusy &&
        hasPermission([
            "business.documents.issue_internal_ticket",
            "documents.issue_internal_ticket"
        ])
    }

    public var canRegisterPhysicalSaleNote: Bool {
        !sale.id.isEmpty &&
        !isBusy &&
        hasPermission([
            "business.documents.register_physical_sale_note",
            "documents.register_physical_sale_note"
        ]) &&
        !normalized(physicalSaleNoteNumber).isEmpty
    }

    public var hasAnyDocumentAction: Bool {
        hasPermission([
            "business.documents.issue_internal_ticket",
            "documents.issue_internal_ticket",
            "business.documents.register_physical_sale_note",
            "documents.register_physical_sale_note"
        ])
    }

    public var hasElectronicInvoiceWarning: Bool {
        hasPermission([
            "business.documents.issue_electronic_invoice",
            "documents.issue_electronic_invoice"
        ])
    }

    private var isBusy: Bool {
        isLoading || isGeneratingInternalTicket || isRegisteringPhysicalSaleNote
    }

    public func load() async {
        guard canViewDocuments else {
            errorMessage = "No tienes permiso para consultar comprobantes."
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
        }

        do {
            let response = try await repository.list(
                organizationId: organizationId,
                saleId: sale.id
            )
            documents = response.documents.sorted(by: sortDocuments)
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func generateInternalTicket() async {
        guard canGenerateInternalTicket else {
            errorMessage = internalTicketValidationMessage()
            return
        }

        isGeneratingInternalTicket = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isGeneratingInternalTicket = false
        }

        do {
            let response = try await repository.generateInternalTicket(
                organizationId: organizationId,
                saleId: sale.id,
                idempotencyKey: .generate(prefix: "document-internal-ticket"),
                request: GenerateInternalTicketRequest(
                    note: emptyToNil(note)
                )
            )
            upsert(response.document)
            infoMessage = response.idempotencyReplayed == true
                ? "Ticket recuperado de un intento anterior."
                : "Ticket interno generado correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func registerPhysicalSaleNote() async {
        guard canRegisterPhysicalSaleNote else {
            errorMessage = physicalSaleNoteValidationMessage()
            return
        }

        isRegisteringPhysicalSaleNote = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isRegisteringPhysicalSaleNote = false
        }

        do {
            let response = try await repository.registerPhysicalSaleNote(
                organizationId: organizationId,
                saleId: sale.id,
                idempotencyKey: .generate(prefix: "document-physical-sale-note"),
                request: RegisterPhysicalSaleNoteRequest(
                    physicalNumber: normalized(physicalSaleNoteNumber),
                    note: emptyToNil(note)
                )
            )
            upsert(response.document)
            infoMessage = response.idempotencyReplayed == true
                ? "Nota de venta recuperada de un intento anterior."
                : "Nota de venta física registrada correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func resetMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func upsert(_ document: BusinessDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
        } else {
            documents.append(document)
        }
        documents.sort(by: sortDocuments)
    }

    private func sortDocuments(_ lhs: BusinessDocument, _ rhs: BusinessDocument) -> Bool {
        switch (lhs.createdAt, rhs.createdAt) {
        case let (left?, right?):
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.id < rhs.id
        }
    }

    private func internalTicketValidationMessage() -> String {
        if !hasPermission(["business.documents.issue_internal_ticket", "documents.issue_internal_ticket"]) {
            return "No tienes permiso para generar ticket interno."
        }
        return "No se puede generar el ticket con el estado actual."
    }

    private func physicalSaleNoteValidationMessage() -> String {
        if !hasPermission(["business.documents.register_physical_sale_note", "documents.register_physical_sale_note"]) {
            return "No tienes permiso para registrar nota de venta física."
        }

        if normalized(physicalSaleNoteNumber).isEmpty {
            return "Ingresa el número físico de la nota de venta."
        }

        return "No se puede registrar la nota de venta con el estado actual."
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage

        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        candidates.contains { effectivePermissions.contains($0) }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = normalized(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
