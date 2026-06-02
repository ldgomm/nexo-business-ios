import XCTest
@testable import Nexo_Business

@MainActor
final class SaleCartRevisionConflictTests: XCTestCase {
    override func tearDown() async throws {
        await BusinessRevisionRegistry.shared.clear()
        try await super.tearDown()
    }
    
    func testPreviewRefreshesContextAndRetriesOnceWhenTaxRevisionIsStale() async {
        let catalog = SalesRevisionConflictCatalogSpy()
        let sales = RevisionConflictSalesRepositorySpy(
            firstPreviewError: APIError.server(
                statusCode: 409,
                code: "business_revision_conflict",
                message: "Tax configuration revision is stale. Current revision is taxrev_altos_staging_3.",
                requestId: "req_1"
            ),
            previewResponse: PreviewData.previewResponse
        )
        let contextRepository = SalesRevisionConflictContextRepositorySpy(
            context: PreviewData.businessContext.withRevisions(
                BusinessRevisions(
                    catalogRevision: "catrev_altos_staging_1",
                    taxConfigurationRevision: "taxrev_altos_staging_3"
                )
            )
        )
        
        let viewModel = SaleCartViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            activityId: PreviewData.businessContext.activities[0].id,
            revisions: BusinessRevisions(
                catalogRevision: "catrev_altos_staging_1",
                taxConfigurationRevision: "taxrev_altos_staging_2"
            ),
            effectivePermissions: PreviewData.businessContext.effectivePermissions,
            catalogRepository: catalog,
            salesRepository: sales,
            contextRepository: contextRepository
        )
        
        viewModel.addToCart(PreviewData.catalogItems[0])
        await viewModel.loadPreview()
        
        XCTAssertEqual(contextRepository.getContextCallCount, 1)
        XCTAssertEqual(sales.previewRequests.count, 2)
        XCTAssertEqual(sales.previewRequests[0].taxConfigurationRevision, "taxrev_altos_staging_2")
        XCTAssertEqual(sales.previewRequests[1].taxConfigurationRevision, "taxrev_altos_staging_3")
        XCTAssertEqual(viewModel.preview?.totals.grandTotal.amount, "25.92")
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testQuickSaleRefreshesContextButDoesNotAutoRetryMutationWhenRevisionIsStale() async {
        let sales = RevisionConflictSalesRepositorySpy(
            quickSaleError: APIError.server(
                statusCode: 409,
                code: "business_revision_conflict",
                message: "Tax configuration revision is stale. Current revision is taxrev_altos_staging_3.",
                requestId: "req_2"
            )
        )
        let contextRepository = SalesRevisionConflictContextRepositorySpy(
            context: PreviewData.businessContext.withRevisions(
                BusinessRevisions(
                    catalogRevision: "catrev_altos_staging_1",
                    taxConfigurationRevision: "taxrev_altos_staging_3"
                )
            )
        )
        
        let viewModel = SaleCartViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            activityId: PreviewData.businessContext.activities[0].id,
            revisions: BusinessRevisions(
                catalogRevision: "catrev_altos_staging_1",
                taxConfigurationRevision: "taxrev_altos_staging_2"
            ),
            effectivePermissions: PreviewData.businessContext.effectivePermissions,
            catalogRepository: SalesRevisionConflictCatalogSpy(),
            salesRepository: sales,
            contextRepository: contextRepository
        )
        
        viewModel.addToCart(PreviewData.catalogItems[0])
        await viewModel.createQuickSale()
        
        XCTAssertEqual(contextRepository.getContextCallCount, 1)
        XCTAssertEqual(sales.quickSaleRequests.count, 1)
        XCTAssertNil(viewModel.createdSale)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.infoMessage, "Contexto del negocio actualizado. Calcula nuevamente el total antes de registrar la venta.")
    }
}

private final class SalesRevisionConflictCatalogSpy: CatalogRepository, @unchecked Sendable {
    func search(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSearchResponse {
        CatalogSearchResponse(items: PreviewData.catalogItems, catalogRevision: catalogRevision)
    }
}

private final class SalesRevisionConflictContextRepositorySpy: BusinessContextRepository, @unchecked Sendable {
    private let context: BusinessContextResponse
    private(set) var getContextCallCount = 0
    
    init(context: BusinessContextResponse) {
        self.context = context
    }
    
    func getContext(organizationId: String) async throws -> BusinessContextResponse {
        getContextCallCount += 1
        return context
    }
}

private final class RevisionConflictSalesRepositorySpy: SalesRepository, @unchecked Sendable {
    private var firstPreviewError: APIError?
    private let previewResponse: SalesPreviewResponse
    private let quickSaleError: APIError?
    private(set) var previewRequests: [SalesPreviewRequest] = []
    private(set) var quickSaleRequests: [QuickSaleRequest] = []
    
    init(
        firstPreviewError: APIError? = nil,
        previewResponse: SalesPreviewResponse = PreviewData.previewResponse,
        quickSaleError: APIError? = nil
    ) {
        self.firstPreviewError = firstPreviewError
        self.previewResponse = previewResponse
        self.quickSaleError = quickSaleError
    }
    
    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        previewRequests.append(request)
        if let error = firstPreviewError {
            firstPreviewError = nil
            throw error
        }
        return previewResponse
    }
    
    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        quickSaleRequests.append(request)
        if let quickSaleError { throw quickSaleError }
        return PreviewData.quickSaleResponse
    }
    
    func getSale(organizationId: String, saleId: String) async throws -> BusinessSaleDetailResponse {
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

private extension BusinessContextResponse {
    func withRevisions(_ revisions: BusinessRevisions) -> BusinessContextResponse {
        BusinessContextResponse(
            user: user,
            organization: organization,
            branches: branches,
            activities: activities,
            activeModules: activeModules,
            effectivePermissions: effectivePermissions,
            revisions: revisions,
            readiness: readiness,
            activeBranchId: activeBranchId,
            activeActivityId: activeActivityId,
            moduleReadiness: moduleReadiness
        )
    }
}
