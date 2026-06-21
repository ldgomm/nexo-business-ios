//
//  ReceivableCollectionViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class ReceivableCollectionViewModelTests: XCTestCase {
    func testCashCollectionRequiresOpenCashSession() async {
        let viewModel = ReceivableCollectionViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            receivable: PreviewData.receivableResponse.receivable,
            effectivePermissions: ["receivables.collect"],
            cashRepository: CollectionSpyCashRepository(currentSession: nil),
            receivablesRepository: CollectionSpyReceivablesRepository()
        )

        await viewModel.load()
        viewModel.selectedMethod = .cash

        XCTAssertFalse(viewModel.canCollect)
        await viewModel.collect()
        XCTAssertEqual(viewModel.errorMessage, "Necesitas una caja abierta para registrar abonos en efectivo.")
    }

    func testListLoadsReceivablesAndFiltersByCustomer() async {
        let receivables = CollectionSpyReceivablesRepository()
        receivables.listResponse = ReceivablesListResponse(
            receivables: [
                ReceivableRecord(
                    id: "recv_001",
                    saleId: "sale_001",
                    customerId: "cus_001",
                    customerName: "Cliente crédito",
                    status: "open",
                    amount: MoneyAmount(amount: "26.60"),
                    balance: MoneyAmount(amount: "26.60"),
                    createdAt: Date()
                )
            ],
            total: 1,
            hasMore: false
        )

        let viewModel = ReceivablesListViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            customerId: "cus_001",
            effectivePermissions: ["receivables.view"],
            receivablesRepository: receivables
        )

        await viewModel.refresh()

        XCTAssertEqual(receivables.lastListCustomerId, "cus_001")
        XCTAssertEqual(receivables.lastListStatus, "open,partially_paid,partially_collected,overdue")
        XCTAssertEqual(viewModel.visibleReceivables.map(\.id), ["recv_001"])
        XCTAssertEqual(viewModel.activeSummaryText, "1 de 1 cuenta")
    }


    func testDoesNotCollectAlreadySettledReceivable() async {
        let receivables = CollectionSpyReceivablesRepository()
        let settled = ReceivableRecord(
            id: "recv_paid",
            saleId: "sale_paid",
            customerId: "cus_001",
            customerName: "Cliente crédito",
            status: "paid",
            amount: MoneyAmount(amount: "26.60"),
            balance: MoneyAmount(amount: "0.00"),
            createdAt: Date()
        )
        let viewModel = ReceivableCollectionViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            receivable: settled,
            effectivePermissions: ["receivables.collect"],
            cashRepository: CollectionSpyCashRepository(currentSession: nil),
            receivablesRepository: receivables
        )

        await viewModel.load()
        viewModel.selectedMethod = .transfer

        XCTAssertFalse(viewModel.canCollect)
        await viewModel.collect()
        XCTAssertNil(receivables.lastCollectRequest)
        XCTAssertEqual(viewModel.errorMessage, "Esta cuenta ya está cobrada. No se pueden registrar más abonos.")
    }

    func testBlocksAmountGreaterThanCurrentBalance() async {
        let receivables = CollectionSpyReceivablesRepository()
        let viewModel = ReceivableCollectionViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            receivable: ReceivableRecord(
                id: "recv_001",
                saleId: "sale_001",
                customerId: "cus_001",
                status: "open",
                amount: MoneyAmount(amount: "26.60"),
                balance: MoneyAmount(amount: "5.00"),
                createdAt: Date()
            ),
            effectivePermissions: ["receivables.collect"],
            cashRepository: CollectionSpyCashRepository(currentSession: nil),
            receivablesRepository: receivables
        )

        await viewModel.load()
        viewModel.selectedMethod = .transfer
        viewModel.amount = "26.60"

        XCTAssertFalse(viewModel.canCollect)
        await viewModel.collect()
        XCTAssertNil(receivables.lastCollectRequest)
        XCTAssertEqual(viewModel.errorMessage, "El monto no puede ser mayor al saldo pendiente.")
    }

    func testBalanceExceededBackendErrorIsHumanizedAndRefreshesReceivable() async {
        let receivables = CollectionSpyReceivablesRepository()
        receivables.collectError = APIError.server(
            statusCode: 422,
            code: "domain_rule_violation",
            message: "Collection amount cannot exceed receivable balance.",
            requestId: "req_test"
        )
        receivables.listResponse = ReceivablesListResponse(
            receivables: [
                ReceivableRecord(
                    id: "recv_001",
                    saleId: "sale_001",
                    customerId: "cus_001",
                    status: "paid",
                    amount: MoneyAmount(amount: "26.60"),
                    balance: MoneyAmount(amount: "0.00"),
                    createdAt: Date()
                )
            ]
        )
        let viewModel = ReceivableCollectionViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            receivable: ReceivableRecord(
                id: "recv_001",
                saleId: "sale_001",
                customerId: "cus_001",
                status: "open",
                amount: MoneyAmount(amount: "26.60"),
                balance: MoneyAmount(amount: "26.60"),
                createdAt: Date()
            ),
            effectivePermissions: ["receivables.collect"],
            cashRepository: CollectionSpyCashRepository(currentSession: nil),
            receivablesRepository: receivables
        )

        await viewModel.load()
        viewModel.selectedMethod = .transfer
        await viewModel.collect()

        XCTAssertEqual(viewModel.errorMessage, "El monto no puede ser mayor al saldo pendiente. Actualizamos la cuenta por cobrar.")
        XCTAssertTrue(viewModel.isSettled)
        XCTAssertEqual(viewModel.currentBalance.amount, "0.00")
        XCTAssertEqual(viewModel.amount, "0.00")
    }

    func testCollectsTransferWithoutCashSession() async {
        let receivables = CollectionSpyReceivablesRepository()
        let viewModel = ReceivableCollectionViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            receivable: PreviewData.receivableResponse.receivable,
            effectivePermissions: ["receivables.collect"],
            cashRepository: CollectionSpyCashRepository(currentSession: nil),
            receivablesRepository: receivables
        )

        await viewModel.load()
        viewModel.selectedMethod = .transfer
        viewModel.reference = "TRX-002"
        viewModel.amount = "5.00"

        await viewModel.collect()

        XCTAssertEqual(receivables.lastCollectRequest?.method, "BANK_TRANSFER")
        XCTAssertEqual(receivables.lastCollectRequest?.saleId, PreviewData.receivableResponse.receivable.saleId)
        XCTAssertNil(receivables.lastCollectRequest?.cashSessionId)
        XCTAssertEqual(receivables.lastCollectRequest?.reference, "TRX-002")
        XCTAssertTrue(receivables.lastCollectIdempotencyKey?.rawValue.hasPrefix("receivable-collect-") ?? false)
    }

    func testBlocksReceivableWithoutIdentifiedCustomer() async {
        let receivables = CollectionSpyReceivablesRepository()
        let viewModel = ReceivableCollectionViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            receivable: ReceivableRecord(
                id: "recv_dirty",
                saleId: "sale_dirty",
                customerId: nil,
                customerName: "Consumidor final",
                status: "open",
                amount: MoneyAmount(amount: "12.00"),
                balance: MoneyAmount(amount: "12.00"),
                createdAt: Date()
            ),
            effectivePermissions: ["receivables.collect"],
            cashRepository: CollectionSpyCashRepository(currentSession: nil),
            receivablesRepository: receivables
        )

        await viewModel.load()
        viewModel.selectedMethod = .transfer

        XCTAssertFalse(viewModel.canCollect)
        await viewModel.collect()
        XCTAssertNil(receivables.lastCollectRequest)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Esta cuenta por cobrar no tiene cliente identificado. Revísala antes de registrar abonos."
        )
    }

}

