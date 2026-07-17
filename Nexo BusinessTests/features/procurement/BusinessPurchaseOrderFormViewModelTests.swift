//
//  BusinessPurchaseOrderFormViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessPurchaseOrderFormViewModelTests: XCTestCase {
    func testCreateRequiresPermissionBeforeNetworkCall() async {
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "DRAFT", version: 1))
        ])
        let viewModel = makeCreateViewModel(permissions: [], client: client)
        prepareValidDraft(viewModel)

        let order = await viewModel.save()

        XCTAssertNil(order)
        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para crear órdenes de compra.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateValidatesLinesAndDateBeforeNetworkCall() async {
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "DRAFT", version: 1))
        ])
        let viewModel = makeCreateViewModel(client: client)
        viewModel.selectedSupplierId = "sup_1"

        _ = await viewModel.save()
        XCTAssertEqual(viewModel.errorMessage, "Agrega al menos un producto o servicio a la orden.")

        viewModel.addCatalogItem(Self.catalogItem)
        viewModel.expectedDate = "20/07/2026"
        _ = await viewModel.save()

        XCTAssertEqual(viewModel.errorMessage, "La fecha esperada debe usar el formato AAAA-MM-DD.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateMapsCatalogLineAndReusesIdempotencyKeyOnRetry() async throws {
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(Self.envelopeJSON(status: "DRAFT", version: 1, replayed: true)),
        ])
        let viewModel = makeCreateViewModel(client: client)
        prepareValidDraft(viewModel)
        viewModel.expectedDate = "2026-07-20"
        viewModel.notes = " Reposición semanal "
        viewModel.lines[0].orderedQuantity = " 2,5 "
        viewModel.lines[0].unitCost = " 10.1250 "
        viewModel.lines[0].discountAmount = " 0.25 "
        viewModel.lines[0].allowsDecimal = true
        viewModel.lines[0].priceTaxMode = .taxInclusive

        let first = await viewModel.save()
        let second = await viewModel.save()

        XCTAssertNil(first)
        XCTAssertEqual(second?.id, "po_1")
        XCTAssertEqual(viewModel.infoMessage, "Orden recuperada de un intento anterior.")
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["purchase-order-create-fixed", "purchase-order-create-fixed"]
        )

        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.purchaseOrders)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        let body = try request.jsonObject()
        XCTAssertEqual(body["branchId"] as? String, "br_1")
        XCTAssertEqual(body["supplierId"] as? String, "sup_1")
        XCTAssertEqual(body["currency"] as? String, "USD")
        XCTAssertEqual(body["expectedDate"] as? String, "2026-07-20")
        XCTAssertEqual(body["notes"] as? String, "Reposición semanal")
        XCTAssertNil(body["expectedVersion"])

        let lines = try XCTUnwrap(body["lines"] as? [[String: Any]])
        XCTAssertEqual(lines.count, 1)
        XCTAssertNil(lines[0]["id"])
        XCTAssertEqual(lines[0]["kind"] as? String, "STOCK_ITEM")
        XCTAssertEqual(lines[0]["catalogItemId"] as? String, "item_1")
        XCTAssertEqual(lines[0]["description"] as? String, "Router")
        XCTAssertEqual(lines[0]["orderedQuantity"] as? String, "2.5")
        XCTAssertEqual(lines[0]["unitCode"] as? String, "unit")
        XCTAssertEqual(lines[0]["allowsDecimal"] as? Bool, true)
        XCTAssertEqual(lines[0]["unitCost"] as? String, "10.1250")
        XCTAssertEqual(lines[0]["discountAmount"] as? String, "0.25")
        XCTAssertEqual(lines[0]["priceTaxMode"] as? String, "TAX_INCLUSIVE")
        XCTAssertEqual(lines[0]["taxProfileId"] as? String, "tax_1")
    }

    func testEditPreservesLineIdentityAttachmentsAndNumericVersionWithoutIdempotency() async throws {
        let current = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "DRAFT", version: 8))
        ])
        let viewModel = makeEditViewModel(order: current, client: client)
        viewModel.lines[0].orderedQuantity = "3"

        let updated = await viewModel.save()

        XCTAssertEqual(updated?.version, 8)
        XCTAssertEqual(viewModel.infoMessage, "Orden actualizada correctamente.")
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.purchaseOrder("po_1"))
        XCTAssertNil(request.headers[BusinessHeaders.idempotencyKey])
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertFalse(body["expectedVersion"] is String)
        XCTAssertEqual(body["attachmentIds"] as? [String], ["patt_1"])
        let lines = try XCTUnwrap(body["lines"] as? [[String: Any]])
        XCTAssertEqual(lines[0]["id"] as? String, "pol_1")
        XCTAssertEqual(lines[0]["targetWarehouseId"] as? String, "wh_1")
    }

    func testEditRejectsRedactedCostsBeforeNetworkCall() async throws {
        let current = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7, withCosts: false)
        ).data
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "DRAFT", version: 8))
        ])
        let viewModel = makeEditViewModel(order: current, client: client)

        let updated = await viewModel.save()

        XCTAssertNil(updated)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Actualiza el detalle con acceso a costos antes de editar para no sobrescribir valores protegidos."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testEditVersionConflictRequiresDetailRefresh() async throws {
        let current = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .error(
                .server(
                    statusCode: 409,
                    code: "procurement_version_conflict",
                    message: "stale",
                    requestId: "req_conflict"
                )
            )
        ])
        let viewModel = makeEditViewModel(order: current, client: client)

        let updated = await viewModel.save()

        XCTAssertNil(updated)
        XCTAssertEqual(
            viewModel.errorMessage,
            "La orden cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        )
    }

    func testSendUsesNumericVersionAndStableActionIdempotencyKeyOnRetry() async throws {
        let current = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(Self.envelopeJSON(status: "SENT", version: 8, replayed: true)),
        ])
        let viewModel = BusinessPurchaseOrderDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.purchaseOrdersView,
                BusinessProcurementPermission.purchaseOrdersSend,
                BusinessProcurementPermission.purchaseOrdersCostView,
            ],
            purchaseOrder: current,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            actionIdempotencyKeys: Self.actionKeys
        )

        let first = await viewModel.perform(action: .send)
        let second = await viewModel.perform(action: .send)

        XCTAssertNil(first)
        XCTAssertEqual(second?.status, .sent)
        XCTAssertEqual(viewModel.infoMessage, "La orden se recuperó de un intento anterior.")
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["po-send-fixed", "po-send-fixed"]
        )
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.purchaseOrderAction(.send, orderId: "po_1")
        )
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertFalse(body["expectedVersion"] is String)
        XCTAssertNil(body["reason"])
    }

    func testCancelRequiresReasonAndCloseUsesRealStatusPermissionGate() async throws {
        let draft = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseOrderMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "CANCELLED", version: 8))
        ])
        let cancelViewModel = BusinessPurchaseOrderDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.purchaseOrdersCancel],
            purchaseOrder: draft,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            actionIdempotencyKeys: Self.actionKeys
        )

        let cancelled = await cancelViewModel.perform(action: .cancel, reason: "   ")

        XCTAssertNil(cancelled)
        XCTAssertEqual(cancelViewModel.errorMessage, "Ingresa el motivo de cancelación.")
        XCTAssertTrue(client.capturedRequests.isEmpty)

        let partial = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "PARTIALLY_RECEIVED", version: 9)
        ).data
        let closeViewModel = BusinessPurchaseOrderDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.purchaseOrdersClose],
            purchaseOrder: partial,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        XCTAssertTrue(closeViewModel.canClose)
        XCTAssertFalse(closeViewModel.canSend)
        XCTAssertFalse(closeViewModel.canEdit)
    }

    func testPurchaseOrderSurfacesGateMutationsAndUseSharedForm() throws {
        let ordersSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseOrdersView.swift"
        )
        let businessSource = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(ordersSource.contains("if viewModel.canCreate"))
        XCTAssertTrue(ordersSource.contains("if viewModel.canEdit"))
        XCTAssertTrue(ordersSource.contains("if viewModel.canSend"))
        XCTAssertTrue(ordersSource.contains("if viewModel.canCancel"))
        XCTAssertTrue(ordersSource.contains("if viewModel.canClose"))
        XCTAssertTrue(ordersSource.contains("BusinessPurchaseOrderFormView"))
        XCTAssertTrue(ordersSource.contains("onOrderChanged"))
        XCTAssertTrue(ordersSource.contains("todavía no cambiará inventario ni cuentas por pagar"))
        XCTAssertTrue(businessSource.contains("catalogRepository: container.catalogRepository"))
        XCTAssertFalse(ordersSource.contains("Text(order.id)"))
        XCTAssertFalse(ordersSource.contains("Text(viewModel.purchaseOrder.id)"))
    }

    private func makeCreateViewModel(
        permissions: Set<String> = [
            BusinessProcurementPermission.purchaseOrdersCreate,
            BusinessProcurementPermission.purchaseOrdersCostView,
        ],
        client: PurchaseOrderMutationAPIClient
    ) -> BusinessPurchaseOrderFormViewModel {
        BusinessPurchaseOrderFormViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1",
            catalogRevision: "cat_rev_1",
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            catalogRepository: PurchaseOrderFormCatalogRepository(),
            createIdempotencyKey: IdempotencyKey(rawValue: "purchase-order-create-fixed")
        )
    }

    private func makeEditViewModel(
        order: BusinessProcurementPurchaseOrderResponse,
        client: PurchaseOrderMutationAPIClient
    ) -> BusinessPurchaseOrderFormViewModel {
        BusinessPurchaseOrderFormViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1",
            catalogRevision: "cat_rev_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.purchaseOrdersUpdate,
                BusinessProcurementPermission.purchaseOrdersCostView,
            ],
            purchaseOrder: order,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            catalogRepository: PurchaseOrderFormCatalogRepository()
        )
    }

    private func prepareValidDraft(_ viewModel: BusinessPurchaseOrderFormViewModel) {
        viewModel.selectedSupplierId = "sup_1"
        viewModel.addCatalogItem(Self.catalogItem)
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

    private static func decodeEnvelope(
        _ json: String
    ) throws -> BusinessProcurementPurchaseOrderEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementPurchaseOrderEnvelopeResponse.self,
            from: Data(json.utf8)
        )
    }

    private static let catalogItem = BusinessCatalogItem(
        id: "item_1",
        name: "Router",
        displayName: "Router",
        sku: "RTR-1",
        type: "PRODUCT",
        status: "ACTIVE",
        unit: BusinessCatalogUnit(code: "unit", name: "Unidad", allowsDecimal: false),
        cost: MoneyAmount(amount: "10.00", currency: "USD"),
        taxProfileId: "tax_1",
        tracksInventory: true,
        hasStockProfile: true,
        allowsDecimalQuantity: false
    )

    private static let actionKeys = BusinessPurchaseOrderActionIdempotencyKeys(
        send: IdempotencyKey(rawValue: "po-send-fixed"),
        cancel: IdempotencyKey(rawValue: "po-cancel-fixed"),
        close: IdempotencyKey(rawValue: "po-close-fixed")
    )

    private static func envelopeJSON(
        status: String,
        version: Int,
        replayed: Bool = false,
        withCosts: Bool = true
    ) -> String {
        let unitCost = withCosts ? #"{"amount":"10.00","currency":"USD"}"# : "null"
        let discount = withCosts ? #"{"amount":"0.00","currency":"USD"}"# : "null"
        let total = withCosts ? #"{"amount":"20.00","currency":"USD"}"# : "null"
        let sentAt = status == "SENT" ? #""2026-07-15T13:00:00Z""# : "null"
        let cancelledAt = status == "CANCELLED" ? #""2026-07-15T13:00:00Z""# : "null"
        return """
        {
          "data": {
            "id":"po_1","branchId":"br_1","supplierId":"sup_1","orderNumber":"PO-202607-000001","status":"\(status)","currency":"USD",
            "lines":[{
              "id":"pol_1","kind":"STOCK_ITEM","catalogItemId":"item_1",
              "catalogItemSnapshot":{"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"unit","taxProfileId":"tax_1","taxProfileVersion":3},
              "descriptionSnapshot":"Router","orderedQuantity":{"value":"2","unitCode":"unit","allowsDecimal":false},"receivedQuantity":"0",
              "unitCost":\(unitCost),"discountAmount":\(discount),"priceTaxMode":"TAX_EXCLUSIVE","taxProfileId":"tax_1","taxProfileVersion":3,
              "taxes":null,"grossAmount":\(total),"netAmount":\(total),"taxAmount":\(discount),"lineTotal":\(total),
              "targetWarehouseId":"wh_1","notes":null
            }],
            "subtotal":\(total),"discountTotal":\(discount),"taxTotal":\(discount),"total":\(total),"expectedDate":"2026-07-20",
            "supplierSnapshot":{"supplierId":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Ferretería Uno","identificationType":"RUC","identificationNumber":null,"paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD"},
            "paymentTermsSnapshot":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"notes":"Reposición","attachmentIds":["patt_1"],
            "createdAt":"2026-07-15T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T12:00:00Z","updatedBy":"usr_1",
            "sentAt":\(sentAt),"sentBy":null,"closedAt":null,"closedBy":null,"closeReason":null,
            "cancelledAt":\(cancelledAt),"cancelledBy":null,"cancellationReason":null,"version":\(version)
          },
          "meta":{"requestId":"req_po","idempotencyReplayed":\(replayed)}
        }
        """
    }
}

private struct PurchaseOrderMutationRequest {
    let method: HTTPMethod
    let path: String
    let headers: [String: String]
    let body: Data?

    func jsonObject() throws -> [String: Any] {
        let body = try XCTUnwrap(body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private final class PurchaseOrderMutationAPIClient: APIClient, @unchecked Sendable {
    enum Outcome {
        case response(String)
        case error(APIError)
    }

    private var outcomes: [Outcome]
    private(set) var capturedRequests: [PurchaseOrderMutationRequest] = []

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            PurchaseOrderMutationRequest(
                method: request.method,
                path: request.path,
                headers: request.headers,
                body: request.body
            )
        )
        guard !outcomes.isEmpty else {
            throw APIError.emptyResponse
        }
        switch outcomes.removeFirst() {
        case .response(let json):
            return try JSONDecoder.nexoDefault.decode(Response.self, from: Data(json.utf8))
        case .error(let error):
            throw error
        }
    }
}

private struct PurchaseOrderFormCatalogRepository: CatalogRepository {
    func search(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSearchResponse {
        CatalogSearchResponse(items: [], catalogRevision: catalogRevision)
    }
}
