//
//  BusinessPurchaseReceiptsViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

struct BusinessPurchaseReceiptPresentation: Equatable, Identifiable, Sendable {
    let receipt: BusinessProcurementPurchaseReceiptResponse
    let supplierName: String?
    let purchaseOrderNumber: String?

    var id: String { receipt.id }

    var businessSupplierName: String {
        supplierName?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
            ?? "Proveedor no disponible"
    }

    var businessPurchaseOrderName: String {
        guard receipt.purchaseOrderId != nil else { return "Sin orden vinculada" }
        return purchaseOrderNumber?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
            ?? "Orden vinculada"
    }
}

@MainActor
@Observable
final class BusinessPurchaseReceiptsViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case draft
        case confirming
        case confirmed
        case cancelled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .draft: return "Borradores"
            case .confirming: return "Confirmando"
            case .confirmed: return "Confirmadas"
            case .cancelled: return "Canceladas"
            }
        }

        var apiValues: [BusinessPurchaseReceiptStatus] {
            switch self {
            case .all: return []
            case .draft: return [.draft]
            case .confirming: return [.confirming]
            case .confirmed: return [.confirmed]
            case .cancelled: return [.cancelled]
            }
        }
    }

    private(set) var purchaseReceipts: [BusinessPurchaseReceiptPresentation] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var nextCursor: String?
    private(set) var hasLoaded = false
    var receivedFrom = ""
    var receivedTo = ""
    var statusFilter: StatusFilter = .all
    var errorMessage: String?
    var infoMessage: String?
    var referenceWarning: String?

    let organizationId: String
    let branchId: String?
    let supplierId: String?
    let purchaseOrderId: String?
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    init(
        organizationId: String,
        branchId: String? = nil,
        supplierId: String? = nil,
        purchaseOrderId: String? = nil,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
        self.supplierId = supplierId?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
        self.purchaseOrderId = purchaseOrderId?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.purchaseReceiptsView)
    }

    var hasActiveFilters: Bool {
        !receivedFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !receivedTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
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
        receivedFrom = ""
        receivedTo = ""
        statusFilter = .all
        await load(reset: true)
    }

    func loadNextPageIfNeeded(currentReceipt: BusinessPurchaseReceiptPresentation) async {
        guard currentReceipt.id == purchaseReceipts.last?.id else { return }
        guard hasLoaded, hasMore, nextCursor != nil else { return }
        await load(reset: false)
    }

    func replace(_ receipt: BusinessProcurementPurchaseReceiptResponse) {
        let existingIndex = purchaseReceipts.firstIndex { $0.id == receipt.id }
        guard matchesCurrentFilters(receipt) else {
            if let existingIndex {
                purchaseReceipts.remove(at: existingIndex)
                infoMessage = purchaseReceipts.isEmpty
                    ? "No encontramos recepciones de compra con estos filtros."
                    : nil
            }
            return
        }

        guard let index = existingIndex else {
            purchaseReceipts.insert(
                BusinessPurchaseReceiptPresentation(
                    receipt: receipt,
                    supplierName: nil,
                    purchaseOrderNumber: nil
                ),
                at: 0
            )
            infoMessage = nil
            return
        }

        let current = purchaseReceipts[index]
        purchaseReceipts[index] = BusinessPurchaseReceiptPresentation(
            receipt: receipt,
            supplierName: current.supplierName,
            purchaseOrderNumber: current.purchaseOrderNumber
        )
        infoMessage = nil
    }

    private func matchesCurrentFilters(
        _ receipt: BusinessProcurementPurchaseReceiptResponse
    ) -> Bool {
        if let branchId, receipt.branchId != branchId { return false }
        if let supplierId, receipt.supplierId != supplierId { return false }
        if let purchaseOrderId, receipt.purchaseOrderId != purchaseOrderId { return false }
        if !statusFilter.apiValues.isEmpty,
           !statusFilter.apiValues.contains(receipt.status) {
            return false
        }

        guard let receivedAt = Self.parseInstant(receipt.receivedAt) else {
            return true
        }
        let from = receivedFrom.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
        let to = receivedTo.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
        if let from, let lowerBound = Self.utcDate(from), receivedAt < lowerBound {
            return false
        }
        if let to,
           let startOfFinalDay = Self.utcDate(to),
           let exclusiveUpperBound = Calendar.businessProcurementUTC.date(
               byAdding: .day,
               value: 1,
               to: startOfFinalDay
           ),
           receivedAt >= exclusiveUpperBound {
            return false
        }
        return true
    }

    private func load(reset: Bool) async {
        guard validateAccess() else { return }
        guard !isLoading else { return }
        guard let receivedRange = validatedReceivedRange() else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.listPurchaseReceipts(
                organizationId: organizationId,
                filters: BusinessProcurementPurchaseReceiptFilters(
                    branchId: branchId,
                    supplierId: supplierId,
                    purchaseOrderId: purchaseOrderId,
                    statuses: statusFilter.apiValues,
                    receivedFrom: receivedRange.from,
                    receivedTo: receivedRange.to,
                    limit: 50,
                    cursor: reset ? nil : nextCursor
                )
            )

            let page = await presentations(for: response.purchaseReceipts)
            if reset {
                purchaseReceipts = page
            } else {
                appendUnique(page)
            }
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            hasLoaded = true
            infoMessage = purchaseReceipts.isEmpty
                ? "No encontramos recepciones de compra con estos filtros."
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
            errorMessage = "No tienes permiso para consultar recepciones de compra."
            infoMessage = nil
            return false
        }
        return true
    }

    private func validatedReceivedRange() -> (from: String?, to: String?)? {
        let from = receivedFrom.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
        let to = receivedTo.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty

        if let from, !Self.isValidDateOnly(from) {
            errorMessage = "La fecha de recepción inicial debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let to, !Self.isValidDateOnly(to) {
            errorMessage = "La fecha de recepción final debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let from, let to, from > to {
            errorMessage = "La fecha de recepción inicial no puede ser posterior a la final."
            infoMessage = nil
            return nil
        }

        return (
            from.map { "\($0)T00:00:00Z" },
            to.map { "\($0)T23:59:59Z" }
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

    private static func utcDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = .businessProcurementUTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value)
    }

    private static func parseInstant(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }

    private func presentations(
        for receipts: [BusinessProcurementPurchaseReceiptResponse]
    ) async -> [BusinessPurchaseReceiptPresentation] {
        var supplierNames: [String: String] = [:]
        var orderNumbers: [String: String] = [:]
        for presentation in purchaseReceipts {
            if let name = presentation.supplierName {
                supplierNames[presentation.receipt.supplierId] = name
            }
            if let orderId = presentation.receipt.purchaseOrderId,
               let number = presentation.purchaseOrderNumber {
                orderNumbers[orderId] = number
            }
        }
        var attemptedSupplierIds = Set<String>()
        var attemptedOrderIds = Set<String>()
        var unresolvedReferenceCount = 0

        for receipt in receipts {
            if accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersView),
               let orderId = receipt.purchaseOrderId,
               orderNumbers[orderId] == nil,
                attemptedOrderIds.insert(orderId).inserted {
                do {
                    let response = try await repository.getPurchaseOrder(
                        organizationId: organizationId,
                        orderId: orderId
                    )
                    let order = response.data
                    orderNumbers[orderId] = order.orderNumber
                    if order.supplierId == receipt.supplierId {
                        supplierNames[receipt.supplierId] = order.businessSupplierName
                    }
                } catch {
                    unresolvedReferenceCount += 1
                }
            }

            if accessPolicy.allows(BusinessProcurementPermission.suppliersView),
               supplierNames[receipt.supplierId] == nil,
               attemptedSupplierIds.insert(receipt.supplierId).inserted {
                do {
                    let response = try await repository.getSupplier(
                        organizationId: organizationId,
                        supplierId: receipt.supplierId
                    )
                    let supplier = response.data
                    supplierNames[receipt.supplierId] = supplier.businessDisplayName
                } catch {
                    unresolvedReferenceCount += 1
                }
            }
        }

        let hasUnavailableReference = receipts.contains { receipt in
            supplierNames[receipt.supplierId] == nil ||
            (receipt.purchaseOrderId != nil && receipt.purchaseOrderId.flatMap { orderNumbers[$0] } == nil)
        }
        if unresolvedReferenceCount > 0 || hasUnavailableReference {
            referenceWarning = "Algunas referencias de proveedor u orden están protegidas o no disponibles. Las recepciones siguen siendo consultables."
        }

        return receipts.map { receipt in
            BusinessPurchaseReceiptPresentation(
                receipt: receipt,
                supplierName: supplierNames[receipt.supplierId],
                purchaseOrderNumber: receipt.purchaseOrderId.flatMap { orderNumbers[$0] }
            )
        }
    }

    private func appendUnique(_ page: [BusinessPurchaseReceiptPresentation]) {
        var knownIds = Set(purchaseReceipts.map(\.id))
        for receipt in page where knownIds.insert(receipt.id).inserted {
            purchaseReceipts.append(receipt)
        }
    }
}

