//
//  SaleBuilderViewModel.swift
//  Nexo Admin
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
        salesRepository: SalesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
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
                    items: draftItems()
                )
            )
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
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
            let response = try await repository.quickSale(
                organizationId: organizationId,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "quick-sale"),
                request: QuickSaleRequest(
                    branchId: branchId,
                    activityId: activityId,
                    items: draftItems()
                )
            )

            createdSale = response.sale
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func draftItems() -> [SaleDraftItem] {
        [
            SaleDraftItem(
                catalogItemId: catalogItemId.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        ]
    }

    private func validateDraft() -> Bool {
        if branchId.isEmpty || activityId.isEmpty {
            errorMessage = "Falta sucursal o actividad operativa."
            return false
        }

        if catalogItemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Ingresa un producto o servicio."
            return false
        }

        if quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Ingresa una cantidad."
            return false
        }

        return true
    }
}
