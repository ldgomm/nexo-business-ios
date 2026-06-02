//
//  SaleBuilderViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class SaleBuilderViewModel {
    public var catalogItemId = ""
    public var quantity = "1"
    public var cashSessionId: String?
    public private(set) var preview: SalesPreviewResponse?
    public private(set) var createdSale: BusinessSale?
    public var isLoading = false
    public var errorMessage: String?

    private let organizationId: String
    private let branchId: String
    private let activityId: String
    private let revisions: BusinessRevisions
    private let repository: SalesRepository

    public init(
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

    public func loadPreview() async {
        guard validateDraft() else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
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
            print("❌ Preview APIError:", error)
            errorMessage = error.userMessage
        } catch {
            print("❌ Preview Error:", error)
            errorMessage = error.localizedDescription
        }
    }

    public func createQuickSale() async {
        guard validateDraft() else { return }

        isLoading = true
        errorMessage = nil

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
        } catch let error as APIError {
            print("❌ QuickSale APIError:", error)
            errorMessage = error.userMessage
        } catch {
            print("❌ QuickSale Error:", error)
            errorMessage = error.localizedDescription
        }
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
