//
//  SaleCartCustomerSelectionTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class SaleCartCustomerSelectionTests: XCTestCase {
    func testSelectingFinalConsumerDoesNotSendCustomerId() async {
        let salesRepository = SaleCartSalesRepositorySpy()
        let viewModel = makeViewModel(salesRepository: salesRepository)

        viewModel.selectCustomer(BusinessCustomerPresentation.finalConsumer)
        viewModel.addToCart(PreviewData.catalogItems[0])

        await viewModel.loadPreview()

        XCTAssertNil(salesRepository.lastPreviewRequest?.customerId)
    }

    func testSelectingIdentifiedCustomerSendsCustomerIdInPreviewAndQuickSale() async {
        let salesRepository = SaleCartSalesRepositorySpy()
        let viewModel = makeViewModel(salesRepository: salesRepository)
        let customer = BusinessCustomer(
            id: "cus_1",
            displayName: "Cliente Uno",
            identificationType: .cedula,
            identificationNumber: "1712345678"
        )

        viewModel.selectCustomer(customer)
        viewModel.addToCart(PreviewData.catalogItems[0])

        await viewModel.loadPreview()
        await viewModel.createQuickSale()

        XCTAssertEqual(salesRepository.lastPreviewRequest?.customerId, "cus_1")
        XCTAssertEqual(salesRepository.lastQuickSaleRequest?.customerId, "cus_1")
    }

    private func makeViewModel(
        salesRepository: SalesRepository
    ) -> SaleCartViewModel {
        SaleCartViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            activityId: PreviewData.businessContext.activities[0].id,
            revisions: PreviewData.businessContext.revisions,
            effectivePermissions: PreviewData.businessContext.effectivePermissions,
            catalogRepository: PreviewCatalogRepository(),
            salesRepository: salesRepository
        )
    }
}

final class SaleCartSalesRepositorySpy: SalesRepository, @unchecked Sendable {
    var lastPreviewRequest: SalesPreviewRequest?
    var lastQuickSaleRequest: QuickSaleRequest?
    var lastBulkAddRequest: BulkAddSaleItemsRequest?
    var lastBulkUpdateRequest: BulkUpdateSaleItemsRequest?
    var lastBulkRemoveRequest: BulkRemoveSaleItemsRequest?
    var lastBulkIdempotencyKey: IdempotencyKey?
    
    func bulkAddItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkAddSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkAddRequest = request
        lastBulkIdempotencyKey = idempotencyKey
        return PreviewData.quickSaleResponse
    }

    func bulkUpdateItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkUpdateSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkUpdateRequest = request
        lastBulkIdempotencyKey = idempotencyKey
        return PreviewData.quickSaleResponse
    }

    func bulkRemoveItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkRemoveSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        lastBulkRemoveRequest = request
        lastBulkIdempotencyKey = idempotencyKey
        return PreviewData.quickSaleResponse
    }

    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        lastPreviewRequest = request
        return PreviewData.previewResponse
    }

    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        lastQuickSaleRequest = request
        return PreviewData.quickSaleResponse
    }

    func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse {
        BusinessSaleDetailResponse(sale: PreviewData.quickSaleResponse.sale)
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
