//
//  BusinessSupplierPaymentsViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

struct BusinessSupplierPaymentPresentation: Equatable, Identifiable, Sendable {
    let payment: BusinessProcurementSupplierPaymentResponse
    let supplierName: String?

    var id: String { payment.id }

    var businessSupplierName: String {
        supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
            ?? "Proveedor no disponible"
    }
}

@MainActor
@Observable
final class BusinessSupplierPaymentsViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case processing
        case recorded
        case voiding
        case voided

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .processing: return "Procesando"
            case .recorded: return "Registrados"
            case .voiding: return "Anulando"
            case .voided: return "Anulados"
            }
        }

        var apiValues: [BusinessSupplierPaymentStatus] {
            switch self {
            case .all: return []
            case .processing: return [.processing]
            case .recorded: return [.recorded]
            case .voiding: return [.voiding]
            case .voided: return [.voided]
            }
        }
    }

    enum MethodFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case cash
        case bankTransfer
        case card
        case check
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .cash: return "Efectivo"
            case .bankTransfer: return "Transferencia bancaria"
            case .card: return "Tarjeta"
            case .check: return "Cheque"
            case .other: return "Otro"
            }
        }

        var apiValue: String? {
            switch self {
            case .all: return nil
            case .cash: return "CASH"
            case .bankTransfer: return "BANK_TRANSFER"
            case .card: return "CARD"
            case .check: return "CHECK"
            case .other: return "OTHER"
            }
        }
    }

    private(set) var supplierPayments: [BusinessSupplierPaymentPresentation] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var nextCursor: String?
    private(set) var hasLoaded = false
    var query = ""
    var paymentFrom = ""
    var paymentTo = ""
    var statusFilter: StatusFilter = .all
    var methodFilter: MethodFilter = .all
    var errorMessage: String?
    var infoMessage: String?
    var referenceWarning: String?

    let organizationId: String
    let branchId: String?
    let supplierId: String?
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    init(
        organizationId: String,
        branchId: String? = nil,
        supplierId: String? = nil,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
        self.supplierId = supplierId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.supplierPaymentsView)
    }

    var hasActiveFilters: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !paymentFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !paymentTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        statusFilter != .all ||
        methodFilter != .all
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load(reset: true)
    }

    func refresh() async {
        await load(reset: true)
    }

    func search() async {
        await load(reset: true)
    }

    func clearFilters() async {
        query = ""
        paymentFrom = ""
        paymentTo = ""
        statusFilter = .all
        methodFilter = .all
        await load(reset: true)
    }

    func loadNextPageIfNeeded(
        currentPayment: BusinessSupplierPaymentPresentation
    ) async {
        guard currentPayment.id == supplierPayments.last?.id else { return }
        guard hasLoaded, hasMore, nextCursor != nil else { return }
        await load(reset: false)
    }

    func replace(_ payment: BusinessProcurementSupplierPaymentResponse) {
        let existingIndex = supplierPayments.firstIndex { $0.id == payment.id }
        guard matchesCurrentFilters(payment) else {
            if let existingIndex {
                supplierPayments.remove(at: existingIndex)
                infoMessage = supplierPayments.isEmpty
                    ? "No encontramos pagos a proveedores con estos filtros."
                    : nil
            }
            return
        }

        if let existingIndex {
            let current = supplierPayments[existingIndex]
            supplierPayments[existingIndex] = BusinessSupplierPaymentPresentation(
                payment: payment,
                supplierName: current.supplierName
            )
        } else {
            supplierPayments.insert(
                BusinessSupplierPaymentPresentation(
                    payment: payment,
                    supplierName: nil
                ),
                at: 0
            )
        }
        infoMessage = nil
    }

    private func load(reset: Bool) async {
        guard validateAccess() else { return }
        guard !isLoading else { return }
        guard let dateRange = validatedPaymentDateRange() else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.listSupplierPayments(
                organizationId: organizationId,
                filters: BusinessProcurementSupplierPaymentFilters(
                    branchId: branchId,
                    supplierId: supplierId,
                    statuses: statusFilter.apiValues,
                    paymentFrom: dateRange.from,
                    paymentTo: dateRange.to,
                    method: methodFilter.apiValue,
                    query: query
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .supplierPaymentNilIfEmpty,
                    limit: 50,
                    cursor: reset ? nil : nextCursor
                )
            )

            let page = await presentations(for: response.supplierPayments)
            if reset {
                supplierPayments = page
            } else {
                appendUnique(page)
            }
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            hasLoaded = true
            infoMessage = supplierPayments.isEmpty
                ? "No encontramos pagos a proveedores con estos filtros."
                : nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateAccess() -> Bool {
        guard accessPolicy.isModuleActive else {
            errorMessage = "El módulo Compras no está activo para esta organización."
            infoMessage = nil
            return false
        }
        guard canView else {
            errorMessage = "No tienes permiso para consultar pagos a proveedores."
            infoMessage = nil
            return false
        }
        return true
    }

    private func validatedPaymentDateRange() -> (from: String?, to: String?)? {
        let from = paymentFrom
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
        let to = paymentTo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty

        if let from, !Self.isValidDateOnly(from) {
            errorMessage = "La fecha inicial del pago debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let to, !Self.isValidDateOnly(to) {
            errorMessage = "La fecha final del pago debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let from, let to, from > to {
            errorMessage = "La fecha inicial del pago no puede ser posterior a la final."
            infoMessage = nil
            return nil
        }
        return (from, to)
    }

    private func presentations(
        for payments: [BusinessProcurementSupplierPaymentResponse]
    ) async -> [BusinessSupplierPaymentPresentation] {
        var supplierNames: [String: String] = [:]
        for presentation in supplierPayments {
            if let name = presentation.supplierName {
                supplierNames[presentation.payment.supplierId] = name
            }
        }

        var attemptedSupplierIds = Set<String>()
        var unresolvedReferenceCount = 0
        for payment in payments where supplierNames[payment.supplierId] == nil {
            guard accessPolicy.allows(BusinessProcurementPermission.suppliersView) else {
                continue
            }
            guard attemptedSupplierIds.insert(payment.supplierId).inserted else {
                continue
            }
            do {
                let response = try await repository.getSupplier(
                    organizationId: organizationId,
                    supplierId: payment.supplierId
                )
                supplierNames[payment.supplierId] = response.data.businessDisplayName
            } catch {
                unresolvedReferenceCount += 1
            }
        }

        let hasUnavailableSupplier = payments.contains {
            supplierNames[$0.supplierId] == nil
        }
        if unresolvedReferenceCount > 0 || hasUnavailableSupplier {
            referenceWarning = "Algunos nombres de proveedor están protegidos o no disponibles. Los pagos, estados e importes siguen siendo consultables."
        }

        return payments.map {
            BusinessSupplierPaymentPresentation(
                payment: $0,
                supplierName: supplierNames[$0.supplierId]
            )
        }
    }

    private func appendUnique(_ page: [BusinessSupplierPaymentPresentation]) {
        var knownIds = Set(supplierPayments.map(\.id))
        for payment in page where knownIds.insert(payment.id).inserted {
            supplierPayments.append(payment)
        }
    }

    private func matchesCurrentFilters(
        _ payment: BusinessProcurementSupplierPaymentResponse
    ) -> Bool {
        if let branchId, payment.branchId != branchId { return false }
        if let supplierId, payment.supplierId != supplierId { return false }
        if !statusFilter.apiValues.isEmpty,
           !statusFilter.apiValues.contains(payment.status) {
            return false
        }
        if let method = methodFilter.apiValue,
           payment.method?.uppercased() != method {
            return false
        }

        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .supplierPaymentNilIfEmpty
        if let normalizedQuery {
            let searchable = [
                payment.paymentNumber,
                payment.reference ?? "",
                payment.notes ?? "",
            ]
            .joined(separator: " ")
            .lowercased()
            if !searchable.contains(normalizedQuery) { return false }
        }

        let from = paymentFrom
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
        let to = paymentTo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
        if let from, payment.paymentDate < from { return false }
        if let to, payment.paymentDate > to { return false }
        return true
    }

    private static func isValidDateOnly(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }
}

