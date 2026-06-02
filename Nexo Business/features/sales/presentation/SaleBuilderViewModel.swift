//
//  SaleBuilderViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 1/6/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SaleBuilderViewModel {
    var catalogItemId = ""
    var quantity = "1"
    var cashSessionId: String?
    private(set) var preview: SalesPreviewResponse?
    private(set) var createdSale: BusinessSale?
    private(set) var orderState: SaleCartOrderState = .editing
    var isLoading = false
    var errorMessage: String?
    var infoMessage: String?

    private let organizationId: String
    private let branchId: String
    private let activityId: String
    private let revisions: BusinessRevisions
    private let repository: SalesRepository

    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        cashSessionId: String? = nil,
        salesRepository: SalesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
        self.cashSessionId = cashSessionId
        self.repository = salesRepository
    }

    var isOrderLocked: Bool {
        createdSale != nil || orderState == .created
    }

    var canPreview: Bool {
        !catalogItemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading && !isOrderLocked
    }

    var canCreateSale: Bool {
        !catalogItemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading && !isOrderLocked
    }

    func loadPreview() async {
        guard !isOrderLocked else {
            errorMessage = "Esta venta ya fue registrada. Inicia una nueva venta para continuar."
            return
        }

        guard validateDraft() else { return }
        guard !isLoading else { return }

        isLoading = true
        orderState = .previewing
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
            if createdSale == nil {
                orderState = .editing
            }
        }

        do {
            preview = try await repository.preview(
                organizationId: organizationId,
                revisions: revisions,
                request: SalesPreviewRequest(
                    branchId: branchId,
                    activityId: activityId,
                    catalogRevision: revisions.catalogRevision,
                    taxConfigurationRevision: revisions.taxConfigurationRevision,
                    items: draftItems()
                )
            )
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createQuickSale() async {
        guard !isLoading else { return }

        guard createdSale == nil else {
            orderState = .created
            errorMessage = "Esta venta ya fue registrada. Inicia una nueva venta para continuar."
            return
        }

        guard validateDraft() else { return }

        isLoading = true
        orderState = .creating
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
        }

        do {
            let identity = BusinessMutationIdentity.generate(prefix: "quick-sale")
            let response = try await repository.quickSale(
                organizationId: organizationId,
                revisions: revisions,
                idempotencyKey: identity.idempotencyKey,
                request: QuickSaleRequest(
                    requestId: identity.requestId,
                    branchId: branchId,
                    activityId: activityId,
                    cashSessionId: cashSessionId,
                    autoConfirm: true,
                    catalogRevision: revisions.catalogRevision,
                    taxConfigurationRevision: revisions.taxConfigurationRevision,
                    items: draftItems()
                )
            )

            createdSale = response.sale
            preview = nil
            orderState = .created
            infoMessage = response.idempotencyReplayed == true
                ? "Venta recuperada sin duplicar la operación."
                : "Venta registrada. Ahora puedes cobrarla o iniciar una nueva venta."
        } catch let error as APIError {
            orderState = .editing
            errorMessage = error.userMessage
        } catch {
            orderState = .editing
            errorMessage = error.localizedDescription
        }
    }

    func startNewOrder() {
        catalogItemId = ""
        quantity = "1"
        preview = nil
        createdSale = nil
        errorMessage = nil
        infoMessage = nil
        orderState = .editing
    }

    private func draftItems() -> [BusinessSaleItemRequest] {
        [
            BusinessSaleItemRequest(
                catalogItemId: catalogItemId.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: BusinessSaleQuantityRequest(
                    value: normalizedQuantity(quantity),
                    unitCode: "unit",
                    allowsDecimal: false
                ),
                priceTaxMode: BusinessSalePriceTaxMode.taxExclusive.rawValue
            )
        ]
    }

    private func validateDraft() -> Bool {
        if branchId.isEmpty || activityId.isEmpty {
            errorMessage = "Falta sucursal o actividad operativa."
            return false
        }

        if revisions.catalogRevision.isEmpty || revisions.taxConfigurationRevision.isEmpty {
            errorMessage = "Faltan revisiones de catálogo o impuestos. Actualiza el contexto."
            return false
        }

        if catalogItemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Ingresa un producto o servicio."
            return false
        }

        if normalizedQuantity(quantity).isEmpty {
            errorMessage = "Ingresa una cantidad."
            return false
        }

        guard let decimal = Decimal(string: normalizedQuantity(quantity)), decimal > Decimal.zero else {
            errorMessage = "Ingresa una cantidad válida mayor a cero."
            return false
        }

        return true
    }

    private func normalizedQuantity(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
    }
}
