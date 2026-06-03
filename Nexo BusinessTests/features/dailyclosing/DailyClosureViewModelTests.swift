import XCTest
@testable import Nexo_Business

@MainActor
final class DailyClosureViewModelTests: XCTestCase {
    func testLoadFetchesReportCashAndPendingWorkWhenCashCanBeViewed() async {
        let report = makeReport()
        let cashSession = makeCashSession()
        let pendingRepository = PendingOperationsRepositorySpy(
            salesResponse: PendingSalesResponse(sales: [makeSale()], total: 1),
            receivablesResponse: PendingReceivablesResponse(receivables: [makeReceivable()], total: 1),
            documentsResponse: PendingDocumentsResponse(documents: [makeDocument()], total: 1)
        )
        let dailyReportRepository = BusinessDailyReportRepositorySpy(
            response: BusinessDailyReportResponse(report: report)
        )
        let cashRepository = CashRepositorySpyForDailyClosure(
            currentResponse: CashCurrentSessionResponse(session: cashSession)
        )

        let viewModel = makeViewModel(
            pendingRepository: pendingRepository,
            dailyReportRepository: dailyReportRepository,
            cashRepository: cashRepository,
            capabilities: makeCapabilities(cash: CashCapabilities(canViewCurrent: true, canClose: true))
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.reportState, AsyncViewState<BusinessDailyReport?>.loaded(report))
        XCTAssertEqual(viewModel.cashState, AsyncViewState<CashSession?>.loaded(cashSession))
        XCTAssertEqual(viewModel.pendingSales.count, 1)
        XCTAssertEqual(viewModel.pendingReceivables.count, 1)
        XCTAssertEqual(viewModel.pendingDocuments.count, 1)
        XCTAssertTrue(viewModel.hasPendingWork)
        XCTAssertTrue(viewModel.canCloseCash)
        XCTAssertEqual(pendingRepository.pendingSalesCallCount, 1)
        XCTAssertEqual(dailyReportRepository.lastBusinessDate, viewModel.selectedBusinessDateString)
        XCTAssertEqual(cashRepository.currentCallCount, 1)
    }

    func testSellerWithoutCashAccessDoesNotCallCashCurrent() async {
        let pendingRepository = PendingOperationsRepositorySpy()
        let dailyReportRepository = BusinessDailyReportRepositorySpy(
            response: BusinessDailyReportResponse(report: makeReport())
        )
        let cashRepository = CashRepositorySpyForDailyClosure(
            currentError: APIError.server(
                statusCode: 422,
                code: "domain_rule_violation",
                message: "Missing required permission: cash.session.view_current.",
                requestId: nil
            )
        )

        let viewModel = makeViewModel(
            pendingRepository: pendingRepository,
            dailyReportRepository: dailyReportRepository,
            cashRepository: cashRepository,
            effectivePermissions: [
                "reports.today",
                "sales.view",
                "receivables.view",
                "documents.view"
            ],
            capabilities: makeCapabilities(
                reports: ReportCapabilities(canViewToday: true, canViewSales: true),
                sales: SalesCapabilities(canView: true),
                cash: CashCapabilities()
            )
        )

        await viewModel.load()

        XCTAssertEqual(cashRepository.currentCallCount, 0)
        XCTAssertEqual(viewModel.cashState, AsyncViewState<CashSession?>.loaded(nil))
        XCTAssertFalse(viewModel.canAccessCash)
        XCTAssertFalse(viewModel.canViewCash)
        XCTAssertFalse(viewModel.canOpenCash)
        XCTAssertFalse(viewModel.errorMessage?.contains("Missing required permission") == true)
        XCTAssertFalse(viewModel.errorMessage?.contains("cash.session.view_current") == true)
    }

    func testCashPermissionFailureIsHumanizedWhenCashWasExpected() async {
        let pendingRepository = PendingOperationsRepositorySpy()
        let dailyReportRepository = BusinessDailyReportRepositorySpy(
            response: BusinessDailyReportResponse(report: makeReport())
        )
        let cashRepository = CashRepositorySpyForDailyClosure(
            currentError: APIError.server(
                statusCode: 422,
                code: "domain_rule_violation",
                message: "Missing required permission: cash.session.view_current.",
                requestId: nil
            )
        )

        let viewModel = makeViewModel(
            pendingRepository: pendingRepository,
            dailyReportRepository: dailyReportRepository,
            cashRepository: cashRepository,
            capabilities: makeCapabilities(cash: CashCapabilities(canViewCurrent: true))
        )

        await viewModel.load()

        XCTAssertEqual(cashRepository.currentCallCount, 1)
        XCTAssertEqual(viewModel.cashState, AsyncViewState<CashSession?>.failed("No tienes permiso para consultar caja."))
        XCTAssertFalse(viewModel.errorMessage?.contains("Missing required permission") == true)
        XCTAssertFalse(viewModel.errorMessage?.contains("cash.session.view_current") == true)
    }

