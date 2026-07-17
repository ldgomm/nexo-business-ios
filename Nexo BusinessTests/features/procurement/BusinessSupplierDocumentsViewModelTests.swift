//
//  BusinessSupplierDocumentsViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSupplierDocumentsViewModelTests: XCTestCase {
    func testLoadRequiresActivePurchasesModuleBeforeNetworkCall() async {
        let client = QueuedSupplierDocumentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            activeModules: [],
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
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

    func testLoadRequiresSupplierDocumentViewPermissionBeforeNetworkCall() async {
        let client = QueuedSupplierDocumentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(permissions: [], client: client)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "No tienes permiso para consultar documentos de proveedor."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testSearchUsesAcceptedContextTypeStatusDateQueryAndPaginationFilters() async throws {
        let client = QueuedSupplierDocumentsAPIClient(
            responses: [Self.firstPageJSON, Self.supplierEnvelopeJSON]
        )
        let viewModel = makeListViewModel(client: client)
        viewModel.documentTypeFilter = .invoice
        viewModel.statusFilter = .confirmed
        viewModel.query = " 001-001-0000123 "
        viewModel.documentDateFrom = " 2026-07-01 "
        viewModel.documentDateTo = " 2026-07-31 "
        viewModel.dueDateFrom = " 2026-08-01 "
        viewModel.dueDateTo = " 2026-08-31 "

        await viewModel.search()

        XCTAssertEqual(viewModel.supplierDocuments.map(\.id), ["sdoc_1"])
        XCTAssertEqual(
            viewModel.supplierDocuments.first?.document.documentNumber,
            "001-001-0000123"
        )
        XCTAssertEqual(
            viewModel.supplierDocuments.first?.businessSupplierName,
            "Ferretería Uno"
        )
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.nextCursor, "cursor_2")
        XCTAssertNil(viewModel.errorMessage)

        let request = try XCTUnwrap(client.capturedRequests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.supplierDocuments)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.queryDictionary["branchId"], "br_1")
        XCTAssertEqual(request.queryDictionary["supplierId"], "sup_1")
        XCTAssertEqual(request.queryDictionary["documentType"], "INVOICE")
        XCTAssertEqual(request.queryDictionary["status"], "CONFIRMED")
        XCTAssertEqual(request.queryDictionary["documentDateFrom"], "2026-07-01")
        XCTAssertEqual(request.queryDictionary["documentDateTo"], "2026-07-31")
        XCTAssertEqual(request.queryDictionary["dueDateFrom"], "2026-08-01")
        XCTAssertEqual(request.queryDictionary["dueDateTo"], "2026-08-31")
        XCTAssertEqual(request.queryDictionary["query"], "001-001-0000123")
        XCTAssertEqual(request.queryDictionary["limit"], "50")
        XCTAssertNil(request.queryDictionary["cursor"])
        XCTAssertEqual(
            client.capturedRequests.last?.path,
            BusinessProcurementRoutes.supplier("sup_1")
        )
    }

    func testDocumentOnlyPermissionDoesNotRequireSupplierEndpoint() async {
        let client = QueuedSupplierDocumentsAPIClient(responses: [Self.firstPageJSON])
        let viewModel = makeListViewModel(
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(client.capturedRequests.count, 1)
        XCTAssertEqual(
            viewModel.supplierDocuments.first?.businessSupplierName,
            "Proveedor no disponible"
        )
        XCTAssertNotNil(viewModel.referenceWarning)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testInvalidDocumentDateStopsBeforeNetworkCall() async {
        let client = QueuedSupplierDocumentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.documentDateFrom = "31/07/2026"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial de documento debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testInvertedDueDateRangeStopsBeforeNetworkCall() async {
        let client = QueuedSupplierDocumentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.dueDateFrom = "2026-09-01"
        viewModel.dueDateTo = "2026-08-31"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial de vencimiento no puede ser posterior a la final."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPaginationUsesCursorWithoutDuplicatingDocumentsOrSupplierLookups() async throws {
        let client = QueuedSupplierDocumentsAPIClient(
            responses: [
                Self.firstPageJSON,
                Self.supplierEnvelopeJSON,
                Self.secondPageJSON,
            ]
        )
        let viewModel = makeListViewModel(client: client)

        await viewModel.loadIfNeeded()
        let firstDocument = try XCTUnwrap(viewModel.supplierDocuments.first)
        await viewModel.loadNextPageIfNeeded(currentDocument: firstDocument)

        XCTAssertEqual(viewModel.supplierDocuments.map(\.id), ["sdoc_1", "sdoc_2"])
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
        let client = QueuedSupplierDocumentsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)

        await viewModel.search()

        XCTAssertTrue(viewModel.supplierDocuments.isEmpty)
        XCTAssertEqual(
            viewModel.infoMessage,
            "No encontramos documentos de proveedor con estos filtros."
        )
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testListMapsAPIErrorToHumanMessage() async {
        let client = QueuedSupplierDocumentsAPIClient(
            responses: [],
            failures: [
                .server(
                    statusCode: 503,
                    code: "procurement_temporarily_unavailable",
                    message: "upstream exception",
                    requestId: "req_documents"
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

    func testDetailRefreshPreservesServerTotalsDatesEvidenceAndPayableTruth() async throws {
        let initial = try decodeEnvelope(Self.confirmedDocumentEnvelopeJSON).data
        let client = QueuedSupplierDocumentsAPIClient(
            responses: [Self.confirmedDocumentEnvelopeJSON, Self.supplierEnvelopeJSON]
        )
        let viewModel = BusinessSupplierDocumentDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.supplierDocumentsView,
                BusinessProcurementPermission.suppliersView,
                BusinessProcurementPermission.payablesView,
            ],
            supplierDocument: initial,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        await viewModel.loadIfNeeded()

        let line = try XCTUnwrap(viewModel.supplierDocument.lines.first)
        XCTAssertEqual(viewModel.businessSupplierName, "Ferretería Uno")
        XCTAssertEqual(viewModel.supplierDocument.status, .confirmed)
        XCTAssertEqual(viewModel.supplierDocument.documentDate, "2026-07-15")
        XCTAssertEqual(viewModel.supplierDocument.dueDate, "2026-08-15")
        XCTAssertEqual(viewModel.supplierDocument.total.amount, "112.00")
        XCTAssertEqual(viewModel.supplierDocument.taxTotal.amount, "12.00")
        XCTAssertEqual(viewModel.supplierDocument.payableAmount.amount, "62.00")
        XCTAssertEqual(viewModel.supplierDocument.sourcePayment?.amount.amount, "50.00")
        XCTAssertEqual(viewModel.payable?.balance.amount, "62.00")
        XCTAssertEqual(line.businessQuantityText, "2 UNIT")
        XCTAssertEqual(line.lineTotal.amount, "112.00")
        XCTAssertTrue(viewModel.hasLoaded)

        XCTAssertEqual(
            client.capturedRequests.first?.path,
            BusinessProcurementRoutes.supplierDocument("sdoc_1")
        )
        XCTAssertEqual(
            client.capturedRequests.last?.path,
            BusinessProcurementRoutes.supplier("sup_1")
        )
    }

    func testSupplierDocumentPresentationUsesBackendStatusesAndCounts() throws {
        let document = try decodeEnvelope(Self.confirmedDocumentEnvelopeJSON).data
        let line = try XCTUnwrap(document.lines.first)

        XCTAssertEqual(document.status.businessDisplayName, "Confirmado")
        XCTAssertEqual(document.businessDocumentTypeName, "Factura de proveedor")
        XCTAssertEqual(document.businessLineCountText, "1 línea")
        XCTAssertEqual(document.businessAttachmentCountText, "1 archivo")
        XCTAssertEqual(document.businessPurchaseOrderLinkCountText, "1 orden vinculada")
        XCTAssertEqual(document.businessPurchaseReceiptLinkCountText, "1 recepción vinculada")
        XCTAssertEqual(line.businessKindName, "Artículo con inventario")
        XCTAssertEqual(line.businessQuantityText, "2 UNIT")
        XCTAssertTrue(document.status.businessPayableExplanation.contains("backend"))
    }

    func testSupplierDocumentSurfaceKeepsDocumentReceiptInventoryAndBalanceBoundariesExplicit() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierDocumentsView.swift"
        )

        XCTAssertTrue(source.contains("No representa una recepción física"))
        XCTAssertTrue(source.contains("no cambia inventario"))
        XCTAssertTrue(source.contains("El total y saldo provienen del servidor"))
        XCTAssertTrue(source.contains("la app no los recalcula sumando líneas"))
        XCTAssertTrue(source.contains("Fecha de pago"))
        XCTAssertTrue(source.contains("Vencimiento"))
        XCTAssertTrue(source.contains("Reintentar"))
        XCTAssertFalse(source.contains("Text(document.id)"))
        XCTAssertFalse(source.contains("Text(viewModel.supplierDocument.id)"))
        XCTAssertFalse(source.contains("Text(viewModel.supplierDocument.payableId)"))
        XCTAssertFalse(source.contains(".reduce("))
    }

    private func makeListViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [
            BusinessProcurementPermission.supplierDocumentsView,
            BusinessProcurementPermission.suppliersView,
        ],
        client: QueuedSupplierDocumentsAPIClient
    ) -> BusinessSupplierDocumentsViewModel {
        BusinessSupplierDocumentsViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            supplierId: "sup_1",
            activeModules: activeModules,
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
    }

    private func decodeEnvelope(
        _ json: String
    ) throws -> BusinessProcurementSupplierDocumentEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementSupplierDocumentEnvelopeResponse.self,
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

    private static let emptyListJSON = #"{"supplierDocuments":[],"nextCursor":null,"hasMore":false}"#

    private static var firstPageJSON: String {
        """
        {"supplierDocuments":[\(documentJSON(id: "sdoc_1", number: "001-001-0000123", status: "CONFIRMED", withLine: true))],"nextCursor":"cursor_2","hasMore":true}
        """
    }

    private static var secondPageJSON: String {
        """
        {"supplierDocuments":[
          \(documentJSON(id: "sdoc_1", number: "001-001-0000123", status: "CONFIRMED", withLine: true)),
          \(documentJSON(id: "sdoc_2", number: "GASTO-002", status: "DRAFT", withLine: false))
        ],"nextCursor":null,"hasMore":false}
        """
    }

    private static var confirmedDocumentEnvelopeJSON: String {
        """
        {"data":\(documentJSON(id: "sdoc_1", number: "001-001-0000123", status: "CONFIRMED", withLine: true)),"payable":\(payableJSON),"meta":{"requestId":"req_document","idempotencyReplayed":false}}
        """
    }

    private static func documentJSON(
        id: String,
        number: String,
        status: String,
        withLine: Bool
    ) -> String {
        let lines = withLine ? "[\(documentLineJSON)]" : "[]"
        let confirmedAt = status == "CONFIRMED"
            ? #""2026-07-15T15:00:00Z""#
            : "null"
        let payableId = status == "CONFIRMED" ? #""pay_1""# : "null"
        return """
        {
          "id":"\(id)","branchId":"br_1","supplierId":"sup_1","documentType":"INVOICE","status":"\(status)",
          "documentNumber":"\(number)","documentNumberNormalized":"\(number)","accessKey":"ACCESS-123","authorizationNumber":"AUTH-123",
          "documentDate":"2026-07-15","dueDate":"2026-08-15","currency":"USD","purchaseOrderIds":["po_1"],"purchaseReceiptIds":["rcpt_1"],
          "lines":\(lines),"subtotal":{"amount":"100.00","currency":"USD"},"discountTotal":{"amount":"0.00","currency":"USD"},
          "taxTotal":{"amount":"12.00","currency":"USD"},"total":{"amount":"112.00","currency":"USD"},
          "sourceTotals":{"total":{"amount":"112.00","currency":"USD"},"taxTotal":{"amount":"12.00","currency":"USD"}},
          "sourcePayment":{"amount":{"amount":"50.00","currency":"USD"},"method":"BANK_TRANSFER","paymentDate":"2026-07-15","reference":"TRX-001"},
          "payableAmount":{"amount":"62.00","currency":"USD"},"payableId":\(payableId),"attachmentIds":["att_1"],
          "accountingStatus":"READY_FOR_ACCOUNTING","notes":"Factura por reposición",
          "createdAt":"2026-07-15T14:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T15:00:00Z","updatedBy":"usr_1",
          "confirmedAt":\(confirmedAt),"confirmedBy":"usr_1","cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":3
        }
        """
    }

    private static var documentLineJSON: String {
        """
        {
          "id":"sdl_1","kind":"STOCK_ITEM","catalogItemId":"item_1",
          "catalogItemSnapshot":{"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"UNIT","taxProfileId":"tax_1","taxProfileVersion":3},
          "purchaseOrderLineId":"pol_1","purchaseReceiptLineId":"prl_1","descriptionSnapshot":"Router",
          "quantity":{"value":"2.000","unitCode":"UNIT","allowsDecimal":false},"unitCost":{"amount":"50.00","currency":"USD"},
          "discountAmount":{"amount":"0.00","currency":"USD"},"priceTaxMode":"TAX_EXCLUSIVE","taxProfileId":"tax_1","taxProfileVersion":3,
          "taxes":[{"taxCode":"VAT","rateCode":"VAT_12","rate":"0.12","taxableBase":{"amount":"100.00","currency":"USD"},"amount":{"amount":"12.00","currency":"USD"}}],
          "grossAmount":{"amount":"100.00","currency":"USD"},"netAmount":{"amount":"100.00","currency":"USD"},
          "taxAmount":{"amount":"12.00","currency":"USD"},"lineTotal":{"amount":"112.00","currency":"USD"},
          "expenseCategoryCode":"INVENTORY_PURCHASE","notes":"Dos unidades"
        }
        """
    }

    private static var payableJSON: String {
        """
        {
          "id":"pay_1","branchId":"br_1","supplierId":"sup_1","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","currency":"USD",
          "originalAmount":{"amount":"62.00","currency":"USD"},"paidAmount":{"amount":"0.00","currency":"USD"},
          "balance":{"amount":"62.00","currency":"USD"},"dueDate":"2026-08-15","settlementStatus":"OPEN","effectiveStatus":"OPEN","allocationIds":[],
          "createdAt":"2026-07-15T15:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T15:00:00Z","updatedBy":"usr_1","version":1
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
}

private struct CapturedSupplierDocumentRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }
}

private final class QueuedSupplierDocumentsAPIClient: APIClient, @unchecked Sendable {
    private var responses: [Data]
    private var failures: [APIError]
    private(set) var capturedRequests: [CapturedSupplierDocumentRequest] = []

    init(responses: [String], failures: [APIError] = []) {
        self.responses = responses.map { Data($0.utf8) }
        self.failures = failures
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedSupplierDocumentRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers
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
