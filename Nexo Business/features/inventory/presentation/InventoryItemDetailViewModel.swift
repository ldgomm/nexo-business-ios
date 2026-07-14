//
//  InventoryItemDetailViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class InventoryItemDetailViewModel {
    private(set) var item: InventoryItem
    private(set) var movements: [InventoryMovement] = []
    private(set) var isLoadingMovements = false
    private(set) var isAdjusting = false
    private(set) var isExportingKardex = false
    private(set) var downloadedKardexFile: BusinessExportDownloadedFile?
    var adjustmentType: InventoryAdjustmentType = .increase
    var adjustmentQuantity = "1"
    var adjustmentReason = InventoryAdjustmentType.increase.defaultReason
    var adjustmentNote = ""
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    private(set) var catalogRevision: String
    let effectivePermissions: Set<String>

    private let repository: InventoryRepository
    private let exportsRepository: BusinessExportsRepository?

    init(
        organizationId: String,
        branchId: String,
        catalogRevision: String,
        item: InventoryItem,
        effectivePermissions: Set<String>,
        inventoryRepository: InventoryRepository,
        exportsRepository: BusinessExportsRepository? = nil
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.catalogRevision = catalogRevision
        self.item = item
        self.effectivePermissions = effectivePermissions
        self.repository = inventoryRepository
        self.exportsRepository = exportsRepository
    }

    var canViewMovements: Bool {
        hasPermission([
            "business.inventory.view_movements",
            "inventory.view_movements",
            "business.inventory.view",
            "inventory.view"
        ])
    }

    var canAdjust: Bool {
        !isAdjusting &&
        item.trackStock &&
        hasPermission([
            "business.inventory.adjust",
            "inventory.adjust"
        ]) &&
        isValidQuantity(adjustmentQuantity) &&
        !normalized(adjustmentReason).isEmpty
    }

    var canExportOperationalKardex: Bool {
        exportsRepository != nil &&
        hasPermission([
            "business.inventory.view_movements",
            "inventory.view_movements",
            "business.inventory.view",
            "inventory.view"
        ]) &&
        hasPermission([
            "business.exports.view",
            "business.exports.download",
            "exports.view",
            "exports.download",
            "reports.export",
            "reports.dashboard.view"
        ])
    }

    var adjustmentReasonPresets: [String] {
        switch adjustmentType {
        case .increase:
            return [
                InventoryAdjustmentType.increase.defaultReason,
                "Devolución de cliente",
                "Corrección de inventario"
            ]
        case .decrease:
            return [
                InventoryAdjustmentType.decrease.defaultReason,
                "Merma o daño",
                "Uso interno",
                "Corrección de inventario"
            ]
        case .set:
            return [
                InventoryAdjustmentType.set.defaultReason,
                "Corrección de inventario"
            ]
        }
    }

    var physicalCountGuidance: String {
        "El conteo físico completo se realizará en Admin Inventory Pro para evitar duplicar el ajuste manual disponible aquí."
    }

    var transferGuidance: String {
        if let warehouseId = item.warehouseId, !warehouseId.isEmpty {
            return "Bodega actual: \(warehouseId). La selección segura de bodega destino se realizará en Admin Inventory Pro."
        }
        return "Este saldo no informa una bodega de origen. La transferencia se realizará en Admin Inventory Pro."
    }

    func exportOperationalKardex() async {
        guard canExportOperationalKardex, let exportsRepository else {
            errorMessage = "No tienes permiso para exportar el Kardex operativo."
            return
        }
        guard !isExportingKardex else { return }

        isExportingKardex = true
        errorMessage = nil
        downloadedKardexFile = nil
        defer { isExportingKardex = false }

        let period = operationalKardexPeriod()
        do {
            downloadedKardexFile = try await exportsRepository.downloadOperationalKardexCSV(
                organizationId: organizationId,
                branchId: branchId,
                itemId: item.catalogItemId,
                warehouseId: item.warehouseId,
                from: period.from,
                to: period.to
            )
            infoMessage = "Kardex operativo listo para compartir."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = "No se pudo exportar el Kardex operativo. Intenta nuevamente."
        }
    }

    private func operationalKardexPeriod() -> (from: String, to: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Guayaquil") ?? .current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -29, to: endDate) ?? endDate
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return (formatter.string(from: startDate), formatter.string(from: endDate))
    }

    func loadMovements() async {
        guard canViewMovements else { return }
        guard !isLoadingMovements else { return }

        isLoadingMovements = true
        errorMessage = nil

        defer {
            isLoadingMovements = false
        }

        do {
            let response = try await repository.listMovements(
                organizationId: organizationId,
                branchId: branchId,
                catalogItemId: item.catalogItemId,
                limit: 30
            )
            movements = response.movements.sorted(by: sortMovements)
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectAdjustmentType(_ type: InventoryAdjustmentType) {
        let knownReasons = InventoryAdjustmentType.allCases
            .map(\.defaultReason) + [
                "Devolución de cliente",
                "Corrección de inventario",
                "Merma o daño",
                "Uso interno"
            ]
        let shouldReplaceReason = normalized(adjustmentReason).isEmpty ||
            knownReasons.contains(normalized(adjustmentReason))
        adjustmentType = type
        if shouldReplaceReason {
            adjustmentReason = type.defaultReason
        }
    }

    func selectAdjustmentReason(_ reason: String) {
        adjustmentReason = normalized(reason)
    }

    func incrementAdjustmentQuantity() {
        stepAdjustmentQuantity(by: 1)
    }

    func decrementAdjustmentQuantity() {
        stepAdjustmentQuantity(by: -1)
    }

    func adjust() async {
        guard !isAdjusting else { return }
        guard canAdjust else {
            errorMessage = validationMessage()
            return
        }

        let catalogIdentity = item

        isAdjusting = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isAdjusting = false
        }

        do {
            let response = try await repository.adjust(
                organizationId: organizationId,
                branchId: branchId,
                catalogItemId: item.catalogItemId,
                catalogRevision: catalogRevision,
                idempotencyKey: .generate(prefix: "inventory-adjust"),
                request: InventoryAdjustmentRequest(
                    branchId: branchId,
                    catalogItemId: item.catalogItemId,
                    adjustmentType: adjustmentType,
                    quantity: normalizedQuantity(adjustmentQuantity),
                    reason: normalized(adjustmentReason),
                    notes: emptyToNil(adjustmentNote)
                )
            )

            item = response.item.displayName == "Producto sin nombre"
                ? response.item.withCatalogIdentity(
                    name: catalogIdentity.name,
                    sku: catalogIdentity.sku,
                    barcode: catalogIdentity.barcode
                )
                : response.item
            if let movement = response.movement {
                upsertMovement(movement)
            }
            if let updatedRevision = response.catalogRevision, !updatedRevision.isEmpty {
                catalogRevision = updatedRevision
            }
            adjustmentQuantity = "1"
            adjustmentReason = adjustmentType.defaultReason
            adjustmentNote = ""
            infoMessage = response.idempotencyReplayed == true
                ? "Ajuste recuperado de un intento anterior."
                : "Inventario actualizado correctamente."
            await refreshAfterAdjustment()
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsertMovement(_ movement: InventoryMovement) {
        if let index = movements.firstIndex(where: { $0.id == movement.id }) {
            movements[index] = movement
        } else {
            movements.append(movement)
        }
        movements.sort(by: sortMovements)
    }

    private func refreshAfterAdjustment() async {
        let currentName = item.name
        let currentSKU = item.sku
        let currentBarcode = item.barcode

        do {
            let response = try await repository.lookupStock(
                organizationId: organizationId,
                branchId: branchId,
                itemId: item.catalogItemId,
                catalogRevision: catalogRevision
            )
            if let confirmedItem = response.item {
                item = confirmedItem.withCatalogIdentity(
                    name: currentName,
                    sku: currentSKU,
                    barcode: currentBarcode
                )
            }
            if let updatedRevision = response.catalogRevision, !updatedRevision.isEmpty {
                catalogRevision = updatedRevision
            }
        } catch {
            infoMessage = "Ajuste guardado. Actualiza para confirmar el saldo más reciente."
        }

        await loadMovements()
    }

    private func sortMovements(_ lhs: InventoryMovement, _ rhs: InventoryMovement) -> Bool {
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

    private func validationMessage() -> String {
        if !item.trackStock {
            return "Este producto no maneja stock."
        }

        if !hasPermission(["business.inventory.adjust", "inventory.adjust"]) {
            return "No tienes permiso para ajustar inventario."
        }

        if !isValidQuantity(adjustmentQuantity) {
            return "Ingresa una cantidad válida mayor que cero."
        }

        if normalized(adjustmentReason).isEmpty {
            return "Ingresa el motivo del ajuste."
        }

        return "No se puede ajustar el inventario con el estado actual."
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

    private func isValidQuantity(_ text: String) -> Bool {
        guard let value = Decimal(
            string: normalizedQuantity(text),
            locale: Locale(identifier: "en_US_POSIX")
        ) else { return false }
        return value > Decimal.zero
    }

    private func normalizedQuantity(_ text: String) -> String {
        normalized(text).replacingOccurrences(of: ",", with: ".")
    }

    private func stepAdjustmentQuantity(by step: Decimal) {
        let current = Decimal(
            string: normalizedQuantity(adjustmentQuantity),
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? .zero
        let next = max(Decimal(1), current + step)
        adjustmentQuantity = NSDecimalNumber(decimal: next).stringValue
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ text: String) -> String? {
        let value = normalized(text)
        return value.isEmpty ? nil : value
    }
}
