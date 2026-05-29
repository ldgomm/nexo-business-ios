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

        XCTAssertEqual(receivables.lastCollectRequest?.method, "transfer")
        XCTAssertNil(receivables.lastCollectRequest?.cashSessionId)
        XCTAssertEqual(receivables.lastCollectRequest?.reference, "TRX-002")
        XCTAssertTrue(receivables.lastCollectIdempotencyKey?.rawValue.hasPrefix("receivable-collect-") ?? false)
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
    var lastCollectIdempotencyKey: IdempotencyKey?
    var lastCollectRequest: CollectReceivableRequest?

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
