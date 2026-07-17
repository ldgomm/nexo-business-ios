//
//  BusinessPurchaseReceiptFormViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

enum BusinessPurchaseReceiptTrackingType: String, CaseIterable, Identifiable, Sendable {
    case serial = "SERIAL"
    case imei = "IMEI"
    case mac = "MAC"
    case custom = "CUSTOM"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serial: return "Serie"
        case .imei: return "IMEI"
        case .mac: return "MAC"
        case .custom: return "Otro identificador"
        }
    }
}

struct BusinessPurchaseReceiptTrackedUnitDraft: Equatable, Identifiable, Sendable {
    let id: UUID
    var trackingType: String
    var trackingValue: String
    var notes: String

    init(
        id: UUID = UUID(),
        trackingType: String = BusinessPurchaseReceiptTrackingType.serial.rawValue,
        trackingValue: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.trackingType = trackingType
        self.trackingValue = trackingValue
        self.notes = notes
    }

    init(response: BusinessProcurementPurchaseTrackedUnitResponse) {
        self.init(
            trackingType: response.trackingType,
            trackingValue: response.trackingValue,
            notes: response.notes ?? ""
        )
    }
}

struct BusinessPurchaseReceiptLineDraft: Equatable, Identifiable, Sendable {
    let id: UUID
    let serverId: String?
    let purchaseOrderLineId: String?
    let kind: String?
    let catalogItemId: String?
    let displayName: String
    let sku: String?
    let orderedQuantityText: String
    let cumulativeReceivedQuantityText: String
    let unitCode: String
    let allowsDecimal: Bool
    let unitCost: String?
    let unitCostDisplayText: String?
    let warehouseId: String
    var receivedQuantity: String
    var acceptedQuantity: String
    var rejectedQuantity: String
    var trackedUnits: [BusinessPurchaseReceiptTrackedUnitDraft]
    var notes: String

    init(
        id: UUID = UUID(),
        serverId: String? = nil,
        purchaseOrderLineId: String?,
        kind: String?,
        catalogItemId: String?,
        displayName: String,
        sku: String?,
        orderedQuantityText: String,
        cumulativeReceivedQuantityText: String,
        unitCode: String,
        allowsDecimal: Bool,
        unitCost: String?,
        unitCostDisplayText: String?,
        warehouseId: String,
        receivedQuantity: String = "0",
        acceptedQuantity: String = "0",
        rejectedQuantity: String = "0",
        trackedUnits: [BusinessPurchaseReceiptTrackedUnitDraft] = [],
        notes: String = ""
    ) {
        self.id = id
        self.serverId = serverId
        self.purchaseOrderLineId = purchaseOrderLineId
        self.kind = kind
        self.catalogItemId = catalogItemId
        self.displayName = displayName
        self.sku = sku
        self.orderedQuantityText = orderedQuantityText
        self.cumulativeReceivedQuantityText = cumulativeReceivedQuantityText
        self.unitCode = unitCode
        self.allowsDecimal = allowsDecimal
        self.unitCost = unitCost
        self.unitCostDisplayText = unitCostDisplayText
        self.warehouseId = warehouseId
        self.receivedQuantity = receivedQuantity
        self.acceptedQuantity = acceptedQuantity
        self.rejectedQuantity = rejectedQuantity
        self.trackedUnits = trackedUnits
        self.notes = notes
    }

    init(orderLine: BusinessProcurementPurchaseOrderLineResponse, warehouseId: String) {
        self.init(
            purchaseOrderLineId: orderLine.id,
            kind: orderLine.kind,
            catalogItemId: orderLine.catalogItemId,
            displayName: orderLine.descriptionSnapshot,
            sku: orderLine.catalogItemSnapshot?.sku,
            orderedQuantityText: orderLine.businessOrderedQuantityText,
            cumulativeReceivedQuantityText: orderLine.businessReceivedQuantityText,
            unitCode: orderLine.orderedQuantity.unitCode,
            allowsDecimal: orderLine.orderedQuantity.allowsDecimal,
            unitCost: orderLine.unitCost?.amount,
            unitCostDisplayText: orderLine.unitCost?.businessDisplayText(),
            warehouseId: warehouseId
        )
    }