    func testLoadWithoutDailyClosurePermissionFailsEarly() async {
        let pendingRepository = PendingOperationsRepositorySpy()
        let dailyReportRepository = BusinessDailyReportRepositorySpy()
        let cashRepository = CashRepositorySpyForDailyClosure()

        let viewModel = DailyClosureViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            revisions: BusinessRevisions(
                catalogRevision: "cat_1",
                taxConfigurationRevision: "tax_1"
            ),
            effectivePermissions: [],
            pendingRepository: pendingRepository,
            dailyReportRepository: dailyReportRepository,
            cashRepository: cashRepository
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar pendientes y cierre diario.")
        XCTAssertEqual(pendingRepository.pendingSalesCallCount, 0)
        XCTAssertEqual(dailyReportRepository.callCount, 0)
        XCTAssertEqual(cashRepository.currentCallCount, 0)
    }

    func testPartialFailureKeepsSuccessfulDataAndShowsError() async {
        let report = makeReport()
        let cashSession = makeCashSession()
        let receivable = makeReceivable()

        let pendingRepository = PendingOperationsRepositorySpy(
            receivablesResponse: PendingReceivablesResponse(
                receivables: [receivable],
                total: 1
            ),
            documentsResponse: PendingDocumentsResponse(
                documents: [],
                total: 0
            ),
            salesError: APIError.server(
                statusCode: 500,
                code: "internal_error",
                message: "Error de ventas",
                requestId: "req_1"
            )
        )

        let dailyReportRepository = BusinessDailyReportRepositorySpy(
            response: BusinessDailyReportResponse(report: report)
        )

        let cashRepository = CashRepositorySpyForDailyClosure(
            currentResponse: CashCurrentSessionResponse(session: cashSession)
        )

        let viewModel = makeViewModel(
            pendingRepository: pendingRepository,
            dailyReportRepository: dailyReportRepository,
            cashRepository: cashRepository,
            capabilities: makeCapabilities(cash: CashCapabilities(canViewCurrent: true, canClose: true))
        )

        await viewModel.load()

        XCTAssertEqual(
            viewModel.reportState,
            AsyncViewState<BusinessDailyReport?>.loaded(report)
        )

        XCTAssertEqual(
            viewModel.cashState,
            AsyncViewState<CashSession?>.loaded(cashSession)
        )

        XCTAssertEqual(viewModel.pendingSales.count, 0)
        XCTAssertEqual(viewModel.pendingReceivables.count, 1)
        XCTAssertTrue(viewModel.errorMessage?.contains("Ventas: El servidor no respondió correctamente") == true)
        XCTAssertFalse(viewModel.errorMessage?.contains("Missing required permission") == true)
        XCTAssertFalse(viewModel.errorMessage?.contains("cash.session.view_current") == true)
    }

    private func makeViewModel(
        pendingRepository: PendingOperationsRepositorySpy,
        dailyReportRepository: BusinessDailyReportRepositorySpy,
        cashRepository: CashRepositorySpyForDailyClosure,
        effectivePermissions: Set<String> = [
            "reports.today",
            "sales.view",
            "receivables.view",
            "documents.view",
            "cash.session.view_current",
            "cash.session.close"
        ],
        capabilities: BusinessCapabilities? = nil
    ) -> DailyClosureViewModel {
        DailyClosureViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            revisions: BusinessRevisions(
                catalogRevision: "cat_1",
                taxConfigurationRevision: "tax_1"
            ),
            effectivePermissions: effectivePermissions,
            capabilities: capabilities,
            pendingRepository: pendingRepository,
            dailyReportRepository: dailyReportRepository,
            cashRepository: cashRepository
        )
    }
}

private final class PendingOperationsRepositorySpy: PendingOperationsRepository, @unchecked Sendable {
    var pendingSalesCallCount = 0
    var pendingReceivablesCallCount = 0
    var pendingDocumentsCallCount = 0

    let salesResponse: PendingSalesResponse
    let receivablesResponse: PendingReceivablesResponse
    let documentsResponse: PendingDocumentsResponse
    let salesError: Error?
    let receivablesError: Error?
    let documentsError: Error?

    init(
        salesResponse: PendingSalesResponse = PendingSalesResponse(sales: [], total: 0),
        receivablesResponse: PendingReceivablesResponse = PendingReceivablesResponse(receivables: [], total: 0),
        documentsResponse: PendingDocumentsResponse = PendingDocumentsResponse(documents: [], total: 0),
        salesError: Error? = nil,
        receivablesError: Error? = nil,
        documentsError: Error? = nil
    ) {
        self.salesResponse = salesResponse
        self.receivablesResponse = receivablesResponse
        self.documentsResponse = documentsResponse
        self.salesError = salesError
        self.receivablesError = receivablesError
        self.documentsError = documentsError
    }

