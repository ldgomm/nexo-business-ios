//
//  SalesHistoryViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class SalesHistoryViewModelTests: XCTestCase {
    func testLoadSearchesSalesWithFilters() async {
        let repository = SalesHistoryRepositorySpy(
            response: BusinessSalesHistoryResponse(
                sales: [makeSale(id: "sale_1", status: "confirmed")],
                total: 1,
                hasMore: false
            )
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.query = "sale_1"
        viewModel.selectedStatus = .confirmed
        viewModel.useDateFilter = false

        await viewModel.load()

        XCTAssertEqual(viewModel.sales.map(\.id), ["sale_1"])
        XCTAssertEqual(viewModel.total, 1)
        XCTAssertEqual(repository.lastRequest?.query, "sale_1")
        XCTAssertEqual(repository.lastRequest?.status, .confirmed)
        XCTAssertNil(repository.lastRequest?.date)
    }

    func testLoadRequiresPermission() async {
        let repository = SalesHistoryRepositorySpy(
            response: BusinessSalesHistoryResponse(sales: [])
        )
        let viewModel = SalesHistoryViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            revisions: BusinessRevisions(catalogRevision: "cat", taxConfigurationRevision: "tax"),
            effectivePermissions: [],
            historyRepository: repository
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar ventas.")
        XCTAssertNil(repository.lastRequest)
    }

    func testLoadMapsAPIErrorToHumanMessage() async {
        let repository = SalesHistoryRepositorySpy(
            error: APIError.server(
                statusCode: 428,
                code: "missing_required_revision",
                message: "Precondition required",
                requestId: "req_1"
            )
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.useDateFilter = false

        await viewModel.load()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Falta una revisión requerida de catálogo o configuración tributaria. Actualiza el contexto."
        )
        XCTAssertEqual(viewModel.infoMessage, "Actualiza el contexto del negocio antes de continuar.")
    }

    func testClearFiltersRestoresDefaults() {
        let repository = SalesHistoryRepositorySpy(
            response: BusinessSalesHistoryResponse(sales: [])
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.query = "abc"
        viewModel.selectedStatus = .closed
        viewModel.useDateFilter = false
        viewModel.errorMessage = "Error"
        viewModel.infoMessage = "Info"

        viewModel.clearFilters()

        XCTAssertEqual(viewModel.query, "")
        XCTAssertEqual(viewModel.selectedStatus, .all)
        XCTAssertTrue(viewModel.useDateFilter)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.infoMessage)
    }

    private func makeViewModel(
        repository: SalesHistoryRepository
    ) -> SalesHistoryViewModel {
        SalesHistoryViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            revisions: BusinessRevisions(catalogRevision: "cat", taxConfigurationRevision: "tax"),
            effectivePermissions: ["business.sales.view"],
            historyRepository: repository
        )
    }

    private func makeSale(
        id: String,
        status: String
    ) -> BusinessSale {
        BusinessSale(
            id: id,
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1",
            status: status,
            paymentStatus: "unpaid",
            documentStatus: "not_required",
            totals: SaleTotals(
                subtotalWithoutTaxes: MoneyAmount(amount: "10.00"),
                discountTotal: MoneyAmount(amount: "0.00"),
                taxTotal: MoneyAmount(amount: "1.50"),
                grandTotal: MoneyAmount(amount: "11.50")
            ),
            createdAt: Date()
        )
    }
}

private final class SalesHistoryRepositorySpy: SalesHistoryRepository, @unchecked Sendable {
    private let response: BusinessSalesHistoryResponse?
    private let error: Error?
    private(set) var lastOrganizationId: String?
    private(set) var lastRequest: SalesHistorySearchRequest?

    init(
        response: BusinessSalesHistoryResponse? = nil,
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func searchSales(
        organizationId: String,
        request: SalesHistorySearchRequest
    ) async throws -> BusinessSalesHistoryResponse {
        lastOrganizationId = organizationId
        lastRequest = request

        if let error {
            throw error
        }

        return response ?? BusinessSalesHistoryResponse(sales: [])
    }
}