struct BusinessPurchaseReceiptActionIdempotencyKeys: Equatable, Sendable {
    let confirm: IdempotencyKey
    let cancel: IdempotencyKey

    static func generate() -> BusinessPurchaseReceiptActionIdempotencyKeys {
        BusinessPurchaseReceiptActionIdempotencyKeys(
            confirm: .generate(prefix: "purchase-receipt-confirm"),
            cancel: .generate(prefix: "purchase-receipt-cancel")
        )
    }
}

@MainActor
@Observable
final class BusinessPurchaseReceiptDetailViewModel {
    private(set) var purchaseReceipt: BusinessProcurementPurchaseReceiptResponse
    private(set) var supplierName: String?
    private(set) var purchaseOrder: BusinessProcurementPurchaseOrderResponse?
    private(set) var purchaseOrderNumber: String?
    private(set) var isLoading = false
    private(set) var isPerformingAction = false
    private(set) var activeAction: BusinessPurchaseReceiptAction?
    private(set) var hasLoaded = false
    var errorMessage: String?
    var infoMessage: String?
    var referenceWarning: String?

    let organizationId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository
    private let actionIdempotencyKeys: BusinessPurchaseReceiptActionIdempotencyKeys

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        purchaseReceipt: BusinessProcurementPurchaseReceiptResponse,
        supplierName: String? = nil,
        purchaseOrderNumber: String? = nil,
        repository: BusinessProcurementRepository,
        actionIdempotencyKeys: BusinessPurchaseReceiptActionIdempotencyKeys = .generate()
    ) {
        self.organizationId = organizationId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.purchaseReceipt = purchaseReceipt
        self.supplierName = supplierName
        self.purchaseOrderNumber = purchaseOrderNumber
        self.repository = repository
        self.actionIdempotencyKeys = actionIdempotencyKeys
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.purchaseReceiptsView)
    }

    var canEdit: Bool {
        accessPolicy.canEditPurchaseReceipt(status: purchaseReceipt.status) &&
        accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersCostView) &&
        purchaseOrder != nil &&
        purchaseReceipt.lines.allSatisfy { $0.unitCost != nil }
    }

    var canConfirm: Bool {
        accessPolicy.canConfirmPurchaseReceipt(status: purchaseReceipt.status)
    }

    var canCancel: Bool {
        accessPolicy.canCancelPurchaseReceipt(status: purchaseReceipt.status)
    }

    var hasAvailableActions: Bool {
        canEdit || canConfirm || canCancel
    }

    var businessSupplierName: String {
        supplierName?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
            ?? "Proveedor no disponible"
    }

    var businessPurchaseOrderName: String {
        guard purchaseReceipt.purchaseOrderId != nil else { return "Sin orden vinculada" }
        return purchaseOrder?.orderNumber
            ?? purchaseOrderNumber?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty
            ?? "Orden vinculada"
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
            errorMessage = "No tienes permiso para consultar esta recepción de compra."
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.getPurchaseReceipt(
                organizationId: organizationId,
                receiptId: purchaseReceipt.id
            )
            purchaseReceipt = response.data
            await hydrateReferences()
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replace(_ receipt: BusinessProcurementPurchaseReceiptResponse) {
        guard receipt.id == purchaseReceipt.id else { return }
        purchaseReceipt = receipt
        hasLoaded = true
        errorMessage = nil
    }

    func recordEditedReceipt(_ receipt: BusinessProcurementPurchaseReceiptResponse) {
        guard receipt.id == purchaseReceipt.id else { return }
        replace(receipt)
        infoMessage = "Recepción actualizada correctamente."
    }

    func perform(
        action: BusinessPurchaseReceiptAction,
        reason: String? = nil
    ) async -> BusinessProcurementPurchaseReceiptResponse? {
        guard !isPerformingAction else { return nil }
        guard isActionAllowed(action) else {
            errorMessage = "La acción ya no está disponible para el estado actual o tus permisos."
            return nil
        }
        guard purchaseReceipt.version > 0 else {
            errorMessage = "No se encontró una versión válida de la recepción."
            return nil
        }

        let normalizedReason = reason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .receiptNilIfEmpty
        if action == .cancel, normalizedReason == nil {
            errorMessage = "Ingresa el motivo de cancelación."
            return nil
        }

        isPerformingAction = true
        activeAction = action
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer {
            activeAction = nil
            isPerformingAction = false
        }

        do {
            let response = try await repository.performPurchaseReceiptAction(
                organizationId: organizationId,
                receiptId: purchaseReceipt.id,
                action: action,
                idempotencyKey: idempotencyKey(for: action),
                request: BusinessProcurementPurchaseReceiptActionRequest(
                    expectedVersion: purchaseReceipt.version,
                    reason: action == .cancel ? normalizedReason : nil
                )
            )
            purchaseReceipt = response.data
            if action == .confirm {
                await hydrateReferences()
            }
            hasLoaded = true
            infoMessage = actionSuccessMessage(
                action,
                status: response.data.status,
                replayed: response.meta.idempotencyReplayed == true
            )
            return response.data
        } catch let error as APIError {
            errorMessage = purchaseReceiptActionErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func linkedOrderLine(
        for receiptLine: BusinessProcurementPurchaseReceiptLineResponse
    ) -> BusinessProcurementPurchaseOrderLineResponse? {
        guard let orderLineId = receiptLine.purchaseOrderLineId else { return nil }
        return purchaseOrder?.lines.first { $0.id == orderLineId }
    }

    func itemName(for line: BusinessProcurementPurchaseReceiptLineResponse) -> String {
        if let snapshotName = line.itemSnapshot?.localName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .receiptNilIfEmpty {
            return snapshotName
        }
        if let orderName = linkedOrderLine(for: line)?.descriptionSnapshot
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .receiptNilIfEmpty {
            return orderName
        }
        return "Artículo sin nombre disponible"
    }

    private func isActionAllowed(_ action: BusinessPurchaseReceiptAction) -> Bool {
        switch action {
        case .confirm: return canConfirm
        case .cancel: return canCancel
        }
    }

    private func idempotencyKey(for action: BusinessPurchaseReceiptAction) -> IdempotencyKey {
        switch action {
        case .confirm: return actionIdempotencyKeys.confirm
        case .cancel: return actionIdempotencyKeys.cancel
        }
    }

    private func actionSuccessMessage(
        _ action: BusinessPurchaseReceiptAction,
        status: BusinessPurchaseReceiptStatus,
        replayed: Bool
    ) -> String {
        if action == .confirm, status == .confirming {
            return "La confirmación está en proceso. Actualiza el detalle antes de asumir un efecto de inventario."
        }
        if replayed {
            return "La recepción se recuperó de un intento anterior."
        }
        switch action {
        case .confirm:
            return status == .confirmed
                ? "Recepción confirmada correctamente."
                : "El servidor actualizó la recepción. Revisa su estado antes de continuar."
        case .cancel:
            return status == .cancelled
                ? "Recepción cancelada correctamente."
                : "El servidor actualizó la recepción. Revisa su estado antes de continuar."
        }
    }

    private func purchaseReceiptActionErrorMessage(_ error: APIError) -> String {
        let code = error.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "La recepción cambió en el servidor. Actualiza el detalle antes de reintentar."
        case "procurement_state_conflict":
            return "El estado de la recepción cambió. Actualiza el detalle antes de continuar."
        default:
            return error.userMessage
        }
    }

    private func hydrateReferences() async {
        var unresolvedReferenceCount = 0
        purchaseOrder = nil

        if accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersView),
           let orderId = purchaseReceipt.purchaseOrderId {
            do {
                let response = try await repository.getPurchaseOrder(
                    organizationId: organizationId,
                    orderId: orderId
                )
                let order = response.data
                purchaseOrder = order
                purchaseOrderNumber = order.orderNumber
                if order.supplierId == purchaseReceipt.supplierId {
                    supplierName = order.businessSupplierName
                }
            } catch {
                unresolvedReferenceCount += 1
            }
        } else if purchaseReceipt.purchaseOrderId == nil {
            purchaseOrderNumber = nil
        }

        if accessPolicy.allows(BusinessProcurementPermission.suppliersView),
           supplierName?.trimmingCharacters(in: .whitespacesAndNewlines).receiptNilIfEmpty == nil {
            do {
                let response = try await repository.getSupplier(
                    organizationId: organizationId,
                    supplierId: purchaseReceipt.supplierId
                )
                let supplier = response.data
                supplierName = supplier.businessDisplayName
            } catch {
                unresolvedReferenceCount += 1
            }
        }

        let hasUnavailableReference = supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .receiptNilIfEmpty == nil ||
            (purchaseReceipt.purchaseOrderId != nil && purchaseOrderNumber == nil)
        if unresolvedReferenceCount > 0 || hasUnavailableReference {
            referenceWarning = "Parte del contexto de proveedor u orden está protegida o no disponible. El contenido de la recepción proviene del servidor."
        }
    }
}

