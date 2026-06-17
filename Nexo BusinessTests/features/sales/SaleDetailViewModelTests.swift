//
//  SaleDetailViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class SaleDetailViewModelTests: XCTestCase {
    func testLoadSaleUsesRepository() async {
        let repository = SaleLifecycleRepositorySpy()
        let viewModel = makeViewModel(repository: repository, initialSale: nil)

        await viewModel.load()

        XCTAssertEqual(viewModel.sale?.id, PreviewData.quickSaleResponse.sale.id)
        XCTAssertEqual(repository.loadedSaleId, PreviewData.quickSaleResponse.sale.id)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testConfirmUsesIdempotencyAndRevisions() async {
        let repository = SaleLifecycleRepositorySpy()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.confirm()

        XCTAssertEqual(viewModel.sale?.status, "confirmed")
        XCTAssertTrue(repository.lastConfirmIdempotencyKey?.rawValue.hasPrefix("sale-confirm-") == true)
        XCTAssertEqual(repository.lastConfirmRevisions?.catalogRevision, "cat_rev_test")
        XCTAssertEqual(viewModel.infoMessage, "Venta confirmada correctamente.")
    }

    func testCancelUsesReasonAndIdempotency() async {
        let repository = SaleLifecycleRepositorySpy()
        let viewModel = makeViewModel(repository: repository)

        viewModel.cancelReason = "Cliente desistió"
        await viewModel.cancel()

        XCTAssertEqual(viewModel.sale?.status, "canceled")
        XCTAssertEqual(repository.lastCancelRequest?.reason, "Cliente desistió")
        XCTAssertTrue(repository.lastCancelIdempotencyKey?.rawValue.hasPrefix("sale-cancel-") == true)
    }

    func testConfirmWithoutPermissionIsBlocked() async {
        let repository = SaleLifecycleRepositorySpy()
        let viewModel = SaleDetailViewModel(
            organizationId: "org_1",
            saleId: PreviewData.quickSaleResponse.sale.id,
            revisions: Self.revisions,
            initialSale: PreviewData.quickSaleResponse.sale,
            effectivePermissions: [],
            salesRepository: repository
        )

        await viewModel.confirm()

        XCTAssertNil(repository.lastConfirmIdempotencyKey)
        XCTAssertEqual(viewModel.errorMessage, "No puedes confirmar esta venta con tu usuario o estado actual.")
    }

    func testRevisionErrorShowsRefreshContextMessage() async {
        let repository = SaleLifecycleRepositorySpy(
            confirmError: APIError.server(
                statusCode: 409,
                code: "stale_catalog_revision",
                message: "Conflict",
                requestId: "req_1"
            )
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.confirm()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La información del negocio cambió. Actualiza el contexto e inténtalo otra vez."
        )
        XCTAssertEqual(
            viewModel.infoMessage,
            "Actualiza el contexto del negocio antes de continuar."
        )
    }

    private func makeViewModel(
        repository: SaleLifecycleRepositorySpy = SaleLifecycleRepositorySpy(),
        initialSale: BusinessSale? = PreviewData.quickSaleResponse.sale
    ) -> SaleDetailViewModel {
        SaleDetailViewModel(
            organizationId: "org_1",
            saleId: PreviewData.quickSaleResponse.sale.id,
            revisions: Self.revisions,
            initialSale: initialSale,
            effectivePermissions: ["business.sales.confirm", "business.sales.cancel"],
            salesRepository: repository
        )
    }

    private static let revisions = BusinessRevisions(
        catalogRevision: "cat_rev_test",
        taxConfigurationRevision: "tax_rev_test"
    )
}

private final class SaleLifecycleRepositorySpy: SalesRepository, @unchecked Sendable {
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
    
    var loadedSaleId: String?

    var lastConfirmRevisions: BusinessRevisions?
    var lastConfirmIdempotencyKey: IdempotencyKey?

    var lastCancelRevisions: BusinessRevisions?
    var lastCancelIdempotencyKey: IdempotencyKey?
    var lastCancelRequest: CancelSaleRequest?

    var lastBulkAddSaleId: String?
    var lastBulkAddRevisions: BusinessRevisions?
    var lastBulkAddIdempotencyKey: IdempotencyKey?
    var lastBulkAddRequest: BulkAddSaleItemsRequest?

    var lastBulkUpdateSaleId: String?
    var lastBulkUpdateRevisions: BusinessRevisions?
    var lastBulkUpdateIdempotencyKey: IdempotencyKey?
    var lastBulkUpdateRequest: BulkUpdateSaleItemsRequest?

    var lastBulkRemoveSaleId: String?
    var lastBulkRemoveRevisions: BusinessRevisions?
    var lastBulkRemoveIdempotencyKey: IdempotencyKey?
    var lastBulkRemoveRequest: BulkRemoveSaleItemsRequest?

    var confirmError: Error?

    init(confirmError: Error? = nil) {
        self.confirmError = confirmError
    }

    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        PreviewData.previewResponse
    }

    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        PreviewData.quickSaleResponse
    }

    func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse {
        loadedSaleId = saleId
        return BusinessSaleDetailResponse(sale: PreviewData.quickSaleResponse.sale)
    }

    func bulkAddItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkAddSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkAddSaleId = saleId
        lastBulkAddRevisions = revisions
        lastBulkAddIdempotencyKey = idempotencyKey
        lastBulkAddRequest = request
        return PreviewData.quickSaleResponse
    }

    func bulkUpdateItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkUpdateSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkUpdateSaleId = saleId
        lastBulkUpdateRevisions = revisions
        lastBulkUpdateIdempotencyKey = idempotencyKey
        lastBulkUpdateRequest = request
        return PreviewData.quickSaleResponse
    }

    func bulkRemoveItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkRemoveSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkRemoveSaleId = saleId
        lastBulkRemoveRevisions = revisions
        lastBulkRemoveIdempotencyKey = idempotencyKey
        lastBulkRemoveRequest = request
        return PreviewData.quickSaleResponse
    }

    func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse {
        lastConfirmRevisions = revisions
        lastConfirmIdempotencyKey = idempotencyKey

        if let confirmError {
            throw confirmError
        }

        return PreviewData.confirmedSaleResponse
    }

    func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CancelSaleRequest
    ) async throws -> CancelSaleResponse {
        lastCancelRevisions = revisions
        lastCancelIdempotencyKey = idempotencyKey
        lastCancelRequest = request
        return PreviewData.canceledSaleResponse
    }
}
