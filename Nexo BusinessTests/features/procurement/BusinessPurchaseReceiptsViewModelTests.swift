//
//  BusinessPurchaseReceiptsViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessPurchaseReceiptsViewModelTests: XCTestCase {
    func testLoadRequiresActivePurchasesModuleBeforeNetworkCall() async {
        let client = QueuedPurchaseReceiptsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            activeModules: [],
            permissions: [BusinessProcurementPermission.purchaseReceiptsView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "El módulo Compras no está activo para esta organización.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testLoadRequiresPurchaseReceiptViewPermissionBeforeNetworkCall() async {
        let client = QueuedPurchaseReceiptsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(permissions: [], client: client)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar recepciones de compra.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testSearchUsesAcceptedContextStatusDateAndPaginationFilters() async throws {
        let client = QueuedPurchaseReceiptsAPIClient(
            responses: [Self.firstPageJSON, Self.purchaseOrderEnvelopeJSON]
        )
        let viewModel = makeListViewModel(client: client)
        viewModel.statusFilter = .confirmed
        viewModel.receivedFrom = " 2026-07-01 "
        viewModel.receivedTo = " 2026-07-31 "

        await viewModel.search()

        XCTAssertEqual(viewModel.purchaseReceipts.map(\.id), ["rcpt_1"])
        XCTAssertEqual(viewModel.purchaseReceipts.first?.receipt.receiptNumber, "RC-0001")
        XCTAssertEqual(viewModel.purchaseReceipts.first?.businessSupplierName, "Ferretería Uno")
        XCTAssertEqual(viewModel.purchaseReceipts.first?.businessPurchaseOrderName, "OC-0001")
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.nextCursor, "cursor_2")
        XCTAssertNil(viewModel.errorMessage)

        let request = try XCTUnwrap(client.capturedRequests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.purchaseReceipts)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.queryDictionary["branchId"], "br_1")
        XCTAssertEqual(request.queryDictionary["supplierId"], "sup_1")
        XCTAssertEqual(request.queryDictionary["purchaseOrderId"], "po_1")
        XCTAssertEqual(request.queryDictionary["status"], "CONFIRMED")
        XCTAssertEqual(request.queryDictionary["receivedFrom"], "2026-07-01T00:00:00Z")
        XCTAssertEqual(request.queryDictionary["receivedTo"], "2026-07-31T23:59:59Z")
        XCTAssertEqual(request.queryDictionary["limit"], "50")
        XCTAssertNil(request.queryDictionary["cursor"])
        XCTAssertEqual(client.capturedRequests.last?.path, BusinessProcurementRoutes.purchaseOrder("po_1"))
    }

    func testReceiptOnlyPermissionDoesNotRequireReferenceEndpoints() async {
        let client = QueuedPurchaseReceiptsAPIClient(responses: [Self.firstPageJSON])
        let viewModel = makeListViewModel(
            permissions: [BusinessProcurementPermission.purchaseReceiptsView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(client.capturedRequests.count, 1)
        XCTAssertEqual(viewModel.purchaseReceipts.first?.businessSupplierName, "Proveedor no disponible")
        XCTAssertEqual(viewModel.purchaseReceipts.first?.businessPurchaseOrderName, "Orden vinculada")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testInvalidReceivedDateStopsBeforeNetworkCall() async {
        let client = QueuedPurchaseReceiptsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.receivedFrom = "31/07/2026"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha de recepción inicial debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testInvertedReceivedRangeStopsBeforeNetworkCall() async {
        let client = QueuedPurchaseReceiptsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.receivedFrom = "2026-08-01"
        viewModel.receivedTo = "2026-07-31"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha de recepción inicial no puede ser posterior a la final."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPaginationUsesCursorAndDoesNotDuplicateReceiptOrReferenceLookups() async throws {
        let client = QueuedPurchaseReceiptsAPIClient(
            responses: [Self.firstPageJSON, Self.purchaseOrderEnvelopeJSON, Self.secondPageJSON]
        )
        let viewModel = makeListViewModel(client: client)

        await viewModel.loadIfNeeded()
        let firstReceipt = try XCTUnwrap(viewModel.purchaseReceipts.first)
        await viewModel.loadNextPageIfNeeded(currentReceipt: firstReceipt)

        XCTAssertEqual(viewModel.purchaseReceipts.map(\.id), ["rcpt_1", "rcpt_2"])
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertNil(viewModel.nextCursor)
        XCTAssertEqual(client.capturedRequests.count, 3)
        XCTAssertEqual(client.capturedRequests[2].queryDictionary["cursor"], "cursor_2")
        XCTAssertEqual(
            client.capturedRequests.filter { $0.path == BusinessProcurementRoutes.purchaseOrder("po_1") }.count,
            1
        )
    }

    func testEmptySearchPresentsExplicitEmptyState() async {
        let client = QueuedPurchaseReceiptsAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)

        await viewModel.search()

        XCTAssertTrue(viewModel.purchaseReceipts.isEmpty)
        XCTAssertEqual(
            viewModel.infoMessage,
            "No encontramos recepciones de compra con estos filtros."
        )
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testListMapsAPIErrorToHumanMessage() async {
        let client = QueuedPurchaseReceiptsAPIClient(
            responses: [],
            failures: [
                .server(
                    statusCode: 503,
                    code: "procurement_temporarily_unavailable",
                    message: "upstream exception",
                    requestId: "req_receipts"
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

    func testDetailRefreshPreservesPartialQuantitiesTrackingAndBackendEvidence() async throws {
        let initial = try decodeEnvelope(Self.confirmedReceiptEnvelopeJSON).data
        let client = QueuedPurchaseReceiptsAPIClient(
            responses: [Self.confirmedReceiptEnvelopeJSON, Self.purchaseOrderEnvelopeJSON]
        )
        let viewModel = BusinessPurchaseReceiptDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.purchaseReceiptsView,
                BusinessProcurementPermission.purchaseOrdersView,
            ],
            purchaseReceipt: initial,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        await viewModel.loadIfNeeded()

        let line = try XCTUnwrap(viewModel.purchaseReceipt.lines.first)
        XCTAssertEqual(viewModel.purchaseReceipt.status, .confirmed)
        XCTAssertEqual(viewModel.businessSupplierName, "Ferretería Uno")
        XCTAssertEqual(viewModel.businessPurchaseOrderName, "OC-0001")
        XCTAssertEqual(viewModel.itemName(for: line), "Router")
        XCTAssertEqual(line.businessReceivedQuantityText, "3 UNIT")
        XCTAssertEqual(line.businessAcceptedQuantityText, "2 UNIT")
        XCTAssertEqual(line.businessRejectedQuantityText, "1 UNIT")
        XCTAssertEqual(line.businessTrackedUnitCountText, "1 unidad rastreada")
        XCTAssertEqual(viewModel.purchaseReceipt.inventoryMovementIds.count, 1)
        XCTAssertNil(line.unitCost)
        XCTAssertEqual(viewModel.linkedOrderLine(for: line)?.businessOrderedQuantityText, "5 UNIT")
        XCTAssertEqual(viewModel.linkedOrderLine(for: line)?.businessReceivedQuantityText, "2 UNIT")
        XCTAssertTrue(viewModel.hasLoaded)

        XCTAssertEqual(client.capturedRequests.first?.path, BusinessProcurementRoutes.purchaseReceipt("rcpt_1"))
        XCTAssertEqual(client.capturedRequests.last?.path, BusinessProcurementRoutes.purchaseOrder("po_1"))
    }

    func testReceiptPresentationUsesBackendStatusesAndTrimmedQuantities() throws {
        let receipt = try decodeEnvelope(Self.confirmedReceiptEnvelopeJSON).data
        let line = try XCTUnwrap(receipt.lines.first)

        XCTAssertEqual(receipt.status.businessDisplayName, "Confirmada")
        XCTAssertEqual(receipt.businessLineCountText, "1 línea")
        XCTAssertEqual(receipt.businessAttachmentCountText, "1 archivo")
        XCTAssertEqual(receipt.businessInventoryMovementCountText, "1 movimiento registrado")
        XCTAssertEqual(line.businessReceivedQuantityText, "3 UNIT")
        XCTAssertEqual(line.businessAcceptedQuantityText, "2 UNIT")
        XCTAssertEqual(line.businessRejectedQuantityText, "1 UNIT")
        XCTAssertTrue(receipt.status.businessInventoryExplanation.contains("exactamente una vez"))
    }

    func testPurchaseReceiptSurfaceKeepsPartialInventoryAndPrivacyBoundariesExplicit() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseReceiptsView.swift"
        )

        XCTAssertTrue(source.contains("Cantidades recibidas, aceptadas y rechazadas"))
        XCTAssertTrue(source.contains("Recibido acumulado"))
        XCTAssertTrue(source.contains("El pendiente permanece autoritativo en la orden de compra"))
        XCTAssertTrue(source.contains("no lo recalcula en el dispositivo"))
        XCTAssertTrue(source.contains("Un borrador no cambia inventario"))
        XCTAssertTrue(source.contains("no crea una cuenta por pagar"))
        XCTAssertTrue(source.contains("Costo no disponible o protegido por permisos"))
        XCTAssertTrue(source.contains("Reintentar"))
        XCTAssertFalse(source.contains("Text(receipt.id)"))
        XCTAssertFalse(source.contains("Text(viewModel.purchaseReceipt.id)"))
        XCTAssertFalse(source.contains("Text(line.inventoryMovementId)"))
        XCTAssertFalse(source.contains(".reduce("))
    }

    private func makeListViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [
            BusinessProcurementPermission.purchaseReceiptsView,
            BusinessProcurementPermission.purchaseOrdersView,
            BusinessProcurementPermission.suppliersView,
        ],
        client: QueuedPurchaseReceiptsAPIClient
    ) -> BusinessPurchaseReceiptsViewModel {
        BusinessPurchaseReceiptsViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            supplierId: "sup_1",
            purchaseOrderId: "po_1",
            activeModules: activeModules,
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
    }

    private func decodeEnvelope(
        _ json: String
    ) throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementPurchaseReceiptEnvelopeResponse.self,
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

    private static let emptyListJSON = #"{"purchaseReceipts":[],"nextCursor":null,"hasMore":false}"#

    private static var firstPageJSON: String {
        """
        {"purchaseReceipts":[\(receiptJSON(id: "rcpt_1", number: "RC-0001", status: "CONFIRMED", withLine: true))],"nextCursor":"cursor_2","hasMore":true}
        """
    }

    private static var secondPageJSON: String {
        """
        {"purchaseReceipts":[
          \(receiptJSON(id: "rcpt_1", number: "RC-0001", status: "CONFIRMED", withLine: true)),
          \(receiptJSON(id: "rcpt_2", number: "RC-0002", status: "DRAFT", withLine: false))
        ],"nextCursor":null,"hasMore":false}
        """
    }

    private static var confirmedReceiptEnvelopeJSON: String {
        """
        {"data":\(receiptJSON(id: "rcpt_1", number: "RC-0001", status: "CONFIRMED", withLine: true)),"meta":{"requestId":"req_receipt","idempotencyReplayed":false}}
        """
    }

    private static func receiptJSON(
        id: String,
        number: String,
        status: String,
        withLine: Bool
    ) -> String {
        let lines = withLine ? "[\(receiptLineJSON)]" : "[]"
        let movementIds = withLine ? #"["imov_1"]"# : "[]"
        let confirmedAt = status == "CONFIRMED" ? #""2026-07-03T15:01:00Z""# : "null"
        return """
        {
          "id":"\(id)","branchId":"br_1","supplierId":"sup_1","purchaseOrderId":"po_1",
          "receiptNumber":"\(number)","status":"\(status)","warehouseId":"wh_1","receivedAt":"2026-07-03T15:00:00Z",
          "lines":\(lines),"inventoryMovementIds":\(movementIds),"attachmentIds":["patt_1"],"notes":"Recepción parcial",
          "createdAt":"2026-07-03T14:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-03T15:01:00Z","updatedBy":"usr_1",
          "confirmedAt":\(confirmedAt),"confirmedBy":null,"cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":2
        }
        """
    }

    private static var receiptLineJSON: String {
        """
        {
          "id":"prl_1","purchaseOrderLineId":"pol_1","kind":"STOCK_ITEM","catalogItemId":"item_1",
          "itemSnapshot":{"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"UNIT","taxProfileId":"tax_1","taxProfileVersion":3},
          "receivedQuantity":{"value":"3.000","unitCode":"UNIT","allowsDecimal":false},"acceptedQuantity":"2.000","rejectedQuantity":"1.000","unitCode":"UNIT",
          "unitCost":null,"warehouseId":"wh_1","trackedUnits":[{"trackingType":"SERIAL","trackingValue":"SN-001","notes":null}],
          "inventoryMovementId":"imov_1","notes":"Una unidad dañada"
        }
        """
    }

    private static var purchaseOrderEnvelopeJSON: String {
        """
        {"data":{
          "id":"po_1","branchId":"br_1","supplierId":"sup_1","orderNumber":"OC-0001","status":"PARTIALLY_RECEIVED","currency":"USD",
          "lines":[{
            "id":"pol_1","kind":"STOCK_ITEM","catalogItemId":"item_1",
            "catalogItemSnapshot":{"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"UNIT","taxProfileId":"tax_1","taxProfileVersion":3},
            "descriptionSnapshot":"Router","orderedQuantity":{"value":"5.000","unitCode":"UNIT","allowsDecimal":false},"receivedQuantity":"2.000",
            "unitCost":null,"discountAmount":null,"priceTaxMode":"TAX_EXCLUSIVE","taxProfileId":"tax_1","taxProfileVersion":3,
            "taxes":null,"grossAmount":null,"netAmount":null,"taxAmount":null,"lineTotal":null,"targetWarehouseId":"wh_1","notes":null
          }],
          "subtotal":null,"discountTotal":null,"taxTotal":null,"total":null,"expectedDate":"2026-07-20",
          "supplierSnapshot":{"supplierId":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Ferretería Uno","identificationType":"RUC","identificationNumber":null,"paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD"},
          "paymentTermsSnapshot":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"notes":"Reposición","attachmentIds":[],
          "createdAt":"2026-07-01T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-03T15:01:00Z","updatedBy":"usr_1",
          "sentAt":"2026-07-01T13:00:00Z","sentBy":"usr_1","closedAt":null,"closedBy":null,"closeReason":null,
          "cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":6
        },"meta":{"requestId":"req_order","idempotencyReplayed":null}}
        """
    }
}

private struct CapturedPurchaseReceiptRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }
}

private final class QueuedPurchaseReceiptsAPIClient: APIClient, @unchecked Sendable {
    private var responses: [Data]
    private var failures: [APIError]
    private(set) var capturedRequests: [CapturedPurchaseReceiptRequest] = []

    init(responses: [String], failures: [APIError] = []) {
        self.responses = responses.map { Data($0.utf8) }
        self.failures = failures
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedPurchaseReceiptRequest(
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
        return try JSONDecoder.nexoDefault.decode(Response.self, from: responses.removeFirst())
    }
}