extension BusinessPurchaseReceiptStatus {
    var businessDisplayName: String {
        switch self {
        case .draft: return "Borrador"
        case .confirming: return "Confirmando"
        case .confirmed: return "Confirmada"
        case .cancelled: return "Cancelada"
        }
    }

    var businessInventoryExplanation: String {
        switch self {
        case .draft:
            return "El borrador todavía no cambia inventario."
        case .confirming:
            return "La confirmación está en proceso; actualiza antes de asumir un efecto de inventario."
        case .confirmed:
            return "La confirmación conserva el efecto autoritativo del backend: solo las cantidades aceptadas de artículos con control de stock generan entrada de inventario, exactamente una vez."
        case .cancelled:
            return "La recepción está cancelada y no genera nuevas entradas de inventario."
        }
    }
}

extension BusinessProcurementPurchaseReceiptResponse {
    var businessLineCountText: String {
        lines.count == 1 ? "1 línea" : "\(lines.count) líneas"
    }

    var businessAttachmentCountText: String {
        attachmentIds.count == 1 ? "1 archivo" : "\(attachmentIds.count) archivos"
    }

    var businessInventoryMovementCountText: String {
        inventoryMovementIds.count == 1
            ? "1 movimiento registrado"
            : "\(inventoryMovementIds.count) movimientos registrados"
    }
}

