//
//  BusinessProcurementNavigationContractTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

final class BusinessProcurementNavigationContractTests: XCTestCase {
    func testSupplierNavigationRequiresPurchasesModuleAndViewPermission() {
        let noModule = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: [BusinessProcurementPermission.suppliersView]
        )
        let noPermission = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["sales.view"]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.suppliersView]
        )

        XCTAssertFalse(noModule.allows(BusinessProcurementPermission.suppliersView))
        XCTAssertFalse(noPermission.allows(BusinessProcurementPermission.suppliersView))
        XCTAssertTrue(allowed.allows(BusinessProcurementPermission.suppliersView))
    }

    func testPurchaseOrderNavigationRequiresPurchasesModuleAndViewPermission() {
        let noModule = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: [BusinessProcurementPermission.purchaseOrdersView]
        )
        let noPermission = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["sales.view"]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.purchaseOrdersView]
        )

        XCTAssertFalse(noModule.allows(BusinessProcurementPermission.purchaseOrdersView))
        XCTAssertFalse(noPermission.allows(BusinessProcurementPermission.purchaseOrdersView))
        XCTAssertTrue(allowed.allows(BusinessProcurementPermission.purchaseOrdersView))
    }

    func testPurchaseReceiptNavigationRequiresPurchasesModuleAndViewPermission() {
        let noModule = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: [BusinessProcurementPermission.purchaseReceiptsView]
        )
        let noPermission = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["sales.view"]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.purchaseReceiptsView]
        )

        XCTAssertFalse(noModule.allows(BusinessProcurementPermission.purchaseReceiptsView))
        XCTAssertFalse(noPermission.allows(BusinessProcurementPermission.purchaseReceiptsView))
        XCTAssertTrue(allowed.allows(BusinessProcurementPermission.purchaseReceiptsView))
    }

    func testSupplierDocumentNavigationRequiresPurchasesModuleAndViewPermission() {
        let noModule = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: [BusinessProcurementPermission.supplierDocumentsView]
        )
        let noPermission = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["sales.view"]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.supplierDocumentsView]
        )

        XCTAssertFalse(noModule.allows(BusinessProcurementPermission.supplierDocumentsView))
        XCTAssertFalse(noPermission.allows(BusinessProcurementPermission.supplierDocumentsView))
        XCTAssertTrue(allowed.allows(BusinessProcurementPermission.supplierDocumentsView))
    }

    func testPayableNavigationRequiresPurchasesModuleAndViewPermission() {
        let noModule = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: [BusinessProcurementPermission.payablesView]
        )
        let noPermission = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["sales.view"]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.payablesView]
        )

        XCTAssertFalse(noModule.allows(BusinessProcurementPermission.payablesView))
        XCTAssertFalse(noPermission.allows(BusinessProcurementPermission.payablesView))
        XCTAssertTrue(allowed.allows(BusinessProcurementPermission.payablesView))
    }

    func testSupplierPaymentNavigationRequiresPurchasesModuleAndViewPermission() {
        let noModule = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: [BusinessProcurementPermission.supplierPaymentsView]
        )
        let noPermission = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: ["sales.view"]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.supplierPaymentsView]
        )

        XCTAssertFalse(noModule.allows(BusinessProcurementPermission.supplierPaymentsView))
        XCTAssertFalse(noPermission.allows(BusinessProcurementPermission.supplierPaymentsView))
        XCTAssertTrue(allowed.allows(BusinessProcurementPermission.supplierPaymentsView))
    }

    func testSupplierStatementNavigationRequiresPurchasesModuleAndViewPermission() {
        let noModule = BusinessProcurementAccessPolicy(
            activeModules: [],
            effectivePermissions: [BusinessProcurementPermission.supplierStatementsView]
        )
        let noPermission = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.suppliersView]
        )
        let allowed = BusinessProcurementAccessPolicy(
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.supplierStatementsView]
        )

        XCTAssertFalse(noModule.allows(BusinessProcurementPermission.supplierStatementsView))
        XCTAssertFalse(noPermission.allows(BusinessProcurementPermission.supplierStatementsView))
        XCTAssertTrue(allowed.allows(BusinessProcurementPermission.supplierStatementsView))
    }

    func testLiveContainerWiresTheProcurementAPIRepository() throws {
        let source = try sourceText(at: "Nexo Business/app/AppContainer.swift")

        XCTAssertTrue(source.contains("let procurementRepository: BusinessProcurementRepository"))
        XCTAssertTrue(source.contains("procurementRepository: BusinessProcurementRepository"))
        XCTAssertTrue(source.contains("BusinessProcurementAPIRepository(apiClient: apiClient)"))
    }

    func testBusinessHubLinksSupplierDirectoryThroughTheAcceptedPolicy() throws {
        let source = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(source.contains("title: \"Compras\""))
        XCTAssertTrue(source.contains("title: \"Proveedores\""))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.suppliersView"))
        XCTAssertTrue(source.contains("BusinessProcurementAccessPolicy("))
        XCTAssertTrue(source.contains("BusinessSuppliersView("))
        XCTAssertTrue(source.contains("BusinessSuppliersViewModel("))
        XCTAssertTrue(source.contains("repository: container.procurementRepository"))
        XCTAssertTrue(source.contains("Módulo no activo"))
        XCTAssertTrue(source.contains("Sin permiso"))
    }

    func testBusinessHubLinksPurchaseOrdersThroughTheAcceptedPolicy() throws {
        let source = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(source.contains("title: \"Órdenes de compra\""))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.purchaseOrdersView"))
        XCTAssertTrue(source.contains("BusinessPurchaseOrdersView("))
        XCTAssertTrue(source.contains("BusinessPurchaseOrdersViewModel("))
        XCTAssertTrue(source.contains("branchId: branchId"))
        XCTAssertTrue(source.contains("activeModules: context.activeModules"))
        XCTAssertTrue(source.contains("effectivePermissions: permissions"))
        XCTAssertTrue(source.contains("repository: container.procurementRepository"))
    }

    func testBusinessHubLinksPurchaseReceiptsThroughTheAcceptedPolicy() throws {
        let source = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(source.contains("title: \"Recepciones de compra\""))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.purchaseReceiptsView"))
        XCTAssertTrue(source.contains("BusinessPurchaseReceiptsView("))
        XCTAssertTrue(source.contains("BusinessPurchaseReceiptsViewModel("))
        XCTAssertTrue(source.contains("branchId: branchId"))
        XCTAssertTrue(source.contains("activeModules: context.activeModules"))
        XCTAssertTrue(source.contains("effectivePermissions: permissions"))
        XCTAssertTrue(source.contains("repository: container.procurementRepository"))
        XCTAssertTrue(source.contains("subtitle: \"Recepción y evidencia\""))
    }

    func testBusinessHubLinksSupplierDocumentsThroughTheAcceptedPolicy() throws {
        let source = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(source.contains("title: \"Documentos de proveedor\""))
        XCTAssertTrue(source.contains("subtitle: \"Cargos y saldos\""))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.supplierDocumentsView"))
        XCTAssertTrue(source.contains("BusinessSupplierDocumentsView("))
        XCTAssertTrue(source.contains("BusinessSupplierDocumentsViewModel("))
        XCTAssertTrue(source.contains("branchId: branchId"))
        XCTAssertTrue(source.contains("activeModules: context.activeModules"))
        XCTAssertTrue(source.contains("effectivePermissions: permissions"))
        XCTAssertTrue(source.contains("repository: container.procurementRepository"))
    }

    func testBusinessHubLinksPayablesThroughTheAcceptedPolicy() throws {
        let source = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(source.contains("title: \"Cuentas por pagar\""))
        XCTAssertTrue(source.contains("subtitle: \"Saldos y vencimientos\""))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.payablesView"))
        XCTAssertTrue(source.contains("BusinessPayablesView("))
        XCTAssertTrue(source.contains("BusinessPayablesViewModel("))
        XCTAssertTrue(source.contains("branchId: branchId"))
        XCTAssertTrue(source.contains("activeModules: context.activeModules"))
        XCTAssertTrue(source.contains("effectivePermissions: permissions"))
        XCTAssertTrue(source.contains("repository: container.procurementRepository"))
    }

    func testBusinessHubLinksSupplierPaymentsThroughTheAcceptedPolicy() throws {
        let source = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(source.contains("title: \"Pagos a proveedores\""))
        XCTAssertTrue(source.contains("subtitle: \"Registro y aplicaciones\""))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.supplierPaymentsView"))
        XCTAssertTrue(source.contains("BusinessSupplierPaymentsView("))
        XCTAssertTrue(source.contains("BusinessSupplierPaymentsViewModel("))
        XCTAssertTrue(source.contains("branchId: branchId"))
        XCTAssertTrue(source.contains("activeModules: context.activeModules"))
        XCTAssertTrue(source.contains("effectivePermissions: permissions"))
        XCTAssertTrue(source.contains("repository: container.procurementRepository"))
    }

    func testSupplierDetailLinksStatementWithActiveContextAndExactPermission() throws {
        let businessSource = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )
        let supplierSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSuppliersView.swift"
        )

        XCTAssertTrue(businessSource.contains("BusinessSuppliersView("))
        XCTAssertTrue(businessSource.contains("branchId: branchId"))
        XCTAssertTrue(supplierSource.contains("Finanzas del proveedor"))
        XCTAssertTrue(supplierSource.contains("Text(\"Estado de cuenta\")"))
        XCTAssertTrue(supplierSource.contains("BusinessProcurementPermission.supplierStatementsView"))
        XCTAssertTrue(supplierSource.contains("BusinessSupplierStatementView("))
        XCTAssertTrue(supplierSource.contains("BusinessSupplierStatementViewModel("))
        XCTAssertTrue(supplierSource.contains("branchId: branchId"))
        XCTAssertTrue(supplierSource.contains("supplierId: viewModel.supplier.id"))
        XCTAssertTrue(supplierSource.contains("supplierName: viewModel.supplier.businessDisplayName"))
        XCTAssertTrue(supplierSource.contains("currency: viewModel.supplier.defaultCurrency"))
        XCTAssertTrue(supplierSource.contains("activeModules: viewModel.accessPolicy.activeModules"))
        XCTAssertTrue(supplierSource.contains("effectivePermissions: viewModel.accessPolicy.effectivePermissions"))
        XCTAssertTrue(supplierSource.contains("repository: viewModel.repository"))
        XCTAssertFalse(supplierSource.contains("downloadSupplierStatementCSV"))
        XCTAssertFalse(supplierSource.contains("BusinessProcurementPermission.supplierStatementsExport"))
    }

    func testPurchaseOrderDetailLinksOnlySourceBoundAttachmentEvidence() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseOrdersView.swift"
        )

        XCTAssertTrue(source.contains("!viewModel.purchaseOrder.attachmentIds.isEmpty"))
        XCTAssertTrue(source.contains("viewModel.canViewCosts"))
        XCTAssertTrue(source.contains("BusinessProcurementAttachmentsView("))
        XCTAssertTrue(source.contains("BusinessProcurementAttachmentsViewModel("))
        XCTAssertTrue(source.contains("sourceType: .purchaseOrder"))
        XCTAssertTrue(source.contains("sourceId: viewModel.purchaseOrder.id"))
        XCTAssertTrue(source.contains("sourceVersion: viewModel.purchaseOrder.version"))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.attachmentsUpload"))
        XCTAssertTrue(source.contains("sourceDisplayName: \"Orden \\(viewModel.purchaseOrder.orderNumber)\""))
        XCTAssertTrue(source.contains("attachmentIds: viewModel.purchaseOrder.attachmentIds"))
        XCTAssertFalse(source.contains("attachmentIds: [viewModel.purchaseOrder.id]"))
        XCTAssertFalse(source.contains("sourceDisplayName: viewModel.purchaseOrder.id"))
        assertAttachmentDestinationUsesActiveContext(source)
    }

    func testPurchaseReceiptDetailLinksOnlySourceBoundAttachmentEvidence() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessPurchaseReceiptsView.swift"
        )

        XCTAssertTrue(source.contains("!viewModel.purchaseReceipt.attachmentIds.isEmpty"))
        XCTAssertTrue(source.contains("viewModel.canView"))
        XCTAssertTrue(source.contains("BusinessProcurementAttachmentsView("))
        XCTAssertTrue(source.contains("sourceType: .purchaseReceipt"))
        XCTAssertTrue(source.contains("sourceId: viewModel.purchaseReceipt.id"))
        XCTAssertTrue(source.contains("sourceVersion: viewModel.purchaseReceipt.version"))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.attachmentsUpload"))
        XCTAssertTrue(source.contains("sourceDisplayName: \"Recepción \\(viewModel.purchaseReceipt.receiptNumber)\""))
        XCTAssertTrue(source.contains("attachmentIds: viewModel.purchaseReceipt.attachmentIds"))
        XCTAssertFalse(source.contains("attachmentIds: [viewModel.purchaseReceipt.id]"))
        XCTAssertFalse(source.contains("sourceDisplayName: viewModel.purchaseReceipt.id"))
        assertAttachmentDestinationUsesActiveContext(source)
    }

    func testSupplierDocumentDetailLinksOnlySourceBoundAttachmentEvidence() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierDocumentsView.swift"
        )

        XCTAssertTrue(source.contains("!viewModel.supplierDocument.attachmentIds.isEmpty"))
        XCTAssertTrue(source.contains("viewModel.canView"))
        XCTAssertTrue(source.contains("BusinessProcurementAttachmentsView("))
        XCTAssertTrue(source.contains("sourceType: .supplierDocument"))
        XCTAssertTrue(source.contains("sourceId: viewModel.supplierDocument.id"))
        XCTAssertTrue(source.contains("sourceVersion: viewModel.supplierDocument.version"))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.attachmentsUpload"))
        XCTAssertTrue(source.contains("sourceDisplayName: \"Documento \\(viewModel.supplierDocument.documentNumber)\""))
        XCTAssertTrue(source.contains("attachmentIds: viewModel.supplierDocument.attachmentIds"))
        XCTAssertFalse(source.contains("attachmentIds: [viewModel.supplierDocument.id]"))
        XCTAssertFalse(source.contains("sourceDisplayName: viewModel.supplierDocument.id"))
        assertAttachmentDestinationUsesActiveContext(source)
    }

    func testSupplierPaymentDetailLinksOnlySourceBoundSensitiveEvidence() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierPaymentsView.swift"
        )

        XCTAssertTrue(source.contains("if let attachmentIds = viewModel.supplierPayment.attachmentIds"))
        XCTAssertTrue(source.contains("!attachmentIds.isEmpty"))
        XCTAssertTrue(source.contains("viewModel.canViewSensitiveEvidence"))
        XCTAssertTrue(source.contains("BusinessProcurementAttachmentsView("))
        XCTAssertTrue(source.contains("sourceType: .supplierPayment"))
        XCTAssertTrue(source.contains("sourceId: viewModel.supplierPayment.id"))
        XCTAssertTrue(source.contains("sourceVersion: viewModel.supplierPayment.version"))
        XCTAssertTrue(source.contains("BusinessProcurementPermission.attachmentsUpload"))
        XCTAssertTrue(source.contains("sourceDisplayName: \"Pago \\(viewModel.supplierPayment.paymentNumber)\""))
        XCTAssertTrue(source.contains("attachmentIds: attachmentIds"))
        XCTAssertFalse(source.contains("attachmentIds: [viewModel.supplierPayment.id]"))
        XCTAssertFalse(source.contains("sourceDisplayName: viewModel.supplierPayment.id"))
        assertAttachmentDestinationUsesActiveContext(source)
    }

    func testSupplierDetailDoesNotInventAttachmentReferencesWithoutAStableSourceContract() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSuppliersView.swift"
        )
        let contract = try sourceText(
            at: "Nexo Business/features/procurement/domain/BusinessProcurementContract.swift"
        )

        XCTAssertFalse(source.contains("sourceType: .supplier"))
        XCTAssertFalse(source.contains("attachmentIds: []"))
        XCTAssertTrue(contract.contains("attachmentCollectionRouteExists = false"))
    }

    func testAttachmentDestinationOwnsDownloadStateAndHasNoGlobalHubEntry() throws {
        let attachmentSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessProcurementAttachmentsView.swift"
        )
        let hubSource = try sourceText(
            at: "Nexo Business/features/business/presentation/BusinessView.swift"
        )

        XCTAssertTrue(attachmentSource.contains("@State private var viewModel: BusinessProcurementAttachmentsViewModel"))
        XCTAssertTrue(attachmentSource.contains("_viewModel = State(initialValue: viewModel)"))
        XCTAssertFalse(hubSource.contains("BusinessProcurementAttachmentsView("))
        XCTAssertFalse(hubSource.contains("title: \"Adjuntos\""))
        XCTAssertFalse(hubSource.contains("title: \"Evidencia\""))
    }

    private func assertAttachmentDestinationUsesActiveContext(
        _ source: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(source.contains("organizationId: viewModel.organizationId"), file: file, line: line)
        XCTAssertTrue(source.contains("activeModules: viewModel.accessPolicy.activeModules"), file: file, line: line)
        XCTAssertTrue(source.contains("effectivePermissions: viewModel.accessPolicy.effectivePermissions"), file: file, line: line)
        XCTAssertTrue(source.contains("repository: viewModel.repository"), file: file, line: line)
        XCTAssertTrue(source.contains(".onDisappear"), file: file, line: line)
        XCTAssertTrue(source.contains("Task { await refreshDetail() }"), file: file, line: line)
        XCTAssertTrue(source.contains("Text(\"Ver evidencia adjunta\")"), file: file, line: line)
    }

    private func sourceText(at repositoryRelativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent(repositoryRelativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
