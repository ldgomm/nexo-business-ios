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
public final class InventoryItemDetailViewModel {
    public private(set) var item: InventoryItem
    public private(set) var movements: [InventoryMovement] = []
    public private(set) var isLoadingMovements = false
    public private(set) var isAdjusting = false
    public var adjustmentType: InventoryAdjustmentType = .increase
    public var adjustmentQuantity = ""
    public var adjustmentReason = ""
    public var adjustmentNote = ""
    public var errorMessage: String?
    public var infoMessage: String?

    public let organizationId: String
    public private(set) var catalogRevision: String
    public let effectivePermissions: Set<String>

    private let repository: InventoryRepository

    public init(
        organizationId: String,
        catalogRevision: String,
        item: InventoryItem,
        effectivePermissions: Set<String>,
        inventoryRepository: InventoryRepository
    ) {
        self.organizationId = organizationId
        self.catalogRevision = catalogRevision
        self.item = item
        self.effectivePermissions = effectivePermissions
        self.repository = inventoryRepository
    }

    public var canViewMovements: Bool {
        hasPermission([
            "business.inventory.view_movements",
            "inventory.view_movements",
            "business.inventory.view",
            "inventory.view"
        ])
    }

    public var canAdjust: Bool {
        !isAdjusting &&
        item.trackStock &&
        hasPermission([
            "business.inventory.adjust",
            "inventory.adjust"
        ]) &&
        isValidQuantity(adjustmentQuantity) &&
        !normalized(adjustmentReason).isEmpty
    }

    public func loadMovements() async {
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
                inventoryItemId: item.id,
                limit: 30
            )
            movements = response.movements.sorted(by: sortMovements)
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func adjust() async {
        guard canAdjust else {
            errorMessage = validationMessage()
            return
        }

        isAdjusting = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isAdjusting = false
        }

        do {
            let response = try await repository.adjust(
                organizationId: organizationId,
                inventoryItemId: item.id,
                catalogRevision: catalogRevision,
                idempotencyKey: .generate(prefix: "inventory-adjust"),
                request: InventoryAdjustmentRequest(
                    type: adjustmentType,
                    quantity: normalizedQuantity(adjustmentQuantity),
                    reason: normalized(adjustmentReason),
                    note: emptyToNil(adjustmentNote)
                )
            )

            item = response.item
            if let movement = response.movement {
                upsertMovement(movement)
            }
            if let updatedRevision = response.catalogRevision, !updatedRevision.isEmpty {
                catalogRevision = updatedRevision
            }
            adjustmentQuantity = ""
            adjustmentReason = ""
            adjustmentNote = ""
            infoMessage = response.idempotencyReplayed == true
                ? "Ajuste recuperado de un intento anterior."
                : "Inventario actualizado correctamente."
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
            return "Ingresa una cantidad válida mayor o igual a cero."
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
        candidates.contains { effectivePermissions.contains($0) }
    }

    private func isValidQuantity(_ text: String) -> Bool {
        guard let value = Decimal(
            string: normalizedQuantity(text),
            locale: Locale(identifier: "en_US_POSIX")
        ) else { return false }
        return value >= Decimal.zero
    }

    private func normalizedQuantity(_ text: String) -> String {
        normalized(text).replacingOccurrences(of: ",", with: ".")
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ text: String) -> String? {
        let value = normalized(text)
        return value.isEmpty ? nil : value
    }
}
