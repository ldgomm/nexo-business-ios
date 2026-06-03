import XCTest
@testable import Nexo_Business

@MainActor
final class CashDashboardViewModelTests: XCTestCase {
    func testLoadCurrentSessionUpdatesStateWithCanonicalPermissions() async {
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(
                session: makeOpenSession()
            )
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(repository.currentCalls, 1)
        XCTAssertEqual(viewModel.currentSession?.id, "cash_1")
        XCTAssertEqual(viewModel.currentSession?.status, "open")
        XCTAssertEqual(viewModel.state, .loaded(makeOpenSession()))
    }

    func testCashierWithOpenPermissionCanOpenWhenNoSessionExists() async {
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: nil),
            openResponse: CashSessionResponse(
                session: makeOpenSession(openingAmount: "25.00"),
                idempotencyReplayed: false
            )
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.openingAmount = "25,00"
        viewModel.openingNote = "Inicio turno mañana"

        await viewModel.load()
        await viewModel.openCash()

        XCTAssertEqual(viewModel.state, .loaded(makeOpenSession(openingAmount: "25.00")))
        XCTAssertEqual(repository.lastOpenRequest?.openingAmount, "25.00")
        XCTAssertEqual(repository.lastOpenRequest?.note, "Inicio turno mañana")
        XCTAssertTrue(repository.lastOpenIdempotencyKey?.rawValue.hasPrefix("cash-open-") == true)
        XCTAssertEqual(viewModel.successMessage, "Caja abierta correctamente.")
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

    func testLoadDoesNotCallCurrentWhenUserCanOpenButCannotViewCurrent() async {
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: makeOpenSession())
        )
        let viewModel = CashDashboardViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            permissions: ["cash.session.open"],
            cashRepository: repository
        )

        await viewModel.load()

        XCTAssertEqual(repository.currentCalls, 0)
        XCTAssertNil(viewModel.currentSession)
        XCTAssertEqual(viewModel.state, .loaded(nil))
        XCTAssertTrue(viewModel.shouldShowOpenSection)
    }

    func testRegisterMovementRequiresOpenSession() async {
        let repository = CashRepositorySpy(
            currentResponse: CashCurrentSessionResponse(session: nil)
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.movementAmount = "5.00"

        await viewModel.registerMovement()

        XCTAssertEqual(viewModel.errorMessage, "Debes tener una caja abierta para registrar ajustes.")
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
            "cash.session.view_current",
            "cash.session.open",
            "cash.session.close",
            "cash.movements.register_inflow",
            "cash.movements.register_outflow",
            "cash.movements.adjust"
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

    var currentCalls = 0
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
        currentCalls += 1
        return currentResponse
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
