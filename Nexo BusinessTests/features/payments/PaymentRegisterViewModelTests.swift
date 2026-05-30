//
//  PaymentRegisterViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class PaymentRegisterViewModelTests: XCTestCase {
    func testCashPaymentRequiresOpenCashSession() async {
        let viewModel = makeViewModel(
            permissions: ["payments.collect"],
            cashSession: nil
        )

        await viewModel.load()
        viewModel.selectedMode = .cash

        XCTAssertFalse(viewModel.canSubmitPayment)
        await viewModel.registerPayment()
        XCTAssertEqual(viewModel.errorMessage, "Necesitas una caja abierta para cobrar en efectivo.")
    }

    func testRegistersCashPaymentWithCashSessionAndIdempotency() async {
        let payments = SpyPaymentsRepository()
        let viewModel = makeViewModel(
            permissions: ["payments.collect"],
            cashSession: openCashSession(),
            paymentsRepository: payments
        )

        await viewModel.load()
        viewModel.selectedMode = .cash
        viewModel.amount = "11.50"

        await viewModel.registerPayment()

        XCTAssertEqual(payments.lastRequest?.saleId, PreviewData.confirmedSaleResponse.sale.id)
        XCTAssertEqual(payments.lastRequest?.cashSessionId, "cash_open")
        XCTAssertEqual(payments.lastRequest?.method, "cash")
        XCTAssertEqual(payments.lastRequest?.amount, "11.50")
        XCTAssertTrue(payments.lastIdempotencyKey?.rawValue.hasPrefix("payment-register-") ?? false)
        XCTAssertEqual(viewModel.infoMessage, "Cobro registrado correctamente.")
    }

    func testTransferPaymentDoesNotRequireCashSession() async {
        let payments = SpyPaymentsRepository()
        let viewModel = makeViewModel(
            permissions: ["payments.collect"],
            cashSession: nil,
            paymentsRepository: payments
        )

        await viewModel.load()
        viewModel.selectedMode = .transfer
        viewModel.reference = "TRX-001"
        viewModel.amount = "11.50"

        await viewModel.registerPayment()

        XCTAssertNil(payments.lastRequest?.cashSessionId)
        XCTAssertEqual(payments.lastRequest?.method, "transfer")
        XCTAssertEqual(payments.lastRequest?.reference, "TRX-001")
    }

    func testCreditRequiresCustomerId() async {
        let viewModel = makeViewModel(
            sale: saleWithoutCustomer(),
            permissions: ["receivables.create"],
            cashSession: openCashSession()
        )

        await viewModel.load()
        viewModel.selectedMode = .credit
        viewModel.customerId = ""

        XCTAssertFalse(viewModel.canCreateReceivable)
        await viewModel.createReceivable()
        XCTAssertEqual(viewModel.errorMessage, "Para dejar una venta por cobrar necesitas un cliente identificado.")
    }

    func testCreatesReceivableWithCustomerAndIdempotency() async {
        let receivables = SpyReceivablesRepository()
        let viewModel = makeViewModel(
            permissions: ["receivables.create"],
            cashSession: openCashSession(),
            receivablesRepository: receivables
        )

        await viewModel.load()
        viewModel.selectedMode = .credit
        viewModel.customerId = "cus_001"
        viewModel.amount = "11.50"

        await viewModel.createReceivable()

        XCTAssertEqual(receivables.lastCreateRequest?.saleId, PreviewData.confirmedSaleResponse.sale.id)
        XCTAssertEqual(receivables.lastCreateRequest?.customerId, "cus_001")
        XCTAssertEqual(receivables.lastCreateRequest?.amount, "11.50")
        XCTAssertTrue(receivables.lastCreateIdempotencyKey?.rawValue.hasPrefix("receivable-create-") ?? false)
        XCTAssertEqual(viewModel.infoMessage, "Cuenta por cobrar creada correctamente.")
    }

    func testMapsBackendConflictToHumanMessage() async {
        let payments = SpyPaymentsRepository(
            error: APIError.server(
                statusCode: 409,
                code: "stale_catalog_revision",
                message: "Conflict",
                requestId: "req_1"
            )
        )
        let viewModel = makeViewModel(
            permissions: ["payments.collect"],
            cashSession: openCashSession(),
            paymentsRepository: payments
        )

        await viewModel.load()
        viewModel.selectedMode = .cash
        await viewModel.registerPayment()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La información del negocio cambió. Actualiza el contexto e inténtalo otra vez."
        )
    }

    private func makeViewModel(
        sale: BusinessSale? = nil,
        permissions: Set<String>,
        cashSession: CashSession?,
        paymentsRepository: SpyPaymentsRepository = SpyPaymentsRepository(),
        receivablesRepository: SpyReceivablesRepository = SpyReceivablesRepository()
    ) -> PaymentRegisterViewModel {
        PaymentRegisterViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            sale: sale ?? saleWithCustomer(),
            effectivePermissions: permissions,
            cashRepository: SpyCashRepository(currentSession: cashSession),
            paymentsRepository: paymentsRepository,
            receivablesRepository: receivablesRepository
        )
    }

    private func openCashSession() -> CashSession {
        CashSession(
            id: "cash_open",
            branchId: PreviewData.businessContext.branches[0].id,
            status: "open",
            openedAt: Date(),
            closedAt: nil,
            openingAmount: MoneyAmount(amount: "20.00"),
            countedAmount: nil,
            expectedAmount: MoneyAmount(amount: "31.50"),
            differenceAmount: nil
        )
    }

    private func saleWithCustomer() -> BusinessSale {
        BusinessSale(
            id: PreviewData.confirmedSaleResponse.sale.id,
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            activityId: PreviewData.businessContext.activities[0].id,
            customerId: "cus_001",
            status: "confirmed",
            paymentStatus: "unpaid",
            documentStatus: "not_required",
            totals: PreviewData.totals,
            items: PreviewData.previewResponse.items,
            createdAt: Date(),
            confirmedAt: Date()
        )
    }

    private func saleWithoutCustomer() -> BusinessSale {
        BusinessSale(
            id: PreviewData.confirmedSaleResponse.sale.id,
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            activityId: PreviewData.businessContext.activities[0].id,
            status: "confirmed",
            paymentStatus: "unpaid",
            documentStatus: "not_required",
            totals: PreviewData.totals,
            items: PreviewData.previewResponse.items,
            createdAt: Date(),
            confirmedAt: Date()
        )
    }
}

