//
//  SaleDetailViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SaleDetailViewModel {
    private(set) var sale: BusinessSale?
    private(set) var isLoading = false
    private(set) var hasAttemptedLoad = false
    private(set) var isConfirming = false
    private(set) var isCanceling = false
    var cancelReason = ""
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let saleId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let repository: SalesRepository

    var salesRepositoryForPaymentReadiness: SalesRepository {
        repository
    }

    init(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        initialSale: BusinessSale? = nil,
        effectivePermissions: Set<String> = [],
        salesRepository: SalesRepository
    ) {
        self.organizationId = organizationId
        self.saleId = saleId
        self.revisions = revisions
        self.sale = initialSale
        self.effectivePermissions = effectivePermissions
        self.repository = salesRepository
    }

    var canEditSale: Bool {
        guard let sale else { return false }
        return !isBusy &&
        hasPermission(["business.sales.create", "sales.create"]) &&
        sale.isEditableForOperationalChanges
    }

    var canConfirm: Bool {
        guard let sale else { return false }
        return !isBusy &&
        hasPermission(["business.sales.confirm", "sales.confirm"]) &&
        SaleStatusPresentation.canConfirm(status: sale.status)
    }

    var canCancel: Bool {
        guard let sale else { return false }
        return !isBusy &&
        hasPermission(["business.sales.cancel", "sales.cancel"]) &&
        sale.isCancellableOperationally
    }

    var canCollect: Bool {
        guard let sale else { return false }
        return !isBusy &&
        sale.isCollectableForOperationalFlow &&
        PaymentStatusPresentation.canCollect(status: sale.paymentStatus) &&
        hasAnyPaymentCapability
    }

    var canViewDocuments: Bool {
        guard sale != nil else { return false }
        return hasPermission(documentViewPermissions + documentIssuePermissions)
    }

    var canIssueElectronicInvoice: Bool {
        guard let sale else { return false }
        return !isBusy && canIssueElectronicInvoice(for: sale)
    }

    var electronicInvoiceBlockedReason: String? {
        guard let sale else { return "No se encontró la venta." }

        if sale.hasElectronicDocumentRegistered {
            return nil
        }

        if sale.isCancelledOperationally {
            return "Esta venta está cancelada. Solo puedes consultar su historial; no se puede cobrar, editar ni emitir comprobante electrónico."
        }

        if sale.isClosedOperationally {
            return "Esta venta está cerrada. Solo puedes consultar su historial y documentos existentes."
        }

        if !sale.isPaidOrFormalCreditForElectronicDocument {
            return "Primero cobra la venta o conviértela en una cuenta por cobrar formal con cliente identificado. En el piloto actual no se emite factura electrónica desde una venta sin cobrar."
        }

        if !sale.electronicInvoiceReadiness.canIssue {
            return sale.electronicInvoiceReadiness.primaryMessage
        }

        if let reason = BusinessElectronicInvoiceCustomerPolicy.blockingMessageForInvoice(sale: sale) {
            return reason
        }


        if !hasElectronicInvoiceIssuePermission {
            return "Tu usuario puede consultar comprobantes, pero no emitir factura electrónica. Pide al administrador activar Emitir factura electrónica."
        }

        if !hasValidEmissionContext(for: sale) {
            return "Actualiza el contexto del negocio antes de emitir factura electrónica."
        }

        return nil
    }

    var shouldLoadOnAppear: Bool {
        guard !isLoading else { return false }
        guard let sale else { return true }
        return sale.requiresDetailHydrationForEditingOrPayment
    }

    private var isBusy: Bool {
        isLoading || isConfirming || isCanceling
    }

    private var hasAnyPaymentCapability: Bool {
        hasPermission(paymentPermissions + receivablePermissions)
    }

    private var hasElectronicInvoiceIssuePermission: Bool {
        hasPermission(electronicInvoiceIssuePermissions)
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

    private var documentIssuePermissions: [String] {
        [
            "business.documents.issue_internal_ticket",
            "documents.issue_internal_ticket",
            "business.documents.register_physical_sale_note",
            "documents.register_physical_sale_note"
        ] + electronicInvoiceIssuePermissions
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

    private var paymentPermissions: [String] {
        [
            "business.payments.collect",
            "payments.collect",
            "business.payments.register",
            "payments.register"
        ]
    }

    private var receivablePermissions: [String] {
        [
            "business.receivables.create",
            "receivables.create",
            "business.payments.mark_as_credit",
            "payments.mark_as_credit"
        ]
    }

    private var electronicDocumentDownloadRidePermissions: [String] {
        [
            "documents.electronic_invoice.download_ride",
            "business.documents.download_ride",
            "documents.download_ride",
            "business.electronic_documents.download_ride"
        ]
    }

    private var electronicDocumentDownloadXmlPermissions: [String] {
        [
            "documents.electronic_invoice.download_xml",
            "business.documents.download_xml",
            "documents.download_xml",
            "business.electronic_documents.download_xml"
        ]
    }

    func documentActionTitle(for sale: BusinessSale) -> String {
        guard !sale.hasElectronicDocumentRegistered else {
            return sale.primaryElectronicDocument == nil ? "Ver comprobantes" : "Ver factura"
        }

        return canIssueElectronicInvoice(for: sale)
            ? "Emitir factura electrónica"
            : "Ver comprobantes"
    }

    func documentActionSystemImage(for sale: BusinessSale) -> String {
        guard !sale.hasElectronicDocumentRegistered else {
            return "doc.text.magnifyingglass"
        }

        return canIssueElectronicInvoice(for: sale)
            ? "doc.badge.plus"
            : "doc.text"
    }

    func canNavigateToDocuments(for sale: BusinessSale) -> Bool {
        if sale.hasElectronicDocumentRegistered {
            return hasPermission(documentViewPermissions)
        }

        return canIssueElectronicInvoice(for: sale)
    }


    func canViewElectronicDocumentDetail(_ document: BusinessDocument?) -> Bool {
        guard document != nil else { return false }
        return hasPermission(documentViewPermissions)
    }

    func canDownloadElectronicDocumentRide(_ document: BusinessDocument?) -> Bool {
        guard let document else { return false }
        guard hasPermission(electronicDocumentDownloadRidePermissions) else { return false }
        return document.hasRide || document.availableActions.contains(.downloadRide)
    }

    func canDownloadElectronicDocumentXml(_ document: BusinessDocument?) -> Bool {
        guard let document else { return false }
        guard hasPermission(electronicDocumentDownloadXmlPermissions) else { return false }
        return document.hasXml || document.availableActions.contains(.downloadXml)
    }

    func canShareElectronicDocumentRide(_ document: BusinessDocument?) -> Bool {
        canDownloadElectronicDocumentRide(document)
    }

    func electronicDocumentXmlAuthorizedOnly(_ document: BusinessDocument) -> Bool {
        BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus)
    }

    func electronicDocumentActionHint(for document: BusinessDocument?) -> String {
        guard let document else {
            return "Sin archivo asociado a esta venta."
        }

        let canDownloadRide = canDownloadElectronicDocumentRide(document)
        let canDownloadXml = canDownloadElectronicDocumentXml(document)

        if canDownloadRide && canDownloadXml {
            return "Puedes revisar el detalle, abrir/compartir el RIDE y abrir el XML desde esta venta."
        }

        if canDownloadRide {
            return "Puedes abrir o compartir el RIDE desde esta venta."
        }

        if canDownloadXml {
            return "Puedes abrir el XML desde esta venta."
        }

        return "Puedes revisar el detalle documental. Los archivos se muestran solo si tu rol y el backend los permiten."
    }

    func canIssueElectronicInvoice(for sale: BusinessSale) -> Bool {
        !sale.hasElectronicDocumentRegistered &&
        BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) &&
        sale.canStartNewElectronicDocumentUnderPilotPolicy &&
        sale.electronicInvoiceReadiness.canIssue &&
        BusinessElectronicInvoiceCustomerPolicy.blockingMessageForInvoice(sale: sale) == nil &&
        hasElectronicInvoiceIssuePermission &&
        hasValidEmissionContext(for: sale)
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
            hasAttemptedLoad = true
        }

        do {
            let response = try await repository.getSale(
                organizationId: organizationId,
                saleId: saleId
            )
            sale = salePreservingKnownElectronicDocument(response.sale)
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }

    func applySaleUpdate(_ updatedSale: BusinessSale) {
        sale = salePreservingKnownElectronicDocument(updatedSale)
    }

    @discardableResult
    func confirm() async -> BusinessSale? {
        guard let sale else {
            errorMessage = "No se encontró la venta. Actualiza e inténtalo nuevamente."
            return nil
        }

        guard canConfirm else {
            errorMessage = "No puedes confirmar esta venta con tu usuario o estado actual."
            return nil
        }

        isConfirming = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isConfirming = false
        }

        do {
            let response = try await repository.confirm(
                organizationId: organizationId,
                saleId: sale.id,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "sale-confirm"),
                request: ConfirmSaleRequest()
            )
            let updated = salePreservingKnownElectronicDocument(response.sale)
            self.sale = updated
            infoMessage = response.idempotencyReplayed == true
                ? "Confirmación recuperada de un intento anterior."
                : "Venta confirmada correctamente."
            return updated
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    func cancel() async {
        guard let sale else {
            errorMessage = "No se encontró la venta. Actualiza e inténtalo nuevamente."
            return
        }

        guard canCancel else {
            errorMessage = "No puedes cancelar esta venta con tu usuario o estado actual."
            return
        }

        let trimmedReason = cancelReason
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let finalReason = trimmedReason.isEmpty
            ? "Cancelación solicitada desde Nexo Business"
            : trimmedReason

        isCanceling = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isCanceling = false
        }

        do {
            let response = try await repository.cancel(
                organizationId: organizationId,
                saleId: sale.id,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "sale-cancel"),
                request: CancelSaleRequest(
                    reason: finalReason
                )
            )

            self.sale = salePreservingKnownElectronicDocument(response.sale)
            infoMessage = response.idempotencyReplayed == true
                ? "Cancelación recuperada de un intento anterior."
                : "Venta cancelada correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hasValidEmissionContext(for sale: BusinessSale) -> Bool {
        !sale.branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        sale.activityId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func salePreservingKnownElectronicDocument(_ loadedSale: BusinessSale) -> BusinessSale {
        let candidates = [loadedSale.primaryElectronicDocument, sale?.primaryElectronicDocument].compactMap { $0 }

        if let bestDocument = BusinessDocument.bestElectronicInvoice(in: candidates) {
            return loadedSale.replacingElectronicDocument(bestDocument)
        }

        return loadedSale
    }

    private func hasPermission(_ permissions: [String]) -> Bool {
        effectivePermissions.contains("*") || permissions.contains { effectivePermissions.contains($0) }
    }

    private func handle(apiError: APIError) {
        if isBusinessRevisionConflict(apiError) {
            errorMessage = "El contexto del negocio está desactualizado. Actualiza la venta o vuelve a cargar el contexto antes de continuar."
            infoMessage = "Nexo detectó una revisión antigua de catálogo/impuestos. No se registró ningún cambio."
            return
        }

        errorMessage = apiError.userMessage

        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }

    private func isBusinessRevisionConflict(_ error: APIError) -> Bool {
        guard error.statusCode == 409 || error.statusCode == 428 else { return false }
        let message = error.userMessage.lowercased()
        return message.contains("business_revision_conflict") ||
        message.contains("catalog revision is stale") ||
        message.contains("revision is stale") ||
        message.contains("contexto del negocio")
    }
}

private extension BusinessSale {
    var requiresDetailHydrationForEditingOrPayment: Bool {
        // Historial y ventas pendientes pueden entregar solo resumen: total + itemCount,
        // pero sin líneas. Para editar/cobrar/documentar siempre forzamos GET detalle.
        items.isEmpty
    }
}
