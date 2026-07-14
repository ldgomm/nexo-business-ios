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
    func testOverviewResponseDecodesIdentityProfileAndPaging() throws {
        let json = """
        {
          "stock": [{
            "id": "item_1",
            "branchId": null,
            "itemId": "item_1",
            "catalogItemId": "item_1",
            "name": "Cuy entero",
            "sku": "CUY-ENTERO",
            "status": "untracked",
            "tracksInventory": false,
            "hasStockProfile": false,
            "quantityAvailable": "0",
            "stockUnit": "unit"
          }],
          "nextCursor": "item_1",
          "hasMore": true
        }
        """

        let response = try JSONDecoder().decode(InventoryItemsResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.items.first?.name, "Cuy entero")
        XCTAssertEqual(response.items.first?.sku, "CUY-ENTERO")
        XCTAssertEqual(response.items.first?.hasStockProfile, false)
        XCTAssertEqual(response.nextCursor, "item_1")
        XCTAssertTrue(response.hasMore)
    }

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

    func testLoadMoreUsesCursorAndAppendsWithoutReplacingFirstPage() async {
        let first = makeItem(id: "inv_1", catalogItemId: "item_1", name: "Cuy entero")
        let second = makeItem(id: "inv_2", catalogItemId: "item_2", name: "Cuy mediano")
        let repository = InventoryRepositorySpy(
            itemsResponse: InventoryItemsResponse(items: []),
            queuedItemResponses: [
                InventoryItemsResponse(items: [first], nextCursor: "item_1", hasMore: true),
                InventoryItemsResponse(items: [second], nextCursor: nil, hasMore: false)
            ]
        )
        let viewModel = makeDashboard(repository: repository)

        await viewModel.load()
        await viewModel.loadMore()

        XCTAssertEqual(viewModel.items, [first, second])
        XCTAssertEqual(repository.lastCursor, "item_1")
        XCTAssertFalse(viewModel.hasMore)
    }

    func testDetailViewModelKeepsContext() {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = makeDashboard(repository: repository)
        let detail = viewModel.makeDetailViewModel(for: makeItem())

        XCTAssertEqual(detail.organizationId, "org_1")
        XCTAssertEqual(detail.branchId, "br_1")
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
    func testAdvancedOperationsAreTruthfullyDeferredToAdmin() {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = makeDetail(repository: repository)

        XCTAssertTrue(viewModel.physicalCountGuidance.contains("Admin Inventory Pro"))
        XCTAssertTrue(viewModel.physicalCountGuidance.contains("evitar duplicar"))
        XCTAssertTrue(viewModel.transferGuidance.contains("no informa una bodega de origen"))
        XCTAssertTrue(viewModel.transferGuidance.contains("Admin Inventory Pro"))

        let warehouseViewModel = InventoryItemDetailViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            catalogRevision: "cat_rev_001",
            item: makeItem(warehouseId: "wh_1"),
            effectivePermissions: ["business.inventory.view"],
            inventoryRepository: repository
        )
        XCTAssertTrue(warehouseViewModel.transferGuidance.contains("Bodega actual: wh_1"))
    }

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
        XCTAssertEqual(repository.lastMovementBranchId, "br_1")
        XCTAssertEqual(repository.lastMovementCatalogItemId, "item_1")
    }

    func testAdjustmentStartsWithSimpleSafeDefaults() {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = makeDetail(repository: repository)

        XCTAssertEqual(viewModel.adjustmentType, .increase)
        XCTAssertEqual(viewModel.adjustmentQuantity, "1")
        XCTAssertEqual(viewModel.adjustmentReason, "Compra o reposición")
        XCTAssertTrue(viewModel.canAdjust)
    }

    func testAdjustmentTypeAndStepperUseHumanDefaults() {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = makeDetail(repository: repository)

        viewModel.selectAdjustmentType(.decrease)
        viewModel.incrementAdjustmentQuantity()
        viewModel.incrementAdjustmentQuantity()
        viewModel.decrementAdjustmentQuantity()

        XCTAssertEqual(viewModel.adjustmentType, .decrease)
        XCTAssertEqual(viewModel.adjustmentQuantity, "2")
        XCTAssertEqual(viewModel.adjustmentReason, "Merma o salida operativa")
        XCTAssertTrue(viewModel.adjustmentReasonPresets.contains("Merma o daño"))
    }

    func testCustomAdjustmentReasonSurvivesOperationChange() {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = makeDetail(repository: repository)
        viewModel.selectAdjustmentReason("Incidencia validada por supervisión")

        viewModel.selectAdjustmentType(.set)

        XCTAssertEqual(viewModel.adjustmentReason, "Incidencia validada por supervisión")
    }

    func testWildcardPermissionCanViewAndAdjust() async {
        let repository = InventoryRepositorySpy(
            itemsResponse: InventoryItemsResponse(items: []),
            adjustmentResponse: InventoryAdjustmentResponse(item: makeItem())
        )
        let viewModel = InventoryItemDetailViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            catalogRevision: "cat_rev_001",
            item: makeItem(),
            effectivePermissions: ["*"],
            inventoryRepository: repository
        )
        viewModel.adjustmentQuantity = "1"
        viewModel.adjustmentReason = "Corrección controlada"

        await viewModel.adjust()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(repository.lastAdjustmentRequest)
    }

    func testZeroAdjustmentIsRejectedBeforeRepositoryCall() async {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = makeDetail(repository: repository)
        viewModel.adjustmentQuantity = "0"
        viewModel.adjustmentReason = "No debe enviarse"

        await viewModel.adjust()

        XCTAssertEqual(viewModel.errorMessage, "Ingresa una cantidad válida mayor que cero.")
        XCTAssertNil(repository.lastAdjustmentRequest)
    }

    func testAdjustRequiresPermission() async {
        let repository = InventoryRepositorySpy(itemsResponse: InventoryItemsResponse(items: []))
        let viewModel = InventoryItemDetailViewModel(
            organizationId: "org_1",
            branchId: "br_1",
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
        XCTAssertEqual(repository.lastAdjustmentRequest?.branchId, "br_1")
        XCTAssertEqual(repository.lastAdjustmentRequest?.catalogItemId, "item_1")
        XCTAssertEqual(repository.lastAdjustmentRequest?.quantity, "10.00")
        XCTAssertEqual(repository.lastAdjustmentRequest?.reason, "Conteo físico")
        XCTAssertEqual(repository.lastAdjustmentBranchId, "br_1")
        XCTAssertEqual(repository.lastAdjustmentCatalogItemId, "item_1")
        XCTAssertTrue(repository.lastIdempotencyKey?.rawValue.hasPrefix("inventory-adjust-") == true)
        XCTAssertEqual(viewModel.item, updated)
        XCTAssertEqual(viewModel.catalogRevision, "cat_rev_002")
        XCTAssertEqual(viewModel.infoMessage, "Inventario actualizado correctamente.")
        XCTAssertEqual(repository.lookupStockCallCount, 1)
        XCTAssertEqual(repository.listMovementsCallCount, 1)
    }

    func testAdjustKeepsCatalogIdentityWhenBalanceResponseIsSparse() async {
        let sparseBalance = InventoryItem(
            id: "inv_1",
            catalogItemId: "item_1",
            name: "item_staging_cuy_entero",
            stockStatus: "active",
            available: InventoryQuantity(quantity: "10")
        )
        let repository = InventoryRepositorySpy(
            itemsResponse: InventoryItemsResponse(items: []),
            adjustmentResponse: InventoryAdjustmentResponse(item: sparseBalance),
            stockLookupResponse: InventoryStockLookupResponse(item: sparseBalance)
        )
        let viewModel = makeDetail(repository: repository)
        viewModel.adjustmentQuantity = "1"
        viewModel.adjustmentReason = "Corrección controlada"

        await viewModel.adjust()

        XCTAssertEqual(viewModel.item.displayName, "Cuy entero")
        XCTAssertEqual(viewModel.item.sku, "CUY-ENTERO")
        XCTAssertEqual(viewModel.item.catalogItemId, "item_1")
        XCTAssertEqual(viewModel.item.available.quantity, "10")
    }

    func testRepeatedTapWhileRequestIsInFlightSubmitsOnlyOnce() async {
        let repository = InventoryRepositorySpy(
            itemsResponse: InventoryItemsResponse(items: []),
            adjustmentResponse: InventoryAdjustmentResponse(item: makeItem()),
            adjustmentDelayNanoseconds: 150_000_000
        )
        let viewModel = makeDetail(repository: repository)
        viewModel.adjustmentQuantity = "1"
        viewModel.adjustmentReason = "Corrección controlada"

        let firstTap = Task { await viewModel.adjust() }
        await Task.yield()
        let secondTap = Task { await viewModel.adjust() }
        await firstTap.value
        await secondTap.value

        XCTAssertEqual(repository.adjustCallCount, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAdjustmentErrorsAreHumanized() async {
        let cases: [(APIError, String)] = [
            (.server(statusCode: 403, code: nil, message: "", requestId: nil), "No tienes permiso para realizar esta acción."),
            (.server(statusCode: 409, code: nil, message: "", requestId: nil), "La información del negocio cambió. Actualiza el contexto e inténtalo otra vez."),
            (.server(statusCode: 422, code: nil, message: "", requestId: nil), "Hay datos que deben corregirse antes de continuar.")
        ]

        for (apiError, expectedMessage) in cases {
            let repository = InventoryRepositorySpy(
                itemsResponse: InventoryItemsResponse(items: []),
                adjustmentError: apiError
            )
            let viewModel = makeDetail(repository: repository)
            viewModel.adjustmentQuantity = "1"
            viewModel.adjustmentReason = "Corrección controlada"

            await viewModel.adjust()

            XCTAssertEqual(viewModel.errorMessage, expectedMessage)
        }
    }

    private func makeDetail(repository: InventoryRepositorySpy) -> InventoryItemDetailViewModel {
        InventoryItemDetailViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            catalogRevision: "cat_rev_001",
            item: makeItem(),
            effectivePermissions: ["business.inventory.view", "business.inventory.adjust"],
            inventoryRepository: repository
        )
    }
}

private func makeItem(
    id: String = "inv_1",
    catalogItemId: String = "item_1",
    name: String = "Cuy entero",
    warehouseId: String? = nil
) -> InventoryItem {
    InventoryItem(
        id: id,
        catalogItemId: catalogItemId,
        name: name,
        sku: "CUY-ENTERO",
        status: "active",
        stockStatus: "active",
        trackStock: true,
        available: InventoryQuantity(quantity: "5", unitCode: "unit", unitName: "Unidad"),
        lowStockThreshold: InventoryQuantity(quantity: "2", unitCode: "unit", unitName: "Unidad"),
        warehouseId: warehouseId
    )
}

private final class InventoryRepositorySpy: InventoryRepository, @unchecked Sendable {
    var itemsResponse: InventoryItemsResponse
    var movementsResponse: InventoryMovementsResponse
    var adjustmentResponse: InventoryAdjustmentResponse?
    var lastQuery: String?
    var lastStockStatus: InventoryItemStockStatus?
    var lastCursor: String?
    var lastAdjustmentRequest: InventoryAdjustmentRequest?
    var lastMovementBranchId: String?
    var lastMovementCatalogItemId: String?
    var lastAdjustmentBranchId: String?
    var lastAdjustmentCatalogItemId: String?
    var lastIdempotencyKey: IdempotencyKey?
    var queuedItemResponses: [InventoryItemsResponse]
    var stockLookupResponse: InventoryStockLookupResponse
    var adjustmentError: APIError?
    var adjustmentDelayNanoseconds: UInt64
    var adjustCallCount = 0
    var lookupStockCallCount = 0
    var listMovementsCallCount = 0

    init(
        itemsResponse: InventoryItemsResponse,
        queuedItemResponses: [InventoryItemsResponse] = [],
        movementsResponse: InventoryMovementsResponse = InventoryMovementsResponse(movements: []),
        adjustmentResponse: InventoryAdjustmentResponse? = nil,
        stockLookupResponse: InventoryStockLookupResponse? = nil,
        adjustmentError: APIError? = nil,
        adjustmentDelayNanoseconds: UInt64 = 0
    ) {
        self.itemsResponse = itemsResponse
        self.queuedItemResponses = queuedItemResponses
        self.movementsResponse = movementsResponse
        self.adjustmentResponse = adjustmentResponse
        self.stockLookupResponse = stockLookupResponse ?? InventoryStockLookupResponse(
            item: adjustmentResponse?.item ?? makeItem()
        )
        self.adjustmentError = adjustmentError
        self.adjustmentDelayNanoseconds = adjustmentDelayNanoseconds
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
        branchId: String,
        catalogItemId: String,
        limit: Int
    ) async throws -> InventoryMovementsResponse {
        listMovementsCallCount += 1
        lastMovementBranchId = branchId
        lastMovementCatalogItemId = catalogItemId
        return movementsResponse
    }

    func lookupStock(
        organizationId: String,
        branchId: String,
        itemId: String,
        catalogRevision: String
    ) async throws -> InventoryStockLookupResponse {
        lookupStockCallCount += 1
        return stockLookupResponse
    }

    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        cursor: String?,
        limit: Int
    ) async throws -> InventoryItemsResponse {
        lastQuery = query
        lastStockStatus = stockStatus
        lastCursor = cursor
        return queuedItemResponses.isEmpty ? itemsResponse : queuedItemResponses.removeFirst()
    }

    func adjust(
        organizationId: String,
        branchId: String,
        catalogItemId: String,
        catalogRevision: String,
        idempotencyKey: IdempotencyKey,
        request: InventoryAdjustmentRequest
    ) async throws -> InventoryAdjustmentResponse {
        adjustCallCount += 1
        if adjustmentDelayNanoseconds > 0 {
            try await Task<Never, Never>.sleep(nanoseconds: adjustmentDelayNanoseconds)
        }
        if let adjustmentError {
            throw adjustmentError
        }
        lastAdjustmentBranchId = branchId
        lastAdjustmentCatalogItemId = catalogItemId
        lastAdjustmentRequest = request
        lastIdempotencyKey = idempotencyKey
        return adjustmentResponse ?? InventoryAdjustmentResponse(item: makeItem())
    }
}