    init(
        receiptLine: BusinessProcurementPurchaseReceiptLineResponse,
        orderLine: BusinessProcurementPurchaseOrderLineResponse?
    ) {
        let displayName = receiptLine.itemSnapshot?.localName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .businessReceiptFormNilIfEmpty
            ?? orderLine?.descriptionSnapshot
            ?? "Artículo de la recepción"
        self.init(
            serverId: receiptLine.id,
            purchaseOrderLineId: receiptLine.purchaseOrderLineId,
            kind: receiptLine.kind,
            catalogItemId: receiptLine.catalogItemId,
            displayName: displayName,
            sku: receiptLine.itemSnapshot?.sku ?? orderLine?.catalogItemSnapshot?.sku,
            orderedQuantityText: orderLine?.businessOrderedQuantityText ?? "No disponible",
            cumulativeReceivedQuantityText: orderLine?.businessReceivedQuantityText ?? "No disponible",
            unitCode: receiptLine.unitCode,
            allowsDecimal: receiptLine.receivedQuantity.allowsDecimal,
            unitCost: receiptLine.unitCost?.amount,
            unitCostDisplayText: receiptLine.unitCost?.businessDisplayText(),
            warehouseId: receiptLine.warehouseId,
            receivedQuantity: receiptLine.receivedQuantity.value,
            acceptedQuantity: receiptLine.acceptedQuantity,
            rejectedQuantity: receiptLine.rejectedQuantity,
            trackedUnits: receiptLine.trackedUnits.map(BusinessPurchaseReceiptTrackedUnitDraft.init(response:)),
            notes: receiptLine.notes ?? ""
        )
    }
}

@MainActor
@Observable
final class BusinessPurchaseReceiptFormViewModel {
    var receivedAt: Date
    var notes: String
    var lines: [BusinessPurchaseReceiptLineDraft]
    private(set) var isSaving = false
    private(set) var savedPurchaseReceipt: BusinessProcurementPurchaseReceiptResponse?
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let supplierName: String
    let purchaseOrderNumber: String
    let warehouseDisplayText: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    private let purchaseOrder: BusinessProcurementPurchaseOrderResponse
    private let purchaseReceiptId: String?
    private let purchaseReceiptStatus: BusinessPurchaseReceiptStatus?
    private let purchaseReceiptContextMatchesOrder: Bool
    private let expectedVersion: Int64?
    private let attachmentIds: [String]
    private let warehouseId: String?
    private let warehouseIssue: String?
    private let hasCompleteCostSnapshot: Bool
    private let hasValidReceivedAtSnapshot: Bool
    private let createIdempotencyKey: IdempotencyKey

