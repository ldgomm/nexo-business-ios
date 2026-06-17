//
//  PaymentRegisterViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import Foundation
import Observation

enum PaymentRegisterMode: String, CaseIterable, Identifiable, Sendable, Hashable {
    case cash
    case transfer
    case card
    case credit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash:
            return "Efectivo"
        case .transfer:
            return "Transferencia"
        case .card:
            return "Tarjeta"
        case .credit:
            return "Cuenta por cobrar"
        }
    }

    var systemImage: String {
        switch self {
        case .cash:
            return "banknote"
        case .transfer:
            return "arrow.left.arrow.right"
        case .card:
            return "creditcard"
        case .credit:
            return "person.crop.circle.badge.clock"
        }
    }

    var paymentMethod: BusinessPaymentMethod? {
        switch self {
        case .cash:
            return .cash
        case .transfer:
            return .transfer
        case .card:
            return .card
        case .credit:
            return nil
        }
    }
}

@MainActor
@Observable
final class PaymentRegisterViewModel {
    private(set) var sale: BusinessSale
    private(set) var currentCashSession: CashSession?
    private(set) var selectedCustomer: BusinessCustomer?
    private(set) var isLoadingCash = false
    private(set) var isSubmitting = false
    private(set) var paymentResult: PaymentRecord?
    private(set) var cashMovementResult: CashMovement?
    private(set) var receivableResult: ReceivableRecord?
    private(set) var electronicDocumentResult: BusinessDocument?
    private(set) var lastSubmittedMode: PaymentRegisterMode?
    private(set) var isIssuingElectronicDocument = false
    var selectedMode: PaymentRegisterMode = .cash
    var amount: String
    var reference = ""
    var note = ""
    var customerId: String
    var dueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var useDueDate = false
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let effectivePermissions: Set<String>
    let activityId: String?
    let revisions: BusinessRevisions?

    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository?
    private let salesRepository: SalesRepository?
    private(set) var hasAttemptedSaleRefreshForInvoiceReadiness = false

    init(
        organizationId: String,
        branchId: String,
        sale: BusinessSale,
        effectivePermissions: Set<String>,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository? = nil,
        salesRepository: SalesRepository? = nil,
        activityId: String? = nil,
        revisions: BusinessRevisions? = nil,
        customersRepository: CustomersRepository = UnavailableCustomersRepository()
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.sale = sale
        self.effectivePermissions = effectivePermissions
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
        self.salesRepository = salesRepository
        self.activityId = activityId ?? sale.activityId
        self.revisions = revisions
        self.amount = sale.totals.grandTotal.amount
        self.customerId = sale.customerId ?? ""
        self.selectedMode = Self.initialMode(effectivePermissions: effectivePermissions)
    }

    var completedSaleForDocuments: BusinessSale? {
        guard hasCompletedSubmission else { return nil }
        return sale
    }
    
    var hasCompletedSubmission: Bool {
        paymentResult != nil || receivableResult != nil
    }

    var saleNeedsCollection: Bool {
        SaleStatusPresentation.canCollect(status: sale.status) &&
        PaymentStatusPresentation.canCollect(status: sale.paymentStatus)
    }

    var collectionClosedMessage: String {
        if PaymentStatusPresentation.isCollected(sale.paymentStatus) {
            return "Esta venta ya está cobrada. Si acabas de confirmar el cobro desde otro intento, vuelve al detalle o al historial y actualiza."
        }

        return "Esta venta ya no está disponible para cobro con el estado actual."
    }

    var registeredPaymentWasCash: Bool {
        lastSubmittedMode == .cash || paymentResult?.method == BusinessPaymentMethod.cash.rawValue
    }

    var availableModes: [PaymentRegisterMode] {
        var modes: [PaymentRegisterMode] = []

        if hasPaymentPermission {
            modes.append(contentsOf: [.cash, .transfer, .card])
        }

        if hasReceivablePermission {
            modes.append(.credit)
        }

        return modes
    }

    var canAccessPaymentScreen: Bool {
        !availableModes.isEmpty
    }

