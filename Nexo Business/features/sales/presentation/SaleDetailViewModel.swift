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
        SaleStatusPresentation.canCancel(status: sale.status)
    }

    var canCollect: Bool {
        guard let sale else { return false }
        return !isBusy &&
        !sale.hasReceivableReference &&
        SaleStatusPresentation.canCollect(status: sale.status) &&
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
        sale == nil && !isLoading
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

    func confirm() async {
        guard let sale else {
            errorMessage = "No se encontró la venta. Actualiza e inténtalo nuevamente."
            return
        }

        guard canConfirm else {
            errorMessage = "No puedes confirmar esta venta con tu usuario o estado actual."
            return
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
            self.sale = salePreservingKnownElectronicDocument(response.sale)
            infoMessage = response.idempotencyReplayed == true
                ? "Confirmación recuperada de un intento anterior."
                : "Venta confirmada correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
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
        errorMessage = apiError.userMessage

        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }
}
