//
//  InventoryDashboardViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class InventoryDashboardViewModelTests: XCTestCase {
    func testLoadItemsUpdatesStateAndCounts() async {
        let repository = InventoryRepositorySpy(
            itemsResponse: InventoryItemsResponse(
                items: [makeItem()],
                catalogRevision: "cat_rev_002",
                totalCount: 1,
                lowStockCount: 0,
                outOfStockCount: 0
            )
        )
        let viewModel = makeDashboard(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.state, .loaded([makeItem()]))
        XCTAssertEqual(viewModel.catalogRevision, "cat_rev_002")
        XCTAssertEqual(viewModel.totalCount, 1)
        XCTAssertEqual(repository.lastQuery, "")
    }

    func testLoadRequiresInventoryPermission() async {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = InventoryDashboardViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1",
            catalogRevision: "cat_rev_001",
            effectivePermissions: [],
            inventoryRepository: repository
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar inventario.")
        XCTAssertNil(repository.lastQuery)
    }

    func testDetailViewModelKeepsContext() {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = makeDashboard(repository: repository)
        let detail = viewModel.makeDetailViewModel(for: makeItem())

        XCTAssertEqual(detail.organizationId, "org_1")
        XCTAssertEqual(detail.catalogRevision, "cat_rev_001")
    }

    private func makeDashboard(repository: InventoryRepositorySpy) -> InventoryDashboardViewModel {
        InventoryDashboardViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1",
            catalogRevision: "cat_rev_001",
            effectivePermissions: ["business.inventory.view", "business.inventory.adjust"],
            inventoryRepository: repository
        )
    }
}

@MainActor
final class InventoryItemDetailViewModelTests: XCTestCase {
    func testLoadMovements() async {
        let movement = InventoryMovement(
            id: "mov_1",
            inventoryItemId: "inv_1",
            type: "increase",
            quantity: InventoryQuantity(quantity: "5"),
            reason: "Reposición"
        )
        let repository = InventoryRepositorySpy(
            itemsResponse: InventoryItemsResponse(items: []),
            movementsResponse: InventoryMovementsResponse(movements: [movement])
        )
        let viewModel = makeDetail(repository: repository)

        await viewModel.loadMovements()

        XCTAssertEqual(viewModel.movements, [movement])
    }

    func testAdjustRequiresPermission() async {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = InventoryItemDetailViewModel(
            organizationId: "org_1",
            catalogRevision: "cat_rev_001",
            item: makeItem(),
            effectivePermissions: [],
            inventoryRepository: repository
        )
        viewModel.adjustmentQuantity = "10"
        viewModel.adjustmentReason = "Reposición"

        await viewModel.adjust()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para ajustar inventario.")
        XCTAssertNil(repository.lastAdjustmentRequest)
    }

    func testAdjustSendsIdempotencyAndUpdatesItem() async {
        let updated = InventoryItem(
            id: "inv_1",
            catalogItemId: "item_1",
            name: "Cuy entero",
            stockStatus: "active",
            available: InventoryQuantity(quantity: "10")
        )
        let repository = InventoryRepositorySpy(
            itemsResponse: InventoryItemsResponse(items: []),
            adjustmentResponse: InventoryAdjustmentResponse(
                item: updated,
                movement: InventoryMovement(
                    id: "mov_1",
                    inventoryItemId: "inv_1",
                    type: "set",
                    quantity: InventoryQuantity(quantity: "10"),
                    reason: "Conteo físico"
                ),
                catalogRevision: "cat_rev_002",
                idempotencyReplayed: false
            )
        )
        let viewModel = makeDetail(repository: repository)
        viewModel.adjustmentType = .set
        viewModel.adjustmentQuantity = "10,00"
        viewModel.adjustmentReason = "Conteo físico"

        await viewModel.adjust()

        XCTAssertEqual(repository.lastAdjustmentRequest?.type, .set)
        XCTAssertEqual(repository.lastAdjustmentRequest?.quantity, "10.00")
        XCTAssertEqual(repository.lastAdjustmentRequest?.reason, "Conteo físico")
        XCTAssertTrue(repository.lastIdempotencyKey?.rawValue.hasPrefix("inventory-adjust-") == true)
        XCTAssertEqual(viewModel.item, updated)
        XCTAssertEqual(viewModel.catalogRevision, "cat_rev_002")
        XCTAssertEqual(viewModel.infoMessage, "Inventario actualizado correctamente.")
    }

    private func makeDetail(repository: InventoryRepositorySpy) -> InventoryItemDetailViewModel {
        InventoryItemDetailViewModel(
            organizationId: "org_1",
            catalogRevision: "cat_rev_001",
            item: makeItem(),
            effectivePermissions: ["business.inventory.view", "business.inventory.adjust"],
            inventoryRepository: repository
        )
    }
}

private func makeItem() -> InventoryItem {
    InventoryItem(
        id: "inv_1",
        catalogItemId: "item_1",
        name: "Cuy entero",
        sku: "CUY-ENTERO",
        status: "active",
        stockStatus: "active",
        trackStock: true,
        available: InventoryQuantity(quantity: "5", unitCode: "unit", unitName: "Unidad"),
        lowStockThreshold: InventoryQuantity(quantity: "2", unitCode: "unit", unitName: "Unidad")
    )
}

private final class InventoryRepositorySpy: InventoryRepository, @unchecked Sendable {
    var itemsResponse: InventoryItemsResponse
    var movementsResponse: InventoryMovementsResponse
    var adjustmentResponse: InventoryAdjustmentResponse?
    var lastQuery: String?
    var lastStockStatus: InventoryItemStockStatus?
    var lastAdjustmentRequest: InventoryAdjustmentRequest?
    var lastIdempotencyKey: IdempotencyKey?

    init(
        itemsResponse: InventoryItemsResponse,
        movementsResponse: InventoryMovementsResponse = InventoryMovementsResponse(movements: []),
        adjustmentResponse: InventoryAdjustmentResponse? = nil
    ) {
        self.itemsResponse = itemsResponse
        self.movementsResponse = movementsResponse
        self.adjustmentResponse = adjustmentResponse
    }

    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        limit: Int
    ) async throws -> InventoryItemsResponse {
        lastQuery = query
        lastStockStatus = stockStatus
        return itemsResponse
    }

    func listMovements(
        organizationId: String,
        inventoryItemId: String,
        limit: Int
    ) async throws -> InventoryMovementsResponse {
        movementsResponse
    }

    func adjust(
        organizationId: String,
        inventoryItemId: String,
        catalogRevision: String,
        idempotencyKey: IdempotencyKey,
        request: InventoryAdjustmentRequest
    ) async throws -> InventoryAdjustmentResponse {
        lastAdjustmentRequest = request
        lastIdempotencyKey = idempotencyKey
        return adjustmentResponse ?? InventoryAdjustmentResponse(item: makeItem())
    }
}
