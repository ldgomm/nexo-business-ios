import Foundation
import Observation

@MainActor
@Observable
final class BusinessDocumentsViewModel {
    private(set) var documents: [BusinessDocument] = []
    private(set) var isLoading = false
    private(set) var isGeneratingInternalTicket = false
    private(set) var isRegisteringPhysicalSaleNote = false
    private(set) var isIssuingElectronicInvoice = false
    var physicalSaleNoteNumber = ""
    var note = ""
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    private(set) var sale: BusinessSale
    let effectivePermissions: Set<String>
    let branchId: String?
    let activityId: String?
    let revisions: BusinessRevisions?

    private let repository: BusinessDocumentsRepository

    init(
        organizationId: String,
        sale: BusinessSale,
        effectivePermissions: Set<String>,
        branchId: String? = nil,
        activityId: String? = nil,
        revisions: BusinessRevisions? = nil,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.organizationId = organizationId
        self.sale = sale
        self.effectivePermissions = effectivePermissions
        self.branchId = branchId ?? sale.branchId
        self.activityId = activityId ?? sale.activityId
        self.revisions = revisions
        self.repository = documentsRepository
    }

    var shouldLoadOnAppear: Bool {
        documents.isEmpty && !isLoading
    }

    var electronicInvoiceDocuments: [BusinessDocument] {
        documents.filter(Self.isElectronicInvoice)
    }

    var latestElectronicInvoice: BusinessDocument? {
        electronicInvoiceDocuments.sorted(by: sortDocuments).first
    }

    var hasElectronicInvoiceRegistered: Bool {
        latestElectronicInvoice != nil || sale.hasElectronicDocumentRegistered
    }

    var electronicInvoiceStatusText: String {
        guard let document = latestElectronicInvoice else {
            return BusinessDocumentStatusPresentation.displayName(sale.effectiveDocumentStatus ?? "not_required")
        }

        return BusinessDocumentStatusPresentation.displayName(document.effectiveStatus)
    }

    var electronicInvoiceDescription: String {
        guard let document = latestElectronicInvoice else {
            if let status = sale.effectiveDocumentStatus, !BusinessDocumentStatusPresentation.isMissingElectronicDocument(status) {
                return "La venta indica un comprobante electrónico en estado \(BusinessDocumentStatusPresentation.displayName(status)), pero todavía falta cargar el detalle documental."
            }
            return "Sin factura electrónica emitida. Esta venta puede estar cobrada y quedar como registro interno hasta que alguien con permiso emita el comprobante."
        }

        if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
            return document.hasRide
                ? "Factura autorizada. Ya puedes ver o compartir RIDE y XML autorizado."
                : "Factura autorizada por el SRI, pero todavía falta generar el RIDE."
        }