    var accessDeniedMessage: String {
        "No puedes cobrar con tu usuario actual. Pide al administrador que active el permiso Registrar cobros para este rol."
    }

    var canSubmitPayment: Bool {
        guard !isSubmitting, !hasCompletedSubmission, selectedMode != .credit else { return false }
        guard hasPaymentPermission else { return false }
        guard SaleStatusPresentation.canCollect(status: sale.status) else { return false }
        guard PaymentStatusPresentation.canCollect(status: sale.paymentStatus) else { return false }
        guard isValidAmount(amount) else { return false }
        guard !requiresReference || !normalized(reference).isEmpty else { return false }

        if selectedMode == .cash {
            return currentCashSession?.isOpen == true
        }

        return true
    }

    var canCreateReceivable: Bool {
        guard !isSubmitting, !hasCompletedSubmission, selectedMode == .credit else { return false }
        guard hasReceivablePermission else { return false }
        guard SaleStatusPresentation.canCollect(status: sale.status) else { return false }
        guard PaymentStatusPresentation.canCollect(status: sale.paymentStatus) else { return false }
        guard isValidAmount(amount) else { return false }
        return !normalized(customerId).isEmpty
    }

    var canSubmitPaymentAndIssueElectronicDocument: Bool {
        canSubmitPayment && canIssueElectronicDocumentAfterPayment
    }

    var finalConsumerInvoiceBlockedReason: String? {
        BusinessElectronicInvoiceCustomerPolicy.blockingMessageForInvoice(sale: sale)
    }

