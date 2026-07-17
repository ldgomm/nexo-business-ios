//
//  BusinessSupplierPaymentsViewModelTests.swift
//  Nexo BusinessTests
//
//  27R.M.9A–9C — supplier-payment list, detail and void-action acceptance.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSupplierPaymentsViewModelTests: XCTestCase {
    func testLoadRequiresActivePurchasesModuleBeforeNetworkCall() async {
        let client = QueuedSupplierPaymentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            activeModules: [],
            permissions: [BusinessProcurementPermission.supplierPaymentsView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "El módulo Compras no está activo para esta organización."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testLoadRequiresSupplierPaymentsViewPermissionBeforeNetworkCall() async {
        let client = QueuedSupplierPaymentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(permissions: [], client: client)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "No tienes permiso para consultar pagos a proveedores."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testSearchUsesAcceptedContextStatusDateMethodQueryAndPaginationFilters() async throws {
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [Self.firstPageJSON, Self.supplierEnvelopeJSON]
        )
        let viewModel = makeListViewModel(client: client)
        viewModel.statusFilter = .recorded
        viewModel.paymentFrom = " 2026-07-01 "
        viewModel.paymentTo = " 2026-07-31 "
        viewModel.methodFilter = .bankTransfer
        viewModel.query = " PAG-0001 "

        await viewModel.search()

        XCTAssertEqual(viewModel.supplierPayments.map(\.id), ["spay_1"])
        XCTAssertEqual(
            viewModel.supplierPayments.first?.businessSupplierName,
            "Ferretería Uno"
        )
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.nextCursor, "cursor_2")
        XCTAssertNil(viewModel.errorMessage)

        let request = try XCTUnwrap(client.capturedRequests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.supplierPayments)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.queryDictionary["branchId"], "br_1")
        XCTAssertEqual(request.queryDictionary["supplierId"], "sup_1")
        XCTAssertEqual(request.queryDictionary["status"], "RECORDED")
        XCTAssertEqual(request.queryDictionary["paymentFrom"], "2026-07-01")
        XCTAssertEqual(request.queryDictionary["paymentTo"], "2026-07-31")
        XCTAssertEqual(request.queryDictionary["method"], "BANK_TRANSFER")
        XCTAssertEqual(request.queryDictionary["query"], "PAG-0001")
        XCTAssertEqual(request.queryDictionary["limit"], "50")
        XCTAssertNil(request.queryDictionary["cursor"])
        XCTAssertEqual(
            client.capturedRequests[1].path,
            BusinessProcurementRoutes.supplier("sup_1")
        )
    }

    func testPaymentOnlyPermissionDoesNotRequireSupplierEndpoint() async {
        let client = QueuedSupplierPaymentsAPIClient(responses: [Self.firstPageJSON])
        let viewModel = makeListViewModel(
            permissions: [BusinessProcurementPermission.supplierPaymentsView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(client.capturedRequests.count, 1)
        XCTAssertEqual(
            viewModel.supplierPayments.first?.businessSupplierName,
            "Proveedor no disponible"
        )
        XCTAssertNotNil(viewModel.referenceWarning)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testInvalidPaymentDateStopsBeforeNetworkCall() async {
        let client = QueuedSupplierPaymentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.paymentFrom = "31/07/2026"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial del pago debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testInvertedPaymentDateRangeStopsBeforeNetworkCall() async {
        let client = QueuedSupplierPaymentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.paymentFrom = "2026-08-01"
        viewModel.paymentTo = "2026-07-31"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial del pago no puede ser posterior a la final."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPaginationUsesCursorWithoutDuplicatingPaymentsOrSupplierLookups() async throws {
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [
                Self.firstPageJSON,
                Self.supplierEnvelopeJSON,
                Self.secondPageJSON,
            ]
        )
        let viewModel = makeListViewModel(client: client)

        await viewModel.loadIfNeeded()
        let firstPayment = try XCTUnwrap(viewModel.supplierPayments.first)
        await viewModel.loadNextPageIfNeeded(currentPayment: firstPayment)

        XCTAssertEqual(viewModel.supplierPayments.map(\.id), ["spay_1", "spay_2"])
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertNil(viewModel.nextCursor)
        XCTAssertEqual(client.capturedRequests.count, 3)
        XCTAssertEqual(client.capturedRequests[2].queryDictionary["cursor"], "cursor_2")
        XCTAssertEqual(
            client.capturedRequests.filter {
                $0.path == BusinessProcurementRoutes.supplier("sup_1")
            }.count,
            1
        )
    }

    func testEmptySearchPresentsExplicitEmptyState() async {
        let client = QueuedSupplierPaymentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)

        await viewModel.search()

        XCTAssertTrue(viewModel.supplierPayments.isEmpty)
        XCTAssertEqual(
            viewModel.infoMessage,
            "No encontramos pagos a proveedores con estos filtros."
        )
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testListMapsAPIErrorToHumanMessage() async {
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [],
            failures: [
                .server(
                    statusCode: 503,
                    code: "procurement_temporarily_unavailable",
                    message: "upstream exception",
                    requestId: "req_supplier_payments"
                ),
            ]
        )
        let viewModel = makeListViewModel(client: client)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "El servidor no respondió correctamente. Inténtalo nuevamente en unos segundos."
        )
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testDetailRefreshPreservesServerPaymentAllocationAndReferenceTruth() async throws {
        let initial = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [
                Self.paymentEnvelopeJSON,
                Self.supplierEnvelopeJSON,
                Self.payableEnvelopeJSON,
                Self.supplierDocumentEnvelopeJSON,
            ]
        )
        let viewModel = BusinessSupplierPaymentDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsSensitiveView,
                BusinessProcurementPermission.suppliersView,
                BusinessProcurementPermission.payablesView,
                BusinessProcurementPermission.supplierDocumentsView,
            ],
            supplierPayment: initial,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.businessSupplierName, "Ferretería Uno")
        XCTAssertEqual(viewModel.supplierPayment.paymentNumber, "PAG-0001")
        XCTAssertEqual(viewModel.supplierPayment.paymentDate, "2026-07-31")
        XCTAssertEqual(viewModel.supplierPayment.amount.amount, "20.00")
        XCTAssertEqual(viewModel.supplierPayment.status, .recorded)
        XCTAssertEqual(viewModel.supplierPayment.allocations.count, 1)
        XCTAssertEqual(
            viewModel.supplierPayment.allocations.first?.payableBalanceBefore.amount,
            "62.00"
        )
        XCTAssertEqual(
            viewModel.supplierPayment.allocations.first?.payableBalanceAfter.amount,
            "42.00"
        )
        XCTAssertEqual(viewModel.visibleReference, "TRX-200")
        XCTAssertEqual(viewModel.visibleNotes, "Abono parcial")
        let allocation = try XCTUnwrap(viewModel.supplierPayment.allocations.first)
        XCTAssertEqual(
            viewModel.allocationTitle(for: allocation, index: 0),
            "Documento 001-001-0000123"
        )
        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertNil(viewModel.errorMessage)

        XCTAssertEqual(
            client.capturedRequests.map(\.path),
            [
                BusinessProcurementRoutes.supplierPayment("spay_1"),
                BusinessProcurementRoutes.supplier("sup_1"),
                BusinessProcurementRoutes.payable("pay_1"),
                BusinessProcurementRoutes.supplierDocument("sdoc_1"),
            ]
        )
    }

    func testDetailRequiresPermissionAndProtectsSensitiveEvidence() async throws {
        let initial = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data
        let client = QueuedSupplierPaymentsAPIClient(responses: [Self.paymentEnvelopeJSON])
        let deniedViewModel = BusinessSupplierPaymentDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [],
            supplierPayment: initial,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        await deniedViewModel.loadIfNeeded()

        XCTAssertEqual(
            deniedViewModel.errorMessage,
            "No tienes permiso para consultar este pago a proveedor."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)

        let protectedViewModel = BusinessSupplierPaymentDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.supplierPaymentsView],
            supplierPayment: initial,
            supplierName: "Ferretería Uno",
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
        XCTAssertNil(protectedViewModel.visibleReference)
        XCTAssertNil(protectedViewModel.visibleNotes)
        XCTAssertFalse(protectedViewModel.canViewSensitiveEvidence)
    }

    func testVoidRequiresPermissionRecordedStateAndReasonBeforeNetworkCall() async throws {
        let recorded = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [Self.voidedPaymentEnvelopeJSON]
        )
        let denied = makeDetailViewModel(
            payment: recorded,
            permissions: [BusinessProcurementPermission.supplierPaymentsView],
            client: client
        )

        XCTAssertFalse(denied.canVoid)
        let deniedResult = await denied.void(reason: "Registro duplicado")
        XCTAssertNil(deniedResult)
        XCTAssertEqual(
            denied.errorMessage,
            "No tienes permiso para anular pagos a proveedores."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)

        let allowed = makeDetailViewModel(
            payment: recorded,
            permissions: [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsVoid,
            ],
            client: client
        )
        XCTAssertTrue(allowed.canVoid)
        let missingReasonResult = await allowed.void(reason: "   ")
        XCTAssertNil(missingReasonResult)
        XCTAssertEqual(allowed.errorMessage, "Ingresa el motivo de anulación.")
        XCTAssertTrue(client.capturedRequests.isEmpty)

        let alreadyVoided = try decodePaymentEnvelope(
            Self.voidedPaymentEnvelopeJSON
        ).data
        let finalState = makeDetailViewModel(
            payment: alreadyVoided,
            permissions: [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsVoid,
            ],
            client: client
        )
        XCTAssertFalse(finalState.canVoid)
        let finalStateResult = await finalState.void(reason: "Registro duplicado")
        XCTAssertNil(finalStateResult)
        XCTAssertEqual(
            finalState.errorMessage,
            "Solo un pago registrado puede anularse. Actualiza el detalle para confirmar su estado."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testVoidSendsStableKeyVersionAndTrimmedReasonThenUsesServerTruth() async throws {
        let recorded = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [Self.voidedPaymentEnvelopeJSON]
        )
        let viewModel = makeDetailViewModel(
            payment: recorded,
            permissions: [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsVoid,
            ],
            client: client
        )

        let payment = await viewModel.void(reason: "  Registro duplicado  ")

        XCTAssertEqual(payment?.status, .voided)
        XCTAssertEqual(viewModel.supplierPayment.status, .voided)
        XCTAssertEqual(viewModel.supplierPayment.version, 2)
        XCTAssertFalse(viewModel.canVoid)
        XCTAssertEqual(
            viewModel.infoMessage,
            "Pago anulado correctamente. El servidor conservó el historial y restauró sus aplicaciones."
        )
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.voidSupplierPayment("spay_1")
        )
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(
            request.headers[BusinessHeaders.idempotencyKey],
            Self.voidActionKey.rawValue
        )
        XCTAssertNil(request.headers[BusinessHeaders.branchId])
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 1)
        XCTAssertEqual(body["reason"] as? String, "Registro duplicado")
    }

    func testVoidRetryReusesTheSameIdempotencyKeyAndAcceptsReplay() async throws {
        let recorded = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [Self.replayedVoidedPaymentEnvelopeJSON],
            failures: [.transport("offline")]
        )
        let viewModel = makeDetailViewModel(
            payment: recorded,
            permissions: [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsVoid,
            ],
            client: client
        )

        let failedAttempt = await viewModel.void(reason: "Registro duplicado")
        XCTAssertNil(failedAttempt)
        XCTAssertEqual(
            viewModel.errorMessage,
            "No se pudo conectar. Revisa internet e inténtalo nuevamente."
        )

        let replayed = await viewModel.void(reason: "Registro duplicado")

        XCTAssertEqual(replayed?.status, .voided)
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            Set(client.capturedRequests.compactMap {
                $0.headers[BusinessHeaders.idempotencyKey]
            }),
            Set([Self.voidActionKey.rawValue])
        )
        XCTAssertEqual(
            viewModel.infoMessage,
            "El pago se recuperó de un intento de anulación anterior. Revisa el estado entregado por el servidor."
        )
    }

    func testVoidProcessingResponseDoesNotClaimCompletedRestoration() async throws {
        let recorded = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [Self.voidingPaymentEnvelopeJSON]
        )
        let viewModel = makeDetailViewModel(
            payment: recorded,
            permissions: [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsVoid,
            ],
            client: client
        )

        let payment = await viewModel.void(reason: "Corrección autorizada")

        XCTAssertEqual(payment?.status, .voiding)
        XCTAssertEqual(
            viewModel.infoMessage,
            "La anulación está en proceso. Actualiza el detalle antes de asumir que las aplicaciones fueron restauradas."
        )
        XCTAssertFalse(viewModel.canVoid)
    }

    func testVoidVersionConflictRequiresDetailRefresh() async throws {
        let recorded = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data
        let client = QueuedSupplierPaymentsAPIClient(
            responses: [],
            failures: [
                .server(
                    statusCode: 409,
                    code: "procurement_version_conflict",
                    message: "stale payment",
                    requestId: "req_void_conflict"
                ),
            ]
        )
        let viewModel = makeDetailViewModel(
            payment: recorded,
            permissions: [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsVoid,
            ],
            client: client
        )

        let conflictResult = await viewModel.void(reason: "Corrección autorizada")
        XCTAssertNil(conflictResult)

        XCTAssertEqual(viewModel.supplierPayment.status, .recorded)
        XCTAssertEqual(
            viewModel.errorMessage,
            "El pago cambió en el servidor. Actualiza el detalle antes de reintentar."
        )
    }

    func testPaymentPresentationUsesBackendStatusMethodMoneyAndCounts() throws {
        let payment = try decodePaymentEnvelope(Self.paymentEnvelopeJSON).data

        XCTAssertEqual(payment.status.businessSupplierPaymentDisplayName, "Registrado")
        XCTAssertTrue(
            payment.status.businessSupplierPaymentExplanation.contains("servidor")
        )
        XCTAssertEqual(payment.businessSupplierPaymentMethodName, "Transferencia bancaria")
        XCTAssertEqual(payment.businessAllocationCountText, "1 aplicación")
        XCTAssertEqual(payment.businessAttachmentCountText, "1 adjunto")
        XCTAssertEqual(
            payment.amount.businessDisplayText(locale: Locale(identifier: "en_US")),
            "$20.00"
        )
        XCTAssertEqual(
            payment.allocations.first?.businessAllocationStatusName,
            "Aplicada"
        )
    }

    func testPaymentSurfaceKeepsBankSensitiveAllocationAndBalanceBoundariesExplicit() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierPaymentsView.swift"
        )

        XCTAssertTrue(source.contains("no mueve dinero real"))
        XCTAssertTrue(source.contains("no recalcula saldos localmente"))
        XCTAssertTrue(source.contains("La app no suma aplicaciones"))
        XCTAssertTrue(source.contains("Saldo anterior"))
        XCTAssertTrue(source.contains("Saldo posterior"))
        XCTAssertTrue(source.contains("La referencia y las notas están protegidas"))
        XCTAssertTrue(source.contains("no almacena credenciales bancarias"))
        XCTAssertTrue(source.contains("Reintentar"))
        XCTAssertFalse(source.contains("Text(viewModel.supplierPayment.id)"))
        XCTAssertFalse(source.contains("Text(allocation.payableId)"))
        XCTAssertFalse(source.contains("Text(viewModel.supplierPayment.cashMovementId)"))
        XCTAssertFalse(source.contains(".reduce("))
    }

    func testVoidSurfaceRequiresReasonAndExplainsServerAuthoritativeEffects() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierPaymentsView.swift"
        )

        XCTAssertTrue(source.contains("if viewModel.canVoid"))
        XCTAssertTrue(source.contains("BusinessSupplierPaymentVoidView("))
        XCTAssertTrue(source.contains("Anular pago"))
        XCTAssertTrue(source.contains("Motivo de anulación"))
        XCTAssertTrue(source.contains("await viewModel.void(reason: reason)"))
        XCTAssertTrue(source.contains("El servidor restaura las aplicaciones"))
        XCTAssertTrue(source.contains("La app no mueve dinero real"))
        XCTAssertTrue(source.contains("El pago no se elimina"))
        XCTAssertFalse(source.contains("deleteSupplierPayment"))
    }

    private func makeListViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [
            BusinessProcurementPermission.supplierPaymentsView,
            BusinessProcurementPermission.suppliersView,
        ],
        client: QueuedSupplierPaymentsAPIClient
    ) -> BusinessSupplierPaymentsViewModel {
        BusinessSupplierPaymentsViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            supplierId: "sup_1",
            activeModules: activeModules,
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
    }

    private func makeDetailViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        payment: BusinessProcurementSupplierPaymentResponse,
        permissions: Set<String>,
        client: QueuedSupplierPaymentsAPIClient
    ) -> BusinessSupplierPaymentDetailViewModel {
        BusinessSupplierPaymentDetailViewModel(
            organizationId: "org_1",
            activeModules: activeModules,
            effectivePermissions: permissions,
            supplierPayment: payment,
            supplierName: "Ferretería Uno",
            repository: BusinessProcurementAPIRepository(apiClient: client),
            voidIdempotencyKey: Self.voidActionKey
        )
    }

    private func decodePaymentEnvelope(
        _ json: String
    ) throws -> BusinessProcurementSupplierPaymentEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementSupplierPaymentEnvelopeResponse.self,
            from: Data(json.utf8)
        )
    }

    private func sourceText(at repositoryRelativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(repositoryRelativePath),
            encoding: .utf8
        )
    }

    private static let emptyListJSON = #"{"supplierPayments":[],"nextCursor":null,"hasMore":false}"#

    private static var firstPageJSON: String {
        """
        {"supplierPayments":[\(paymentJSON(id: "spay_1", number: "PAG-0001", status: "RECORDED"))],"nextCursor":"cursor_2","hasMore":true}
        """
    }

    private static var secondPageJSON: String {
        """
        {"supplierPayments":[
          \(paymentJSON(id: "spay_1", number: "PAG-0001", status: "RECORDED")),
          \(paymentJSON(id: "spay_2", number: "PAG-0002", status: "VOIDED"))
        ],"nextCursor":null,"hasMore":false}
        """
    }

    private static var paymentEnvelopeJSON: String {
        """
        {"data":\(paymentJSON(id: "spay_1", number: "PAG-0001", status: "RECORDED")),"meta":{"requestId":"req_payment","idempotencyReplayed":false}}
        """
    }

    private static var voidingPaymentEnvelopeJSON: String {
        """
        {"data":\(paymentJSON(id: "spay_1", number: "PAG-0001", status: "VOIDING", version: 2)),"meta":{"requestId":"req_voiding","idempotencyReplayed":false}}
        """
    }

    private static var voidedPaymentEnvelopeJSON: String {
        """
        {"data":\(paymentJSON(id: "spay_1", number: "PAG-0001", status: "VOIDED", version: 2, voidReason: "Registro duplicado")),"meta":{"requestId":"req_voided","idempotencyReplayed":false}}
        """
    }

    private static var replayedVoidedPaymentEnvelopeJSON: String {
        """
        {"data":\(paymentJSON(id: "spay_1", number: "PAG-0001", status: "VOIDED", version: 2, voidReason: "Registro duplicado")),"meta":{"requestId":"req_voided_replay","idempotencyReplayed":true}}
        """
    }

    private static func paymentJSON(
        id: String,
        number: String,
        status: String,
        version: Int = 1,
        voidReason: String? = nil
    ) -> String {
        let isVoided = status == "VOIDED"
        let allocationStatus = isVoided ? "REVERSED" : "APPLIED"
        let reversedAt = isVoided ? #""2026-07-31T13:00:00Z""# : "null"
        let reversedBy = isVoided ? #""usr_2""# : "null"
        let encodedVoidReason = voidReason.map { "\"\($0)\"" } ?? "null"
        let voidedAt = isVoided ? #""2026-07-31T13:00:00Z""# : "null"
        let voidedBy = isVoided ? #""usr_2""# : "null"
        return """
        {
          "id":"\(id)","branchId":"br_1","supplierId":"sup_1","paymentNumber":"\(number)","paymentDate":"2026-07-31","currency":"USD",
          "amount":{"amount":"20.00","currency":"USD"},"method":"BANK_TRANSFER","reference":"TRX-200","status":"\(status)",
          "allocations":[{"id":"alloc_2","payableId":"pay_1","amount":{"amount":"20.00","currency":"USD"},
            "payableBalanceBefore":{"amount":"62.00","currency":"USD"},"payableBalanceAfter":{"amount":"42.00","currency":"USD"},
            "status":"\(allocationStatus)","createdAt":"2026-07-31T12:00:00Z","createdBy":"usr_1","reversedAt":\(reversedAt),"reversedBy":\(reversedBy),"reversalReason":\(encodedVoidReason)}],
          "attachmentIds":["att_1"],"cashMovementId":null,"notes":"Abono parcial","createdAt":"2026-07-31T12:00:00Z","createdBy":"usr_1",
          "updatedAt":"2026-07-31T12:00:00Z","updatedBy":"usr_1","recordedAt":"2026-07-31T12:00:00Z","recordedBy":"usr_1",
          "voidedAt":\(voidedAt),"voidedBy":\(voidedBy),"voidReason":\(encodedVoidReason),"version":\(version)
        }
        """
    }

    private static let voidActionKey = IdempotencyKey(
        rawValue: "supplier-payment-void-fixed"
    )

    private static var supplierEnvelopeJSON: String {
        """
        {"data":{
          "id":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Ferretería Uno","identificationType":"RUC","identificationNumber":"1790012345001",
          "email":"compras@example.com","phone":"0999999999","address":"Quito","categories":["FERRETERIA"],"contacts":[],
          "paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD","status":"ACTIVE","notes":null,
          "createdAt":"2026-07-01T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T12:00:00Z","updatedBy":"usr_1","version":2
        },"meta":{"requestId":"req_supplier","idempotencyReplayed":null}}
        """
    }

    private static var payableEnvelopeJSON: String {
        """
        {"data":{
          "id":"pay_1","branchId":"br_1","supplierId":"sup_1","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","currency":"USD",
          "originalAmount":{"amount":"112.00","currency":"USD"},"paidAmount":{"amount":"70.00","currency":"USD"},
          "balance":{"amount":"42.00","currency":"USD"},"dueDate":"2026-08-15","settlementStatus":"PARTIALLY_PAID","effectiveStatus":"PARTIALLY_PAID","allocationIds":["alloc_1","alloc_2"],
          "createdAt":"2026-07-15T15:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-31T12:00:00Z","updatedBy":"usr_1","version":3
        },"meta":{"requestId":"req_payable","idempotencyReplayed":null}}
        """
    }

    private static var supplierDocumentEnvelopeJSON: String {
        """
        {"data":{
          "id":"sdoc_1","branchId":"br_1","supplierId":"sup_1","documentType":"INVOICE","status":"CONFIRMED",
          "documentNumber":"001-001-0000123","documentNumberNormalized":"0010010000123","accessKey":"ACCESS-123","authorizationNumber":"AUTH-123",
          "documentDate":"2026-07-15","dueDate":"2026-08-15","currency":"USD","purchaseOrderIds":["po_1"],"purchaseReceiptIds":["rcpt_1"],
          "lines":[],"subtotal":{"amount":"100.00","currency":"USD"},"discountTotal":{"amount":"0.00","currency":"USD"},
          "taxTotal":{"amount":"12.00","currency":"USD"},"total":{"amount":"112.00","currency":"USD"},
          "sourceTotals":{"total":{"amount":"112.00","currency":"USD"},"taxTotal":{"amount":"12.00","currency":"USD"}},
          "sourcePayment":{"amount":{"amount":"50.00","currency":"USD"},"method":"BANK_TRANSFER","paymentDate":"2026-07-15","reference":"TRX-001"},
          "payableAmount":{"amount":"62.00","currency":"USD"},"payableId":"pay_1","attachmentIds":["att_1"],
          "accountingStatus":"READY_FOR_ACCOUNTING","notes":"Factura por reposición",
          "createdAt":"2026-07-15T14:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T15:00:00Z","updatedBy":"usr_1",
          "confirmedAt":"2026-07-15T15:00:00Z","confirmedBy":"usr_1","cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":3
        },"payable":null,"meta":{"requestId":"req_document","idempotencyReplayed":false}}
        """
    }
}

private struct CapturedSupplierPaymentRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }

    func jsonObject() throws -> [String: Any] {
        let body = try XCTUnwrap(body)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
    }
}

private final class QueuedSupplierPaymentsAPIClient: APIClient, @unchecked Sendable {
    private var responses: [Data]
    private var failures: [APIError]
    private(set) var capturedRequests: [CapturedSupplierPaymentRequest] = []

    init(responses: [String], failures: [APIError] = []) {
        self.responses = responses.map { Data($0.utf8) }
        self.failures = failures
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedSupplierPaymentRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers,
                body: request.body
            )
        )
        if !failures.isEmpty {
            throw failures.removeFirst()
        }
        guard !responses.isEmpty else {
            throw APIError.emptyResponse
        }
        return try JSONDecoder.nexoDefault.decode(
            Response.self,
            from: responses.removeFirst()
        )
    }
}