        if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
            return "Factura emitida, pero requiere revisión: \(error)"
        }

        if BusinessDocumentStatusPresentation.isError(document.effectiveStatus) {
            return "Factura emitida, pero no autorizada. Abre el detalle para revisar el motivo y el XML firmado."
        }

        return "Factura electrónica emitida. Abre el detalle para revisar estado SRI, RIDE, XML, correo y timeline."
    }

    var canViewDocuments: Bool {
        hasPermission(documentViewPermissions + documentActionPermissions)
    }

    var canGenerateInternalTicket: Bool {
        !sale.id.isEmpty &&
        !isBusy &&
        hasPermission(internalTicketPermissions)
    }

    var canRegisterPhysicalSaleNote: Bool {
        !sale.id.isEmpty &&
        !isBusy &&
        hasPermission(physicalSaleNotePermissions) &&
        !normalized(physicalSaleNoteNumber).isEmpty
    }

    var canIssueElectronicInvoice: Bool {
        !sale.id.isEmpty &&
        !isBusy &&
        !hasElectronicInvoiceRegistered &&
        BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) &&
        branchId?.isEmpty == false &&
        activityId?.isEmpty == false &&
        revisions != nil &&
        hasElectronicInvoiceIssuePermission
    }

    var hasElectronicInvoiceIssuePermission: Bool {
        hasPermission(electronicInvoiceIssuePermissions)
    }

    var shouldShowElectronicInvoiceButton: Bool {
        !hasElectronicInvoiceRegistered &&
        BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) &&
        hasElectronicInvoiceIssuePermission
    }

    var electronicInvoiceBlockedReason: String? {
        if hasElectronicInvoiceRegistered {
            return nil
        }

        if !BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) {
            return nil
        }

        if !hasElectronicInvoiceIssuePermission {
            return "Tu usuario puede consultar comprobantes, pero no emitir factura electrónica. Pide al administrador activar Emitir factura electrónica."
        }

        if branchId?.isEmpty != false || activityId?.isEmpty != false || revisions == nil {
            return "Actualiza el contexto del negocio antes de emitir factura electrónica."
        }

        return nil
    }

    var hasAnyDocumentAction: Bool {
        hasPermission(internalTicketPermissions + physicalSaleNotePermissions)
    }

    var hasElectronicInvoiceWarning: Bool {
        hasElectronicInvoiceIssuePermission
    }

    private var isBusy: Bool {
        isLoading || isGeneratingInternalTicket || isRegisteringPhysicalSaleNote || isIssuingElectronicInvoice
    }

    private var documentViewPermissions: [String] {
        [
            "business.documents.view",
            "documents.view",
            "business.electronic_documents.view",
            "electronic_documents.view",
            "documents.electronic_invoice.view"
        ]
    }

    private var documentActionPermissions: [String] {
        internalTicketPermissions + physicalSaleNotePermissions + electronicInvoiceIssuePermissions
    }

    private var internalTicketPermissions: [String] {
        [
            "business.documents.issue_internal_ticket",
            "documents.issue_internal_ticket"
        ]
    }

    private var physicalSaleNotePermissions: [String] {
        [
            "business.documents.register_physical_sale_note",
            "documents.register_physical_sale_note"
        ]
    }

    private var electronicInvoiceIssuePermissions: [String] {
        [
            "business.documents.issue_electronic_invoice",
            "documents.issue_electronic_invoice",
            "documents.electronic_invoice.issue",
            "electronic_documents.issue",
            "business.electronic_documents.issue"
        ]
    }

    func load() async {
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

        var loadedDocuments: [BusinessDocument] = []
        var failedSources: [String] = []

        if let saleDocument = sale.primaryElectronicDocument {
            loadedDocuments.append(saleDocument)
        }

        do {
            let response = try await repository.listElectronicDocuments(
                organizationId: organizationId,
                filters: BusinessElectronicDocumentFilters(saleId: sale.id, limit: 25)
            )
            loadedDocuments.append(contentsOf: response.documents)
        } catch {
            failedSources.append("facturas electrónicas")
        }

        do {
            let response = try await repository.list(
                organizationId: organizationId,
                saleId: sale.id
            )
            loadedDocuments.append(contentsOf: response.documents)
        } catch {
            failedSources.append("documentos internos")
        }

        let merged = uniqueDocuments(loadedDocuments).sorted(by: sortDocuments)
        documents = merged

        if let latestElectronicInvoice {
            sale = sale.replacingElectronicDocument(latestElectronicInvoice)
        }

        if !failedSources.isEmpty, merged.isEmpty {
            errorMessage = "No se pudieron cargar los comprobantes de esta venta."
        } else if !failedSources.isEmpty {
            infoMessage = "Algunos comprobantes no pudieron actualizarse: \(failedSources.joined(separator: ", "))."
        }
    }

    func generateInternalTicket() async {
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

    func registerPhysicalSaleNote() async {
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

    func issueElectronicInvoice() async {
        guard canIssueElectronicInvoice else {
            errorMessage = electronicInvoiceBlockedReason ?? "No se puede emitir factura electrónica con el estado actual."
            return
        }

        guard let branchId, let activityId, let revisions else {
            errorMessage = "Actualiza el contexto del negocio antes de emitir factura electrónica."
            return
        }

        isIssuingElectronicInvoice = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isIssuingElectronicInvoice = false
        }

        do {
            let response = try await repository.issueElectronicInvoice(
                organizationId: organizationId,
                saleId: sale.id,
                branchId: branchId,
                activityId: activityId,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "electronic-invoice-issue"),
                request: IssueBusinessElectronicDocumentRequest()
            )
            upsert(response.document)
            sale = sale.replacingElectronicDocument(response.document)

            if response.idempotencyReplayed {
                infoMessage = "Factura electrónica recuperada de un intento anterior. No se duplicó el comprobante."
            } else if response.authorized {
                infoMessage = "Factura electrónica autorizada correctamente."
            } else if let error = BusinessDocumentTextSanitizer.sanitizedMessage(response.document.lastErrorMessage) {
                infoMessage = "Factura emitida, pero requiere revisión: \(error)"
            } else if response.stoppedBeforeSri {
                infoMessage = "Factura generada. Revisa readiness SRI antes de enviarla."
            } else {
                infoMessage = "Factura electrónica enviada. Revisa el estado del comprobante."
            }
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    func makeElectronicDocumentDetailViewModel(for document: BusinessDocument) -> BusinessElectronicDocumentDetailViewModel {
        BusinessElectronicDocumentDetailViewModel(
            organizationId: organizationId,
            documentId: document.documentId,
            effectivePermissions: effectivePermissions,
            documentsRepository: repository
        )
    }

    private func upsert(_ document: BusinessDocument) {
        if let index = documents.firstIndex(where: { sameDocument($0, document) }) {
            documents[index] = document
        } else {
            documents.append(document)
        }
        documents = uniqueDocuments(documents).sorted(by: sortDocuments)
    }

    private func uniqueDocuments(_ input: [BusinessDocument]) -> [BusinessDocument] {
        var seen = Set<String>()
        var result: [BusinessDocument] = []

        for document in input {
            let key = documentIdentity(document)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(document)
        }

        return result
    }

    private func documentIdentity(_ document: BusinessDocument) -> String {
        if !document.documentId.isEmpty { return "documentId:\(document.documentId)" }
        if let accessKey = document.accessKey, !accessKey.isEmpty { return "accessKey:\(accessKey)" }
        return "id:\(document.id)"
    }

    private func sameDocument(_ lhs: BusinessDocument, _ rhs: BusinessDocument) -> Bool {
        documentIdentity(lhs) == documentIdentity(rhs)
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

    private static func isElectronicInvoice(_ document: BusinessDocument) -> Bool {
        let type = document.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return type.contains("electronic_invoice") || type.contains("factura") || type.contains("invoice")
    }

    private func internalTicketValidationMessage() -> String {
        if !hasPermission(internalTicketPermissions) {
            return "No tienes permiso para generar ticket interno."
        }
        return "No se puede generar el ticket con el estado actual."
    }

    private func physicalSaleNoteValidationMessage() -> String {
        if !hasPermission(physicalSaleNotePermissions) {
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
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = normalized(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