    init(
        organizationId: String,
        branchId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        purchaseOrder: BusinessProcurementPurchaseOrderResponse,
        purchaseReceipt: BusinessProcurementPurchaseReceiptResponse? = nil,
        repository: BusinessProcurementRepository,
        createIdempotencyKey: IdempotencyKey? = nil,
        now: Date = Date()
    ) {
        self.organizationId = organizationId
        self.branchId = purchaseReceipt?.branchId ?? branchId
        self.purchaseOrder = purchaseOrder
        self.supplierName = purchaseOrder.businessSupplierName
        self.purchaseOrderNumber = purchaseOrder.orderNumber
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
        self.purchaseReceiptId = purchaseReceipt?.id
        self.purchaseReceiptStatus = purchaseReceipt?.status
        self.purchaseReceiptContextMatchesOrder = purchaseReceipt == nil || (
            purchaseReceipt?.purchaseOrderId == purchaseOrder.id &&
            purchaseReceipt?.supplierId == purchaseOrder.supplierId &&
            purchaseReceipt?.branchId == purchaseOrder.branchId
        )
        self.expectedVersion = purchaseReceipt?.version
        self.attachmentIds = purchaseReceipt?.attachmentIds ?? []
        self.hasCompleteCostSnapshot = purchaseReceipt == nil || purchaseReceipt?.lines.allSatisfy {
            $0.unitCost != nil
        } == true
        self.createIdempotencyKey = createIdempotencyKey ?? .generate(prefix: "purchase-receipt-create")

        let parsedReceivedAt = purchaseReceipt.flatMap { Self.parseInstant($0.receivedAt) }
        self.hasValidReceivedAtSnapshot = purchaseReceipt == nil || parsedReceivedAt != nil
        self.receivedAt = parsedReceivedAt ?? now
        self.notes = purchaseReceipt?.notes ?? ""

        if let purchaseReceipt {
            let normalizedWarehouse = Self.optional(purchaseReceipt.warehouseId)
            self.warehouseId = normalizedWarehouse
            self.warehouseIssue = normalizedWarehouse == nil
                ? "La recepción no contiene una bodega válida y no puede editarse con seguridad."
                : nil
            self.warehouseDisplayText = "Bodega de la recepción"
            self.lines = purchaseReceipt.lines.map { receiptLine in
                let orderLine = receiptLine.purchaseOrderLineId.flatMap { lineId in
                    purchaseOrder.lines.first { $0.id == lineId }
                }
                return BusinessPurchaseReceiptLineDraft(
                    receiptLine: receiptLine,
                    orderLine: orderLine
                )
            }
        } else {
            let targetWarehouses = purchaseOrder.lines.map { Self.optional($0.targetWarehouseId) }
            let distinctWarehouses = Set(targetWarehouses.compactMap { $0 })
            if purchaseOrder.lines.isEmpty {
                self.warehouseId = nil
                self.warehouseIssue = "La orden no contiene líneas para registrar una recepción."
            } else if targetWarehouses.contains(where: { $0 == nil }) {
                self.warehouseId = nil
                self.warehouseIssue = "La orden no define una bodega de destino para todas sus líneas. No se puede crear la recepción sin una bodega explícita."
            } else if distinctWarehouses.count != 1 {
                self.warehouseId = nil
                self.warehouseIssue = "La orden contiene varias bodegas de destino. Registra cada recepción desde una selección de bodega compatible cuando esa fuente esté disponible."
            } else {
                self.warehouseId = distinctWarehouses.first
                self.warehouseIssue = nil
            }
            self.warehouseDisplayText = "Bodega definida por la orden"
            self.lines = purchaseOrder.lines.map { orderLine in
                BusinessPurchaseReceiptLineDraft(
                    orderLine: orderLine,
                    warehouseId: Self.optional(orderLine.targetWarehouseId) ?? ""
                )
            }
        }
    }

    var isEditing: Bool {
        purchaseReceiptId != nil
    }

    var navigationTitle: String {
        isEditing ? "Editar recepción" : "Nueva recepción"
    }

    var saveButtonTitle: String {
        isEditing ? "Guardar cambios" : "Crear borrador"
    }

    var canSave: Bool {
        !isSaving && accessValidationMessage == nil && inputValidationMessage == nil
    }

