//
//  BusinessPurchaseOrdersViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessPurchaseOrdersViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case draft
        case sent
        case partiallyReceived
        case received
        case cancelled
        case closed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .draft: return "Borradores"
            case .sent: return "Enviadas"
            case .partiallyReceived: return "Recepción parcial"
            case .received: return "Recibidas"
            case .cancelled: return "Canceladas"
            case .closed: return "Cerradas"
            }
        }

        var apiValues: [BusinessPurchaseOrderStatus] {
            switch self {
            case .all: return []
            case .draft: return [.draft]
            case .sent: return [.sent]
            case .partiallyReceived: return [.partiallyReceived]
            case .received: return [.received]
            case .cancelled: return [.cancelled]
            case .closed: return [.closed]
            }
        }
    }

    private(set) var purchaseOrders: [BusinessProcurementPurchaseOrderResponse] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var nextCursor: String?
    private(set) var hasLoaded = false
    var query = ""
    var expectedFrom = ""
    var expectedTo = ""
    var statusFilter: StatusFilter = .all
    var errorMessage: String?
    var infoMessage: String?

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
        self.branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines).businessNilIfEmpty
        self.supplierId = supplierId?.trimmingCharacters(in: .whitespacesAndNewlines).businessNilIfEmpty
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersView)
    }

    var canViewCosts: Bool {
        accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersCostView)
    }

    var canCreate: Bool {
        accessPolicy.canCreatePurchaseOrder &&
        accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersCostView)
    }

    var hasActiveFilters: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !expectedFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !expectedTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
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
        query = ""
        expectedFrom = ""
        expectedTo = ""
        statusFilter = .all
        await load(reset: true)
    }

    func loadNextPageIfNeeded(currentOrder: BusinessProcurementPurchaseOrderResponse) async {
        guard currentOrder.id == purchaseOrders.last?.id else { return }
        guard hasLoaded, hasMore, nextCursor != nil else { return }
        await load(reset: false)
    }

    func replace(_ order: BusinessProcurementPurchaseOrderResponse) {
        if let index = purchaseOrders.firstIndex(where: { $0.id == order.id }) {
            purchaseOrders[index] = order
        } else {
            purchaseOrders.insert(order, at: 0)
        }
    }

    private func load(reset: Bool) async {
        guard validateAccess() else { return }
        guard !isLoading else { return }
        guard let dateRange = validatedDateRange() else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            let response = try await repository.listPurchaseOrders(
                organizationId: organizationId,
                filters: BusinessProcurementPurchaseOrderFilters(
                    branchId: branchId,
                    supplierId: supplierId,
                    statuses: statusFilter.apiValues,
                    expectedFrom: dateRange.from,
                    expectedTo: dateRange.to,
                    query: query.trimmingCharacters(in: .whitespacesAndNewlines).businessNilIfEmpty,
                    limit: 50,
                    cursor: reset ? nil : nextCursor
                )
            )

            if reset {
                purchaseOrders = response.purchaseOrders
            } else {
                appendUnique(response.purchaseOrders)
            }
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            hasLoaded = true
            infoMessage = purchaseOrders.isEmpty
                ? "No encontramos órdenes de compra con estos filtros."
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
            errorMessage = "No tienes permiso para consultar órdenes de compra."
            infoMessage = nil
            return false
        }
        return true
    }

    private func validatedDateRange() -> (from: String?, to: String?)? {
        let from = expectedFrom.trimmingCharacters(in: .whitespacesAndNewlines).businessNilIfEmpty
        let to = expectedTo.trimmingCharacters(in: .whitespacesAndNewlines).businessNilIfEmpty

        if let from, !Self.isValidDateOnly(from) {
            errorMessage = "La fecha esperada inicial debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let to, !Self.isValidDateOnly(to) {
            errorMessage = "La fecha esperada final debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let from, let to, from > to {
            errorMessage = "La fecha esperada inicial no puede ser posterior a la final."
            infoMessage = nil
            return nil
        }
        return (from, to)
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

    private func appendUnique(_ page: [BusinessProcurementPurchaseOrderResponse]) {
        var knownIds = Set(purchaseOrders.map(\.id))
        for order in page where knownIds.insert(order.id).inserted {
            purchaseOrders.append(order)
        }
    }
}

