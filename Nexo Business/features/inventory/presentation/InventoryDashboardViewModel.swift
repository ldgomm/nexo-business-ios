//
//  InventoryDashboardViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class InventoryDashboardViewModel {
    private(set) var state: AsyncViewState<[InventoryItem]> = .idle
    private(set) var items: [InventoryItem] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isExportingKardex = false
    private(set) var downloadedKardexFile: BusinessExportDownloadedFile?
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    var searchQuery = ""
    var stockStatus: InventoryItemStockStatus = .all
    var errorMessage: String?
    var infoMessage: String?
    var lowStockCount: Int?
    var outOfStockCount: Int?
    var totalCount: Int?

    let organizationId: String
    let branchId: String
    let activityId: String
    private(set) var catalogRevision: String
    let effectivePermissions: Set<String>

    private let repository: InventoryRepository
    private let exportsRepository: BusinessExportsRepository?

    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        effectivePermissions: Set<String>,
        inventoryRepository: InventoryRepository,
        exportsRepository: BusinessExportsRepository? = nil
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.catalogRevision = catalogRevision
        self.effectivePermissions = effectivePermissions
        self.repository = inventoryRepository
        self.exportsRepository = exportsRepository
    }

    var canView: Bool {
        hasPermission([
            "business.inventory.view",
            "inventory.view",
            "business.inventory.adjust",
            "inventory.adjust"
        ])
    }

    var canAdjust: Bool {
        hasPermission([
            "business.inventory.adjust",
            "inventory.adjust"
        ])
    }

    var canExportConsolidatedKardex: Bool {
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

    func load() async {
        guard canView else {
            errorMessage = "No tienes permiso para consultar inventario."
            state = .failed(errorMessage ?? "")
            return
        }

        guard validateContext() else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        nextCursor = nil
        hasMore = false
        state = .loading

        defer {
            isLoading = false
        }

        do {
            let response = try await repository.listItems(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: catalogRevision,
                query: searchQuery,
                stockStatus: stockStatus,
                cursor: nil,
                limit: 50
            )

            items = response.items
            totalCount = response.totalCount ?? response.items.count
            lowStockCount = response.lowStockCount
            outOfStockCount = response.outOfStockCount
            nextCursor = response.nextCursor
            hasMore = response.hasMore

            if let updatedRevision = response.catalogRevision, !updatedRevision.isEmpty {
                catalogRevision = updatedRevision
            }

            state = .loaded(response.items)
            infoMessage = response.items.isEmpty ? "No hay productos que coincidan con el filtro." : nil
        } catch let error as APIError {
            handle(apiError: error)
            state = .failed(error.userMessage)
        } catch {
            errorMessage = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        await load()
    }

    func exportConsolidatedKardex() async {
        guard canExportConsolidatedKardex, let exportsRepository else {
            errorMessage = "No tienes permiso para exportar el Kardex operativo."
            return
        }
        guard validateContext(), !isExportingKardex else { return }
        isExportingKardex = true
        errorMessage = nil
        infoMessage = nil
        downloadedKardexFile = nil
        defer { isExportingKardex = false }
        let period = Self.defaultKardexPeriod()
        do {
            downloadedKardexFile = try await exportsRepository.downloadConsolidatedKardexCSV(
                organizationId: organizationId, branchId: branchId, activityId: activityId,
                warehouseId: nil, movementType: nil, from: period.from, to: period.to
            )
            infoMessage = "Kardex consolidado listo para compartir."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = "No se pudo exportar el Kardex consolidado. Intenta nuevamente."
        }
    }

    func loadMore() async {
        guard canView, hasMore, let cursor = nextCursor, !isLoading, !isLoadingMore else { return }
        guard validateContext() else { return }

        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await repository.listItems(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: catalogRevision,
                query: searchQuery,
                stockStatus: stockStatus,
                cursor: cursor,
                limit: 50
            )
            let knownIds = Set(items.map(\.id))
            items.append(contentsOf: response.items.filter { !knownIds.contains($0.id) })
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            totalCount = response.totalCount ?? items.count
            lowStockCount = response.lowStockCount ?? lowStockCount
            outOfStockCount = response.outOfStockCount ?? outOfStockCount
            if let updatedRevision = response.catalogRevision, !updatedRevision.isEmpty {
                catalogRevision = updatedRevision
            }
            state = .loaded(items)
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeDetailViewModel(for item: InventoryItem) -> InventoryItemDetailViewModel {
        InventoryItemDetailViewModel(
            organizationId: organizationId,
            branchId: branchId,
            catalogRevision: catalogRevision,
            item: item,
            effectivePermissions: effectivePermissions,
            inventoryRepository: repository,
            exportsRepository: exportsRepository
        )
    }

    func updateItem(_ item: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            state = .loaded(items)
        }
    }

    private func validateContext() -> Bool {
        if organizationId.isEmpty || branchId.isEmpty || activityId.isEmpty {
            errorMessage = "Falta organización, sucursal o actividad operativa. Actualiza el contexto."
            state = .failed(errorMessage ?? "")
            return false
        }

        if catalogRevision.isEmpty {
            errorMessage = "Falta la revisión de catálogo. Actualiza el contexto."
            state = .failed(errorMessage ?? "")
            return false
        }

        return true
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

    private static func defaultKardexPeriod() -> (from: String, to: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Guayaquil") ?? .current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -29, to: end) ?? end
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return (formatter.string(from: start), formatter.string(from: end))
    }
}
