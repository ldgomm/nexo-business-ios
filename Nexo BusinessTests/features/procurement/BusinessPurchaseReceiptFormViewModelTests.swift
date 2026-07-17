//
//  BusinessPurchaseReceiptFormViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessPurchaseReceiptFormViewModelTests: XCTestCase {
    func testCreateRequiresModulePermissionAndReceivableOrderStatusBeforeNetwork() async throws {
        let sent = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "SENT")
        ).data
        let partial = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "PARTIALLY_RECEIVED")
        ).data
        let draft = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "DRAFT")
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [])

        let noModule = makeCreateViewModel(
            order: sent,
            activeModules: [],
            client: client
        )
        prepareValidReceipt(noModule)
        let noModuleResult = await noModule.save()
        XCTAssertNil(noModuleResult)
        XCTAssertEqual(
            noModule.errorMessage,
            "El módulo Compras no está activo para esta organización."
        )

        let noCreatePermission = makeCreateViewModel(
            order: sent,
            permissions: [BusinessProcurementPermission.purchaseOrdersView],
            client: client
        )
        prepareValidReceipt(noCreatePermission)
        let noCreatePermissionResult = await noCreatePermission.save()
        XCTAssertNil(noCreatePermissionResult)
        XCTAssertEqual(
            noCreatePermission.errorMessage,
            "Solo puedes recibir una orden enviada o parcialmente recibida con el permiso correspondiente."
        )

        let invalidState = makeCreateViewModel(order: draft, client: client)
        prepareValidReceipt(invalidState)
        let invalidStateResult = await invalidState.save()
        XCTAssertNil(invalidStateResult)
        XCTAssertEqual(
            invalidState.errorMessage,
            "Solo puedes recibir una orden enviada o parcialmente recibida con el permiso correspondiente."
        )

        XCTAssertNil(makeCreateViewModel(order: sent, client: client).accessValidationMessage)
        XCTAssertNil(makeCreateViewModel(order: partial, client: client).accessValidationMessage)
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateRequiresOneExplicitWarehouseWithoutExposingItsIdentifier() throws {
        let missing = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(targetWarehouseIds: [nil])
        ).data
        let multiple = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(targetWarehouseIds: ["wh_1", "wh_2"])
        ).data
        let single = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(targetWarehouseIds: ["wh_1", "wh_1"])
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [])

        let missingViewModel = makeCreateViewModel(order: missing, client: client)
        XCTAssertEqual(
            missingViewModel.accessValidationMessage,
            "La orden no define una bodega de destino para todas sus líneas. No se puede crear la recepción sin una bodega explícita."
        )

        let multipleViewModel = makeCreateViewModel(order: multiple, client: client)
        XCTAssertEqual(
            multipleViewModel.accessValidationMessage,
            "La orden contiene varias bodegas de destino. Registra cada recepción desde una selección de bodega compatible cuando esa fuente esté disponible."
        )

        let singleViewModel = makeCreateViewModel(order: single, client: client)
        XCTAssertNil(singleViewModel.accessValidationMessage)
        XCTAssertEqual(singleViewModel.warehouseDisplayText, "Bodega definida por la orden")
        XCTAssertFalse(singleViewModel.warehouseDisplayText.contains("wh_1"))
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateValidatesEventQuantitiesDecimalsAndTrackingBeforeNetwork() throws {
        let order = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(targetWarehouseIds: ["wh_1", "wh_1"])
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [])
        let viewModel = makeCreateViewModel(order: order, client: client)

        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "Ingresa una cantidad recibida mayor que cero en al menos una línea."
        )

        viewModel.lines[0].receivedQuantity = "2"
        viewModel.lines[0].acceptedQuantity = "1"
        viewModel.lines[0].rejectedQuantity = "0"
        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "En la línea 1, la cantidad aceptada más la rechazada debe coincidir con la recibida."
        )

        viewModel.lines[0].receivedQuantity = "1.0000001"
        viewModel.lines[0].acceptedQuantity = "1.0000001"
        viewModel.lines[0].rejectedQuantity = "0"
        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "Las cantidades de la línea 1 admiten hasta 6 decimales."
        )

        viewModel.lines[0].receivedQuantity = "1,5"
        viewModel.lines[0].acceptedQuantity = "1,5"
        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "Las cantidades de la línea 1 deben ser números enteros."
        )

        viewModel.lines[0].receivedQuantity = "1"
        viewModel.lines[0].acceptedQuantity = "1"
        viewModel.addTrackedUnit(to: viewModel.lines[0].id)
        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "La línea 1 contiene una serie o identificador vacío."
        )

        viewModel.lines[0].trackedUnits[0].trackingValue = " SN-001 "
        viewModel.lines[0].trackedUnits[0].trackingType = "LOT"
        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "La línea 1 contiene un tipo de rastreo no compatible."
        )

        viewModel.lines[0].trackedUnits[0].trackingType = "SERIAL"
        viewModel.lines[1].receivedQuantity = "1"
        viewModel.lines[1].acceptedQuantity = "1"
        viewModel.addTrackedUnit(to: viewModel.lines[1].id)
        viewModel.lines[1].trackedUnits[0].trackingType = "IMEI"
        viewModel.lines[1].trackedUnits[0].trackingValue = "sn-001"
        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "La serie o identificador sn-001 está repetido en la recepción."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateDoesNotCalculateOrBlockOverReceiptOnDevice() throws {
        let order = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "PARTIALLY_RECEIVED")
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [])
        let viewModel = makeCreateViewModel(order: order, client: client)

        viewModel.lines[0].receivedQuantity = "100"
        viewModel.lines[0].acceptedQuantity = "100"
        viewModel.lines[0].rejectedQuantity = "0"

        XCTAssertNil(viewModel.inputValidationMessage)
        XCTAssertEqual(viewModel.lines[0].orderedQuantityText, "5 unit")
        XCTAssertEqual(viewModel.lines[0].cumulativeReceivedQuantityText, "2 unit")
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testTrackingWhitelistAcceptsOnlyBackendSupportedTypes() throws {
        let order = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON()
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [])

        XCTAssertEqual(
            BusinessPurchaseReceiptTrackingType.allCases.map(\.rawValue),
            ["SERIAL", "IMEI", "MAC", "CUSTOM"]
        )

        for type in BusinessPurchaseReceiptTrackingType.allCases {
            let viewModel = makeCreateViewModel(order: order, client: client)
            prepareValidReceipt(viewModel)
            viewModel.addTrackedUnit(to: viewModel.lines[0].id)
            viewModel.lines[0].trackedUnits[0].trackingType = type.rawValue
            viewModel.lines[0].trackedUnits[0].trackingValue = "VALUE-\(type.rawValue)"

            XCTAssertNil(viewModel.inputValidationMessage, type.rawValue)
        }
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testReplacingReceiptRemovesServerStateThatLeavesTheActiveFilter() throws {
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let confirmed = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "CONFIRMED", version: 8)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [])
        let viewModel = BusinessPurchaseReceiptsViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.purchaseReceiptsView],
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
        viewModel.statusFilter = .draft

        viewModel.replace(draft)
        XCTAssertEqual(viewModel.purchaseReceipts.map(\.id), ["rcpt_1"])

        viewModel.replace(confirmed)
        XCTAssertTrue(viewModel.purchaseReceipts.isEmpty)
        XCTAssertEqual(
            viewModel.infoMessage,
            "No encontramos recepciones de compra con estos filtros."
        )

        viewModel.statusFilter = .all
        viewModel.replace(confirmed)
        XCTAssertEqual(viewModel.purchaseReceipts.first?.receipt.status, .confirmed)
        XCTAssertNil(viewModel.infoMessage)
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateMapsReceiptEventAndReusesIdempotencyKeyOnRetry() async throws {
        let order = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "PARTIALLY_RECEIVED")
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(Self.receiptEnvelopeJSON(status: "DRAFT", version: 1, replayed: true)),
        ])
        let viewModel = makeCreateViewModel(order: order, client: client)
        prepareValidReceipt(viewModel)
        viewModel.notes = "  Recepción física parcial  "
        viewModel.lines[0].receivedQuantity = " 2 "
        viewModel.lines[0].acceptedQuantity = " 1 "
        viewModel.lines[0].rejectedQuantity = " 1 "
        viewModel.addTrackedUnit(to: viewModel.lines[0].id)
        viewModel.lines[0].trackedUnits[0].trackingType = " serial "
        viewModel.lines[0].trackedUnits[0].trackingValue = " SN-001 "
        viewModel.lines[0].trackedUnits[0].notes = "  Caja íntegra  "
        viewModel.lines[0].notes = "  Una unidad dañada  "

        let first = await viewModel.save()
        let second = await viewModel.save()

        XCTAssertNil(first)
        XCTAssertEqual(second?.id, "rcpt_1")
        XCTAssertEqual(viewModel.infoMessage, "Recepción recuperada de un intento anterior.")
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["purchase-receipt-create-fixed", "purchase-receipt-create-fixed"]
        )

        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.purchaseReceipts)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        let body = try request.jsonObject()
        XCTAssertEqual(body["branchId"] as? String, "br_1")
        XCTAssertEqual(body["supplierId"] as? String, "sup_1")
        XCTAssertEqual(body["purchaseOrderId"] as? String, "po_1")
        XCTAssertEqual(body["warehouseId"] as? String, "wh_1")
        XCTAssertEqual(body["receivedAt"] as? String, "2026-07-15T13:30:00Z")
        XCTAssertEqual(body["notes"] as? String, "Recepción física parcial")
        XCTAssertEqual(body["attachmentIds"] as? [String], [])
        XCTAssertNil(body["expectedVersion"])

        let lines = try XCTUnwrap(body["lines"] as? [[String: Any]])
        XCTAssertEqual(lines.count, 1)
        XCTAssertNil(lines[0]["id"])
        XCTAssertEqual(lines[0]["purchaseOrderLineId"] as? String, "pol_1")
        XCTAssertEqual(lines[0]["kind"] as? String, "STOCK_ITEM")
        XCTAssertEqual(lines[0]["catalogItemId"] as? String, "item_1")
        XCTAssertEqual(lines[0]["receivedQuantity"] as? String, "2")
        XCTAssertEqual(lines[0]["acceptedQuantity"] as? String, "1")
        XCTAssertEqual(lines[0]["rejectedQuantity"] as? String, "1")
        XCTAssertEqual(lines[0]["unitCode"] as? String, "unit")
        XCTAssertEqual(lines[0]["allowsDecimal"] as? Bool, false)
        XCTAssertEqual(lines[0]["unitCost"] as? String, "10.00")
        XCTAssertEqual(lines[0]["warehouseId"] as? String, "wh_1")
        XCTAssertEqual(lines[0]["notes"] as? String, "Una unidad dañada")
        let trackedUnits = try XCTUnwrap(lines[0]["trackedUnits"] as? [[String: Any]])
        XCTAssertEqual(trackedUnits.count, 1)
        XCTAssertEqual(trackedUnits[0]["trackingType"] as? String, "SERIAL")
        XCTAssertEqual(trackedUnits[0]["trackingValue"] as? String, "SN-001")
        XCTAssertEqual(trackedUnits[0]["notes"] as? String, "Caja íntegra")
    }

    func testEditRequiresDraftUpdatePermissionAndCompleteVisibleCosts() async throws {
        let order = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "SENT")
        ).data
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let redacted = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7, withCost: false)
        ).data
        let confirmed = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "CONFIRMED", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [])

        let noUpdatePermission = makeEditViewModel(
            order: order,
            receipt: draft,
            permissions: [BusinessProcurementPermission.purchaseOrdersCostView],
            client: client
        )
        XCTAssertEqual(
            noUpdatePermission.accessValidationMessage,
            "Solo puedes editar recepciones en borrador cuando tienes el permiso correspondiente."
        )
        let noUpdateResult = await noUpdatePermission.save()
        XCTAssertNil(noUpdateResult)

        let noCostPermission = makeEditViewModel(
            order: order,
            receipt: draft,
            permissions: [BusinessProcurementPermission.purchaseReceiptsUpdate],
            client: client
        )
        XCTAssertEqual(
            noCostPermission.accessValidationMessage,
            "La edición requiere permiso para consultar los costos y evitar sobrescribir valores protegidos."
        )

        let redactedCosts = makeEditViewModel(
            order: order,
            receipt: redacted,
            client: client
        )
        XCTAssertEqual(
            redactedCosts.accessValidationMessage,
            "Actualiza el detalle con acceso a costos antes de editar para no sobrescribir valores protegidos."
        )

        let nonDraft = makeEditViewModel(
            order: order,
            receipt: confirmed,
            client: client
        )
        XCTAssertEqual(
            nonDraft.accessValidationMessage,
            "Solo puedes editar recepciones en borrador cuando tienes el permiso correspondiente."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testEditPreservesIdentitiesAttachmentsTrackingAndNumericVersionWithoutIdempotency() async throws {
        let order = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "SENT")
        ).data
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .response(Self.receiptEnvelopeJSON(status: "DRAFT", version: 8))
        ])
        let viewModel = makeEditViewModel(
            order: order,
            receipt: draft,
            client: client
        )

        let updated = await viewModel.save()

        XCTAssertEqual(updated?.version, 8)
        XCTAssertEqual(viewModel.infoMessage, "Recepción actualizada correctamente.")
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.purchaseReceipt("rcpt_1"))
        XCTAssertNil(request.headers[BusinessHeaders.idempotencyKey])
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertFalse(body["expectedVersion"] is String)
        XCTAssertEqual(body["attachmentIds"] as? [String], ["patt_1"])
        XCTAssertEqual(body["branchId"] as? String, "br_1")
        XCTAssertEqual(body["supplierId"] as? String, "sup_1")
        XCTAssertEqual(body["purchaseOrderId"] as? String, "po_1")
        XCTAssertEqual(body["warehouseId"] as? String, "wh_1")
        XCTAssertEqual(body["receivedAt"] as? String, "2026-07-15T13:30:00Z")
        XCTAssertEqual(body["notes"] as? String, "Recepción parcial")
        let lines = try XCTUnwrap(body["lines"] as? [[String: Any]])
        XCTAssertEqual(lines[0]["id"] as? String, "prl_1")
        XCTAssertEqual(lines[0]["purchaseOrderLineId"] as? String, "pol_1")
        XCTAssertEqual(lines[0]["kind"] as? String, "STOCK_ITEM")
        XCTAssertEqual(lines[0]["catalogItemId"] as? String, "item_1")
        XCTAssertEqual(lines[0]["receivedQuantity"] as? String, "2")
        XCTAssertEqual(lines[0]["acceptedQuantity"] as? String, "1")
        XCTAssertEqual(lines[0]["rejectedQuantity"] as? String, "1")
        XCTAssertEqual(lines[0]["unitCode"] as? String, "unit")
        XCTAssertEqual(lines[0]["allowsDecimal"] as? Bool, false)
        XCTAssertEqual(lines[0]["unitCost"] as? String, "10.00")
        XCTAssertEqual(lines[0]["warehouseId"] as? String, "wh_1")
        XCTAssertEqual(lines[0]["notes"] as? String, "Una unidad dañada")
        let trackedUnits = try XCTUnwrap(lines[0]["trackedUnits"] as? [[String: Any]])
        XCTAssertEqual(trackedUnits[0]["trackingType"] as? String, "SERIAL")
        XCTAssertEqual(trackedUnits[0]["trackingValue"] as? String, "SN-001")

        let detailViewModel = makeDetailViewModel(
            receipt: draft,
            permissions: [],
            client: client
        )
        detailViewModel.recordEditedReceipt(try XCTUnwrap(updated))
        XCTAssertEqual(
            detailViewModel.infoMessage,
            "Recepción actualizada correctamente."
        )
    }

    func testEditVersionConflictRequiresClosingAndRefreshingDetail() async throws {
        let order = try Self.decodePurchaseOrderEnvelope(
            Self.purchaseOrderEnvelopeJSON(status: "SENT")
        ).data
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .error(
                .server(
                    statusCode: 409,
                    code: "procurement_version_precondition_required",
                    message: "stale",
                    requestId: "req_edit_conflict"
                )
            )
        ])
        let viewModel = makeEditViewModel(
            order: order,
            receipt: draft,
            client: client
        )

        let result = await viewModel.save()
        XCTAssertNil(result)
        XCTAssertEqual(
            viewModel.errorMessage,
            "La recepción cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        )
    }

    func testConfirmUsesNumericVersionAndStableIdempotencyKeyOnRetry() async throws {
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(Self.receiptEnvelopeJSON(status: "CONFIRMED", version: 8, replayed: true)),
        ])
        let viewModel = makeDetailViewModel(
            receipt: draft,
            permissions: [BusinessProcurementPermission.purchaseReceiptsConfirm],
            client: client
        )

        let first = await viewModel.perform(action: .confirm)
        let second = await viewModel.perform(action: .confirm)

        XCTAssertNil(first)
        XCTAssertEqual(second?.status, .confirmed)
        XCTAssertEqual(viewModel.infoMessage, "La recepción se recuperó de un intento anterior.")
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["receipt-confirm-fixed", "receipt-confirm-fixed"]
        )

        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.purchaseReceiptAction(.confirm, receiptId: "rcpt_1")
        )
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertFalse(body["expectedVersion"] is String)
        XCTAssertNil(body["reason"])
    }

    func testConfirmingResponseNeverClaimsInventoryWasCompleted() async throws {
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .response(Self.receiptEnvelopeJSON(status: "CONFIRMING", version: 8))
        ])
        let viewModel = makeDetailViewModel(
            receipt: draft,
            permissions: [BusinessProcurementPermission.purchaseReceiptsConfirm],
            client: client
        )

        let receipt = await viewModel.perform(action: .confirm)

        XCTAssertEqual(receipt?.status, .confirming)
        XCTAssertEqual(
            viewModel.infoMessage,
            "La confirmación está en proceso. Actualiza el detalle antes de asumir un efecto de inventario."
        )
        XCTAssertFalse(viewModel.infoMessage?.contains("confirmada correctamente") == true)
        XCTAssertFalse(viewModel.canConfirm)
        XCTAssertFalse(viewModel.hasAvailableActions)
    }

    func testConfirmRefreshesLinkedOrderFromBackendWithoutLocalFulfillmentMutation() async throws {
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .response(Self.receiptEnvelopeJSON(status: "CONFIRMED", version: 8)),
            .response(Self.purchaseOrderEnvelopeJSON(status: "PARTIALLY_RECEIVED", version: 9)),
        ])
        let viewModel = makeDetailViewModel(
            receipt: draft,
            permissions: [
                BusinessProcurementPermission.purchaseReceiptsConfirm,
                BusinessProcurementPermission.purchaseOrdersView,
            ],
            client: client
        )

        let receipt = await viewModel.perform(action: .confirm)

        XCTAssertEqual(receipt?.status, .confirmed)
        XCTAssertEqual(viewModel.purchaseOrder?.status, .partiallyReceived)
        XCTAssertEqual(viewModel.purchaseOrder?.version, 9)
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.last?.path,
            BusinessProcurementRoutes.purchaseOrder("po_1")
        )
    }

    func testCancelRequiresReasonAndUsesIndependentStableKey() async throws {
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(Self.receiptEnvelopeJSON(status: "CANCELLED", version: 8, replayed: true)),
        ])
        let viewModel = makeDetailViewModel(
            receipt: draft,
            permissions: [
                BusinessProcurementPermission.purchaseReceiptsConfirm,
                BusinessProcurementPermission.purchaseReceiptsCancel,
            ],
            client: client
        )

        let rejected = await viewModel.perform(action: .cancel, reason: "   ")

        XCTAssertNil(rejected)
        XCTAssertEqual(viewModel.errorMessage, "Ingresa el motivo de cancelación.")
        XCTAssertTrue(client.capturedRequests.isEmpty)

        let firstAttempt = await viewModel.perform(
            action: .cancel,
            reason: "  Mercadería no entregada  "
        )
        let cancelled = await viewModel.perform(
            action: .cancel,
            reason: "  Mercadería no entregada  "
        )

        XCTAssertNil(firstAttempt)
        XCTAssertEqual(cancelled?.status, .cancelled)
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["receipt-cancel-fixed", "receipt-cancel-fixed"]
        )
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.purchaseReceiptAction(.cancel, receiptId: "rcpt_1")
        )
        XCTAssertEqual(
            request.headers[BusinessHeaders.idempotencyKey],
            "receipt-cancel-fixed"
        )
        XCTAssertNotEqual(
            request.headers[BusinessHeaders.idempotencyKey],
            "receipt-confirm-fixed"
        )
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertEqual(body["reason"] as? String, "Mercadería no entregada")
    }

    func testNonDraftReceiptsExposeNoMutationActionsAndNeverCallNetwork() async throws {
        for status in ["CONFIRMING", "CONFIRMED", "CANCELLED"] {
            let receipt = try Self.decodeReceiptEnvelope(
                Self.receiptEnvelopeJSON(status: status, version: 8)
            ).data
            let client = PurchaseReceiptMutationAPIClient(outcomes: [])
            let viewModel = makeDetailViewModel(
                receipt: receipt,
                permissions: [
                    BusinessProcurementPermission.purchaseReceiptsUpdate,
                    BusinessProcurementPermission.purchaseReceiptsConfirm,
                    BusinessProcurementPermission.purchaseReceiptsCancel,
                ],
                client: client
            )

            XCTAssertFalse(viewModel.canEdit, status)
            XCTAssertFalse(viewModel.canConfirm, status)
            XCTAssertFalse(viewModel.canCancel, status)
            XCTAssertFalse(viewModel.hasAvailableActions, status)

            let result = await viewModel.perform(action: .confirm)
            XCTAssertNil(result, status)
            let cancelResult = await viewModel.perform(
                action: .cancel,
                reason: "No aplica"
            )
            XCTAssertNil(cancelResult, status)
            XCTAssertTrue(client.capturedRequests.isEmpty, status)
        }
    }

    func testReceiptActionVersionAndStateConflictsRequireRefresh() async throws {
        let draft = try Self.decodeReceiptEnvelope(
            Self.receiptEnvelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = PurchaseReceiptMutationAPIClient(outcomes: [
            .error(
                .server(
                    statusCode: 409,
                    code: "procurement_version_conflict",
                    message: "stale",
                    requestId: "req_version"
                )
            ),
            .error(
                .server(
                    statusCode: 409,
                    code: "procurement_state_conflict",
                    message: "state",
                    requestId: "req_state"
                )
            ),
        ])
        let viewModel = makeDetailViewModel(
            receipt: draft,
            permissions: [BusinessProcurementPermission.purchaseReceiptsConfirm],
            client: client
        )

        _ = await viewModel.perform(action: .confirm)
        XCTAssertEqual(
            viewModel.errorMessage,
            "La recepción cambió en el servidor. Actualiza el detalle antes de reintentar."
        )

        _ = await viewModel.perform(action: .confirm)
        XCTAssertEqual(
            viewModel.errorMessage,
            "El estado de la recepción cambió. Actualiza el detalle antes de continuar."
        )
    }

    func testReceiptSurfacesGateMutationsExplainEffectsAndEnterFromOrderContext() throws {
        let receiptSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseReceiptsView.swift"
        )
        let orderSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseOrdersView.swift"
        )
        let formSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseReceiptFormView.swift"
        )
        let formViewModelSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseReceiptFormViewModel.swift"
        )

        XCTAssertTrue(receiptSource.contains("if viewModel.canEdit"))
        XCTAssertTrue(receiptSource.contains("if viewModel.canConfirm"))
        XCTAssertTrue(receiptSource.contains("if viewModel.canCancel"))
        XCTAssertTrue(receiptSource.contains("BusinessPurchaseReceiptFormView("))
        XCTAssertTrue(receiptSource.contains("purchaseReceipt: viewModel.purchaseReceipt"))
        XCTAssertTrue(receiptSource.contains("onReceiptChanged"))
        XCTAssertTrue(receiptSource.contains("cantidades aceptadas"))
        XCTAssertTrue(receiptSource.contains("cantidades rechazadas no entran"))
        XCTAssertTrue(receiptSource.contains("exactamente una vez"))
        XCTAssertTrue(receiptSource.contains("evidencia inmutable"))
        XCTAssertTrue(receiptSource.contains("no crea una cuenta por pagar"))
        XCTAssertFalse(receiptSource.contains("Text(viewModel.purchaseReceipt.id)"))
        XCTAssertFalse(receiptSource.contains("Text(line.inventoryMovementId)"))

        XCTAssertTrue(orderSource.contains("if viewModel.canReceive"))
        XCTAssertTrue(orderSource.contains("Registrar recepción"))
        XCTAssertTrue(orderSource.contains("BusinessPurchaseReceiptFormView("))
        XCTAssertTrue(orderSource.contains("purchaseOrder: viewModel.purchaseOrder"))
        XCTAssertTrue(orderSource.contains("purchaseOrderId: viewModel.purchaseOrder.id"))
        XCTAssertTrue(orderSource.contains("Ver recepciones de esta orden"))
        XCTAssertFalse(orderSource.contains("Text(viewModel.purchaseOrder.id)"))

        XCTAssertTrue(formSource.contains("Proveedor, orden y bodega permanecen bloqueados"))
        XCTAssertFalse(formSource.contains("Picker(\"Orden de compra\""))
        XCTAssertFalse(formSource.contains("Text(line.warehouseId)"))
        XCTAssertFalse(formSource.contains("Text(viewModel.warehouseId)"))
        XCTAssertFalse(formViewModelSource.contains("listPurchaseOrders("))
    }

    private func makeDetailViewModel(
        receipt: BusinessProcurementPurchaseReceiptResponse,
        permissions: Set<String>,
        client: PurchaseReceiptMutationAPIClient
    ) -> BusinessPurchaseReceiptDetailViewModel {
        BusinessPurchaseReceiptDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            purchaseReceipt: receipt,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            actionIdempotencyKeys: Self.actionKeys
        )
    }

    private func makeCreateViewModel(
        order: BusinessProcurementPurchaseOrderResponse,
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [
            BusinessProcurementPermission.purchaseOrdersView,
            BusinessProcurementPermission.purchaseReceiptsCreate,
        ],
        client: PurchaseReceiptMutationAPIClient
    ) -> BusinessPurchaseReceiptFormViewModel {
        BusinessPurchaseReceiptFormViewModel(
            organizationId: "org_1",
            branchId: order.branchId,
            activeModules: activeModules,
            effectivePermissions: permissions,
            purchaseOrder: order,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            createIdempotencyKey: IdempotencyKey(rawValue: "purchase-receipt-create-fixed"),
            now: Self.receivedAt
        )
    }

    private func makeEditViewModel(
        order: BusinessProcurementPurchaseOrderResponse,
        receipt: BusinessProcurementPurchaseReceiptResponse,
        permissions: Set<String> = [
            BusinessProcurementPermission.purchaseReceiptsUpdate,
            BusinessProcurementPermission.purchaseOrdersCostView,
        ],
        client: PurchaseReceiptMutationAPIClient
    ) -> BusinessPurchaseReceiptFormViewModel {
        BusinessPurchaseReceiptFormViewModel(
            organizationId: "org_1",
            branchId: receipt.branchId,
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            purchaseOrder: order,
            purchaseReceipt: receipt,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            createIdempotencyKey: IdempotencyKey(rawValue: "unused-edit-key"),
            now: Self.receivedAt
        )
    }

    private func prepareValidReceipt(_ viewModel: BusinessPurchaseReceiptFormViewModel) {
        guard !viewModel.lines.isEmpty else { return }
        viewModel.lines[0].receivedQuantity = "1"
        viewModel.lines[0].acceptedQuantity = "1"
        viewModel.lines[0].rejectedQuantity = "0"
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

    private static func decodeReceiptEnvelope(
        _ json: String
    ) throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementPurchaseReceiptEnvelopeResponse.self,
            from: Data(json.utf8)
        )
    }

    private static func decodePurchaseOrderEnvelope(
        _ json: String
    ) throws -> BusinessProcurementPurchaseOrderEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementPurchaseOrderEnvelopeResponse.self,
            from: Data(json.utf8)
        )
    }

    private static let receivedAt: Date = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: "2026-07-15T13:30:00Z")!
    }()

    private static let actionKeys = BusinessPurchaseReceiptActionIdempotencyKeys(
        confirm: IdempotencyKey(rawValue: "receipt-confirm-fixed"),
        cancel: IdempotencyKey(rawValue: "receipt-cancel-fixed")
    )

    private static func receiptEnvelopeJSON(
        status: String,
        version: Int,
        replayed: Bool = false,
        withCost: Bool = true
    ) -> String {
        let unitCost = withCost ? #"{"amount":"10.00","currency":"USD"}"# : "null"
        let confirmedAt = status == "CONFIRMED" ? #""2026-07-15T14:00:00Z""# : "null"
        let cancelledAt = status == "CANCELLED" ? #""2026-07-15T14:00:00Z""# : "null"
        return """
        {
          "data": {
            "id":"rcpt_1","branchId":"br_1","supplierId":"sup_1","purchaseOrderId":"po_1",
            "receiptNumber":"RC-202607-000001","status":"\(status)","warehouseId":"wh_1","receivedAt":"2026-07-15T13:30:00Z",
            "lines":[{
              "id":"prl_1","purchaseOrderLineId":"pol_1","kind":"STOCK_ITEM","catalogItemId":"item_1",
              "itemSnapshot":{"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"unit","taxProfileId":"tax_1","taxProfileVersion":3},
              "receivedQuantity":{"value":"2","unitCode":"unit","allowsDecimal":false},"acceptedQuantity":"1","rejectedQuantity":"1","unitCode":"unit",
              "unitCost":\(unitCost),"warehouseId":"wh_1","trackedUnits":[{"trackingType":"SERIAL","trackingValue":"SN-001","notes":"Caja íntegra"}],
              "inventoryMovementId":null,"notes":"Una unidad dañada"
            }],
            "inventoryMovementIds":[],"attachmentIds":["patt_1"],"notes":"Recepción parcial",
            "createdAt":"2026-07-15T13:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T13:30:00Z","updatedBy":"usr_1",
            "confirmedAt":\(confirmedAt),"confirmedBy":null,"cancelledAt":\(cancelledAt),"cancelledBy":null,
            "cancellationReason":null,"version":\(version)
          },
          "meta":{"requestId":"req_receipt","idempotencyReplayed":\(replayed)}
        }
        """
    }

    private static func purchaseOrderEnvelopeJSON(
        status: String = "SENT",
        version: Int = 7,
        targetWarehouseIds: [String?] = ["wh_1"],
        withCosts: Bool = true
    ) -> String {
        let lines = targetWarehouseIds.enumerated().map { index, warehouseId in
            let suffix = index + 1
            let warehouseJSON = warehouseId.map { "\"\($0)\"" } ?? "null"
            let unitCost = withCosts ? #"{"amount":"10.00","currency":"USD"}"# : "null"
            let discount = withCosts ? #"{"amount":"0.00","currency":"USD"}"# : "null"
            return """
            {
              "id":"pol_\(suffix)","kind":"STOCK_ITEM","catalogItemId":"item_\(suffix)",
              "catalogItemSnapshot":{"catalogItemId":"item_\(suffix)","localName":"Router \(suffix)","sku":"RTR-\(suffix)","unitCode":"unit","taxProfileId":"tax_1","taxProfileVersion":3},
              "descriptionSnapshot":"Router \(suffix)","orderedQuantity":{"value":"5","unitCode":"unit","allowsDecimal":false},"receivedQuantity":"2",
              "unitCost":\(unitCost),"discountAmount":\(discount),"priceTaxMode":"TAX_EXCLUSIVE","taxProfileId":"tax_1","taxProfileVersion":3,
              "taxes":null,"grossAmount":null,"netAmount":null,"taxAmount":null,"lineTotal":null,
              "targetWarehouseId":\(warehouseJSON),"notes":null
            }
            """
        }.joined(separator: ",")
        return """
        {
          "data": {
            "id":"po_1","branchId":"br_1","supplierId":"sup_1","orderNumber":"PO-202607-000001","status":"\(status)","currency":"USD",
            "lines":[\(lines)],"subtotal":null,"discountTotal":null,"taxTotal":null,"total":null,"expectedDate":"2026-07-20",
            "supplierSnapshot":{"supplierId":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Ferretería Uno","identificationType":"RUC","identificationNumber":null,"paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD"},
            "paymentTermsSnapshot":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"notes":"Reposición","attachmentIds":["po_att_1"],
            "createdAt":"2026-07-15T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T13:00:00Z","updatedBy":"usr_1",
            "sentAt":"2026-07-15T13:00:00Z","sentBy":"usr_1","closedAt":null,"closedBy":null,"closeReason":null,
            "cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":\(version)
          },
          "meta":{"requestId":"req_order","idempotencyReplayed":false}
        }
        """
    }
}

private struct CapturedPurchaseReceiptMutationRequest {
    let method: HTTPMethod
    let path: String
    let headers: [String: String]
    let body: Data?

    func jsonObject() throws -> [String: Any] {
        let body = try XCTUnwrap(body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private final class PurchaseReceiptMutationAPIClient: APIClient, @unchecked Sendable {
    enum Outcome {
        case response(String)
        case error(APIError)
    }

    private var outcomes: [Outcome]
    private(set) var capturedRequests: [CapturedPurchaseReceiptMutationRequest] = []

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedPurchaseReceiptMutationRequest(
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
