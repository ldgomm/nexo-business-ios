//
//  SaleCartViewModelTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class SaleCartViewModelTests: XCTestCase {
    func testSearchCatalogLoadsResults() async {
        let catalog = CatalogRepositorySpy(
            response: CatalogSearchResponse(items: [Self.item])
        )
        let sales = SalesRepositorySpy()
        let viewModel = makeViewModel(
            catalogRepository: catalog,
            salesRepository: sales
        )

        viewModel.searchQuery = "cuy"
        await viewModel.searchCatalog()

        XCTAssertEqual(viewModel.searchResults, [Self.item])
        XCTAssertEqual(catalog.lastQuery, "cuy")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddSameItemTwiceIncrementsQuantity() {
        let viewModel = makeViewModel()

        viewModel.addToCart(Self.item)
        viewModel.addToCart(Self.item)

        XCTAssertEqual(viewModel.cartItems.count, 1)
        XCTAssertEqual(viewModel.cartItems[0].quantity, "2")
    }

    func testPreviewSendsCartItemsAndRevisions() async {
        let sales = SalesRepositorySpy(
            previewResponse: PreviewData.previewResponse
        )
        let viewModel = makeViewModel(salesRepository: sales)

        viewModel.addToCart(Self.item)
        viewModel.updateQuantity(cartItemId: viewModel.cartItems[0].id, quantity: "3")

        await viewModel.loadPreview()

        XCTAssertNotNil(viewModel.preview)
        XCTAssertEqual(viewModel.preview?.items.count, PreviewData.previewResponse.items.count)
        XCTAssertEqual(viewModel.preview?.totals.grandTotal.amount, PreviewData.previewResponse.totals.grandTotal.amount)

        XCTAssertEqual(sales.lastPreviewRequest?.items.first?.catalogItemId, Self.item.id)
        XCTAssertEqual(sales.lastPreviewRequest?.items.first?.quantity.value, "3")
        XCTAssertEqual(sales.lastPreviewRequest?.items.first?.quantity.unitCode, "unit")
        XCTAssertEqual(sales.lastPreviewRequest?.items.first?.quantity.allowsDecimal, false)
        XCTAssertEqual(sales.lastPreviewRequest?.items.first?.priceTaxMode, BusinessSalePriceTaxMode.taxExclusive.rawValue)
        XCTAssertEqual(sales.lastPreviewRequest?.catalogRevision, "cat_rev_test")
        XCTAssertEqual(sales.lastPreviewRequest?.taxConfigurationRevision, "tax_rev_test")
        XCTAssertEqual(sales.lastPreviewRevisions?.catalogRevision, "cat_rev_test")
    }

    func testCreateQuickSaleUsesIdempotencyAndCartItems() async {
        let sales = SalesRepositorySpy(
            quickSaleResponse: PreviewData.quickSaleResponse
        )
        let viewModel = makeViewModel(salesRepository: sales)

        viewModel.addToCart(Self.item)
        await viewModel.createQuickSale()

        XCTAssertEqual(viewModel.createdSale?.id, "sale_preview_001")
        XCTAssertEqual(sales.lastQuickSaleRequest?.items.first?.catalogItemId, Self.item.id)
        XCTAssertEqual(sales.lastQuickSaleRequest?.items.first?.quantity.value, "1")
        XCTAssertEqual(sales.lastQuickSaleRequest?.requestId, sales.lastIdempotencyKey?.rawValue)
        XCTAssertEqual(sales.lastQuickSaleRequest?.autoConfirm, true)
        XCTAssertEqual(sales.lastQuickSaleRequest?.catalogRevision, "cat_rev_test")
        XCTAssertEqual(sales.lastQuickSaleRequest?.taxConfigurationRevision, "tax_rev_test")
        XCTAssertTrue(sales.lastIdempotencyKey?.rawValue.hasPrefix("quick-sale-") == true)
        XCTAssertEqual(viewModel.infoMessage, "Venta sin cobrar. La venta fue registrada, pero todavía no se ha cobrado ni es cuenta por cobrar.")
    }

    func testRevisionErrorShowsRefreshMessage() async {
        let sales = SalesRepositorySpy(
            previewError: APIError.server(
                statusCode: 428,
                code: "missing_required_revision",
                message: "Precondition required",
                requestId: "req_1"
            )
        )
        let viewModel = makeViewModel(salesRepository: sales)

        viewModel.addToCart(Self.item)
        await viewModel.loadPreview()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Falta una revisión requerida de catálogo o configuración tributaria. Actualiza el contexto."
        )
        XCTAssertEqual(
            viewModel.infoMessage,
            "Actualiza el contexto del negocio antes de continuar."
        )
    }


    func testCreatedSaleCannotBeCollectedWithoutPaymentPermission() async {
        let sales = SalesRepositorySpy(
            quickSaleResponse: PreviewData.quickSaleResponse
        )
        let viewModel = makeViewModel(salesRepository: sales)

        viewModel.addToCart(Self.item)
        await viewModel.createQuickSale()

        XCTAssertFalse(viewModel.canCollectCreatedSale)
    }

    func testCreatedSaleCanBeCollectedWithPaymentPermission() async {
        let sales = SalesRepositorySpy(
            quickSaleResponse: PreviewData.quickSaleResponse
        )
        let viewModel = makeViewModel(
            salesRepository: sales,
            effectivePermissions: ["payments.collect"]
        )

        viewModel.addToCart(Self.item)
        await viewModel.createQuickSale()

        XCTAssertTrue(viewModel.canCollectCreatedSale)
    }

    private func makeViewModel(
        catalogRepository: CatalogRepository = CatalogRepositorySpy(),
        salesRepository: SalesRepository = SalesRepositorySpy(),
        effectivePermissions: Set<String> = []
    ) -> SaleCartViewModel {
        SaleCartViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1",
            revisions: BusinessRevisions(
                catalogRevision: "cat_rev_test",
                taxConfigurationRevision: "tax_rev_test"
            ),
            effectivePermissions: effectivePermissions,
            catalogRepository: catalogRepository,
            salesRepository: salesRepository
        )
    }

    private static let item = BusinessCatalogItem(
        id: "item_cuy",
        name: "Cuy entero",
        itemDescription: "Plato principal",
        sku: "CUY",
        type: "product",
        status: "active",
        price: MoneyAmount(amount: "24.00")
    )
}

