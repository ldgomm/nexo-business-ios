//
//  CashDashboardViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class CashDashboardViewModelTests: XCTestCase {
    func testLoadCurrentSessionUpdatesState() async {
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(
                session: makeOpenSession()
            )
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.currentSession?.id, "cash_1")
        XCTAssertEqual(viewModel.currentSession?.status, "open")
        XCTAssertEqual(viewModel.state, .loaded(makeOpenSession()))
    }

    func testOpenCashRequiresPermission() async {
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: nil)
        )
        let viewModel = CashDashboardViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            permissions: [],
            cashRepository: repository
        )

        await viewModel.openCash()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para abrir caja.")
        XCTAssertNil(repository.lastOpenRequest)
    }

    func testOpenCashSendsIdempotencyAndUpdatesSession() async {
        let opened = makeOpenSession(openingAmount: "25.00")
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: nil),
            openResponse: CashSessionResponse(
                session: opened,
                idempotencyReplayed: false
            )
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.openingAmount = "25,00"
        viewModel.openingNote = "Inicio turno mañana"

        await viewModel.openCash()

        XCTAssertEqual(repository.lastOpenRequest?.openingAmount, "25.00")
        XCTAssertEqual(repository.lastOpenRequest?.note, "Inicio turno mañana")
        XCTAssertTrue(repository.lastOpenIdempotencyKey?.rawValue.hasPrefix("cash-open-") == true)
        XCTAssertEqual(viewModel.currentSession, opened)
        XCTAssertEqual(viewModel.successMessage, "Caja abierta correctamente.")
    }

    func testRegisterMovementRequiresOpenSession() async {
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: nil)
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.movementAmount = "5.00"

        await viewModel.registerMovement()

        XCTAssertEqual(viewModel.errorMessage, "Debes tener una caja abierta para registrar movimientos.")
        XCTAssertNil(repository.lastMovementRequest)
    }

    func testRegisterMovementSendsIdempotencyAndClearsInputs() async {
        let movement = CashMovement(
            id: "mov_1",
            cashSessionId: "cash_1",
            type: .inflow,
            amount: MoneyAmount(amount: "5.00"),
            note: "Cambio extra",
            status: "registered",
            createdAt: nil
        )
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: makeOpenSession()),
            movementResponse: CashMovementResponse(
                movement: movement,
                session: makeOpenSession(),
                idempotencyReplayed: false
            )
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        viewModel.movementType = .inflow
        viewModel.movementAmount = "5.00"
        viewModel.movementNote = "Cambio extra"

        await viewModel.registerMovement()

        XCTAssertEqual(repository.lastMovementRequest?.type, .inflow)
        XCTAssertEqual(repository.lastMovementRequest?.amount, "5.00")
        XCTAssertEqual(repository.lastMovementRequest?.note, "Cambio extra")
        XCTAssertTrue(repository.lastMovementIdempotencyKey?.rawValue.hasPrefix("cash-movement-") == true)
        XCTAssertEqual(viewModel.lastMovement, movement)
        XCTAssertEqual(viewModel.movementAmount, "")
        XCTAssertEqual(viewModel.movementNote, "")
    }

    func testCloseCashSendsCountedAmountAndUpdatesSession() async {
        let closed = CashSession(
            id: "cash_1",
            branchId: "br_1",
            status: "closed",
            openedAt: nil,
            closedAt: nil,
            openingAmount: MoneyAmount(amount: "20.00"),
            countedAmount: MoneyAmount(amount: "40.00"),
            expectedAmount: MoneyAmount(amount: "40.00"),
            differenceAmount: MoneyAmount(amount: "0.00")
        )
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: makeOpenSession()),
            closeResponse: CashSessionResponse(
                session: closed,
                idempotencyReplayed: false
            )
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        viewModel.countedAmount = "40.00"
        viewModel.closingNote = "Cierre sin novedad"

        await viewModel.closeCash()

        XCTAssertEqual(repository.lastCloseRequest?.countedAmount, "40.00")
        XCTAssertEqual(repository.lastCloseRequest?.note, "Cierre sin novedad")
        XCTAssertTrue(repository.lastCloseIdempotencyKey?.rawValue.hasPrefix("cash-close-") == true)
        XCTAssertEqual(viewModel.currentSession, closed)
        XCTAssertEqual(viewModel.successMessage, "Caja cerrada correctamente.")
    }

    private func makeViewModel(
        repository: CashRepositorySpy,
        permissions: Set<String> = [
            "cash.view_current",
            "cash.open",
            "cash.close",
            "cash.register_inflow",
            "cash.register_outflow",
            "cash.adjust"
        ]
    ) -> CashDashboardViewModel {
        CashDashboardViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            permissions: permissions,
            cashRepository: repository
        )
    }

    private func makeOpenSession(openingAmount: String = "20.00") -> CashSession {
        CashSession(
            id: "cash_1",
            branchId: "br_1",
            status: "open",
            openedAt: nil,
            closedAt: nil,
            openingAmount: MoneyAmount(amount: openingAmount),
            countedAmount: nil,
            expectedAmount: MoneyAmount(amount: openingAmount),
            differenceAmount: nil
        )
    }
}