struct BusinessPurchaseOrderActionIdempotencyKeys: Equatable, Sendable {
    let send: IdempotencyKey
    let cancel: IdempotencyKey
    let close: IdempotencyKey

    static func generate() -> BusinessPurchaseOrderActionIdempotencyKeys {
        BusinessPurchaseOrderActionIdempotencyKeys(
            send: .generate(prefix: "purchase-order-send"),
            cancel: .generate(prefix: "purchase-order-cancel"),
            close: .generate(prefix: "purchase-order-close")
        )
    }
}

@MainActor
@Observable
final class BusinessPurchaseOrderDetailViewModel {
    private(set) var purchaseOrder: BusinessProcurementPurchaseOrderResponse
    private(set) var isLoading = false
    private(set) var isPerformingAction = false
    private(set) var activeAction: BusinessPurchaseOrderAction?
    private(set) var hasLoaded = false
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository
    private let actionIdempotencyKeys: BusinessPurchaseOrderActionIdempotencyKeys

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        purchaseOrder: BusinessProcurementPurchaseOrderResponse,
        repository: BusinessProcurementRepository,
        actionIdempotencyKeys: BusinessPurchaseOrderActionIdempotencyKeys = .generate()
    ) {
        self.organizationId = organizationId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.purchaseOrder = purchaseOrder
        self.repository = repository
        self.actionIdempotencyKeys = actionIdempotencyKeys
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersView)
    }

    var canViewCosts: Bool {
        accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersCostView)
    }

    var canEdit: Bool {
        accessPolicy.canEditPurchaseOrder(status: purchaseOrder.status) &&
        canViewCosts &&
        purchaseOrder.lines.allSatisfy { $0.unitCost != nil && $0.discountAmount != nil }
    }

    var canSend: Bool {
        accessPolicy.canSendPurchaseOrder(status: purchaseOrder.status) && canViewCosts
    }

    var canCancel: Bool {
        accessPolicy.canCancelPurchaseOrder(status: purchaseOrder.status)
    }

    var canClose: Bool {
        accessPolicy.canClosePurchaseOrder(status: purchaseOrder.status)
    }

    var canReceive: Bool {
        accessPolicy.canReceivePurchaseOrder(status: purchaseOrder.status)
    }

    var canViewLinkedReceipts: Bool {
        accessPolicy.allows(BusinessProcurementPermission.purchaseReceiptsView)
    }

    var hasAvailableActions: Bool {
        canEdit || canSend || canCancel || canClose || canReceive
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
            errorMessage = "No tienes permiso para consultar esta orden de compra."
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            let response = try await repository.getPurchaseOrder(
                organizationId: organizationId,
                orderId: purchaseOrder.id
            )
            purchaseOrder = response.data
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replace(_ order: BusinessProcurementPurchaseOrderResponse) {
        guard order.id == purchaseOrder.id else { return }
        purchaseOrder = order
        hasLoaded = true
        errorMessage = nil
    }

    func recordCreatedReceipt(_ receipt: BusinessProcurementPurchaseReceiptResponse) {
        guard receipt.purchaseOrderId == purchaseOrder.id else { return }
        errorMessage = nil
        infoMessage = "Recepción \(receipt.receiptNumber) creada como borrador. Revisa y confirma la recepción para que el backend aplique el efecto de inventario."
    }

    func perform(
        action: BusinessPurchaseOrderAction,
        reason: String? = nil
    ) async -> BusinessProcurementPurchaseOrderResponse? {
        guard !isPerformingAction else { return nil }
        guard isActionAllowed(action) else {
            errorMessage = "La acción ya no está disponible para el estado actual o tus permisos."
            return nil
        }
        guard purchaseOrder.version > 0 else {
            errorMessage = "No se encontró una versión válida de la orden."
            return nil
        }

        let normalizedReason = reason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .businessNilIfEmpty
        if action != .send, normalizedReason == nil {
            errorMessage = action == .cancel
                ? "Ingresa el motivo de cancelación."
                : "Ingresa el motivo de cierre."
            return nil
        }

        isPerformingAction = true
        activeAction = action
        errorMessage = nil
        infoMessage = nil
        defer {
            activeAction = nil
            isPerformingAction = false
        }

        do {
            let response = try await repository.performPurchaseOrderAction(
                organizationId: organizationId,
                orderId: purchaseOrder.id,
                action: action,
                idempotencyKey: idempotencyKey(for: action),
                request: BusinessProcurementPurchaseOrderActionRequest(
                    expectedVersion: purchaseOrder.version,
                    reason: normalizedReason
                )
            )
            purchaseOrder = response.data
            hasLoaded = true
            infoMessage = actionSuccessMessage(
                action,
                replayed: response.meta.idempotencyReplayed == true
            )
            return response.data
        } catch let error as APIError {
            errorMessage = purchaseOrderActionErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func isActionAllowed(_ action: BusinessPurchaseOrderAction) -> Bool {
        switch action {
        case .send: return canSend
        case .cancel: return canCancel
        case .close: return canClose
        }
    }

    private func idempotencyKey(for action: BusinessPurchaseOrderAction) -> IdempotencyKey {
        switch action {
        case .send: return actionIdempotencyKeys.send
        case .cancel: return actionIdempotencyKeys.cancel
        case .close: return actionIdempotencyKeys.close
        }
    }

    private func actionSuccessMessage(
        _ action: BusinessPurchaseOrderAction,
        replayed: Bool
    ) -> String {
        if replayed {
            return "La orden se recuperó de un intento anterior."
        }
        switch action {
        case .send: return "Orden enviada correctamente."
        case .cancel: return "Orden cancelada correctamente."
        case .close: return "Orden cerrada correctamente."
        }
    }

    private func purchaseOrderActionErrorMessage(_ error: APIError) -> String {
        let code = error.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "La orden cambió en el servidor. Actualiza el detalle antes de reintentar."
        case "procurement_state_conflict":
            return "El estado de la orden cambió. Actualiza el detalle antes de continuar."
        default:
            return error.userMessage
        }
    }
}

extension BusinessPurchaseOrderStatus {
    var businessDisplayName: String {
        switch self {
        case .draft: return "Borrador"
        case .sent: return "Enviada"
        case .partiallyReceived: return "Parcialmente recibida"
        case .received: return "Recibida"
        case .cancelled: return "Cancelada"
        case .closed: return "Cerrada"
        }
    }
}

extension BusinessProcurementSupplierSnapshotResponse {
    var businessDisplayName: String {
        tradeName?.trimmingCharacters(in: .whitespacesAndNewlines).businessNilIfEmpty ?? legalName
    }

    var businessLegalNameDetail: String? {
        let normalizedTradeName = tradeName?.trimmingCharacters(in: .whitespacesAndNewlines).businessNilIfEmpty
        guard normalizedTradeName != nil, normalizedTradeName != legalName else { return nil }
        return legalName
    }
}

extension BusinessProcurementPurchaseOrderResponse {
    var businessSupplierName: String {
        supplierSnapshot.businessDisplayName
    }

    var businessLineCountText: String {
        lines.count == 1 ? "1 línea" : "\(lines.count) líneas"
    }
}

extension BusinessProcurementPurchaseOrderLineResponse {
    var businessOrderedQuantityText: String {
        "\(businessTrimmedDecimal(orderedQuantity.value)) \(orderedQuantity.unitCode)"
    }

    var businessReceivedQuantityText: String {
        "\(businessTrimmedDecimal(receivedQuantity)) \(orderedQuantity.unitCode)"
    }
}

extension BusinessProcurementMoneyResponse {
    func businessDisplayText(locale: Locale = .current) -> String {
        guard let decimal = Decimal(
            string: amount,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return "\(currency) \(businessTrimmedDecimal(amount))"
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: decimal as NSDecimalNumber)
            ?? "\(currency) \(businessTrimmedDecimal(amount))"
    }
}

private func businessTrimmedDecimal(_ rawValue: String) -> String {
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

private extension String {
    var businessNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