private final class CatalogRepositorySpy: CatalogRepository, @unchecked Sendable {
    var response: CatalogSearchResponse
    var error: Error?
    var lastQuery: String?
    var lastCatalogRevision: String?

    init(
        response: CatalogSearchResponse = CatalogSearchResponse(items: []),
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func search(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSearchResponse {
        lastQuery = query
        lastCatalogRevision = catalogRevision

        if let error {
            throw error
        }

        return response
    }
}

private final class SalesRepositorySpy: SalesRepository, @unchecked Sendable {
    func updateCustomer(organizationId: String, saleId: String, revisions: Nexo_Business.BusinessRevisions, idempotencyKey: Nexo_Business.IdempotencyKey, request: Nexo_Business.UpdateSaleCustomerRequest) async throws -> Nexo_Business.QuickSaleResponse {
        lastUpdateCustomerRequest = request
        lastUpdateCustomerIdempotencyKey = idempotencyKey
        if let updateCustomerError {
            throw updateCustomerError
        }
        return updateCustomerResponse
    }
    
    var lastUpdateCustomerRequest: UpdateSaleCustomerRequest?
    var lastUpdateCustomerIdempotencyKey: IdempotencyKey?
    var updateCustomerResponse: QuickSaleResponse = PreviewData.quickSaleResponse
    var updateCustomerError: Error?
    
    var previewResponse: SalesPreviewResponse
    var quickSaleResponse: QuickSaleResponse
    var previewError: Error?
    var quickSaleError: Error?
    var lastPreviewRequest: SalesPreviewRequest?
    var lastPreviewRevisions: BusinessRevisions?
    var lastQuickSaleRequest: QuickSaleRequest?
    var lastQuickSaleRevisions: BusinessRevisions?
    var lastIdempotencyKey: IdempotencyKey?
    var lastBulkAddRequest: BulkAddSaleItemsRequest?
    var lastBulkUpdateRequest: BulkUpdateSaleItemsRequest?
    var lastBulkRemoveRequest: BulkRemoveSaleItemsRequest?
    var lastBulkRevisions: BusinessRevisions?
    var lastBulkIdempotencyKey: IdempotencyKey?
    
    func bulkAddItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkAddSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkAddRequest = request
        lastBulkRevisions = revisions
        lastBulkIdempotencyKey = idempotencyKey

        if let quickSaleError {
            throw quickSaleError
        }

        return quickSaleResponse
    }

    func bulkUpdateItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkUpdateSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkUpdateRequest = request
        lastBulkRevisions = revisions
        lastBulkIdempotencyKey = idempotencyKey

        if let quickSaleError {
            throw quickSaleError
        }

        return quickSaleResponse
    }

    func bulkRemoveItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkRemoveSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkRemoveRequest = request
        lastBulkRevisions = revisions
        lastBulkIdempotencyKey = idempotencyKey

        if let quickSaleError {
            throw quickSaleError
        }

        return quickSaleResponse
    }

    init(
        previewResponse: SalesPreviewResponse = PreviewData.previewResponse,
        quickSaleResponse: QuickSaleResponse = PreviewData.quickSaleResponse,
        previewError: Error? = nil,
        quickSaleError: Error? = nil
    ) {
        self.previewResponse = previewResponse
        self.quickSaleResponse = quickSaleResponse
        self.previewError = previewError
        self.quickSaleError = quickSaleError
    }

    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        lastPreviewRequest = request
        lastPreviewRevisions = revisions

        if let previewError {
            throw previewError
        }

        return previewResponse
    }

    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        lastQuickSaleRequest = request
        lastQuickSaleRevisions = revisions
        lastIdempotencyKey = idempotencyKey

        if let quickSaleError {
            throw quickSaleError
        }

        return quickSaleResponse
    }

    func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse {
        BusinessSaleDetailResponse(sale: quickSaleResponse.sale)
    }

    func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse {
        PreviewData.confirmedSaleResponse
    }

    func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CancelSaleRequest
    ) async throws -> CancelSaleResponse {
        PreviewData.canceledSaleResponse
    }
}