@MainActor
@Observable
final class BusinessSupplierPaymentDetailViewModel {
    private(set) var supplierPayment: BusinessProcurementSupplierPaymentResponse
    private(set) var supplierName: String?
    private(set) var payableReferences: [String: String] = [:]
    private(set) var isLoading = false
    private(set) var isVoiding = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    var infoMessage: String?
    var referenceWarning: String?

    let organizationId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository
    private let voidIdempotencyKey: IdempotencyKey

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        supplierPayment: BusinessProcurementSupplierPaymentResponse,
        supplierName: String? = nil,
        repository: BusinessProcurementRepository,
        voidIdempotencyKey: IdempotencyKey = .generate(
            prefix: "supplier-payment-void"
        )
    ) {
        self.organizationId = organizationId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.supplierPayment = supplierPayment
        self.supplierName = supplierName
        self.repository = repository
        self.voidIdempotencyKey = voidIdempotencyKey
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.supplierPaymentsView)
    }

    var canViewSensitiveEvidence: Bool {
        accessPolicy.allows(
            BusinessProcurementPermission.supplierPaymentsSensitiveView
        )
    }

    var canVoid: Bool {
        canView && accessPolicy.canVoidSupplierPayment(status: supplierPayment.status)
    }

    var isBusy: Bool {
        isLoading || isVoiding
    }

    var businessSupplierName: String {
        supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
            ?? "Proveedor no disponible"
    }

    var visibleReference: String? {
        guard canViewSensitiveEvidence else { return nil }
        return supplierPayment.reference?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
    }

    var visibleNotes: String? {
        guard canViewSensitiveEvidence else { return nil }
        return supplierPayment.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty
    }

    func allocationTitle(
        for allocation: BusinessProcurementSupplierPaymentAllocationResponse,
        index: Int
    ) -> String {
        payableReferences[allocation.payableId] ?? "Cuenta por pagar \(index + 1)"
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        guard accessPolicy.isModuleActive else {
            errorMessage = "El módulo Compras no está activo para esta organización."
            return
        }
        guard canView else {
            errorMessage = "No tienes permiso para consultar este pago a proveedor."
            return
        }
        guard !isBusy else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.getSupplierPayment(
                organizationId: organizationId,
                paymentId: supplierPayment.id
            )
            supplierPayment = response.data
            await hydrateReferences()
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replace(_ payment: BusinessProcurementSupplierPaymentResponse) {
        guard payment.id == supplierPayment.id else { return }
        supplierPayment = payment
        hasLoaded = true
        errorMessage = nil
    }

    func void(
        reason: String
    ) async -> BusinessProcurementSupplierPaymentResponse? {
        guard !isBusy else { return nil }
        guard accessPolicy.isModuleActive else {
            errorMessage = "El módulo Compras no está activo para esta organización."
            return nil
        }
        guard canView else {
            errorMessage = "No tienes permiso para consultar este pago a proveedor."
            return nil
        }
        guard accessPolicy.allows(BusinessProcurementPermission.supplierPaymentsVoid) else {
            errorMessage = "No tienes permiso para anular pagos a proveedores."
            return nil
        }
        guard supplierPayment.status == .recorded else {
            errorMessage = "Solo un pago registrado puede anularse. Actualiza el detalle para confirmar su estado."
            return nil
        }
        guard supplierPayment.version > 0 else {
            errorMessage = "No se encontró una versión válida del pago."
            return nil
        }

        let normalizedReason = reason
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedReason.isEmpty else {
            errorMessage = "Ingresa el motivo de anulación."
            return nil
        }

        isVoiding = true
        errorMessage = nil
        infoMessage = nil
        defer { isVoiding = false }

        do {
            let response = try await repository.voidSupplierPayment(
                organizationId: organizationId,
                paymentId: supplierPayment.id,
                idempotencyKey: voidIdempotencyKey,
                request: BusinessProcurementSupplierPaymentVoidRequest(
                    reason: normalizedReason,
                    expectedVersion: supplierPayment.version
                )
            )
            supplierPayment = response.data
            hasLoaded = true
            infoMessage = voidSuccessMessage(
                status: response.data.status,
                replayed: response.meta.idempotencyReplayed == true
            )
            return response.data
        } catch let error as APIError {
            errorMessage = supplierPaymentVoidErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func voidSuccessMessage(
        status: BusinessSupplierPaymentStatus,
        replayed: Bool
    ) -> String {
        if replayed {
            return "El pago se recuperó de un intento de anulación anterior. Revisa el estado entregado por el servidor."
        }
        switch status {
        case .voiding:
            return "La anulación está en proceso. Actualiza el detalle antes de asumir que las aplicaciones fueron restauradas."
        case .voided:
            return "Pago anulado correctamente. El servidor conservó el historial y restauró sus aplicaciones."
        case .processing, .recorded:
            return "El servidor recibió la solicitud. Actualiza el detalle antes de asumir el resultado de la anulación."
        }
    }

    private func supplierPaymentVoidErrorMessage(_ error: APIError) -> String {
        let code = error.code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "El pago cambió en el servidor. Actualiza el detalle antes de reintentar."
        case "procurement_state_conflict":
            return "El estado del pago cambió. Actualiza el detalle antes de continuar."
        default:
            return error.userMessage
        }
    }

    private func hydrateReferences() async {
        var unavailableReference = false

        if accessPolicy.allows(BusinessProcurementPermission.suppliersView) {
            do {
                let response = try await repository.getSupplier(
                    organizationId: organizationId,
                    supplierId: supplierPayment.supplierId
                )
                supplierName = response.data.businessDisplayName
            } catch {
                unavailableReference = true
            }
        } else if supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierPaymentNilIfEmpty == nil {
            unavailableReference = true
        }

        payableReferences = [:]
        if accessPolicy.allows(BusinessProcurementPermission.payablesView) {
            var attemptedPayableIds = Set<String>()
            for allocation in supplierPayment.allocations {
                guard attemptedPayableIds.insert(allocation.payableId).inserted else {
                    continue
                }
                do {
                    let response = try await repository.getPayable(
                        organizationId: organizationId,
                        payableId: allocation.payableId,
                        asOf: nil
                    )
                    guard response.data.id == allocation.payableId,
                          response.data.supplierId == supplierPayment.supplierId else {
                        unavailableReference = true
                        continue
                    }
                    payableReferences[allocation.payableId] = await payableLabel(
                        for: response.data
                    )
                } catch {
                    unavailableReference = true
                }
            }
        } else if !supplierPayment.allocations.isEmpty {
            unavailableReference = true
        }

        if unavailableReference {
            referenceWarning = "Alguna referencia está protegida o no disponible. El pago, sus aplicaciones y todos los importes siguen siendo la respuesta autoritativa del servidor."
        }
    }

    private func payableLabel(
        for payable: BusinessProcurementPayableResponse
    ) async -> String {
        if payable.sourceType.uppercased() == "SUPPLIER_DOCUMENT",
           accessPolicy.allows(BusinessProcurementPermission.supplierDocumentsView) {
            do {
                let response = try await repository.getSupplierDocument(
                    organizationId: organizationId,
                    documentId: payable.sourceId
                )
                if response.data.id == payable.sourceId,
                   response.data.supplierId == supplierPayment.supplierId {
                    return "Documento \(response.data.documentNumber)"
                }
            } catch {
                // Fall through to a protected business label.
            }
        }

        switch payable.sourceType.uppercased() {
        case "SUPPLIER_DOCUMENT": return "Documento de proveedor"
        case "OPENING_BALANCE": return "Saldo inicial"
        case "ADJUSTMENT": return "Ajuste operativo"
        default: return "Cuenta por pagar"
        }
    }
}

extension BusinessSupplierPaymentStatus {
    var businessSupplierPaymentDisplayName: String {
        switch self {
        case .processing: return "Procesando"
        case .recorded: return "Registrado"
        case .voiding: return "Anulando"
        case .voided: return "Anulado"
        }
    }

    var businessSupplierPaymentExplanation: String {
        switch self {
        case .processing:
            return "El servidor aún está procesando el registro; no repitas el pago desde la app."
        case .recorded:
            return "El servidor registró el pago y sus aplicaciones operativas."
        case .voiding:
            return "El servidor está anulando el pago y restaurando sus aplicaciones con trazabilidad."
        case .voided:
            return "El pago fue anulado con evidencia; su historial no fue eliminado."
        }
    }
}

extension BusinessProcurementSupplierPaymentResponse {
    var businessSupplierPaymentMethodName: String {
        switch method?.uppercased() {
        case "CASH": return "Efectivo"
        case "BANK_TRANSFER": return "Transferencia bancaria"
        case "CARD": return "Tarjeta"
        case "CHECK": return "Cheque"
        case "OTHER": return "Otro"
        case .none: return "No informado"
        default:
            return method?
                .replacingOccurrences(of: "_", with: " ")
                .lowercased()
                .localizedCapitalized ?? "No informado"
        }
    }

    var businessAllocationCountText: String {
        allocations.count == 1
            ? "1 aplicación"
            : "\(allocations.count) aplicaciones"
    }

    var businessAttachmentCountText: String {
        let count = attachmentIds?.count ?? 0
        return count == 1 ? "1 adjunto" : "\(count) adjuntos"
    }
}

extension BusinessProcurementSupplierPaymentAllocationResponse {
    var businessAllocationStatusName: String {
        switch status.uppercased() {
        case "APPLIED": return "Aplicada"
        case "REVERSED": return "Revertida"
        default:
            return status
                .replacingOccurrences(of: "_", with: " ")
                .lowercased()
                .localizedCapitalized
        }
    }
}

private extension String {
    var supplierPaymentNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
