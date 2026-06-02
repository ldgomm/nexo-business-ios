//
//  SalesHistoryViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SalesHistoryViewModel {
    private(set) var sales: [BusinessSale] = []
    private(set) var total: Int?
    private(set) var hasMore: Bool?
    private(set) var isLoading = false
    var query = ""
    var selectedStatus: SalesHistoryStatusFilter = .all
    var selectedDate = Date()
    var useDateFilter = true
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let repository: SalesHistoryRepository

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        historyRepository: SalesHistoryRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.repository = historyRepository
    }

    var canSearch: Bool {
        !isLoading && canViewSales && !branchId.isEmpty
    }

    var canViewSales: Bool {
        hasPermission([
            "business.sales.view",
            "sales.view",
            "business.sales.create",
            "sales.create"
        ])
    }

    var hasResults: Bool {
        !sales.isEmpty
    }

    var activeFiltersDescription: String {
        var parts: [String] = []

        if !normalized(query).isEmpty {
            parts.append("Texto: \(normalized(query))")
        }

        if selectedStatus != .all {
            parts.append("Estado: \(selectedStatus.displayName)")
        }

        if useDateFilter {
            parts.append("Fecha: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
        }

        return parts.isEmpty ? "Sin filtros" : parts.joined(separator: " · ")
    }

    func load() async {
        guard canViewSales else {
            sales = []
            errorMessage = "No tienes permiso para consultar ventas."
            return
        }

        guard !branchId.isEmpty else {
            sales = []
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
        }

        do {
            let response = try await repository.searchSales(
                organizationId: organizationId,
                request: SalesHistorySearchRequest(
                    branchId: branchId,
                    query: emptyToNil(query),
                    status: selectedStatus,
                    date: useDateFilter ? selectedDate : nil,
                    limit: 50
                )
            )

            sales = response.sales.sorted(by: sortSales)
            total = response.total
            hasMore = response.hasMore
            infoMessage = sales.isEmpty ? "No encontramos ventas con estos filtros." : nil
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearFilters() {
        query = ""
        selectedStatus = .all
        selectedDate = Date()
        useDateFilter = true
        errorMessage = nil
        infoMessage = nil
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
        switch (lhs.createdAt, rhs.createdAt) {
        case let (left?, right?):
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.id > rhs.id
        }
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

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = normalized(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