private final class CashRepositorySpy: CashRepository, @unchecked Sendable {
    let currentResponse: CashCurrentSessionResponse
    let openResponse: CashSessionResponse?
    let movementResponse: CashMovementResponse?
    let closeResponse: CashSessionResponse?

    var lastOpenRequest: OpenCashSessionRequest?
    var lastOpenIdempotencyKey: IdempotencyKey?
    var lastMovementRequest: RegisterCashMovementRequest?
    var lastMovementIdempotencyKey: IdempotencyKey?
    var lastCloseRequest: CloseCashSessionRequest?
    var lastCloseIdempotencyKey: IdempotencyKey?

    init(
        currentResponse: CashCurrentSessionResponse,
        openResponse: CashSessionResponse? = nil,
        movementResponse: CashMovementResponse? = nil,
        closeResponse: CashSessionResponse? = nil
    ) {
        self.currentResponse = currentResponse
        self.openResponse = openResponse
        self.movementResponse = movementResponse
        self.closeResponse = closeResponse
    }

    func current(
        organizationId: String,
        branchId: String
    ) async throws -> CashCurrentSessionResponse {
        currentResponse
    }

    func open(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: OpenCashSessionRequest
    ) async throws -> CashSessionResponse {
        lastOpenRequest = request
        lastOpenIdempotencyKey = idempotencyKey

        if let openResponse {
            return openResponse
        }

        return CashSessionResponse(
            session: CashSession(
                id: "cash_opened",
                branchId: request.branchId,
                status: "open",
                openedAt: nil,
                closedAt: nil,
                openingAmount: MoneyAmount(amount: request.openingAmount),
                countedAmount: nil
            ),
            idempotencyReplayed: false
        )
    }

    func registerMovement(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterCashMovementRequest
    ) async throws -> CashMovementResponse {
        lastMovementRequest = request
        lastMovementIdempotencyKey = idempotencyKey

        if let movementResponse {
            return movementResponse
        }

        return CashMovementResponse(
            movement: CashMovement(
                id: "mov_1",
                cashSessionId: cashSessionId,
                type: request.type,
                amount: MoneyAmount(amount: request.amount),
                note: request.note
            ),
            idempotencyReplayed: false
        )
    }

    func close(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: CloseCashSessionRequest
    ) async throws -> CashSessionResponse {
        lastCloseRequest = request
        lastCloseIdempotencyKey = idempotencyKey

        if let closeResponse {
            return closeResponse
        }

        return CashSessionResponse(
            session: CashSession(
                id: cashSessionId,
                branchId: "br_1",
                status: "closed",
                openedAt: nil,
                closedAt: nil,
                openingAmount: MoneyAmount(amount: "20.00"),
                countedAmount: MoneyAmount(amount: request.countedAmount)
            ),
            idempotencyReplayed: false
        )
    }
}
