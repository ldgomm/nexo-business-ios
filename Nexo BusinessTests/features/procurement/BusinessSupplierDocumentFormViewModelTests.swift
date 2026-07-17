//
//  BusinessSupplierDocumentFormViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSupplierDocumentFormViewModelTests: XCTestCase {
    func testCreateRequiresPermissionBeforeNetworkCall() async {
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "DRAFT", version: 1)),
        ])
        let viewModel = makeCreateViewModel(permissions: [], client: client)
        prepareValidDraft(viewModel)

        let document = await viewModel.save()

        XCTAssertNil(document)
        XCTAssertEqual(
            viewModel.errorMessage,
            "No tienes permiso para crear documentos de proveedor."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateValidatesDocumentDateDueDateAndLinesBeforeNetworkCall() async {
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "DRAFT", version: 1)),
        ])
        let viewModel = makeCreateViewModel(client: client)
        viewModel.selectedSupplierId = "sup_1"
        viewModel.documentNumber = "001-001-0000123"
        viewModel.documentDate = "15/07/2026"

        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha del documento debe usar el formato AAAA-MM-DD."
        )

        viewModel.documentDate = "2026-07-15"
        viewModel.dueDate = "2026-07-14"
        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha de vencimiento no puede ser anterior a la fecha del documento."
        )

        viewModel.dueDate = "2026-08-15"
        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "Agrega al menos una línea al documento."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateMapsEvidenceLinesAndReusesIdempotencyKeyOnRetry() async throws {
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(Self.envelopeJSON(status: "DRAFT", version: 1, replayed: true)),
        ])
        let viewModel = makeCreateViewModel(client: client)
        prepareValidDraft(viewModel)
        viewModel.documentType = .invoice
        viewModel.accessKey = " ACCESS-123 "
        viewModel.authorizationNumber = " AUTH-123 "
        viewModel.purchaseOrderIdsText = "po_1, po_1; po_2"
        viewModel.purchaseReceiptIdsText = "rcpt_1\nrcpt_2"
        viewModel.attachmentIdsText = "att_1, att_2"
        viewModel.sourceTotal = " 112,00 "
        viewModel.sourceTaxTotal = " 12.00 "
        viewModel.sourcePaymentAmount = "50,00"
        viewModel.sourcePaymentMethod = " bank_transfer "
        viewModel.sourcePaymentDate = "2026-07-15"
        viewModel.sourcePaymentReference = " TRX-001 "
        viewModel.notes = " Factura por reposición "
        viewModel.lines[0].quantity = " 2,5 "
        viewModel.lines[0].allowsDecimal = true
        viewModel.lines[0].unitCost = " 40.00 "
        viewModel.lines[0].discountAmount = " 1,25 "
        viewModel.lines[0].priceTaxMode = .taxInclusive
        viewModel.lines[0].taxProfileId = "tax_1"
        viewModel.lines[0].expenseCategoryCode = " inventory_purchase "

        let first = await viewModel.save()
        let second = await viewModel.save()

        XCTAssertNil(first)
        XCTAssertEqual(second?.id, "sdoc_1")
        XCTAssertEqual(viewModel.infoMessage, "Documento recuperado de un intento anterior.")
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["supplier-document-create-fixed", "supplier-document-create-fixed"]
        )

        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.supplierDocuments)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")

        let body = try request.jsonObject()
        XCTAssertEqual(body["branchId"] as? String, "br_1")
        XCTAssertEqual(body["supplierId"] as? String, "sup_1")
        XCTAssertEqual(body["documentType"] as? String, "INVOICE")
        XCTAssertEqual(body["documentNumber"] as? String, "001-001-0000123")
        XCTAssertEqual(body["accessKey"] as? String, "ACCESS-123")
        XCTAssertEqual(body["authorizationNumber"] as? String, "AUTH-123")
        XCTAssertEqual(body["documentDate"] as? String, "2026-07-15")
        XCTAssertEqual(body["dueDate"] as? String, "2026-08-15")
        XCTAssertEqual(body["currency"] as? String, "USD")
        XCTAssertEqual(body["purchaseOrderIds"] as? [String], ["po_1", "po_2"])
        XCTAssertEqual(body["purchaseReceiptIds"] as? [String], ["rcpt_1", "rcpt_2"])
        XCTAssertEqual(body["attachmentIds"] as? [String], ["att_1", "att_2"])
        XCTAssertEqual(body["notes"] as? String, "Factura por reposición")
        XCTAssertNil(body["expectedVersion"])

        let sourceTotals = try XCTUnwrap(body["sourceTotals"] as? [String: Any])
        XCTAssertEqual(sourceTotals["total"] as? String, "112.00")
        XCTAssertEqual(sourceTotals["taxTotal"] as? String, "12.00")
        let sourcePayment = try XCTUnwrap(body["sourcePayment"] as? [String: Any])
        XCTAssertEqual(sourcePayment["amount"] as? String, "50.00")
        XCTAssertEqual(sourcePayment["method"] as? String, "BANK_TRANSFER")
        XCTAssertEqual(sourcePayment["paymentDate"] as? String, "2026-07-15")
        XCTAssertEqual(sourcePayment["reference"] as? String, "TRX-001")

        let lines = try XCTUnwrap(body["lines"] as? [[String: Any]])
        XCTAssertEqual(lines.count, 1)
        XCTAssertNil(lines[0]["id"])
        XCTAssertEqual(lines[0]["kind"] as? String, "EXPENSE")
        XCTAssertEqual(lines[0]["description"] as? String, "Internet mensual")
        XCTAssertEqual(lines[0]["quantity"] as? String, "2.5")
        XCTAssertEqual(lines[0]["unitCode"] as? String, "unit")
        XCTAssertEqual(lines[0]["allowsDecimal"] as? Bool, true)
        XCTAssertEqual(lines[0]["unitCost"] as? String, "40.00")
        XCTAssertEqual(lines[0]["discountAmount"] as? String, "1.25")
        XCTAssertEqual(lines[0]["priceTaxMode"] as? String, "TAX_INCLUSIVE")
        XCTAssertEqual(lines[0]["taxProfileId"] as? String, "tax_1")
        XCTAssertEqual(lines[0]["expenseCategoryCode"] as? String, "inventory_purchase")
    }

    func testSourceTotalsAndImmediatePaymentAreValidatedAsCompleteEvidence() async {
        let client = SupplierDocumentMutationAPIClient(outcomes: [])
        let viewModel = makeCreateViewModel(client: client)
        prepareValidDraft(viewModel)
        viewModel.sourceTotal = "112.00"

        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "El impuesto informado por el origen debe ser cero o mayor."
        )

        viewModel.sourceTaxTotal = "12.00"
        viewModel.sourcePaymentAmount = "50.00"
        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "Selecciona o escribe el método del pago inmediato informado."
        )

        viewModel.sourcePaymentMethod = "CASH"
        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha del pago inmediato debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testStockLineRequiresCatalogIdentityAndWholeQuantityWhenConfigured() async {
        let client = SupplierDocumentMutationAPIClient(outcomes: [])
        let viewModel = makeCreateViewModel(client: client)
        prepareValidDraft(viewModel)
        viewModel.lines[0].kind = "STOCK_ITEM"
        viewModel.lines[0].quantity = "1.5"
        viewModel.lines[0].allowsDecimal = false

        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "La cantidad de la línea 1 debe ser un número entero."
        )

        viewModel.lines[0].quantity = "1"
        _ = await viewModel.save()
        XCTAssertEqual(
            viewModel.errorMessage,
            "La línea 1 de inventario necesita un producto vinculado."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testEditPreservesStableLinksEvidenceAndNumericVersion() async throws {
        let current = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "DRAFT", version: 8)),
        ])
        let viewModel = makeEditViewModel(document: current, client: client)
        viewModel.lines[0].quantity = "3"

        let updated = await viewModel.save()

        XCTAssertEqual(updated?.version, 8)
        XCTAssertEqual(viewModel.infoMessage, "Documento actualizado correctamente.")
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.supplierDocument("sdoc_1")
        )
        XCTAssertNil(request.headers[BusinessHeaders.idempotencyKey])
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertFalse(body["expectedVersion"] is String)
        XCTAssertEqual(body["purchaseOrderIds"] as? [String], ["po_1"])
        XCTAssertEqual(body["purchaseReceiptIds"] as? [String], ["rcpt_1"])
        XCTAssertEqual(body["attachmentIds"] as? [String], ["att_1"])
        let lines = try XCTUnwrap(body["lines"] as? [[String: Any]])
        XCTAssertEqual(lines[0]["id"] as? String, "sdl_1")
        XCTAssertEqual(lines[0]["catalogItemId"] as? String, "item_1")
        XCTAssertEqual(lines[0]["purchaseOrderLineId"] as? String, "pol_1")
        XCTAssertEqual(lines[0]["purchaseReceiptLineId"] as? String, "prl_1")
        XCTAssertEqual(lines[0]["taxProfileId"] as? String, "tax_1")
    }

    func testEditRejectsNonDraftOrMissingUpdatePermissionBeforeNetworkCall() async throws {
        let confirmed = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "CONFIRMED", version: 7)
        ).data
        let client = SupplierDocumentMutationAPIClient(outcomes: [])
        let viewModel = makeEditViewModel(document: confirmed, client: client)

        let updated = await viewModel.save()

        XCTAssertNil(updated)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Solo puedes editar documentos en borrador cuando tienes el permiso correspondiente."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testEditVersionConflictRequiresDetailRefresh() async throws {
        let current = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .error(
                .server(
                    statusCode: 409,
                    code: "procurement_version_conflict",
                    message: "stale",
                    requestId: "req_conflict"
                )
            ),
        ])
        let viewModel = makeEditViewModel(document: current, client: client)

        let updated = await viewModel.save()

        XCTAssertNil(updated)
        XCTAssertEqual(
            viewModel.errorMessage,
            "El documento cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        )
    }

    func testConfirmUsesNumericVersionStableIdempotencyAndReturnedPayable() async throws {
        let draft = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(
                Self.envelopeJSON(
                    status: "CONFIRMED",
                    version: 8,
                    replayed: true,
                    includePayable: true
                )
            ),
        ])
        let viewModel = BusinessSupplierDocumentDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.supplierDocumentsConfirm,
                BusinessProcurementPermission.payablesView,
            ],
            supplierDocument: draft,
            supplierName: "Ferretería Uno",
            repository: BusinessProcurementAPIRepository(apiClient: client),
            actionIdempotencyKeys: Self.actionKeys
        )

        let first = await viewModel.perform(action: .confirm)
        let second = await viewModel.perform(action: .confirm)

        XCTAssertNil(first)
        XCTAssertEqual(second?.status, .confirmed)
        XCTAssertEqual(viewModel.payable?.id, "pay_1")
        XCTAssertEqual(viewModel.infoMessage, "El documento se recuperó de un intento anterior.")
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["sdoc-confirm-fixed", "sdoc-confirm-fixed"]
        )
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.supplierDocumentAction(
                .confirm,
                documentId: "sdoc_1"
            )
        )
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertFalse(body["expectedVersion"] is String)
        XCTAssertNil(body["reason"])
    }

    func testConfirmingResponseDoesNotClaimFinalPayableEffect() async throws {
        let draft = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "CONFIRMING", version: 8)),
        ])
        let viewModel = makeDetailViewModel(
            document: draft,
            permissions: [BusinessProcurementPermission.supplierDocumentsConfirm],
            client: client
        )

        let confirming = await viewModel.perform(action: .confirm)

        XCTAssertEqual(confirming?.status, .confirming)
        XCTAssertEqual(
            viewModel.infoMessage,
            "La confirmación está en proceso. Actualiza el detalle antes de asumir la creación de una cuenta por pagar."
        )
        XCTAssertNil(viewModel.payable)
    }

    func testCancelRequiresReasonAndUsesStableActionKey() async throws {
        let draft = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let client = SupplierDocumentMutationAPIClient(outcomes: [
            .response(Self.envelopeJSON(status: "CANCELLED", version: 8)),
        ])
        let viewModel = makeDetailViewModel(
            document: draft,
            permissions: [BusinessProcurementPermission.supplierDocumentsCancel],
            client: client
        )

        let missingReason = await viewModel.perform(action: .cancel, reason: "   ")
        XCTAssertNil(missingReason)
        XCTAssertEqual(viewModel.errorMessage, "Ingresa el motivo de cancelación.")
        XCTAssertTrue(client.capturedRequests.isEmpty)

        let cancelled = await viewModel.perform(
            action: .cancel,
            reason: " Documento duplicado "
        )

        XCTAssertEqual(cancelled?.status, .cancelled)
        XCTAssertEqual(viewModel.infoMessage, "Documento cancelado correctamente.")
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(
            request.headers[BusinessHeaders.idempotencyKey],
            "sdoc-cancel-fixed"
        )
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertEqual(body["reason"] as? String, "Documento duplicado")
    }

    func testActionAvailabilityUsesRealStateAndPermissions() throws {
        let draft = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "DRAFT", version: 7)
        ).data
        let confirmed = try Self.decodeEnvelope(
            Self.envelopeJSON(status: "CONFIRMED", version: 8)
        ).data
        let client = SupplierDocumentMutationAPIClient(outcomes: [])
        let permissions: Set<String> = [
            BusinessProcurementPermission.supplierDocumentsUpdate,
            BusinessProcurementPermission.supplierDocumentsConfirm,
            BusinessProcurementPermission.supplierDocumentsCancel,
        ]

        let draftViewModel = makeDetailViewModel(
            document: draft,
            permissions: permissions,
            client: client
        )
        XCTAssertTrue(draftViewModel.canEdit)
        XCTAssertTrue(draftViewModel.canConfirm)
        XCTAssertTrue(draftViewModel.canCancel)
        XCTAssertTrue(draftViewModel.hasAvailableActions)

        let confirmedViewModel = makeDetailViewModel(
            document: confirmed,
            permissions: permissions,
            client: client
        )
        XCTAssertFalse(confirmedViewModel.canEdit)
        XCTAssertFalse(confirmedViewModel.canConfirm)
        XCTAssertFalse(confirmedViewModel.canCancel)
        XCTAssertFalse(confirmedViewModel.hasAvailableActions)
    }

    func testListCreateRequiresPermissionAndConcreteBranch() {
        let client = SupplierDocumentMutationAPIClient(outcomes: [])
        let repository = BusinessProcurementAPIRepository(apiClient: client)
        let permissions: Set<String> = [
            BusinessProcurementPermission.supplierDocumentsCreate,
        ]

        let scoped = BusinessSupplierDocumentsViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            repository: repository
        )
        XCTAssertTrue(scoped.canCreate)

        let missingBranch = BusinessSupplierDocumentsViewModel(
            organizationId: "org_1",
            branchId: nil,
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            repository: repository
        )
        XCTAssertFalse(missingBranch.canCreate)
    }

    func testSupplierDocumentSurfacesExposeGuardedSharedFormAndEffects() throws {
        let viewSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierDocumentsView.swift"
        )
        let formSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierDocumentFormView.swift"
        )

        XCTAssertTrue(viewSource.contains("if viewModel.canCreate"))
        XCTAssertTrue(viewSource.contains("if viewModel.canEdit"))
        XCTAssertTrue(viewSource.contains("if viewModel.canConfirm"))
        XCTAssertTrue(viewSource.contains("if viewModel.canCancel"))
        XCTAssertTrue(viewSource.contains("BusinessSupplierDocumentFormView"))
        XCTAssertTrue(viewSource.contains("onDocumentChanged"))
        XCTAssertTrue(viewSource.contains("crea la cuenta por pagar exactamente una vez"))
        XCTAssertTrue(viewSource.contains("no modifica inventario"))
        XCTAssertTrue(formSource.contains("El backend valida impuestos y calcula los totales finales"))
        XCTAssertFalse(viewSource.contains("Text(document.id)"))
        XCTAssertFalse(viewSource.contains("Text(viewModel.supplierDocument.id)"))
    }

    private func makeCreateViewModel(
        permissions: Set<String> = [
            BusinessProcurementPermission.supplierDocumentsCreate,
        ],
        client: SupplierDocumentMutationAPIClient
    ) -> BusinessSupplierDocumentFormViewModel {
        BusinessSupplierDocumentFormViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            createIdempotencyKey: IdempotencyKey(
                rawValue: "supplier-document-create-fixed"
            )
        )
    }

    private func makeEditViewModel(
        document: BusinessProcurementSupplierDocumentResponse,
        client: SupplierDocumentMutationAPIClient
    ) -> BusinessSupplierDocumentFormViewModel {
        BusinessSupplierDocumentFormViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.supplierDocumentsUpdate,
            ],
            supplierDocument: document,
            supplierName: "Ferretería Uno",
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
    }

    private func makeDetailViewModel(
        document: BusinessProcurementSupplierDocumentResponse,
        permissions: Set<String>,
        client: SupplierDocumentMutationAPIClient
    ) -> BusinessSupplierDocumentDetailViewModel {
        BusinessSupplierDocumentDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            supplierDocument: document,
            supplierName: "Ferretería Uno",
            repository: BusinessProcurementAPIRepository(apiClient: client),
            actionIdempotencyKeys: Self.actionKeys
        )
    }

    private func prepareValidDraft(
        _ viewModel: BusinessSupplierDocumentFormViewModel
    ) {
        viewModel.selectedSupplierId = "sup_1"
        viewModel.documentNumber = "001-001-0000123"
        viewModel.documentDate = "2026-07-15"
        viewModel.dueDate = "2026-08-15"
        viewModel.currency = "USD"
        viewModel.lines = [
            BusinessSupplierDocumentLineDraft(
                kind: "EXPENSE",
                description: "Internet mensual",
                quantity: "1",
                unitCode: "unit",
                allowsDecimal: false,
                unitCost: "100.00",
                discountAmount: "0"
            ),
        ]
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
    ) throws -> BusinessProcurementSupplierDocumentEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementSupplierDocumentEnvelopeResponse.self,
            from: Data(json.utf8)
        )
    }

    private static let actionKeys = BusinessSupplierDocumentActionIdempotencyKeys(
        confirm: IdempotencyKey(rawValue: "sdoc-confirm-fixed"),
        cancel: IdempotencyKey(rawValue: "sdoc-cancel-fixed")
    )

    private static func envelopeJSON(
        status: String,
        version: Int,
        replayed: Bool = false,
        includePayable: Bool = false
    ) -> String {
        let payable = includePayable ? payableJSON : "null"
        return """
        {
          "data":\(documentJSON(status: status, version: version)),
          "payable":\(payable),
          "meta":{"requestId":"req_document","idempotencyReplayed":\(replayed)}
        }
        """
    }

    private static func documentJSON(status: String, version: Int) -> String {
        let confirmedAt = status == "CONFIRMED"
            ? #""2026-07-15T15:00:00Z""#
            : "null"
        let cancelledAt = status == "CANCELLED"
            ? #""2026-07-15T15:00:00Z""#
            : "null"
        let payableId = status == "CONFIRMED" ? #""pay_1""# : "null"
        return """
        {
          "id":"sdoc_1","branchId":"br_1","supplierId":"sup_1","documentType":"INVOICE","status":"\(status)",
          "documentNumber":"001-001-0000123","documentNumberNormalized":"0010010000123","accessKey":"ACCESS-123","authorizationNumber":"AUTH-123",
          "documentDate":"2026-07-15","dueDate":"2026-08-15","currency":"USD","purchaseOrderIds":["po_1"],"purchaseReceiptIds":["rcpt_1"],
          "lines":[\(documentLineJSON)],"subtotal":{"amount":"100.00","currency":"USD"},"discountTotal":{"amount":"0.00","currency":"USD"},
          "taxTotal":{"amount":"12.00","currency":"USD"},"total":{"amount":"112.00","currency":"USD"},
          "sourceTotals":{"total":{"amount":"112.00","currency":"USD"},"taxTotal":{"amount":"12.00","currency":"USD"}},
          "sourcePayment":{"amount":{"amount":"50.00","currency":"USD"},"method":"BANK_TRANSFER","paymentDate":"2026-07-15","reference":"TRX-001"},
          "payableAmount":{"amount":"62.00","currency":"USD"},"payableId":\(payableId),"attachmentIds":["att_1"],
          "accountingStatus":"READY_FOR_ACCOUNTING","notes":"Factura por reposición",
          "createdAt":"2026-07-15T14:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T15:00:00Z","updatedBy":"usr_1",
          "confirmedAt":\(confirmedAt),"confirmedBy":null,"cancelledAt":\(cancelledAt),"cancelledBy":null,"cancellationReason":null,"version":\(version)
        }
        """
    }

    private static var documentLineJSON: String {
        """
        {
          "id":"sdl_1","kind":"STOCK_ITEM","catalogItemId":"item_1",
          "catalogItemSnapshot":{"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"unit","taxProfileId":"tax_1","taxProfileVersion":3},
          "purchaseOrderLineId":"pol_1","purchaseReceiptLineId":"prl_1","descriptionSnapshot":"Router",
          "quantity":{"value":"2","unitCode":"unit","allowsDecimal":false},"unitCost":{"amount":"50.00","currency":"USD"},
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
}

private struct SupplierDocumentMutationRequest {
    let method: HTTPMethod
    let path: String
    let headers: [String: String]
    let body: Data?

    func jsonObject() throws -> [String: Any] {
        let body = try XCTUnwrap(body)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
    }
}

private final class SupplierDocumentMutationAPIClient: APIClient, @unchecked Sendable {
    enum Outcome {
        case response(String)
        case error(APIError)
    }

    private var outcomes: [Outcome]
    private(set) var capturedRequests: [SupplierDocumentMutationRequest] = []

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            SupplierDocumentMutationRequest(
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
