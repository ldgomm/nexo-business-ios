//
//  BusinessPurchaseOrdersViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessPurchaseOrdersViewModelTests: XCTestCase {
    func testLoadRequiresActivePurchasesModuleBeforeNetworkCall() async {
        let client = QueuedPurchaseOrdersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            activeModules: [],
            permissions: [BusinessProcurementPermission.purchaseOrdersView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "El módulo Compras no está activo para esta organización.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testLoadRequiresPurchaseOrderViewPermissionBeforeNetworkCall() async {
        let client = QueuedPurchaseOrdersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            permissions: [],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar órdenes de compra.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testSearchUsesAcceptedBranchStatusDateAndQueryFilters() async throws {
        let client = QueuedPurchaseOrdersAPIClient(responses: [Self.firstPageJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.query = "  OC-0001  "
        viewModel.statusFilter = .partiallyReceived
        viewModel.expectedFrom = " 2026-07-01 "
        viewModel.expectedTo = " 2026-07-31 "

        await viewModel.search()

        XCTAssertEqual(viewModel.purchaseOrders.map(\.id), ["po_1"])
        XCTAssertEqual(viewModel.purchaseOrders.first?.orderNumber, "OC-0001")
        XCTAssertEqual(viewModel.purchaseOrders.first?.businessSupplierName, "Ferretería Uno")
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.nextCursor, "cursor_2")
        XCTAssertNil(viewModel.errorMessage)

        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.purchaseOrders)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.queryDictionary["branchId"], "br_1")
        XCTAssertEqual(request.queryDictionary["status"], "PARTIALLY_RECEIVED")
        XCTAssertEqual(request.queryDictionary["expectedFrom"], "2026-07-01")
        XCTAssertEqual(request.queryDictionary["expectedTo"], "2026-07-31")
        XCTAssertEqual(request.queryDictionary["query"], "OC-0001")
        XCTAssertEqual(request.queryDictionary["limit"], "50")
        XCTAssertNil(request.queryDictionary["cursor"])
    }

    func testInvalidExpectedDateStopsBeforeNetworkCall() async {
        let client = QueuedPurchaseOrdersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.expectedFrom = "31/07/2026"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha esperada inicial debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testInvertedExpectedRangeStopsBeforeNetworkCall() async {
        let client = QueuedPurchaseOrdersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.expectedFrom = "2026-08-01"
        viewModel.expectedTo = "2026-07-31"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha esperada inicial no puede ser posterior a la final."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPaginationUsesCursorAndDoesNotDuplicatePurchaseOrder() async throws {
        let client = QueuedPurchaseOrdersAPIClient(
            responses: [Self.firstPageJSON, Self.secondPageJSON]
        )
        let viewModel = makeListViewModel(client: client)

        await viewModel.loadIfNeeded()
        let firstOrder = try XCTUnwrap(viewModel.purchaseOrders.first)
        await viewModel.loadNextPageIfNeeded(currentOrder: firstOrder)

        XCTAssertEqual(viewModel.purchaseOrders.map(\.id), ["po_1", "po_2"])
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertNil(viewModel.nextCursor)
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(client.capturedRequests[1].queryDictionary["cursor"], "cursor_2")
    }

    func testEmptySearchPresentsExplicitEmptyState() async {
        let client = QueuedPurchaseOrdersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)

        await viewModel.search()

        XCTAssertTrue(viewModel.purchaseOrders.isEmpty)
        XCTAssertEqual(viewModel.infoMessage, "No encontramos órdenes de compra con estos filtros.")
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testDetailRefreshPreservesBackendQuantitiesAndRedactedCosts() async throws {
        let initial = try decodeEnvelope(Self.redactedEnvelopeJSON).data
        let client = QueuedPurchaseOrdersAPIClient(responses: [Self.redactedEnvelopeJSON])
        let repository = BusinessProcurementAPIRepository(apiClient: client)
        let viewModel = BusinessPurchaseOrderDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.purchaseOrdersView],
            purchaseOrder: initial,
            repository: repository
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.purchaseOrder.status, .partiallyReceived)
        XCTAssertEqual(viewModel.purchaseOrder.lines.first?.businessOrderedQuantityText, "5 UNIT")
        XCTAssertEqual(viewModel.purchaseOrder.lines.first?.businessReceivedQuantityText, "2 UNIT")
        XCTAssertNil(viewModel.purchaseOrder.lines.first?.unitCost)
        XCTAssertNil(viewModel.purchaseOrder.total)
        XCTAssertFalse(viewModel.canViewCosts)
        XCTAssertTrue(viewModel.hasLoaded)

        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.purchaseOrder("po_1"))
        XCTAssertTrue(request.queryItems.isEmpty)
    }

    func testPurchaseOrderPresentationUsesBackendNamesStatusesAndCurrency() throws {
        let order = try decodeEnvelope(Self.costedEnvelopeJSON).data
        let money = try XCTUnwrap(order.total)
        let renderedMoney = money.businessDisplayText(locale: Locale(identifier: "en_US"))

        XCTAssertEqual(order.businessSupplierName, "Ferretería Uno")
        XCTAssertEqual(order.supplierSnapshot.businessLegalNameDetail, "Proveedor Uno S.A.")
        XCTAssertEqual(order.status.businessDisplayName, "Enviada")
        XCTAssertEqual(order.businessLineCountText, "1 línea")
        XCTAssertTrue(renderedMoney.contains("1,250.50"))
    }

    func testPurchaseOrderSurfaceKeepsAuthoritativeAndPrivacyBoundariesExplicit() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseOrdersView.swift"
        )

        XCTAssertTrue(source.contains("Cantidades ordenadas y recibidas"))
        XCTAssertTrue(source.contains("Totales del backend"))
        XCTAssertTrue(source.contains("no recalcula el total"))
        XCTAssertTrue(source.contains("Costos protegidos"))
        XCTAssertTrue(source.contains("Reintentar"))
        XCTAssertFalse(source.contains("Text(order.id)"))
        XCTAssertFalse(source.contains("Text(viewModel.purchaseOrder.id)"))
        XCTAssertFalse(source.contains(".reduce("))
    }

    private func makeListViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [
            BusinessProcurementPermission.purchaseOrdersView,
            BusinessProcurementPermission.purchaseOrdersCostView,
        ],
        client: QueuedPurchaseOrdersAPIClient
    ) -> BusinessPurchaseOrdersViewModel {
        BusinessPurchaseOrdersViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activeModules: activeModules,
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
    }

    private func decodeEnvelope(_ json: String) throws -> BusinessProcurementPurchaseOrderEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementPurchaseOrderEnvelopeResponse.self,
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

    private static let emptyListJSON = #"{"purchaseOrders":[],"nextCursor":null,"hasMore":false}"#

    private static var firstPageJSON: String {
        """
        {"purchaseOrders":[\(purchaseOrderJSON(id: "po_1", number: "OC-0001", status: "PARTIALLY_RECEIVED", withCosts: false, withLine: true))],"nextCursor":"cursor_2","hasMore":true}
        """
    }

    private static var secondPageJSON: String {
        """
        {"purchaseOrders":[
          \(purchaseOrderJSON(id: "po_1", number: "OC-0001", status: "PARTIALLY_RECEIVED", withCosts: false, withLine: true)),
          \(purchaseOrderJSON(id: "po_2", number: "OC-0002", status: "DRAFT", withCosts: true, withLine: false))
        ],"nextCursor":null,"hasMore":false}
        """
    }

    private static var redactedEnvelopeJSON: String {
        """
        {"data":\(purchaseOrderJSON(id: "po_1", number: "OC-0001", status: "PARTIALLY_RECEIVED", withCosts: false, withLine: true)),"meta":{"requestId":"req_po","idempotencyReplayed":null}}
        """
    }

    private static var costedEnvelopeJSON: String {
        """
        {"data":\(purchaseOrderJSON(id: "po_2", number: "OC-0002", status: "SENT", withCosts: true, withLine: true)),"meta":{"requestId":"req_po_2","idempotencyReplayed":false}}
        """
    }

    private static func purchaseOrderJSON(
        id: String,
        number: String,
        status: String,
        withCosts: Bool,
        withLine: Bool
    ) -> String {
        let money = withCosts ? #"{"amount":"1250.50","currency":"USD"}"# : "null"
        let lines = withLine ? "[\(lineJSON(withCosts: withCosts))]" : "[]"
        return """
        {
          "id":"\(id)","branchId":"br_1","supplierId":"sup_1","orderNumber":"\(number)","status":"\(status)","currency":"USD",
          "lines":\(lines),"subtotal":\(money),"discountTotal":\(money),"taxTotal":\(money),"total":\(money),"expectedDate":"2026-07-20",
          "supplierSnapshot":{"supplierId":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Ferretería Uno","identificationType":"RUC","identificationNumber":null,"paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD"},
          "paymentTermsSnapshot":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"notes":"Reposición","attachmentIds":[],
          "createdAt":"2026-07-01T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-02T12:00:00Z","updatedBy":"usr_1",
          "sentAt":"2026-07-01T13:00:00Z","sentBy":"usr_1","closedAt":null,"closedBy":null,"closeReason":null,
          "cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":6
        }
        """
    }

    private static func lineJSON(withCosts: Bool) -> String {
        let money = withCosts ? #"{"amount":"1250.50","currency":"USD"}"# : "null"
        return """
        {
          "id":"pol_1","kind":"CATALOG_ITEM","catalogItemId":"item_1",
          "catalogItemSnapshot":{"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"UNIT","taxProfileId":"tax_1","taxProfileVersion":3},
          "descriptionSnapshot":"Router","orderedQuantity":{"value":"5.000","unitCode":"UNIT","allowsDecimal":false},"receivedQuantity":"2.000",
          "unitCost":\(money),"discountAmount":\(money),"priceTaxMode":"TAX_EXCLUSIVE","taxProfileId":"tax_1","taxProfileVersion":3,
          "taxes":null,"grossAmount":\(money),"netAmount":\(money),"taxAmount":\(money),"lineTotal":\(money),
          "targetWarehouseId":"wh_1","notes":null
        }
        """
    }
}

private struct CapturedPurchaseOrderRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }
}

private final class QueuedPurchaseOrdersAPIClient: APIClient, @unchecked Sendable {
    private var responses: [Data]
    private(set) var capturedRequests: [CapturedPurchaseOrderRequest] = []

    init(responses: [String]) {
        self.responses = responses.map { Data($0.utf8) }
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedPurchaseOrderRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers
            )
        )
        guard !responses.isEmpty else {
            throw APIError.emptyResponse
        }
        return try JSONDecoder.nexoDefault.decode(Response.self, from: responses.removeFirst())
    }
}
