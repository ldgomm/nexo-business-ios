//
//  BusinessPayablesViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

struct BusinessPayablePresentation: Equatable, Identifiable, Sendable {
    let payable: BusinessProcurementPayableResponse
    let supplierName: String?
    let sourceDocumentNumber: String?

    var id: String { payable.id }

    var businessSupplierName: String {
        supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
            ?? "Proveedor no disponible"
    }

    var businessSourceDescription: String {
        sourceDocumentNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
            ?? payable.sourceType.businessPayableSourceName
    }
}

@MainActor
@Observable
final class BusinessPayablesViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case outstanding
        case open
        case partiallyPaid
        case overdue
        case paid
        case cancelled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .outstanding: return "Con saldo"
            case .open: return "Pendientes"
            case .partiallyPaid: return "Pago parcial"
            case .overdue: return "Vencidas"
            case .paid: return "Pagadas"
            case .cancelled: return "Canceladas"
            }
        }

        var apiValues: [BusinessPayableEffectiveStatus] {
            switch self {
            case .all: return []
            case .outstanding: return [.open, .partiallyPaid, .overdue]
            case .open: return [.open]
            case .partiallyPaid: return [.partiallyPaid]
            case .overdue: return [.overdue]
            case .paid: return [.paid]
            case .cancelled: return [.cancelled]
            }
        }
    }

    private(set) var payables: [BusinessPayablePresentation] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var nextCursor: String?
    private(set) var hasLoaded = false
    private(set) var snapshotAsOf: String?
    var dueFrom = ""
    var dueTo = ""
    var currency = ""
    var asOf = ""
    var statusFilter: StatusFilter = .all
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
            .payableNilIfEmpty
        self.supplierId = supplierId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.payablesView)
    }

    var hasActiveFilters: Bool {
        !dueFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !dueTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !asOf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        statusFilter != .all
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
        dueFrom = ""
        dueTo = ""
        currency = ""
        asOf = ""
        statusFilter = .all
        await load(reset: true)
    }

    func loadNextPageIfNeeded(currentPayable: BusinessPayablePresentation) async {
        guard currentPayable.id == payables.last?.id else { return }
        guard hasLoaded, hasMore, nextCursor != nil else { return }
        await load(reset: false)
    }

    func replace(_ payable: BusinessProcurementPayableResponse) {
        let existingIndex = payables.firstIndex { $0.id == payable.id }
        guard matchesCurrentFilters(payable) else {
            if let existingIndex {
                payables.remove(at: existingIndex)
                infoMessage = payables.isEmpty
                    ? "No encontramos cuentas por pagar con estos filtros."
                    : nil
            }
            return
        }

        if let existingIndex {
            let current = payables[existingIndex]
            payables[existingIndex] = BusinessPayablePresentation(
                payable: payable,
                supplierName: current.supplierName,
                sourceDocumentNumber: current.sourceDocumentNumber
            )
        } else {
            payables.insert(
                BusinessPayablePresentation(
                    payable: payable,
                    supplierName: nil,
                    sourceDocumentNumber: nil
                ),
                at: 0
            )
        }
        infoMessage = nil
    }

    private func load(reset: Bool) async {
        guard validateAccess() else { return }
        guard !isLoading else { return }
        guard let filters = validatedFilters() else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.listPayables(
                organizationId: organizationId,
                filters: BusinessProcurementPayableFilters(
                    branchId: branchId,
                    supplierId: supplierId,
                    settlementStatuses: [],
                    effectiveStatuses: statusFilter.apiValues,
                    dueFrom: filters.dueFrom,
                    dueTo: filters.dueTo,
                    currency: filters.currency,
                    asOf: filters.asOf,
                    limit: 50,
                    cursor: reset ? nil : nextCursor
                )
            )

            let page = await presentations(for: response.payables)
            if reset {
                payables = page
            } else {
                appendUnique(page)
            }
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            snapshotAsOf = response.asOf
            hasLoaded = true
            infoMessage = payables.isEmpty
                ? "No encontramos cuentas por pagar con estos filtros."
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
            errorMessage = "No tienes permiso para consultar cuentas por pagar."
            infoMessage = nil
            return false
        }
        return true
    }

    private func validatedFilters() -> (
        dueFrom: String?,
        dueTo: String?,
        currency: String?,
        asOf: String?
    )? {
        let normalizedDueFrom = dueFrom
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
        let normalizedDueTo = dueTo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
        let normalizedAsOf = asOf
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
        let normalizedCurrency = currency
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .payableNilIfEmpty

        if let normalizedDueFrom, !Self.isValidDateOnly(normalizedDueFrom) {
            errorMessage = "La fecha inicial de vencimiento debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let normalizedDueTo, !Self.isValidDateOnly(normalizedDueTo) {
            errorMessage = "La fecha final de vencimiento debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let normalizedDueFrom, let normalizedDueTo,
           normalizedDueFrom > normalizedDueTo {
            errorMessage = "La fecha inicial de vencimiento no puede ser posterior a la final."
            infoMessage = nil
            return nil
        }
        if let normalizedAsOf, !Self.isValidDateOnly(normalizedAsOf) {
            errorMessage = "La fecha de corte debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let normalizedCurrency,
           normalizedCurrency.range(
               of: "^[A-Z]{3}$",
               options: .regularExpression
           ) == nil {
            errorMessage = "La moneda debe usar un código de tres letras, por ejemplo USD."
            infoMessage = nil
            return nil
        }

        return (
            normalizedDueFrom,
            normalizedDueTo,
            normalizedCurrency,
            normalizedAsOf
        )
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

    private func presentations(
        for page: [BusinessProcurementPayableResponse]
    ) async -> [BusinessPayablePresentation] {
        var supplierNames: [String: String] = [:]
        var sourceDocumentNumbers: [String: String] = [:]
        for presentation in payables {
            if let supplierName = presentation.supplierName {
                supplierNames[presentation.payable.supplierId] = supplierName
            }
            if let sourceDocumentNumber = presentation.sourceDocumentNumber {
                sourceDocumentNumbers[presentation.payable.sourceId] = sourceDocumentNumber
            }
        }

        var attemptedSupplierIds = Set<String>()
        var attemptedSourceIds = Set<String>()
        var unavailableReferences = false

        for payable in page {
            if supplierNames[payable.supplierId] == nil,
               accessPolicy.allows(BusinessProcurementPermission.suppliersView),
               attemptedSupplierIds.insert(payable.supplierId).inserted {
                do {
                    let response = try await repository.getSupplier(
                        organizationId: organizationId,
                        supplierId: payable.supplierId
                    )
                    supplierNames[payable.supplierId] = response.data.businessPayableSupplierName
                } catch {
                    unavailableReferences = true
                }
            }

            if payable.sourceType.uppercased() == "SUPPLIER_DOCUMENT",
               sourceDocumentNumbers[payable.sourceId] == nil,
               accessPolicy.allows(BusinessProcurementPermission.supplierDocumentsView),
               attemptedSourceIds.insert(payable.sourceId).inserted {
                do {
                    let response = try await repository.getSupplierDocument(
                        organizationId: organizationId,
                        documentId: payable.sourceId
                    )
                    if response.data.id == payable.sourceId,
                       response.data.supplierId == payable.supplierId {
                        sourceDocumentNumbers[payable.sourceId] = response.data.documentNumber
                    } else {
                        unavailableReferences = true
                    }
                } catch {
                    unavailableReferences = true
                }
            }
        }

        let hasProtectedSupplier = page.contains {
            supplierNames[$0.supplierId] == nil
        }
        let hasProtectedSource = page.contains {
            $0.sourceType.uppercased() == "SUPPLIER_DOCUMENT" &&
            sourceDocumentNumbers[$0.sourceId] == nil
        }
        if unavailableReferences || hasProtectedSupplier || hasProtectedSource {
            referenceWarning = "Algunos nombres de proveedor o documentos de origen están protegidos o no disponibles. Los saldos recibidos del servidor siguen siendo consultables."
        }

        return page.map {
            BusinessPayablePresentation(
                payable: $0,
                supplierName: supplierNames[$0.supplierId],
                sourceDocumentNumber: sourceDocumentNumbers[$0.sourceId]
            )
        }
    }

    private func appendUnique(_ page: [BusinessPayablePresentation]) {
        var knownIds = Set(payables.map(\.id))
        for presentation in page where knownIds.insert(presentation.id).inserted {
            payables.append(presentation)
        }
    }

    private func matchesCurrentFilters(
        _ payable: BusinessProcurementPayableResponse
    ) -> Bool {
        if let branchId, payable.branchId != branchId { return false }
        if let supplierId, payable.supplierId != supplierId { return false }
        if !statusFilter.apiValues.isEmpty,
           !statusFilter.apiValues.contains(payable.effectiveStatus) {
            return false
        }

        let normalizedCurrency = currency
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .payableNilIfEmpty
        if let normalizedCurrency, payable.currency.uppercased() != normalizedCurrency {
            return false
        }

        let normalizedDueFrom = dueFrom
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
        let normalizedDueTo = dueTo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
        if let normalizedDueFrom, payable.dueDate < normalizedDueFrom { return false }
        if let normalizedDueTo, payable.dueDate > normalizedDueTo { return false }
        return true
    }
}

@MainActor
@Observable
final class BusinessPayableDetailViewModel {
    private(set) var payable: BusinessProcurementPayableResponse
    private(set) var supplierName: String?
    private(set) var sourceDocument: BusinessProcurementSupplierDocumentResponse?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    var referenceWarning: String?

    let organizationId: String
    let asOf: String?
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository
    private let initialSourceId: String
    private let initialSourceDocumentNumber: String?

    init(
        organizationId: String,
        asOf: String? = nil,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        payable: BusinessProcurementPayableResponse,
        supplierName: String? = nil,
        sourceDocumentNumber: String? = nil,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
        self.asOf = asOf?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.payable = payable
        self.supplierName = supplierName
        self.initialSourceId = payable.sourceId
        if let sourceDocumentNumber,
           payable.sourceType.uppercased() == "SUPPLIER_DOCUMENT" {
            self.sourceDocument = nil
            self.initialSourceDocumentNumber = sourceDocumentNumber
        } else {
            self.sourceDocument = nil
            self.initialSourceDocumentNumber = nil
        }
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.payablesView)
    }

    var businessSupplierName: String {
        supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
            ?? "Proveedor no disponible"
    }

    var businessSourceDescription: String {
        sourceDocument?.documentNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
            ?? (
                payable.sourceId == initialSourceId
                    ? initialSourceDocumentNumber?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .payableNilIfEmpty
                    : nil
            )
            ?? payable.sourceType.businessPayableSourceName
    }

    var canRecordPayment: Bool {
        accessPolicy.canAllocate(payable.effectiveStatus)
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
            errorMessage = "No tienes permiso para consultar esta cuenta por pagar."
            return
        }
        if let asOf, !Self.isValidDateOnly(asOf) {
            errorMessage = "La fecha de corte debe usar el formato AAAA-MM-DD."
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.getPayable(
                organizationId: organizationId,
                payableId: payable.id,
                asOf: asOf
            )
            payable = response.data
            await hydrateReferences()
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replace(_ updatedPayable: BusinessProcurementPayableResponse) {
        guard updatedPayable.id == payable.id else { return }
        payable = updatedPayable
        hasLoaded = true
        errorMessage = nil
    }

    private func hydrateReferences() async {
        var unavailableReference = false
        sourceDocument = nil

        if accessPolicy.allows(BusinessProcurementPermission.suppliersView) {
            do {
                let response = try await repository.getSupplier(
                    organizationId: organizationId,
                    supplierId: payable.supplierId
                )
                supplierName = response.data.businessPayableSupplierName
            } catch {
                unavailableReference = true
            }
        } else if supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty == nil {
            unavailableReference = true
        }

        if payable.sourceType.uppercased() == "SUPPLIER_DOCUMENT" {
            if accessPolicy.allows(BusinessProcurementPermission.supplierDocumentsView) {
                do {
                    let response = try await repository.getSupplierDocument(
                        organizationId: organizationId,
                        documentId: payable.sourceId
                    )
                    if response.data.id == payable.sourceId,
                       response.data.supplierId == payable.supplierId {
                        sourceDocument = response.data
                    } else {
                        unavailableReference = true
                    }
                } catch {
                    unavailableReference = true
                }
            } else if initialSourceDocumentNumber == nil {
                unavailableReference = true
            }
        }

        if unavailableReference {
            referenceWarning = "Alguna referencia está protegida o no disponible. Los importes, el estado y el saldo siguen siendo la respuesta autoritativa del servidor."
        }
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

enum BusinessSupplierPaymentMethod: String, CaseIterable, Identifiable, Sendable {
    case cash = "CASH"
    case bankTransfer = "BANK_TRANSFER"
    case card = "CARD"
    case check = "CHECK"
    case other = "OTHER"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return "Efectivo"
        case .bankTransfer: return "Transferencia bancaria"
        case .card: return "Tarjeta"
        case .check: return "Cheque"
        case .other: return "Otro"
        }
    }

    var requiresReference: Bool {
        self != .cash
    }
}

struct BusinessSupplierPaymentRecordResult: Equatable, Sendable {
    let payment: BusinessProcurementSupplierPaymentResponse
    let updatedPayable: BusinessProcurementPayableResponse?
}

@MainActor
@Observable
final class BusinessSupplierPaymentFormViewModel {
    var paymentDate: String
    var amount: String
    var method: BusinessSupplierPaymentMethod
    var reference: String
    var notes: String
    private(set) var isRecording = false
    private(set) var recordedPayment: BusinessProcurementSupplierPaymentResponse?
    private(set) var updatedPayable: BusinessProcurementPayableResponse?
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let payable: BusinessProcurementPayableResponse
    let supplierName: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository
    private let idempotencyKey: IdempotencyKey

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        payable: BusinessProcurementPayableResponse,
        supplierName: String,
        repository: BusinessProcurementRepository,
        paymentDate: String? = nil,
        idempotencyKey: IdempotencyKey? = nil
    ) {
        self.organizationId = organizationId
        self.payable = payable
        self.supplierName = supplierName
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
        self.idempotencyKey = idempotencyKey
            ?? .generate(prefix: "supplier-payment-record")
        self.paymentDate = paymentDate ?? Self.todayDateOnly()
        self.amount = payable.balance.amount
        self.method = .bankTransfer
        self.reference = ""
        self.notes = ""
    }

    var canRecord: Bool {
        !isRecording && recordedPayment == nil &&
        accessValidationMessage == nil && inputValidationMessage == nil
    }

    var accessValidationMessage: String? {
        guard accessPolicy.isModuleActive else {
            return "El módulo Compras no está activo para esta organización."
        }
        guard accessPolicy.allows(BusinessProcurementPermission.payablesView) else {
            return "No tienes permiso para consultar esta cuenta por pagar."
        }
        guard accessPolicy.canRecordSupplierPayment else {
            return "No tienes permiso para registrar pagos a proveedores."
        }
        guard accessPolicy.canAllocate(payable.effectiveStatus) else {
            return "Esta cuenta ya no admite pagos según su estado actual."
        }
        return nil
    }

    var inputValidationMessage: String? {
        guard Self.isValidDateOnly(normalized(paymentDate)) else {
            return "La fecha del pago debe usar el formato AAAA-MM-DD."
        }
        guard let paymentAmount = decimal(amount), paymentAmount > .zero else {
            return "El importe del pago debe ser mayor que cero."
        }
        guard let availableBalance = decimal(payable.balance.amount),
              availableBalance > .zero else {
            return "El servidor no informa un saldo disponible para pagar."
        }
        guard paymentAmount <= availableBalance else {
            return "El importe no puede superar el saldo pendiente informado por el servidor."
        }
        if method.requiresReference, optional(reference) == nil {
            return "Ingresa una referencia para este método de pago."
        }
        return nil
    }

    func recordPayment() async -> BusinessSupplierPaymentRecordResult? {
        guard !isRecording, recordedPayment == nil else { return nil }
        if let accessValidationMessage {
            errorMessage = accessValidationMessage
            return nil
        }
        if let inputValidationMessage {
            errorMessage = inputValidationMessage
            return nil
        }

        isRecording = true
        errorMessage = nil
        infoMessage = nil
        defer { isRecording = false }

        do {
            let response = try await repository.recordSupplierPayment(
                organizationId: organizationId,
                idempotencyKey: idempotencyKey,
                request: makeRequest()
            )
            recordedPayment = response.data

            do {
                let payableResponse = try await repository.getPayable(
                    organizationId: organizationId,
                    payableId: payable.id,
                    asOf: nil
                )
                updatedPayable = payableResponse.data
                infoMessage = response.meta.idempotencyReplayed == true
                    ? "Pago recuperado de un intento anterior; saldo actualizado desde el servidor."
                    : "Pago registrado y saldo actualizado desde el servidor."
            } catch {
                updatedPayable = nil
                infoMessage = "El pago quedó registrado, pero el saldo debe actualizarse nuevamente desde el servidor."
            }

            return BusinessSupplierPaymentRecordResult(
                payment: response.data,
                updatedPayable: updatedPayable
            )
        } catch let error as APIError {
            errorMessage = supplierPaymentErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func makeRequest() -> BusinessProcurementSupplierPaymentCreateRequest {
        let normalizedAmount = normalizedDecimal(amount)
        return BusinessProcurementSupplierPaymentCreateRequest(
            branchId: optional(payable.branchId),
            supplierId: payable.supplierId,
            paymentDate: normalized(paymentDate),
            currency: payable.currency.uppercased(),
            amount: normalizedAmount,
            method: method.rawValue,
            reference: optional(reference),
            allocations: [
                BusinessProcurementSupplierPaymentAllocationRequest(
                    payableId: payable.id,
                    amount: normalizedAmount
                ),
            ],
            attachmentIds: [],
            notes: optional(notes)
        )
    }

    private func supplierPaymentErrorMessage(_ error: APIError) -> String {
        let code = error.code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch code {
        case "procurement_state_conflict",
             "procurement_payment_over_allocation",
             "procurement_allocation_exceeds_payable_balance",
             "procurement_insufficient_payable_balance":
            return "El saldo o estado cambió en el servidor. Cierra el formulario, actualiza la cuenta e inténtalo nuevamente."
        case "procurement_currency_mismatch":
            return "La moneda del pago no coincide con la cuenta por pagar."
        case "step_up_required", "reauthentication_required", "insufficient_authentication":
            return "La sesión necesita confirmación adicional para registrar este pago. Vuelve a autenticarte e inténtalo nuevamente."
        default:
            return error.userMessage
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedDecimal(_ value: String) -> String {
        normalized(value).replacingOccurrences(of: ",", with: ".")
    }

    private func decimal(_ value: String) -> Decimal? {
        Decimal(
            string: normalizedDecimal(value),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func optional(_ value: String) -> String? {
        normalized(value).payableNilIfEmpty
    }

    private static func todayDateOnly() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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

extension BusinessPayableEffectiveStatus {
    var businessPayableDisplayName: String {
        switch self {
        case .open: return "Pendiente"
        case .partiallyPaid: return "Pago parcial"
        case .paid: return "Pagada"
        case .overdue: return "Vencida"
        case .cancelled: return "Cancelada"
        }
    }

    var businessPayableExplanation: String {
        switch self {
        case .open:
            return "El servidor informa un saldo pendiente."
        case .partiallyPaid:
            return "El servidor informa pagos aplicados y un saldo todavía pendiente."
        case .paid:
            return "El servidor informa que el saldo está completamente pagado."
        case .overdue:
            return "El servidor evalúa esta obligación como vencida para la fecha de corte."
        case .cancelled:
            return "El servidor informa que esta obligación está cancelada."
        }
    }
}

extension BusinessProcurementPayableResponse {
    var businessAllocationCountText: String {
        allocationIds.count == 1
            ? "1 aplicación de pago"
            : "\(allocationIds.count) aplicaciones de pago"
    }

    var businessSettlementStatusName: String {
        switch settlementStatus.uppercased() {
        case "OPEN": return "Pendiente"
        case "PARTIALLY_PAID": return "Pago parcial"
        case "PAID": return "Pagada"
        case "CANCELLED": return "Cancelada"
        default:
            return settlementStatus
                .replacingOccurrences(of: "_", with: " ")
                .lowercased()
                .localizedCapitalized
        }
    }
}

private extension BusinessProcurementSupplierResponse {
    var businessPayableSupplierName: String {
        tradeName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .payableNilIfEmpty
            ?? legalName
    }
}

private extension String {
    var payableNilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var businessPayableSourceName: String {
        switch uppercased() {
        case "SUPPLIER_DOCUMENT": return "Documento de proveedor"
        case "OPENING_BALANCE": return "Saldo inicial"
        case "ADJUSTMENT": return "Ajuste operativo"
        default:
            return replacingOccurrences(of: "_", with: " ")
                .lowercased()
                .localizedCapitalized
        }
    }
}
