//
//  BusinessProcurementContractTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessProcurementContractTests: XCTestCase {
    func testBusinessRoutesMatchAcceptedBackendContract() {
        XCTAssertEqual(BusinessProcurementRoutes.suppliers, "/api/v1/business/procurement/suppliers")
        XCTAssertEqual(BusinessProcurementRoutes.supplier("sup_1"), "/api/v1/business/procurement/suppliers/sup_1")
        XCTAssertEqual(BusinessProcurementRoutes.supplierStatus("sup_1"), "/api/v1/business/procurement/suppliers/sup_1/status")
        XCTAssertEqual(BusinessProcurementRoutes.purchaseOrder("po_1"), "/api/v1/business/procurement/purchase-orders/po_1")
        XCTAssertEqual(
            BusinessProcurementRoutes.purchaseOrderAction(.send, orderId: "po_1"),
            "/api/v1/business/procurement/purchase-orders/po_1/send"
        )
        XCTAssertEqual(
            BusinessProcurementRoutes.purchaseReceiptAction(.confirm, receiptId: "prcpt_1"),
            "/api/v1/business/procurement/purchase-receipts/prcpt_1/confirm"
        )
        XCTAssertEqual(
            BusinessProcurementRoutes.supplierDocumentAction(.cancel, documentId: "sdoc_1"),
            "/api/v1/business/procurement/supplier-documents/sdoc_1/cancel"
        )
        XCTAssertEqual(BusinessProcurementRoutes.payableAging, "/api/v1/business/procurement/payables/aging")
        XCTAssertEqual(
            BusinessProcurementRoutes.voidSupplierPayment("spay_1"),
            "/api/v1/business/procurement/supplier-payments/spay_1/void"
        )
        XCTAssertEqual(
            BusinessProcurementRoutes.supplierStatement("sup_1"),
            "/api/v1/business/procurement/suppliers/sup_1/statement"
        )
        XCTAssertEqual(
            BusinessProcurementRoutes.supplierStatementCSV("sup_1"),
            "/api/v1/business/procurement/suppliers/sup_1/statement.csv"
        )
        XCTAssertEqual(
            BusinessProcurementRoutes.attachment("patt_1"),
            "/api/v1/business/procurement/attachments/patt_1"
        )
    }

    func testPurchasesModuleIsMandatoryEvenWithWildcardPermission() {
        let blocked = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: ["*"]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["*"]
        )

        XCTAssertFalse(blocked.canEnterProcurement)
        XCTAssertFalse(blocked.canCreatePurchaseOrder)
        XCTAssertTrue(allowed.canEnterProcurement)
        XCTAssertTrue(allowed.canCreatePurchaseOrder)
    }

    func testEntryRequiresAtLeastOneProcurementSurfacePermission() {
        let unrelated = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["sales.view"]
        )
        let viewer = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.payablesView]
        )

        XCTAssertFalse(unrelated.canEnterProcurement)
        XCTAssertTrue(viewer.canEnterProcurement)
    }

    func testPurchaseOrderActionsFollowBackendStateAndPermission() {
        let policy = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.purchaseOrdersUpdate,
                BusinessProcurementPermission.purchaseOrdersSend,
                BusinessProcurementPermission.purchaseOrdersCancel,
                BusinessProcurementPermission.purchaseOrdersClose,
                BusinessProcurementPermission.purchaseReceiptsCreate,
            ]
        )

        XCTAssertTrue(policy.canEditPurchaseOrder(status: .draft))
        XCTAssertTrue(policy.canSendPurchaseOrder(status: .draft))
        XCTAssertTrue(policy.canCancelPurchaseOrder(status: .sent))
        XCTAssertFalse(policy.canCancelPurchaseOrder(status: .partiallyReceived))
        XCTAssertTrue(policy.canReceivePurchaseOrder(status: .sent))
        XCTAssertTrue(policy.canReceivePurchaseOrder(status: .partiallyReceived))
        XCTAssertFalse(policy.canReceivePurchaseOrder(status: .received))
        XCTAssertTrue(policy.canClosePurchaseOrder(status: .partiallyReceived))
        XCTAssertTrue(policy.canClosePurchaseOrder(status: .received))
        XCTAssertFalse(policy.canClosePurchaseOrder(status: .sent))
    }

    func testReceiptAndDocumentMutationsAreDraftOnly() {
        let policy = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.purchaseReceiptsUpdate,
                BusinessProcurementPermission.purchaseReceiptsConfirm,
                BusinessProcurementPermission.purchaseReceiptsCancel,
                BusinessProcurementPermission.supplierDocumentsUpdate,
                BusinessProcurementPermission.supplierDocumentsConfirm,
                BusinessProcurementPermission.supplierDocumentsCancel,
            ]
        )

        XCTAssertTrue(policy.canEditPurchaseReceipt(status: .draft))
        XCTAssertTrue(policy.canConfirmPurchaseReceipt(status: .draft))
        XCTAssertTrue(policy.canCancelPurchaseReceipt(status: .draft))
        XCTAssertFalse(policy.canEditPurchaseReceipt(status: .confirming))
        XCTAssertFalse(policy.canConfirmPurchaseReceipt(status: .confirmed))
        XCTAssertFalse(policy.canCancelPurchaseReceipt(status: .cancelled))

        XCTAssertTrue(policy.canEditSupplierDocument(status: .draft))
        XCTAssertTrue(policy.canConfirmSupplierDocument(status: .draft))
        XCTAssertTrue(policy.canCancelSupplierDocument(status: .draft))
        XCTAssertFalse(policy.canEditSupplierDocument(status: .confirming))
        XCTAssertFalse(policy.canConfirmSupplierDocument(status: .confirmed))
        XCTAssertFalse(policy.canCancelSupplierDocument(status: .cancelled))
    }

    func testPaymentsUsePayableStateAndStepUpContract() {
        let policy = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.supplierPaymentsCreate,
                BusinessProcurementPermission.supplierPaymentsVoid,
            ]
        )

        XCTAssertTrue(policy.canRecordSupplierPayment)
        XCTAssertTrue(policy.canAllocate(.open))
        XCTAssertTrue(policy.canAllocate(.partiallyPaid))
        XCTAssertTrue(policy.canAllocate(.overdue))
        XCTAssertFalse(policy.canAllocate(.paid))
        XCTAssertTrue(policy.canVoidSupplierPayment(status: .recorded))
        XCTAssertFalse(policy.canVoidSupplierPayment(status: .processing))
        XCTAssertFalse(policy.canVoidSupplierPayment(status: .voided))
        XCTAssertTrue(policy.requiresStepUp(BusinessProcurementPermission.supplierPaymentsCreate))
        XCTAssertTrue(policy.requiresStepUp(BusinessProcurementPermission.supplierPaymentsVoid))
        XCTAssertTrue(policy.requiresStepUp(BusinessProcurementPermission.supplierStatementsExport))
        XCTAssertFalse(policy.requiresStepUp(BusinessProcurementPermission.purchaseOrdersCreate))
    }

    func testContractDecisionsDoNotInventUnsupportedClientTruth() {
        XCTAssertEqual(BusinessProcurementContractDecision.version, "27R.M.2.v1")
        XCTAssertTrue(BusinessProcurementContractDecision.backendOwnsAuthoritativeTotals)
        XCTAssertFalse(BusinessProcurementContractDecision.attachmentCollectionRouteExists)
        XCTAssertFalse(BusinessProcurementContractDecision.inventClientStepUpRoute)
        XCTAssertEqual(BusinessProcurementContractDecision.maximumAttachmentBytes, 10_485_760)
    }
}
