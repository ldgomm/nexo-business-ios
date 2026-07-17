//
//  BusinessPayablesViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessPayablesViewModelTests: XCTestCase {
    func testLoadRequiresActivePurchasesModuleBeforeNetworkCall() async {
        let client = QueuedPayablesAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            activeModules: [],
            permissions: [BusinessProcurementPermission.payablesView],
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

    func testLoadRequiresPayablesViewPermissionBeforeNetworkCall() async {
        let client = QueuedPayablesAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(permissions: [], client: client)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "No tienes permiso para consultar cuentas por pagar."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testSearchUsesAcceptedContextStatusDueCurrencyAsOfAndPaginationFilters() async throws {
        let client = QueuedPayablesAPIClient(
            responses: [
                Self.firstPageJSON,
                Self.supplierEnvelopeJSON,
                Self.supplierDocumentEnvelopeJSON,
            ]
        )
        let viewModel = makeListViewModel(client: client)
        viewModel.statusFilter = .outstanding
        viewModel.dueFrom = " 2026-08-01 "
        viewModel.dueTo = " 2026-08-31 "
        viewModel.currency = " usd "
        viewModel.asOf = " 2026-07-31 "

        await viewModel.search()

        XCTAssertEqual(viewModel.payables.map(\.id), ["pay_1"])
        XCTAssertEqual(viewModel.payables.first?.businessSupplierName, "Ferretería Uno")
        XCTAssertEqual(
            viewModel.payables.first?.businessSourceDescription,
            "001-001-0000123"
        )
        XCTAssertEqual(viewModel.snapshotAsOf, "2026-07-31")
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.nextCursor, "cursor_2")
        XCTAssertNil(viewModel.errorMessage)

        let request = try XCTUnwrap(client.capturedRequests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.payables)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.queryDictionary["branchId"], "br_1")
        XCTAssertEqual(request.queryDictionary["supplierId"], "sup_1")
        XCTAssertEqual(
            request.queryDictionary["effectiveStatus"],
            "OPEN,PARTIALLY_PAID,OVERDUE"
        )
        XCTAssertEqual(request.queryDictionary["dueFrom"], "2026-08-01")
        XCTAssertEqual(request.queryDictionary["dueTo"], "2026-08-31")
        XCTAssertEqual(request.queryDictionary["currency"], "USD")
        XCTAssertEqual(request.queryDictionary["asOf"], "2026-07-31")
        XCTAssertEqual(request.queryDictionary["limit"], "50")
        XCTAssertNil(request.queryDictionary["cursor"])
        XCTAssertEqual(
            client.capturedRequests[1].path,
            BusinessProcurementRoutes.supplier("sup_1")
        )
        XCTAssertEqual(
            client.capturedRequests[2].path,
            BusinessProcurementRoutes.supplierDocument("sdoc_1")
        )
    }

    func testPayableOnlyPermissionDoesNotRequireProtectedReferenceEndpoints() async {
        let client = QueuedPayablesAPIClient(responses: [Self.firstPageJSON])
        let viewModel = makeListViewModel(
            permissions: [BusinessProcurementPermission.payablesView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(client.capturedRequests.count, 1)
        XCTAssertEqual(
            viewModel.payables.first?.businessSupplierName,
            "Proveedor no disponible"
        )
        XCTAssertEqual(
            viewModel.payables.first?.businessSourceDescription,
            "Documento de proveedor"
        )
        XCTAssertNotNil(viewModel.referenceWarning)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testInvalidDueDateStopsBeforeNetworkCall() async {
        let client = QueuedPayablesAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.dueFrom = "31/08/2026"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial de vencimiento debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testInvertedDueDateRangeStopsBeforeNetworkCall() async {
        let client = QueuedPayablesAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.dueFrom = "2026-09-01"
        viewModel.dueTo = "2026-08-31"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial de vencimiento no puede ser posterior a la final."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testInvalidAsOfAndCurrencyStopBeforeNetworkCall() async {
        let client = QueuedPayablesAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.asOf = "2026-02-30"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha de corte debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)

        viewModel.asOf = ""
        viewModel.currency = "US"
        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La moneda debe usar un código de tres letras, por ejemplo USD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPaginationUsesCursorWithoutDuplicatingPayablesOrReferenceLookups() async throws {
        let client = QueuedPayablesAPIClient(
            responses: [
                Self.firstPageJSON,
                Self.supplierEnvelopeJSON,
                Self.supplierDocumentEnvelopeJSON,
                Self.secondPageJSON,
            ]
        )
        let viewModel = makeListViewModel(client: client)

        await viewModel.loadIfNeeded()
        let firstPayable = try XCTUnwrap(viewModel.payables.first)
        await viewModel.loadNextPageIfNeeded(currentPayable: firstPayable)

        XCTAssertEqual(viewModel.payables.map(\.id), ["pay_1", "pay_2"])
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertNil(viewModel.nextCursor)
        XCTAssertEqual(client.capturedRequests.count, 4)
        XCTAssertEqual(client.capturedRequests[3].queryDictionary["cursor"], "cursor_2")
        XCTAssertEqual(
            client.capturedRequests.filter {
                $0.path == BusinessProcurementRoutes.supplier("sup_1")
            }.count,
            1
        )
        XCTAssertEqual(
            client.capturedRequests.filter {
                $0.path == BusinessProcurementRoutes.supplierDocument("sdoc_1")
            }.count,
            1
        )
    }

    func testEmptySearchPresentsExplicitEmptyState() async {
        let client = QueuedPayablesAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)

        await viewModel.search()

        XCTAssertTrue(viewModel.payables.isEmpty)
        XCTAssertEqual(
            viewModel.infoMessage,
            "No encontramos cuentas por pagar con estos filtros."
        )
        XCTAssertEqual(viewModel.snapshotAsOf, "2026-07-31")
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testListMapsAPIErrorToHumanMessage() async {
        let client = QueuedPayablesAPIClient(
            responses: [],
            failures: [
                .server(
                    statusCode: 503,
                    code: "procurement_temporarily_unavailable",
                    message: "upstream exception",
                    requestId: "req_payables"
                )
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

    func testDetailRefreshPreservesServerAmountsStatusDatesAndSourceTruth() async throws {
        let initial = try decodePayableEnvelope(Self.payableEnvelopeJSON).data
        let client = QueuedPayablesAPIClient(
            responses: [
                Self.payableEnvelopeJSON,
                Self.supplierEnvelopeJSON,
                Self.supplierDocumentEnvelopeJSON,
            ]
        )
        let viewModel = BusinessPayableDetailViewModel(
            organizationId: "org_1",
            asOf: "2026-07-31",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.payablesView,
                BusinessProcurementPermission.suppliersView,
                BusinessProcurementPermission.supplierDocumentsView,
                BusinessProcurementPermission.supplierPaymentsCreate,
            ],
            payable: initial,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.businessSupplierName, "Ferretería Uno")
        XCTAssertEqual(viewModel.businessSourceDescription, "001-001-0000123")
        XCTAssertEqual(viewModel.payable.originalAmount.amount, "112.00")
        XCTAssertEqual(viewModel.payable.paidAmount.amount, "50.00")
        XCTAssertEqual(viewModel.payable.balance.amount, "62.00")
        XCTAssertEqual(viewModel.payable.dueDate, "2026-08-15")
        XCTAssertEqual(viewModel.payable.effectiveStatus, .partiallyPaid)
        XCTAssertEqual(viewModel.payable.allocationIds.count, 1)
        XCTAssertEqual(viewModel.payable.version, 2)
        XCTAssertTrue(viewModel.canRecordPayment)
        XCTAssertTrue(viewModel.hasLoaded)

        XCTAssertEqual(
            client.capturedRequests.first?.path,
            BusinessProcurementRoutes.payable("pay_1")
        )
        XCTAssertEqual(
            client.capturedRequests.first?.queryDictionary["asOf"],
            "2026-07-31"
        )
        XCTAssertEqual(
            client.capturedRequests.last?.path,
            BusinessProcurementRoutes.supplierDocument("sdoc_1")
        )
    }

    func testDetailRejectsInvalidAsOfBeforeNetworkCall() async throws {
        let initial = try decodePayableEnvelope(Self.payableEnvelopeJSON).data
        let client = QueuedPayablesAPIClient(responses: [Self.payableEnvelopeJSON])
        let viewModel = BusinessPayableDetailViewModel(
            organizationId: "org_1",
            asOf: "31/07/2026",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.payablesView],
            payable: initial,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha de corte debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testPaymentFormRequiresCreatePermissionBeforeNetworkCall() async throws {
        let payable = try decodePayableEnvelope(Self.payableEnvelopeJSON).data
        let client = QueuedPayablesAPIClient(responses: [])
        let viewModel = BusinessSupplierPaymentFormViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.payablesView],
            payable: payable,
            supplierName: "Ferretería Uno",
            repository: BusinessProcurementAPIRepository(apiClient: client),
            paymentDate: "2026-07-31",
            idempotencyKey: IdempotencyKey(rawValue: "supplier-payment-test")
        )
        viewModel.reference = "TRX-200"

        let result = await viewModel.recordPayment()

        XCTAssertNil(result)
        XCTAssertEqual(
            viewModel.errorMessage,
            "No tienes permiso para registrar pagos a proveedores."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPaymentFormRejectsInvalidDateMissingReferenceAndOverAllocationLocally() async throws {
        let payable = try decodePayableEnvelope(Self.payableEnvelopeJSON).data
        let client = QueuedPayablesAPIClient(responses: [])
        let viewModel = makePaymentFormViewModel(payable: payable, client: client)

        viewModel.paymentDate = "31/07/2026"
        let invalidDateResult = await viewModel.recordPayment()
        XCTAssertNil(invalidDateResult)
        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha del pago debe usar el formato AAAA-MM-DD."
        )

        viewModel.paymentDate = "2026-07-31"
        let missingReferenceResult = await viewModel.recordPayment()
        XCTAssertNil(missingReferenceResult)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Ingresa una referencia para este método de pago."
        )

        viewModel.reference = "TRX-OVER"
        viewModel.amount = "62.01"
        let overAllocationResult = await viewModel.recordPayment()
        XCTAssertNil(overAllocationResult)
        XCTAssertEqual(
            viewModel.errorMessage,
            "El importe no puede superar el saldo pendiente informado por el servidor."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPartialSupplierPaymentSendsOneAuditedAllocationAndRefreshesServerTruth() async throws {
        let payable = try decodePayableEnvelope(Self.payableEnvelopeJSON).data
        let client = QueuedPayablesAPIClient(
            responses: [
                Self.supplierPaymentEnvelopeJSON(
                    amount: "20.00",
                    balanceBefore: "62.00",
                    balanceAfter: "42.00"
                ),
                Self.updatedPayableEnvelopeJSON(
                    paidAmount: "70.00",
                    balance: "42.00",
                    settlementStatus: "PARTIALLY_PAID",
                    effectiveStatus: "PARTIALLY_PAID",
                    allocationIds: ["alloc_1", "alloc_2"]
                ),
            ]
        )
        let viewModel = makePaymentFormViewModel(payable: payable, client: client)
        viewModel.amount = " 20,00 "
        viewModel.method = .bankTransfer
        viewModel.reference = " TRX-200 "
        viewModel.notes = " Abono parcial "

        let recordedResult = await viewModel.recordPayment()
        let result = try XCTUnwrap(recordedResult)

        XCTAssertEqual(result.payment.id, "spay_1")
        XCTAssertEqual(result.updatedPayable?.paidAmount.amount, "70.00")
        XCTAssertEqual(result.updatedPayable?.balance.amount, "42.00")
        XCTAssertEqual(result.updatedPayable?.effectiveStatus, .partiallyPaid)
        XCTAssertEqual(viewModel.recordedPayment?.allocations.count, 1)
        XCTAssertEqual(
            viewModel.infoMessage,
            "Pago registrado y saldo actualizado desde el servidor."
        )

        XCTAssertEqual(client.capturedRequests.count, 2)
        let recordRequest = client.capturedRequests[0]
        XCTAssertEqual(recordRequest.method, .post)
        XCTAssertEqual(recordRequest.path, BusinessProcurementRoutes.supplierPayments)
        XCTAssertEqual(recordRequest.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(recordRequest.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(
            recordRequest.headers[BusinessHeaders.idempotencyKey],
            "supplier-payment-test"
        )
        let body = try recordRequest.jsonObject()
        XCTAssertEqual(body["supplierId"] as? String, "sup_1")
        XCTAssertEqual(body["paymentDate"] as? String, "2026-07-31")
        XCTAssertEqual(body["currency"] as? String, "USD")
        XCTAssertEqual(body["amount"] as? String, "20.00")
        XCTAssertEqual(body["method"] as? String, "BANK_TRANSFER")
        XCTAssertEqual(body["reference"] as? String, "TRX-200")
        XCTAssertEqual(body["notes"] as? String, "Abono parcial")
        let allocations = try XCTUnwrap(body["allocations"] as? [[String: Any]])
        XCTAssertEqual(allocations.count, 1)
        XCTAssertEqual(allocations[0]["payableId"] as? String, "pay_1")
        XCTAssertEqual(allocations[0]["amount"] as? String, "20.00")

        let refreshRequest = client.capturedRequests[1]
        XCTAssertEqual(refreshRequest.method, .get)
        XCTAssertEqual(refreshRequest.path, BusinessProcurementRoutes.payable("pay_1"))
        XCTAssertNil(refreshRequest.queryDictionary["asOf"])
    }

    func testFullSupplierPaymentUsesServerBalanceAndAcceptsIdempotentReplay() async throws {
        let payable = try decodePayableEnvelope(Self.payableEnvelopeJSON).data
        let client = QueuedPayablesAPIClient(
            responses: [
                Self.supplierPaymentEnvelopeJSON(
                    amount: "62.00",
                    balanceBefore: "62.00",
                    balanceAfter: "0.00",
                    replayed: true
                ),
                Self.updatedPayableEnvelopeJSON(
                    paidAmount: "112.00",
                    balance: "0.00",
                    settlementStatus: "PAID",
                    effectiveStatus: "PAID",
                    allocationIds: ["alloc_1", "alloc_2"]
                ),
            ]
        )
        let viewModel = makePaymentFormViewModel(payable: payable, client: client)
        viewModel.reference = "TRX-FULL"

        let recordedResult = await viewModel.recordPayment()
        let result = try XCTUnwrap(recordedResult)

        XCTAssertEqual(result.updatedPayable?.balance.amount, "0.00")
        XCTAssertEqual(result.updatedPayable?.effectiveStatus, .paid)
        XCTAssertEqual(
            viewModel.infoMessage,
            "Pago recuperado de un intento anterior; saldo actualizado desde el servidor."
        )
        let body = try client.capturedRequests[0].jsonObject()
        XCTAssertEqual(body["amount"] as? String, "62.00")
        let allocations = try XCTUnwrap(body["allocations"] as? [[String: Any]])
        XCTAssertEqual(allocations[0]["amount"] as? String, "62.00")
    }

    func testPayablePresentationUsesBackendStatusesAmountsAndAllocationCount() throws {
        let payable = try decodePayableEnvelope(Self.payableEnvelopeJSON).data

        XCTAssertEqual(payable.effectiveStatus.businessPayableDisplayName, "Pago parcial")
        XCTAssertEqual(payable.businessSettlementStatusName, "Pago parcial")
        XCTAssertEqual(payable.businessAllocationCountText, "1 aplicación de pago")
        XCTAssertTrue(
            payable.effectiveStatus.businessPayableExplanation.contains("servidor")
        )
        XCTAssertEqual(
            payable.balance.businessDisplayText(locale: Locale(identifier: "en_US")),
            "$62.00"
        )
    }

    func testPayableSurfaceKeepsSourcePaymentAndBalanceBoundariesExplicit() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPayablesView.swift"
        )

        XCTAssertTrue(source.contains("la app no recalcula la cuenta por pagar"))
        XCTAssertTrue(source.contains("La app no resta pagos"))
        XCTAssertTrue(source.contains("Fecha de corte"))
        XCTAssertTrue(source.contains("Vencimiento"))
        XCTAssertTrue(source.contains("Reintentar"))
        XCTAssertTrue(source.contains("Registrar pago"))
        XCTAssertTrue(source.contains("No mueve dinero en el banco"))
        XCTAssertTrue(source.contains("BusinessSupplierPaymentFormViewModel("))
        XCTAssertTrue(source.contains("una aplicación auditada"))
        XCTAssertFalse(source.contains("Text(payable.id)"))
        XCTAssertFalse(source.contains("Text(viewModel.payable.id)"))
        XCTAssertFalse(source.contains("Text(viewModel.payable.sourceId)"))
        XCTAssertFalse(source.contains(".reduce("))
    }

    private func makeListViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [
            BusinessProcurementPermission.payablesView,
            BusinessProcurementPermission.suppliersView,
            BusinessProcurementPermission.supplierDocumentsView,
        ],
        client: QueuedPayablesAPIClient
    ) -> BusinessPayablesViewModel {
        BusinessPayablesViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            supplierId: "sup_1",
            activeModules: activeModules,
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
    }

    private func makePaymentFormViewModel(
        payable: BusinessProcurementPayableResponse,
        client: QueuedPayablesAPIClient
    ) -> BusinessSupplierPaymentFormViewModel {
        BusinessSupplierPaymentFormViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.payablesView,
                BusinessProcurementPermission.supplierPaymentsCreate,
            ],
            payable: payable,
            supplierName: "Ferretería Uno",
            repository: BusinessProcurementAPIRepository(apiClient: client),
            paymentDate: "2026-07-31",
            idempotencyKey: IdempotencyKey(rawValue: "supplier-payment-test")
        )
    }

    private func decodePayableEnvelope(
        _ json: String
    ) throws -> BusinessProcurementPayableEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementPayableEnvelopeResponse.self,
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

    private static let emptyListJSON = #"{"payables":[],"nextCursor":null,"hasMore":false,"asOf":"2026-07-31"}"#

    private static var firstPageJSON: String {
        """
        {"payables":[\(payableJSON(id: "pay_1", effectiveStatus: "PARTIALLY_PAID"))],"nextCursor":"cursor_2","hasMore":true,"asOf":"2026-07-31"}
        """
    }

    private static var secondPageJSON: String {
        """
        {"payables":[
          \(payableJSON(id: "pay_1", effectiveStatus: "PARTIALLY_PAID")),
          \(payableJSON(id: "pay_2", effectiveStatus: "OVERDUE"))
        ],"nextCursor":null,"hasMore":false,"asOf":"2026-07-31"}
        """
    }

    private static var payableEnvelopeJSON: String {
        """
        {"data":\(payableJSON(id: "pay_1", effectiveStatus: "PARTIALLY_PAID")),"meta":{"requestId":"req_payable","idempotencyReplayed":false}}
        """
    }

    private static func payableJSON(
        id: String,
        effectiveStatus: String
    ) -> String {
        """
        {
          "id":"\(id)","branchId":"br_1","supplierId":"sup_1","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","currency":"USD",
          "originalAmount":{"amount":"112.00","currency":"USD"},"paidAmount":{"amount":"50.00","currency":"USD"},
          "balance":{"amount":"62.00","currency":"USD"},"dueDate":"2026-08-15","settlementStatus":"PARTIALLY_PAID","effectiveStatus":"\(effectiveStatus)","allocationIds":["alloc_1"],
          "createdAt":"2026-07-15T15:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-20T12:00:00Z","updatedBy":"usr_2","version":2
        }
        """
    }

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
        },"payable":\(payableJSON(id: "pay_1", effectiveStatus: "PARTIALLY_PAID")),"meta":{"requestId":"req_document","idempotencyReplayed":false}}
        """
    }

    private static func supplierPaymentEnvelopeJSON(
        amount: String,
        balanceBefore: String,
        balanceAfter: String,
        replayed: Bool = false
    ) -> String {
        """
        {"data":{
          "id":"spay_1","branchId":"br_1","supplierId":"sup_1","paymentNumber":"PAG-0001","paymentDate":"2026-07-31","currency":"USD",
          "amount":{"amount":"\(amount)","currency":"USD"},"method":"BANK_TRANSFER","reference":"TRX-200","status":"RECORDED",
          "allocations":[{"id":"alloc_2","payableId":"pay_1","amount":{"amount":"\(amount)","currency":"USD"},
            "payableBalanceBefore":{"amount":"\(balanceBefore)","currency":"USD"},"payableBalanceAfter":{"amount":"\(balanceAfter)","currency":"USD"},
            "status":"APPLIED","createdAt":"2026-07-31T12:00:00Z","createdBy":"usr_1","reversedAt":null,"reversedBy":null,"reversalReason":null}],
          "attachmentIds":[],"cashMovementId":null,"notes":"Abono parcial","createdAt":"2026-07-31T12:00:00Z","createdBy":"usr_1",
          "updatedAt":"2026-07-31T12:00:00Z","updatedBy":"usr_1","recordedAt":"2026-07-31T12:00:00Z","recordedBy":"usr_1",
          "voidedAt":null,"voidedBy":null,"voidReason":null,"version":1
        },"meta":{"requestId":"req_payment","idempotencyReplayed":\(replayed ? "true" : "false")}}
        """
    }

    private static func updatedPayableEnvelopeJSON(
        paidAmount: String,
        balance: String,
        settlementStatus: String,
        effectiveStatus: String,
        allocationIds: [String]
    ) -> String {
        let allocationJSON = allocationIds
            .map { "\"\($0)\"" }
            .joined(separator: ",")
        return """
        {"data":{
          "id":"pay_1","branchId":"br_1","supplierId":"sup_1","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","currency":"USD",
          "originalAmount":{"amount":"112.00","currency":"USD"},"paidAmount":{"amount":"\(paidAmount)","currency":"USD"},
          "balance":{"amount":"\(balance)","currency":"USD"},"dueDate":"2026-08-15","settlementStatus":"\(settlementStatus)",
          "effectiveStatus":"\(effectiveStatus)","allocationIds":[\(allocationJSON)],
          "createdAt":"2026-07-15T15:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-31T12:00:00Z","updatedBy":"usr_1","version":3
        },"meta":{"requestId":"req_payable_after_payment","idempotencyReplayed":null}}
        """
    }
}

private struct CapturedPayablesRequest {
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
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private final class QueuedPayablesAPIClient: APIClient, @unchecked Sendable {
    private var responses: [Data]
    private var failures: [APIError]
    private(set) var capturedRequests: [CapturedPayablesRequest] = []

    init(responses: [String], failures: [APIError] = []) {
        self.responses = responses.map { Data($0.utf8) }
        self.failures = failures
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedPayablesRequest(
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
