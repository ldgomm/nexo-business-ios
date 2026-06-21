//
//  PaymentRegisterViewModelTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class PaymentRegisterViewModelTests: XCTestCase {
    func testUserWithoutPaymentOrReceivablePermissionDoesNotQueryCash() async {
        let cash = SpyCashRepository(currentSession: openCashSession())
        let viewModel = makeViewModel(
            permissions: ["sales.create"],
            cashRepository: cash
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.canAccessPaymentScreen)
        XCTAssertEqual(cash.currentCalls, 0)
        XCTAssertEqual(viewModel.errorMessage, viewModel.accessDeniedMessage)
    }

    func testCashPaymentRequiresOpenCashSession() async {
        let viewModel = makeViewModel(
            permissions: ["payments.collect", "cash.session.view_current"],
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
            permissions: ["payments.collect", "cash.session.view_current"],
            cashSession: openCashSession(),
            paymentsRepository: payments
        )

        await viewModel.load()
        viewModel.selectedMode = .cash
        viewModel.amount = "11.50"

        await viewModel.registerPayment()

        XCTAssertEqual(payments.lastRequest?.saleId, PreviewData.confirmedSaleResponse.sale.id)
        XCTAssertEqual(payments.lastRequest?.cashSessionId, "cash_open")
        XCTAssertEqual(payments.lastRequest?.method, "CASH")
        XCTAssertEqual(payments.lastRequest?.amount, "11.50")
        XCTAssertTrue(payments.lastIdempotencyKey?.rawValue.hasPrefix("payment-register-") ?? false)
        XCTAssertEqual(viewModel.infoMessage, "Cobro registrado. La caja fue actualizada automáticamente.")
    }

    func testTransferPaymentDoesNotRequireCashSession() async {
        let payments = SpyPaymentsRepository()
        let cash = SpyCashRepository(currentSession: nil)
        let viewModel = makeViewModel(
            permissions: ["payments.collect"],
            cashRepository: cash,
            paymentsRepository: payments
        )

        viewModel.selectedMode = .transfer
        await viewModel.load()
        viewModel.reference = "TRX-001"
        viewModel.amount = "11.50"

        await viewModel.registerPayment()

        XCTAssertEqual(cash.currentCalls, 0)
        XCTAssertNil(payments.lastRequest?.cashSessionId)
        XCTAssertEqual(payments.lastRequest?.method, "BANK_TRANSFER")
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

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("cliente identificado") == true)
        XCTAssertTrue(viewModel.errorMessage?.contains("Consumidor final no puede quedar fiado") == true)
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


    func testCreditWithSelectedCustomerPersistsCustomerBeforeCreatingReceivable() async {
        let receivables = SpyReceivablesRepository()
        let sales = SpyPaymentSalesRepository(initialSale: saleWithoutCustomer())
        sales.updateCustomerResponse = QuickSaleResponse(
            sale: saleWithCustomer(
                id: "cus_009",
                name: "Cliente Crédito Seguro",
                identification: "1710034065"
            )
        )
        let viewModel = makeViewModel(
            sale: saleWithoutCustomer(),
            permissions: ["receivables.create"],
            cashSession: openCashSession(),
            receivablesRepository: receivables,
            salesRepository: sales
        )

        await viewModel.load()
        viewModel.selectedMode = .credit
        viewModel.selectCustomer(
            BusinessCustomer(
                id: "cus_009",
                displayName: "Cliente Crédito Seguro",
                identificationType: .cedula,
                identificationNumber: "1710034065"
            )
        )
        viewModel.amount = "11.50"

        await viewModel.createReceivable()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(sales.lastUpdateCustomerRequest?.customerId, "cus_009")
        XCTAssertEqual(sales.lastUpdateCustomerRequest?.customerSnapshot?.displayName, "Cliente Crédito Seguro")
        XCTAssertEqual(receivables.lastCreateRequest?.saleId, PreviewData.confirmedSaleResponse.sale.id)
        XCTAssertEqual(receivables.lastCreateRequest?.customerId, "cus_009")
        XCTAssertEqual(viewModel.infoMessage, "Cuenta por cobrar creada correctamente.")
    }

    func testManualCustomerIdWithoutPersistedSaleCustomerDoesNotCreateReceivable() async {
        let receivables = SpyReceivablesRepository()
        let viewModel = makeViewModel(
            sale: saleWithoutCustomer(),
            permissions: ["receivables.create"],
            cashSession: openCashSession(),
            receivablesRepository: receivables
        )

        await viewModel.load()
        viewModel.selectedMode = .credit
        viewModel.customerId = "cus_manual"
        viewModel.amount = "11.50"

        XCTAssertFalse(viewModel.canCreateReceivable)
        await viewModel.createReceivable()

        XCTAssertNil(receivables.lastCreateRequest)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Para dejar una venta por cobrar necesitas seleccionar un cliente identificado. Consumidor final no puede quedar fiado."
        )
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
            permissions: ["payments.collect", "cash.session.view_current"],
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

    func testMissingPermissionFromBackendIsNotShownRaw() async {
        let cash = SpyCashRepository(
            currentError: APIError.server(
                statusCode: 422,
                code: "domain_rule_violation",
                message: "Missing required permission: cash.session.view_current.",
                requestId: nil
            )
        )
        let viewModel = makeViewModel(
            permissions: ["payments.collect", "cash.session.view_current"],
            cashRepository: cash
        )

        await viewModel.load()

        XCTAssertEqual(
            viewModel.errorMessage,
            "No puedes cobrar en efectivo con tu usuario actual. Pide que activen Ver caja actual y Registrar cobros."
        )
    }

    private func makeViewModel(
        sale: BusinessSale? = nil,
        permissions: Set<String>,
        cashSession: CashSession? = nil,
        cashRepository: SpyCashRepository? = nil,
        paymentsRepository: SpyPaymentsRepository = SpyPaymentsRepository(),
        receivablesRepository: SpyReceivablesRepository = SpyReceivablesRepository(),
        salesRepository: SalesRepository? = nil
    ) -> PaymentRegisterViewModel {
        PaymentRegisterViewModel(
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            sale: sale ?? saleWithCustomer(),
            effectivePermissions: permissions,
            cashRepository: cashRepository ?? SpyCashRepository(currentSession: cashSession),
            paymentsRepository: paymentsRepository,
            receivablesRepository: receivablesRepository,
            salesRepository: salesRepository,
            activityId: PreviewData.businessContext.activities[0].id,
            revisions: salesRepository.map { _ in PreviewData.businessContext.revisions }
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


    private func saleWithCustomer(
        id: String,
        name: String,
        identification: String
    ) -> BusinessSale {
        BusinessSale(
            id: PreviewData.confirmedSaleResponse.sale.id,
            organizationId: PreviewData.businessContext.organization.id,
            branchId: PreviewData.businessContext.branches[0].id,
            activityId: PreviewData.businessContext.activities[0].id,
            customerId: id,
            customerName: name,
            customer: BusinessSaleCustomer(
                id: id,
                displayName: name,
                identification: identification
            ),
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
    private let currentError: Error?
    var currentCalls = 0

    init(
        currentSession: CashSession? = nil,
        currentError: Error? = nil
    ) {
        self.currentSession = currentSession
        self.currentError = currentError
    }

    func current(
        organizationId: String,
        branchId: String
    ) async throws -> CashCurrentSessionResponse {
        currentCalls += 1
        if let currentError { throw currentError }
        return CashCurrentSessionResponse(session: currentSession)
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


private final class SpyPaymentSalesRepository: SalesRepository, @unchecked Sendable {
    var sale: BusinessSale
    var lastUpdateCustomerRequest: UpdateSaleCustomerRequest?
    var lastUpdateCustomerIdempotencyKey: IdempotencyKey?
    var updateCustomerResponse: QuickSaleResponse?

    init(initialSale: BusinessSale) {
        self.sale = initialSale
    }

    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse { fatalError("Not needed in this test") }

    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse { fatalError("Not needed in this test") }

    func bulkAddItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkAddSaleItemsRequest
    ) async throws -> QuickSaleResponse { fatalError("Not needed in this test") }

    func bulkUpdateItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkUpdateSaleItemsRequest
    ) async throws -> QuickSaleResponse { fatalError("Not needed in this test") }

    func bulkRemoveItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkRemoveSaleItemsRequest
    ) async throws -> QuickSaleResponse { fatalError("Not needed in this test") }

    func updateCustomer(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: UpdateSaleCustomerRequest
    ) async throws -> QuickSaleResponse {
        lastUpdateCustomerRequest = request
        lastUpdateCustomerIdempotencyKey = idempotencyKey
        if let updateCustomerResponse {
            sale = updateCustomerResponse.sale
            return updateCustomerResponse
        }
        return QuickSaleResponse(sale: sale)
    }

    func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse {
        BusinessSaleDetailResponse(sale: sale)
    }

    func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse { fatalError("Not needed in this test") }

    func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CancelSaleRequest
    ) async throws -> CancelSaleResponse { fatalError("Not needed in this test") }
}

private final class SpyReceivablesRepository: ReceivablesRepository, @unchecked Sendable {
    var lastCreateIdempotencyKey: IdempotencyKey?
    var lastCreateRequest: CreateReceivableRequest?

    func list(
        organizationId: String,
        customerId: String?,
        status: String?,
        limit: Int
    ) async throws -> ReceivablesListResponse {
        ReceivablesListResponse(receivables: [])
    }

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