    var accessValidationMessage: String? {
        guard accessPolicy.isModuleActive else {
            return "El módulo Compras no está activo para esta organización."
        }
        guard !organizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No se encontró una organización válida para la recepción."
        }
        guard !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              branchId == purchaseOrder.branchId else {
            return "La orden no pertenece a la sucursal operativa seleccionada."
        }
        guard let warehouseId, !warehouseId.isEmpty else {
            return warehouseIssue ?? "No se encontró una bodega explícita para la recepción."
        }
        if isEditing {
            guard purchaseReceiptContextMatchesOrder else {
                return "La recepción no coincide con la orden, el proveedor o la sucursal cargados. Actualiza el detalle antes de editar."
            }
            guard let purchaseReceiptStatus,
                  accessPolicy.canEditPurchaseReceipt(status: purchaseReceiptStatus) else {
                return "Solo puedes editar recepciones en borrador cuando tienes el permiso correspondiente."
            }
            guard accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersCostView) else {
                return "La edición requiere permiso para consultar los costos y evitar sobrescribir valores protegidos."
            }
            guard hasCompleteCostSnapshot else {
                return "Actualiza el detalle con acceso a costos antes de editar para no sobrescribir valores protegidos."
            }
            guard let expectedVersion, expectedVersion > 0 else {
                return "No se encontró una versión válida de la recepción."
            }
        } else {
            guard accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersView) else {
                return "Necesitas permiso para consultar la orden antes de registrar su recepción."
            }
            guard accessPolicy.canReceivePurchaseOrder(status: purchaseOrder.status) else {
                return "Solo puedes recibir una orden enviada o parcialmente recibida con el permiso correspondiente."
            }
        }
        return nil
    }

    var inputValidationMessage: String? {
        guard hasValidReceivedAtSnapshot else {
            return "La fecha original de la recepción no tiene un formato válido. Actualiza el detalle antes de editar."
        }
        guard !lines.isEmpty else {
            return "La recepción necesita al menos una línea."
        }

        var hasPositiveLine = false
        var trackedUnitKeys = Set<String>()
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            guard Self.optional(line.unitCode) != nil else {
                return "La línea \(lineNumber) no tiene una unidad válida."
            }
            guard Self.optional(line.warehouseId) != nil else {
                return "La línea \(lineNumber) no contiene una bodega válida y no puede guardarse con seguridad."
            }
            guard let received = decimal(line.receivedQuantity), received >= .zero,
                  let accepted = decimal(line.acceptedQuantity), accepted >= .zero,
                  let rejected = decimal(line.rejectedQuantity), rejected >= .zero else {
                return "Las cantidades de la línea \(lineNumber) deben ser números iguales o mayores que cero."
            }
            if exceedsQuantityScale(line.receivedQuantity) ||
                exceedsQuantityScale(line.acceptedQuantity) ||
                exceedsQuantityScale(line.rejectedQuantity) {
                return "Las cantidades de la línea \(lineNumber) admiten hasta 6 decimales."
            }
            if !line.allowsDecimal,
               (!Self.isWhole(received) || !Self.isWhole(accepted) || !Self.isWhole(rejected)) {
                return "Las cantidades de la línea \(lineNumber) deben ser números enteros."
            }
            guard accepted + rejected == received else {
                return "En la línea \(lineNumber), la cantidad aceptada más la rechazada debe coincidir con la recibida."
            }
            if received > .zero {
                hasPositiveLine = true
            } else if !line.trackedUnits.isEmpty {
                return "La línea \(lineNumber) no puede incluir series o identificadores con cantidad recibida cero."
            }

            for trackedUnit in line.trackedUnits {
                let type = normalized(trackedUnit.trackingType).uppercased()
                guard BusinessPurchaseReceiptTrackingType(rawValue: type) != nil else {
                    return "La línea \(lineNumber) contiene un tipo de rastreo no compatible."
                }
                let value = normalized(trackedUnit.trackingValue)
                guard !value.isEmpty else {
                    return "La línea \(lineNumber) contiene una serie o identificador vacío."
                }
                let key = value.lowercased()
                guard trackedUnitKeys.insert(key).inserted else {
                    return "La serie o identificador \(value) está repetido en la recepción."
                }
            }
        }

        guard hasPositiveLine else {
            return "Ingresa una cantidad recibida mayor que cero en al menos una línea."
        }
        return nil
    }

    func addTrackedUnit(to lineId: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[index].trackedUnits.append(BusinessPurchaseReceiptTrackedUnitDraft())
    }

    func removeTrackedUnit(lineId: UUID, trackedUnitId: UUID) {
        guard let lineIndex = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[lineIndex].trackedUnits.removeAll { $0.id == trackedUnitId }
    }

    func save() async -> BusinessProcurementPurchaseReceiptResponse? {
        guard !isSaving else { return nil }
        if let accessValidationMessage {
            errorMessage = accessValidationMessage
            return nil
        }
        if let inputValidationMessage {
            errorMessage = inputValidationMessage
            return nil
        }

        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        let request = makeRequest()
        do {
            let response: BusinessProcurementPurchaseReceiptEnvelopeResponse
            if let purchaseReceiptId {
                response = try await repository.updatePurchaseReceipt(
                    organizationId: organizationId,
                    receiptId: purchaseReceiptId,
                    request: request
                )
            } else {
                response = try await repository.createPurchaseReceipt(
                    organizationId: organizationId,
                    idempotencyKey: createIdempotencyKey,
                    request: request
                )
            }

            savedPurchaseReceipt = response.data
            if response.meta.idempotencyReplayed == true {
                infoMessage = "Recepción recuperada de un intento anterior."
            } else {
                infoMessage = isEditing
                    ? "Recepción actualizada correctamente."
                    : "Recepción creada como borrador. Todavía no cambia inventario."
            }
            return response.data
        } catch let error as APIError {
            errorMessage = purchaseReceiptErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func makeRequest() -> BusinessProcurementPurchaseReceiptWriteRequest {
        let requestLines = isEditing ? lines : lines.filter {
            (decimal($0.receivedQuantity) ?? .zero) > .zero
        }
        return BusinessProcurementPurchaseReceiptWriteRequest(
            branchId: normalized(branchId),
            supplierId: purchaseOrder.supplierId,
            purchaseOrderId: purchaseOrder.id,
            warehouseId: warehouseId ?? "",
            receivedAt: Self.formatInstant(receivedAt),
            lines: requestLines.map { line in
                BusinessProcurementPurchaseReceiptLineRequest(
                    id: line.serverId,
                    purchaseOrderLineId: line.purchaseOrderLineId,
                    kind: Self.optional(line.kind)?.uppercased(),
                    catalogItemId: line.catalogItemId,
                    receivedQuantity: normalizedDecimal(line.receivedQuantity),
                    acceptedQuantity: normalizedDecimal(line.acceptedQuantity),
                    rejectedQuantity: normalizedDecimal(line.rejectedQuantity),
                    unitCode: normalized(line.unitCode),
                    allowsDecimal: line.allowsDecimal,
                    unitCost: line.unitCost.map(normalizedDecimal),
                    warehouseId: normalized(line.warehouseId),
                    trackedUnits: line.trackedUnits.map { trackedUnit in
                        BusinessProcurementPurchaseTrackedUnitRequest(
                            trackingType: normalized(trackedUnit.trackingType).uppercased(),
                            trackingValue: normalized(trackedUnit.trackingValue),
                            notes: Self.optional(trackedUnit.notes)
                        )
                    },
                    notes: Self.optional(line.notes)
                )
            },
            notes: Self.optional(notes),
            attachmentIds: attachmentIds,
            expectedVersion: expectedVersion
        )
    }

    private func purchaseReceiptErrorMessage(_ error: APIError) -> String {
        let code = error.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "La recepción cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        case "procurement_state_conflict":
            return "El estado de la recepción cambió. Actualiza el detalle antes de continuar."
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

    private func exceedsQuantityScale(_ value: String) -> Bool {
        let normalizedValue = normalizedDecimal(value)
        guard let separator = normalizedValue.firstIndex(of: ".") else { return false }
        return normalizedValue.distance(from: normalizedValue.index(after: separator), to: normalizedValue.endIndex) > 6
    }

    private static func isWhole(_ value: Decimal) -> Bool {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return rounded == value
    }

    private static func optional(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .businessReceiptFormNilIfEmpty
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

    private static func formatInstant(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

private extension String {
    var businessReceiptFormNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
