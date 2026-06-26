//
//  UnpaidSalesListViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 25/6/26.
//

import SwiftUI

@MainActor
@Observable
class UnpaidSalesListViewModel {
    private(set) var sales: [BusinessSale] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let pendingRepository: PendingOperationsRepository
    private var lastLoadedAt: Date?

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        pendingRepository: PendingOperationsRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.pendingRepository = pendingRepository
    }

    var canView: Bool {
        hasPermission([
            "business.sales.view",
            "sales.view",
            "business.sales.create",
            "sales.create"
        ])
    }

    func loadIfNeeded() async {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < 8, !sales.isEmpty {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard canView else {
            sales = []
            errorMessage = "No tienes permiso para consultar ventas sin cobrar."
            return
        }

        guard !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            sales = []
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
            lastLoadedAt = Date()
        }

        do {
            let response = try await pendingRepository.pendingSales(
                organizationId: organizationId,
                branchId: branchId,
                limit: 100
            )

            sales = response.sales
                .filter { $0.isSavedSaleWithoutReceivable }
                .sorted(by: sortSales)
            infoMessage = sales.isEmpty ? "No hay ventas guardadas o sin cobrar." : nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeSaleDetailViewModel(
        for sale: BusinessSale,
        salesRepository: SalesRepository
    ) -> SaleDetailViewModel {
        SaleDetailViewModel(
            organizationId: organizationId,
            saleId: sale.id,
            revisions: revisions,
            initialSale: sale,
            effectivePermissions: effectivePermissions,
            salesRepository: salesRepository
        )
    }

    private func sortSales(_ lhs: BusinessSale, _ rhs: BusinessSale) -> Bool {
        (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }
}