private final class CollectionSpyCashRepository: CashRepository, @unchecked Sendable {
    private let currentSession: CashSession?

    init(currentSession: CashSession?) {
        self.currentSession = currentSession
    }

    func current(
        organizationId: String,
        branchId: String
    ) async throws -> CashCurrentSessionResponse {
        CashCurrentSessionResponse(session: currentSession)
    }

    func open(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: OpenCashSessionRequest
    ) async throws -> CashSessionResponse { fatalError("Not needed") }

    func registerMovement(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterCashMovementRequest
    ) async throws -> CashMovementResponse { fatalError("Not needed") }

    func close(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: CloseCashSessionRequest
    ) async throws -> CashSessionResponse { fatalError("Not needed") }
}

private final class CollectionSpyReceivablesRepository: ReceivablesRepository, @unchecked Sendable {
    var lastListCustomerId: String?
    var lastListStatus: String?
    var listResponse = ReceivablesListResponse(receivables: [])
    var lastCollectIdempotencyKey: IdempotencyKey?
    var lastCollectRequest: CollectReceivableRequest?
    var collectError: Error?

    func list(
        organizationId: String,
        customerId: String?,
        status: String?,
        limit: Int
    ) async throws -> ReceivablesListResponse {
        lastListCustomerId = customerId
        lastListStatus = status
        return listResponse
    }

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateReceivableRequest
    ) async throws -> ReceivableResponse { fatalError("Not needed") }

    func collect(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CollectReceivableRequest
    ) async throws -> ReceivableCollectionResponse {
        if let collectError {
            throw collectError
        }
        lastCollectIdempotencyKey = idempotencyKey
        lastCollectRequest = request
        return ReceivableCollectionResponse(
            receivable: ReceivableRecord(
                id: request.receivableId,
                saleId: PreviewData.receivableResponse.receivable.saleId,
                customerId: PreviewData.receivableResponse.receivable.customerId,
                status: "partially_collected",
                amount: PreviewData.receivableResponse.receivable.amount,
                balance: MoneyAmount(amount: "6.50"),
                createdAt: Date()
            ),
            payment: PaymentRecord(
                id: "pay_collect_test",
                saleId: PreviewData.receivableResponse.receivable.saleId,
                status: "registered",
                method: request.method,
                amount: MoneyAmount(amount: request.amount),
                reference: request.reference,
                note: request.note,
                registeredAt: Date()
            ),
            idempotencyReplayed: false
        )
    }
}