    func pendingSales(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingSalesResponse {
        pendingSalesCallCount += 1
        if let salesError {
            throw salesError
        }
        return salesResponse
    }

    func pendingReceivables(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingReceivablesResponse {
        pendingReceivablesCallCount += 1
        if let receivablesError {
            throw receivablesError
        }
        return receivablesResponse
    }

    func pendingDocuments(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingDocumentsResponse {
        pendingDocumentsCallCount += 1
        if let documentsError {
            throw documentsError
        }
        return documentsResponse
    }
}

private final class BusinessDailyReportRepositorySpy: BusinessDailyReportRepository, @unchecked Sendable {
    var callCount = 0
    var lastBusinessDate: String?
    let response: BusinessDailyReportResponse
    let error: Error?

    init(
        response: BusinessDailyReportResponse = BusinessDailyReportResponse(report: makeReport()),
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func dailyReport(
        organizationId: String,
        branchId: String,
        businessDate: String
    ) async throws -> BusinessDailyReportResponse {
        callCount += 1
        lastBusinessDate = businessDate
        if let error {
            throw error
        }
        return response
    }
}

private final class CashRepositorySpyForDailyClosure: CashRepository, @unchecked Sendable {
    var currentCallCount = 0
    let currentResponse: CashCurrentSessionResponse
    let currentError: Error?

    init(
        currentResponse: CashCurrentSessionResponse = CashCurrentSessionResponse(session: nil),
        currentError: Error? = nil
    ) {
        self.currentResponse = currentResponse
        self.currentError = currentError
    }

    func current(
        organizationId: String,
        branchId: String
    ) async throws -> CashCurrentSessionResponse {
        currentCallCount += 1
        if let currentError {
            throw currentError
        }
        return currentResponse
    }

    func open(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: OpenCashSessionRequest
    ) async throws -> CashSessionResponse {
        throw APIError.server(
            statusCode: 501,
            code: "not_implemented",
            message: "Not implemented in this test.",
            requestId: nil
        )
    }

    func registerMovement(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterCashMovementRequest
    ) async throws -> CashMovementResponse {
        throw APIError.server(
            statusCode: 501,
            code: "not_implemented",
            message: "Not implemented in this test.",
            requestId: nil
        )
    }

    func close(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: CloseCashSessionRequest
    ) async throws -> CashSessionResponse {
        throw APIError.server(
            statusCode: 501,
            code: "not_implemented",
            message: "Not implemented in this test.",
            requestId: nil
        )
    }
}

private func makeCapabilities(
    reports: ReportCapabilities = ReportCapabilities(canViewToday: true, canViewSales: true),
    sales: SalesCapabilities = SalesCapabilities(canView: true),
    cash: CashCapabilities = CashCapabilities(),
    receivables: ReceivableCapabilities = ReceivableCapabilities(canView: true),
    documents: DocumentCapabilities = DocumentCapabilities(canView: true)
) -> BusinessCapabilities {
    BusinessCapabilities(
        sales: sales,
        cash: cash,
        receivables: receivables,
        documents: documents,
        reports: reports
    )
}

private func makeReport() -> BusinessDailyReport {
    BusinessDailyReport(
        businessDate: "2026-05-29",
        branchId: "br_1",
        salesCount: 3,
        salesTotal: MoneyAmount(amount: "30.00"),
        paymentsCount: 2,
        paymentsTotal: MoneyAmount(amount: "20.00"),
        cashExpectedAmount: MoneyAmount(amount: "40.00"),
        receivablesPendingCount: 1,
        receivablesPendingTotal: MoneyAmount(amount: "10.00"),
        pendingSalesCount: 1,
        pendingDocumentsCount: 1,
        cashStatus: "open",
        generatedAt: nil
    )
}

private func makeCashSession() -> CashSession {
    CashSession(
        id: "cash_1",
        branchId: "br_1",
        status: "open",
        openedAt: nil,
        closedAt: nil,
        openingAmount: MoneyAmount(amount: "20.00"),
        countedAmount: nil,
        expectedAmount: MoneyAmount(amount: "40.00"),
        differenceAmount: nil
    )
}

private func makeTotals() -> SaleTotals {
    SaleTotals(
        subtotalWithoutTaxes: MoneyAmount(amount: "10.00"),
        discountTotal: MoneyAmount(amount: "0.00"),
        taxTotal: MoneyAmount(amount: "1.50"),
        grandTotal: MoneyAmount(amount: "11.50")
    )
}

private func makeSale() -> BusinessSale {
    BusinessSale(
        id: "sale_1",
        organizationId: "org_1",
        branchId: "br_1",
        activityId: "act_1",
        status: "confirmed",
        paymentStatus: "unpaid",
        documentStatus: "not_required",
        totals: makeTotals()
    )
}

private func makeReceivable() -> ReceivableRecord {
    ReceivableRecord(
        id: "recv_1",
        saleId: "sale_1",
        customerId: "cus_1",
        status: "pending",
        amount: MoneyAmount(amount: "11.50"),
        balance: MoneyAmount(amount: "11.50")
    )
}

private func makeDocument() -> BusinessDocument {
    BusinessDocument(
        id: "doc_1",
        saleId: "sale_1",
        type: "electronic_invoice",
        status: "rejected",
        number: "001-001-000000001"
    )
}