private final class SpyCashRepository: CashRepository, @unchecked Sendable {
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
    ) async throws -> CashSessionResponse {
        fatalError("Not needed in this test")
    }

    func registerMovement(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterCashMovementRequest
    ) async throws -> CashMovementResponse {
        fatalError("Not needed in this test")
    }

    func close(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: CloseCashSessionRequest
    ) async throws -> CashSessionResponse {
        fatalError("Not needed in this test")
    }
}

private final class SpyPaymentsRepository: PaymentsRepository, @unchecked Sendable {
    var lastIdempotencyKey: IdempotencyKey?
    var lastRequest: RegisterPaymentRequest?
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func register(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPaymentRequest
    ) async throws -> PaymentResponse {
        if let error { throw error }
        lastIdempotencyKey = idempotencyKey
        lastRequest = request

        return PaymentResponse(
            payment: PaymentRecord(
                id: "pay_test",
                saleId: request.saleId,
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

private final class SpyReceivablesRepository: ReceivablesRepository, @unchecked Sendable {
    var lastCreateIdempotencyKey: IdempotencyKey?
    var lastCreateRequest: CreateReceivableRequest?

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateReceivableRequest
    ) async throws -> ReceivableResponse {
        lastCreateIdempotencyKey = idempotencyKey
        lastCreateRequest = request

        let amount = request.amount ?? PreviewData.confirmedSaleResponse.sale.totals.grandTotal.amount

        return ReceivableResponse(
            receivable: ReceivableRecord(
                id: "recv_test",
                saleId: request.saleId,
                customerId: request.customerId,
                status: "pending",
                amount: MoneyAmount(amount: amount),
                balance: MoneyAmount(amount: amount),
                dueDate: request.dueDate,
                createdAt: Date()
            ),
            idempotencyReplayed: false
        )
    }

    func collect(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CollectReceivableRequest
    ) async throws -> ReceivableCollectionResponse {
        fatalError("Not needed in this test")
    }
}