extension BusinessProcurementPurchaseReceiptLineResponse {
    var businessReceivedQuantityText: String {
        "\(receiptTrimmedDecimal(receivedQuantity.value)) \(receivedQuantity.unitCode)"
    }

    var businessAcceptedQuantityText: String {
        "\(receiptTrimmedDecimal(acceptedQuantity)) \(unitCode)"
    }

    var businessRejectedQuantityText: String {
        "\(receiptTrimmedDecimal(rejectedQuantity)) \(unitCode)"
    }

    var businessTrackedUnitCountText: String {
        trackedUnits.count == 1 ? "1 unidad rastreada" : "\(trackedUnits.count) unidades rastreadas"
    }

    var businessInventoryEvidenceText: String {
        inventoryMovementId == nil
            ? "Sin movimiento de inventario informado"
            : "Movimiento de inventario registrado por el servidor"
    }
}

private func receiptTrimmedDecimal(_ rawValue: String) -> String {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let separator = value.firstIndex(of: ".") else { return value }

    let integer = String(value[..<separator])
    let fractionStart = value.index(after: separator)
    let fraction = String(value[fractionStart...]).replacingOccurrences(
        of: "0+$",
        with: "",
        options: .regularExpression
    )
    return fraction.isEmpty ? integer : "\(integer).\(fraction)"
}

private extension Calendar {
    static var businessProcurementUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private extension String {
    var receiptNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