    var shouldShowPaymentAndIssueElectronicDocumentAction: Bool {
        selectedMode != .credit &&
        !hasCompletedSubmission &&
        !sale.hasElectronicDocumentRegistered &&
        BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) &&
        canEvaluateElectronicInvoiceReadinessForActions &&
        sale.electronicInvoiceReadiness.canIssue &&
        finalConsumerInvoiceBlockedReason == nil
    }

    var canIssueElectronicDocumentAfterPayment: Bool {
        documentsRepository != nil &&
        hasElectronicInvoiceIssuePermission &&
        activityId?.isEmpty == false &&
        revisions != nil &&
        !sale.hasElectronicDocumentRegistered &&
        BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) &&
        canEvaluateElectronicInvoiceReadinessForActions &&
        sale.electronicInvoiceReadiness.canIssue &&
        finalConsumerInvoiceBlockedReason == nil
    }

    var hasReliableElectronicInvoiceReadinessData: Bool {
        guard !sale.items.isEmpty else { return false }

        return sale.items.allSatisfy { item in
            [item.taxProfileCode, item.taxTreatment, item.sriTaxCode, item.sriRateCode]
                .contains { value in
                    value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                }
        }
    }

    var hasPositiveTaxEvidenceForElectronicInvoice: Bool {
        isPositiveDecimalText(sale.totals.tax.amount) ||
        sale.items.contains { item in
            isPositiveDecimalText(item.taxAmount?.amount) ||
            isPositiveDecimalText(item.taxRate)
        }
    }

    var hasActionableElectronicInvoiceReadinessEvidence: Bool {
        guard !sale.items.isEmpty else { return false }
        guard sale.electronicInvoiceReadiness.canIssue else { return false }

        return hasReliableElectronicInvoiceReadinessData ||
        hasPositiveTaxEvidenceForElectronicInvoice
    }

    var canEvaluateElectronicInvoiceReadinessForActions: Bool {
        hasActionableElectronicInvoiceReadinessEvidence
    }

    var electronicDocumentAfterPaymentBlockedReason: String? {
        guard selectedMode != .credit else { return nil }
        guard !sale.hasElectronicDocumentRegistered,
              BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) else { return nil }

        if !sale.electronicInvoiceReadiness.canIssue {
            return sale.electronicInvoiceReadiness.primaryMessage
        }

        if let finalConsumerInvoiceBlockedReason {
            return finalConsumerInvoiceBlockedReason
        }

        if !hasActionableElectronicInvoiceReadinessEvidence {
            return "Esta venta todavía no tiene información tributaria suficiente para emitir factura electrónica desde esta pantalla. Si el producto tiene IVA vigente, actualiza la venta; si sigue igual, revisa la configuración tributaria del producto."
        }
        if !hasElectronicInvoiceIssuePermission {
            return "Tu usuario puede cobrar, pero no emitir factura electrónica."
        }
        if documentsRepository == nil || activityId?.isEmpty != false || revisions == nil {
            return "Falta contexto para emitir factura electrónica después del cobro."
        }
        return nil
    }

    var shouldShowCashWarning: Bool {
        selectedMode == .cash && currentCashSession?.isOpen != true
    }

    var requiresReference: Bool {
        selectedMode == .transfer || selectedMode == .card
    }

    var referenceHelpText: String? {
        switch selectedMode {
        case .transfer:
            return "Ingresa el número, comprobante o referencia de la transferencia antes de confirmar."
        case .card:
            return "Ingresa el voucher, lote o referencia de la tarjeta antes de confirmar."
        default:
            return nil
        }
    }

    var salePaymentStatusText: String {
        PaymentStatusPresentation.displayName(sale.paymentStatus)
    }

    var saleDocumentStatusText: String {
        BusinessDocumentStatusPresentation.displayName(sale.effectiveDocumentStatus ?? "not_required")
    }

    var hasPaymentPermission: Bool {
        hasPermission([
            "business.payments.collect",
            "payments.collect",
            "business.payments.register",
            "payments.register",
            "sales.payments.register",
            "business.sales.payments.register"        ])
    }

    var hasReceivablePermission: Bool {
        hasPermission([
            "business.receivables.create",
            "receivables.create",
            "business.payments.mark_as_credit",
            "payments.mark_as_credit"
        ])
    }

    var hasElectronicInvoiceIssuePermission: Bool {
        hasPermission([
            "business.documents.issue_electronic_invoice",
            "documents.issue_electronic_invoice",
            "documents.electronic_invoice.issue",
            "electronic_documents.issue",
            "business.electronic_documents.issue"
        ])
    }

    var amountMoney: String {
        "\(sale.totals.grandTotal.currency) \(amount)"
    }

    var submitButtonTitle: String {
        selectedMode == .credit ? "Crear cuenta por cobrar" : "Confirmar cobro"
    }

    func submitButtonTitle(issueElectronicDocumentAfterPayment: Bool) -> String {
        if selectedMode == .credit { return "Crear cuenta por cobrar" }
        return issueElectronicDocumentAfterPayment ? "Confirmar cobro y emitir documento" : "Confirmar cobro"
    }

    var submitConfirmationTitle: String {
        selectedMode == .credit ? "Crear cuenta por cobrar" : "Confirmar cobro"
    }

    func submitConfirmationTitle(issueElectronicDocumentAfterPayment: Bool) -> String {
        if selectedMode == .credit { return "Crear cuenta por cobrar" }
        return issueElectronicDocumentAfterPayment ? "Confirmar cobro y emitir documento" : "Confirmar cobro"
    }

    var submitConfirmationMessage: String {
        submitConfirmationMessage(issueElectronicDocumentAfterPayment: false)
    }

    func submitConfirmationMessage(issueElectronicDocumentAfterPayment: Bool) -> String {
        if selectedMode == .credit {
            let dueText = useDueDate ? dueDate.formatted(date: .abbreviated, time: .omitted) : "Sin fecha de vencimiento"
            return "Vas a dejar esta venta como cuenta por cobrar por \(amountMoney).\n\nCliente: \(customerId)\nVencimiento: \(dueText)"
        }

        var message = "Vas a registrar un cobro por \(amountMoney).\n\nMétodo: \(selectedMode.title)"
        if requiresReference {
            message += "\nReferencia: \(normalized(reference))"
        }
        if selectedMode == .cash {
            message += "\n\nEsto actualizará la caja automáticamente. No registres este valor como movimiento manual."
        }
        if issueElectronicDocumentAfterPayment {
            message += "\n\nDespués del cobro se emitirá la factura electrónica para esta venta."
        }
        return message
    }

    func selectCustomer(_ customer: BusinessCustomer) {
        guard !hasCompletedSubmission else { return }
        selectedCustomer = customer
        customerId = customer.identificationType == .finalConsumer ? "" : customer.id
        resetResultMessages()
    }

    func clearCustomer() {
        guard !hasCompletedSubmission else { return }
        selectedCustomer = nil
        customerId = sale.customerId ?? ""
        resetResultMessages()
    }

    func load() async {
        await refreshSaleForElectronicInvoiceReadinessIfPossible()
        await refreshForSelectedMode()
    }

    private func refreshSaleForElectronicInvoiceReadinessIfPossible() async {
        guard let salesRepository else {
            hasAttemptedSaleRefreshForInvoiceReadiness = true
            return
        }

        do {
            let response = try await salesRepository.getSale(
                organizationId: organizationId,
                saleId: sale.id
            )
            sale = salePreservingKnownElectronicDocument(response.sale)
            hasAttemptedSaleRefreshForInvoiceReadiness = true
        } catch {
            hasAttemptedSaleRefreshForInvoiceReadiness = true
        }
    }

    func refreshForSelectedMode() async {
        guard !branchId.isEmpty else {
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        guard canAccessPaymentScreen else {
            currentCashSession = nil
            errorMessage = accessDeniedMessage
            return
        }

        guard availableModes.contains(selectedMode) else {
            selectedMode = availableModes.first ?? .cash
            await refreshForSelectedMode()
            return
        }

        guard selectedMode == .cash else {
            currentCashSession = nil
            errorMessage = nil
            return
        }

        guard hasPaymentPermission else {
            currentCashSession = nil
            errorMessage = "No tienes permiso para registrar cobros."
            return
        }

        guard canViewCashCurrent else {
            currentCashSession = nil
            errorMessage = "No tienes permiso para consultar caja. Pide a un cajero o administrador que registre el cobro en efectivo."
            return
        }

        guard !isLoadingCash else { return }

        isLoadingCash = true
        errorMessage = nil

        defer {
            isLoadingCash = false
        }

        do {
            let response = try await cashRepository.current(
                organizationId: organizationId,
                branchId: branchId
            )
            currentCashSession = response.session
        } catch let error as APIError {
            currentCashSession = nil
            errorMessage = humanMessage(for: error)
        } catch {
            currentCashSession = nil
            errorMessage = error.localizedDescription
        }
    }

    func submit(issueElectronicDocumentAfterPayment: Bool = false) async {
        if selectedMode == .credit {
            await createReceivable()
        } else {
            await registerPayment(issueElectronicDocumentAfterPayment: issueElectronicDocumentAfterPayment)
        }
    }

    func registerPayment(issueElectronicDocumentAfterPayment: Bool = false) async {
        guard selectedMode != .credit else {
            errorMessage = "Selecciona efectivo, transferencia o tarjeta para registrar un cobro."
            return
        }

        guard canSubmitPayment else {
            errorMessage = paymentValidationMessage()
            return
        }

        let shouldIssueElectronicDocument = issueElectronicDocumentAfterPayment && canIssueElectronicDocumentAfterPayment
        guard !issueElectronicDocumentAfterPayment || shouldIssueElectronicDocument else {
            errorMessage = electronicDocumentAfterPaymentBlockedReason ?? "No se puede emitir factura electrónica para esta venta."
            return
        }

        guard let method = selectedMode.paymentMethod else {
            errorMessage = "Método de cobro no válido."
            return
        }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isSubmitting = false
        }

        do {
            let submittedMode = selectedMode
            let identity = BusinessMutationIdentity.generate(prefix: "payment-register")
            let response = try await paymentsRepository.register(
                organizationId: organizationId,
                idempotencyKey: identity.idempotencyKey,
                request: RegisterPaymentRequest(
                    saleId: sale.id,
                    cashSessionId: selectedMode == .cash ? currentCashSession?.id : nil,
                    method: method.rawValue,
                    amount: normalized(amount),
                    reference: emptyToNil(reference),
                    note: emptyToNil(note),
                    requestId: identity.requestId
                )
            )

            paymentResult = response.payment
            cashMovementResult = response.cashMovement
            lastSubmittedMode = submittedMode
            if let updatedSale = response.sale {
                sale = updatedSale
            } else {
                sale = sale.replacingPaymentStatus(
                    response.salePaymentStatus ?? inferredPaymentStatus(after: response.payment)
                )
            }
            if let cashSession = response.cashSession {
                currentCashSession = cashSession
            }
            if response.idempotencyReplayed == true {
                infoMessage = "Cobro recuperado de un intento anterior. No se duplicó la operación."
            } else if submittedMode == .cash {
                infoMessage = "Cobro registrado. La caja fue actualizada automáticamente."
            } else {
                infoMessage = "Cobro registrado correctamente."
            }

            if shouldIssueElectronicDocument {
                await issueElectronicInvoiceAfterPayment()
            }
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func issueElectronicInvoiceAfterPayment() async {
        guard canIssueElectronicDocumentAfterPayment else {
            errorMessage = electronicDocumentAfterPaymentBlockedReason ?? "No se puede emitir factura electrónica para esta venta."
            return
        }
        guard let documentsRepository, let activityId, let revisions else {
            errorMessage = "Falta contexto para emitir factura electrónica."
            return
        }

        isIssuingElectronicDocument = true
        electronicDocumentResult = nil
        errorMessage = nil

        defer {
            isIssuingElectronicDocument = false
        }

        do {
            let response = try await documentsRepository.issueElectronicInvoice(
                organizationId: organizationId,
                saleId: sale.id,
                branchId: sale.branchId.isEmpty ? branchId : sale.branchId,
                activityId: activityId,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "payment-and-electronic-invoice"),
                request: IssueBusinessElectronicDocumentRequest()
            )

            electronicDocumentResult = response.document
            sale = sale.replacingElectronicDocument(response.document)
            infoMessage = electronicInvoiceAfterPaymentSuccessMessage(response: response)
        } catch let error as APIError {
            errorMessage = electronicInvoiceAfterPaymentFailureMessage(reason: humanMessage(for: error))
        } catch {
            errorMessage = electronicInvoiceAfterPaymentFailureMessage(reason: error.localizedDescription)
        }
    }

    private func electronicInvoiceAfterPaymentSuccessMessage(response: BusinessElectronicDocumentIssueResponse) -> String {
        let paymentLine = registeredPaymentWasCash
            ? "Cobro registrado.\nLa caja fue actualizada."
            : "Cobro registrado.\nLa venta quedó cobrada."

        let document = response.document
        let statusText = BusinessDocumentStatusPresentation.displayName(document.effectiveStatus)
        let numberText = document.displayNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if response.idempotencyReplayed {
            return "\(paymentLine)\n\nFactura recuperada de un intento anterior.\nEstado: \(statusText)."
        }

        if response.authorized {
            let numberLine = numberText.isEmpty ? "" : "\nNúmero: \(numberText)"
            return "\(paymentLine)\n\nFactura electrónica autorizada.\(numberLine)\nPuedes verla en Comprobantes para revisar RIDE, XML o compartirla."
        }

        if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
            return "\(paymentLine)\n\nFactura electrónica no autorizada.\nMotivo: \(error)\nRevisa el comprobante antes de intentar otra acción."
        }

        return "\(paymentLine)\n\nFactura electrónica emitida.\nEstado: \(statusText).\nRevisa Comprobantes para ver RIDE, XML, correo y timeline."
    }

    private func electronicInvoiceAfterPaymentFailureMessage(reason: String) -> String {
        let cleanedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReason = cleanedReason.isEmpty ? "La factura electrónica no pudo emitirse." : cleanedReason

        return "No se pudo emitir la factura electrónica.\nMotivo: \(finalReason)\n\nLa venta ya quedó cobrada. No vuelvas a confirmar el cobro."
    }

    func createReceivable() async {
        guard canCreateReceivable else {
            errorMessage = receivableValidationMessage()
            return
        }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isSubmitting = false
        }

        do {
            let response = try await receivablesRepository.create(
                organizationId: organizationId,
                idempotencyKey: .generate(prefix: "receivable-create"),
                request: CreateReceivableRequest(
                    saleId: sale.id,
                    customerId: normalized(customerId),
                    amount: normalized(amount),
                    dueDate: useDueDate ? dueDate : nil,
                    note: emptyToNil(note)
                )
            )

            receivableResult = response.receivable
            lastSubmittedMode = .credit
            sale = sale.replacingPaymentStatus("partially_paid")
            infoMessage = response.idempotencyReplayed == true
                ? "Cuenta por cobrar recuperada de un intento anterior."
                : "Cuenta por cobrar creada correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetResultMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func salePreservingKnownElectronicDocument(_ loadedSale: BusinessSale) -> BusinessSale {
        let candidates = [loadedSale.primaryElectronicDocument, sale.primaryElectronicDocument].compactMap { $0 }

        if let bestDocument = BusinessDocument.bestElectronicInvoice(in: candidates) {
            return loadedSale.replacingElectronicDocument(bestDocument)
        }

        return loadedSale
    }

    func makeBusinessDocumentsViewModel() -> BusinessDocumentsViewModel? {
        guard let documentsRepository,
              let activityId,
              let revisions else {
            return nil
        }

        return BusinessDocumentsViewModel(
            organizationId: organizationId,
            sale: sale,
            effectivePermissions: effectivePermissions,
            branchId: sale.branchId.isEmpty ? branchId : sale.branchId,
            activityId: activityId,
            revisions: revisions,
            documentsRepository: documentsRepository
        )
    }

    func makeCashDashboardViewModel() -> CashDashboardViewModel {
        CashDashboardViewModel(
            organizationId: organizationId,
            branchId: branchId,
            permissions: effectivePermissions,
            cashRepository: cashRepository
        )
    }

    func paymentMethodDisplayName(_ rawValue: String) -> String {
        BusinessPaymentMethod(rawValue: rawValue)?.displayName ?? rawValue
    }

    private var canViewCashCurrent: Bool {
        hasPermission([
            "cash.view",
            "cash.session.view_current",
            "cash.sessions.view_current",
            "cash.session.current",
            "cash.session.view",
            "cash.view_current",
            "business.cash.view_current"        ])
    }

    private func paymentValidationMessage() -> String {
        if hasCompletedSubmission {
            return "Este cobro ya fue registrado. Actualiza la venta o vuelve al historial."
        }

        if !hasPaymentPermission {
            return "No tienes permiso para registrar cobros."
        }

        if !isValidAmount(amount) {
            return "Ingresa un monto válido mayor a cero."
        }

        if requiresReference && normalized(reference).isEmpty {
            return selectedMode == .transfer
                ? "Ingresa la referencia de la transferencia antes de confirmar el cobro."
                : "Ingresa la referencia de la tarjeta antes de confirmar el cobro."
        }

        if selectedMode == .cash && currentCashSession?.isOpen != true {
            return "Necesitas una caja abierta para cobrar en efectivo."
        }

        return "No se puede registrar el cobro con el estado actual."
    }

    private func receivableValidationMessage() -> String {
        if hasCompletedSubmission {
            return "Esta operación ya fue registrada. Actualiza la venta o vuelve al historial."
        }

        if !hasReceivablePermission {
            return "No tienes permiso para crear cuentas por cobrar."
        }

        if !isValidAmount(amount) {
            return "Ingresa un monto válido mayor a cero."
        }

        if normalized(customerId).isEmpty {
            return "Para dejar una venta por cobrar necesitas un cliente identificado."
        }

        return "No se puede crear la cuenta por cobrar con el estado actual."
    }

    private func handle(apiError: APIError) {
        errorMessage = humanMessage(for: apiError)
    }

    private func humanMessage(for error: APIError) -> String {
        if isMissingPermission(error) {
            if selectedMode == .cash {
                return "No puedes cobrar en efectivo con tu usuario actual. Pide que activen Ver caja actual y Registrar cobros."
            }
            return selectedMode == .credit
                ? "No puedes crear cuentas por cobrar con tu usuario actual. Pide que activen Cuentas por cobrar."
                : "No puedes cobrar con tu usuario actual. Pide que activen Registrar cobros."
        }

        return error.userMessage
    }

    private func isMissingPermission(_ error: APIError) -> Bool {
        guard case let .server(_, _, message, _) = error else { return false }
        return message.localizedCaseInsensitiveContains("Missing required permission") ||
        message.localizedCaseInsensitiveContains("cash.session") ||
        message.localizedCaseInsensitiveContains("payments.") ||
        message.localizedCaseInsensitiveContains("receivables.")
    }

    private func inferredPaymentStatus(after payment: PaymentRecord) -> String {
        guard let paid = decimal(from: payment.amount.amount),
              let total = decimal(from: sale.totals.grandTotal.amount) else {
            return "paid"
        }

        if paid >= total {
            return "paid"
        }

        return "partially_paid"
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private func isValidAmount(_ text: String) -> Bool {
        guard let value = decimal(from: text) else { return false }
        return value > Decimal.zero
    }

    private func decimal(from text: String) -> Decimal? {
        Decimal(
            string: normalized(text).replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func isPositiveDecimalText(_ value: String?) -> Bool {
        guard let normalizedValue = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "."),
              !normalizedValue.isEmpty,
              let decimal = Decimal(string: normalizedValue, locale: Locale(identifier: "en_US_POSIX")) else {
            return false
        }

        return decimal > Decimal.zero
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ text: String) -> String? {
        let value = normalized(text)
        return value.isEmpty ? nil : value
    }

    private static func initialMode(effectivePermissions: Set<String>) -> PaymentRegisterMode {
        let hasPayments = effectivePermissions.contains("*") || [
            "business.payments.collect",
            "payments.collect",
            "business.payments.register",
            "payments.register",
            "sales.payments.register",
            "business.sales.payments.register"        ].contains { effectivePermissions.contains($0) }

        if hasPayments {
            return .cash
        }

        let hasReceivables = effectivePermissions.contains("*") || [
            "business.receivables.create",
            "receivables.create",
            "business.payments.mark_as_credit",
            "payments.mark_as_credit"
        ].contains { effectivePermissions.contains($0) }

        return hasReceivables ? .credit : .cash
    }
    
    func prepareForCashCollectionIfNeeded() async {
        await refreshSaleForElectronicInvoiceReadinessIfPossible()

        guard selectedMode == .cash else {
            await refreshForSelectedMode()
            return
        }

        await refreshForSelectedMode()

        if currentCashSession?.isOpen == true {
            return
        }

        guard canOpenCashAutomatically else {
            return
        }

        await openCashAutomatically()

        if currentCashSession?.isOpen != true {
            await refreshForSelectedMode()
        }
    }
    
    private var canOpenCashAutomatically: Bool {
        hasPermission([
            "cash.open",
            "cash.session.open",
            "business.cash.open"
        ])
    }

    private func openCashAutomatically() async {
        guard !branchId.isEmpty else {
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        guard canOpenCashAutomatically else {
            errorMessage = "No tienes permiso para abrir caja automáticamente."
            return
        }

        guard !isLoadingCash else { return }

        isLoadingCash = true
        errorMessage = nil

        defer {
            isLoadingCash = false
        }

        do {
            let identity = BusinessMutationIdentity.generate(prefix: "cash-auto-open")

            let response = try await cashRepository.open(
                organizationId: organizationId,
                idempotencyKey: identity.idempotencyKey,
                request: OpenCashSessionRequest(
                    branchId: branchId,
                    openingAmount: "0.00",
                    note: "Apertura automática antes de cobrar",
                    requestId: identity.requestId
                )
            )

            currentCashSession = response.session
        } catch let error as APIError {
            currentCashSession = nil
            errorMessage = humanMessage(for: error)
        } catch {
            currentCashSession = nil
            errorMessage = error.localizedDescription
        }
    }
}
