//
//  BusinessProcurementContract.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation

extension ModuleCode {
    static let modulePurchases: ModuleCode = "module.purchases"
}

enum BusinessProcurementRoutes {
    static let base = "/api/v1/business/procurement"

    static let suppliers = "\(base)/suppliers"
    static let purchaseOrders = "\(base)/purchase-orders"
    static let purchaseReceipts = "\(base)/purchase-receipts"
    static let supplierDocuments = "\(base)/supplier-documents"
    static let payables = "\(base)/payables"
    static let payableAging = "\(payables)/aging"
    static let supplierPayments = "\(base)/supplier-payments"
    static let attachments = "\(base)/attachments"

    static func supplier(_ supplierId: String) -> String {
        "\(suppliers)/\(supplierId)"
    }

    static func supplierStatus(_ supplierId: String) -> String {
        "\(supplier(supplierId))/status"
    }

    static func purchaseOrder(_ orderId: String) -> String {
        "\(purchaseOrders)/\(orderId)"
    }

    static func purchaseOrderAction(_ action: BusinessPurchaseOrderAction, orderId: String) -> String {
        "\(purchaseOrder(orderId))/\(action.rawValue)"
    }

    static func purchaseReceipt(_ receiptId: String) -> String {
        "\(purchaseReceipts)/\(receiptId)"
    }

    static func purchaseReceiptAction(_ action: BusinessPurchaseReceiptAction, receiptId: String) -> String {
        "\(purchaseReceipt(receiptId))/\(action.rawValue)"
    }

    static func supplierDocument(_ documentId: String) -> String {
        "\(supplierDocuments)/\(documentId)"
    }

    static func supplierDocumentAction(_ action: BusinessSupplierDocumentAction, documentId: String) -> String {
        "\(supplierDocument(documentId))/\(action.rawValue)"
    }

    static func payable(_ payableId: String) -> String {
        "\(payables)/\(payableId)"
    }

    static func supplierPayment(_ paymentId: String) -> String {
        "\(supplierPayments)/\(paymentId)"
    }

    static func voidSupplierPayment(_ paymentId: String) -> String {
        "\(supplierPayment(paymentId))/void"
    }

    static func supplierStatement(_ supplierId: String) -> String {
        "\(supplier(supplierId))/statement"
    }

    static func supplierStatementCSV(_ supplierId: String) -> String {
        "\(supplier(supplierId))/statement.csv"
    }

    static func attachment(_ attachmentId: String) -> String {
        "\(attachments)/\(attachmentId)"
    }
}

enum BusinessProcurementPermission {
    static let suppliersView = "suppliers.view"
    static let suppliersSensitiveView = "suppliers.sensitive_view"
    static let suppliersCreate = "suppliers.create"
    static let suppliersUpdate = "suppliers.update"
    static let suppliersStatusManage = "suppliers.status_manage"

    static let purchaseOrdersView = "purchase_orders.view"
    static let purchaseOrdersCostView = "purchase_orders.cost_view"
    static let purchaseOrdersCreate = "purchase_orders.create"
    static let purchaseOrdersUpdate = "purchase_orders.update"
    static let purchaseOrdersSend = "purchase_orders.send"
    static let purchaseOrdersCancel = "purchase_orders.cancel"
    static let purchaseOrdersClose = "purchase_orders.close"

    static let purchaseReceiptsView = "purchase_receipts.view"
    static let purchaseReceiptsCreate = "purchase_receipts.create"
    static let purchaseReceiptsUpdate = "purchase_receipts.update"
    static let purchaseReceiptsConfirm = "purchase_receipts.confirm"
    static let purchaseReceiptsCancel = "purchase_receipts.cancel"

    static let supplierDocumentsView = "supplier_documents.view"
    static let supplierDocumentsCreate = "supplier_documents.create"
    static let supplierDocumentsUpdate = "supplier_documents.update"
    static let supplierDocumentsConfirm = "supplier_documents.confirm"
    static let supplierDocumentsCancel = "supplier_documents.cancel"

    static let payablesView = "payables.view"
    static let payablesAgingView = "payables.aging_view"

    static let supplierPaymentsView = "supplier_payments.view"
    static let supplierPaymentsSensitiveView = "supplier_payments.sensitive_view"
    static let supplierPaymentsCreate = "supplier_payments.create"
    static let supplierPaymentsVoid = "supplier_payments.void"

    static let supplierStatementsView = "supplier_statements.view"
    static let supplierStatementsExport = "supplier_statements.export"

    static let attachmentsUpload = "procurement.attachments_upload"
    static let attachmentsDelete = "procurement.attachments_delete"
    static let auditView = "procurement.audit_view"

    static let stepUpRequired: Set<String> = [
        supplierPaymentsCreate,
        supplierPaymentsVoid,
        supplierStatementsExport,
    ]

    static let surfaceEntry: Set<String> = [
        suppliersView,
        suppliersCreate,
        purchaseOrdersView,
        purchaseOrdersCreate,
        purchaseReceiptsView,
        purchaseReceiptsCreate,
        supplierDocumentsView,
        supplierDocumentsCreate,
        payablesView,
        payablesAgingView,
        supplierPaymentsView,
        supplierPaymentsCreate,
        supplierStatementsView,
    ]
}

enum BusinessSupplierStatus: String, Codable, CaseIterable, Sendable {
    case active = "ACTIVE"
    case inactive = "INACTIVE"
    case blocked = "BLOCKED"
}

enum BusinessPurchaseOrderStatus: String, Codable, CaseIterable, Sendable {
    case draft = "DRAFT"
    case sent = "SENT"
    case partiallyReceived = "PARTIALLY_RECEIVED"
    case received = "RECEIVED"
    case cancelled = "CANCELLED"
    case closed = "CLOSED"
}

enum BusinessPurchaseReceiptStatus: String, Codable, CaseIterable, Sendable {
    case draft = "DRAFT"
    case confirming = "CONFIRMING"
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
}

enum BusinessSupplierDocumentStatus: String, Codable, CaseIterable, Sendable {
    case draft = "DRAFT"
    case confirming = "CONFIRMING"
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
}

enum BusinessSupplierPaymentStatus: String, Codable, CaseIterable, Sendable {
    case processing = "PROCESSING"
    case recorded = "RECORDED"
    case voiding = "VOIDING"
    case voided = "VOIDED"
}

enum BusinessPayableEffectiveStatus: String, Codable, CaseIterable, Sendable {
    case open = "OPEN"
    case partiallyPaid = "PARTIALLY_PAID"
    case paid = "PAID"
    case overdue = "OVERDUE"
    case cancelled = "CANCELLED"
}

enum BusinessPurchaseOrderAction: String, Codable, CaseIterable, Sendable {
    case send
    case cancel
    case close
}

enum BusinessPurchaseReceiptAction: String, Codable, CaseIterable, Sendable {
    case confirm
    case cancel
}

enum BusinessSupplierDocumentAction: String, Codable, CaseIterable, Sendable {
    case confirm
    case cancel
}

enum BusinessProcurementAttachmentSourceType: String, Codable, CaseIterable, Sendable {
    case supplier = "SUPPLIER"
    case purchaseOrder = "PURCHASE_ORDER"
    case purchaseReceipt = "PURCHASE_RECEIPT"
    case supplierDocument = "SUPPLIER_DOCUMENT"
    case supplierPayment = "SUPPLIER_PAYMENT"
}

enum BusinessProcurementAttachmentMediaType: String, Codable, CaseIterable, Sendable {
    case pdf = "application/pdf"
    case jpeg = "image/jpeg"
    case png = "image/png"
}

struct BusinessProcurementAccessPolicy: Equatable, Sendable {
    let activeModules: Set<ModuleCode>
    let effectivePermissions: Set<String>

    init(activeModules: Set<ModuleCode>, effectivePermissions: Set<String>) {
        self.activeModules = activeModules
        self.effectivePermissions = effectivePermissions
    }

    var isModuleActive: Bool {
        activeModules.contains(.modulePurchases)
    }

    var canEnterProcurement: Bool {
        isModuleActive && BusinessProcurementPermission.surfaceEntry.contains { hasPermission($0) }
    }

    func hasPermission(_ permission: String) -> Bool {
        effectivePermissions.contains("*") || effectivePermissions.contains(permission)
    }

    func allows(_ permission: String) -> Bool {
        isModuleActive && hasPermission(permission)
    }

    func requiresStepUp(_ permission: String) -> Bool {
        BusinessProcurementPermission.stepUpRequired.contains(permission)
    }

    var canCreateSupplier: Bool {
        allows(BusinessProcurementPermission.suppliersCreate)
    }

    var canCreatePurchaseOrder: Bool {
        allows(BusinessProcurementPermission.purchaseOrdersCreate)
    }

    func canEditPurchaseOrder(status: BusinessPurchaseOrderStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.purchaseOrdersUpdate)
    }

    func canSendPurchaseOrder(status: BusinessPurchaseOrderStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.purchaseOrdersSend)
    }

    func canCancelPurchaseOrder(status: BusinessPurchaseOrderStatus) -> Bool {
        [.draft, .sent].contains(status) && allows(BusinessProcurementPermission.purchaseOrdersCancel)
    }

    func canClosePurchaseOrder(status: BusinessPurchaseOrderStatus) -> Bool {
        [.partiallyReceived, .received].contains(status) && allows(BusinessProcurementPermission.purchaseOrdersClose)
    }

    func canReceivePurchaseOrder(status: BusinessPurchaseOrderStatus) -> Bool {
        [.sent, .partiallyReceived].contains(status) && allows(BusinessProcurementPermission.purchaseReceiptsCreate)
    }

    func canEditPurchaseReceipt(status: BusinessPurchaseReceiptStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.purchaseReceiptsUpdate)
    }

    func canConfirmPurchaseReceipt(status: BusinessPurchaseReceiptStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.purchaseReceiptsConfirm)
    }

    func canCancelPurchaseReceipt(status: BusinessPurchaseReceiptStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.purchaseReceiptsCancel)
    }

    func canEditSupplierDocument(status: BusinessSupplierDocumentStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.supplierDocumentsUpdate)
    }

    func canConfirmSupplierDocument(status: BusinessSupplierDocumentStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.supplierDocumentsConfirm)
    }

    func canCancelSupplierDocument(status: BusinessSupplierDocumentStatus) -> Bool {
        status == .draft && allows(BusinessProcurementPermission.supplierDocumentsCancel)
    }

    var canRecordSupplierPayment: Bool {
        allows(BusinessProcurementPermission.supplierPaymentsCreate)
    }

    func canVoidSupplierPayment(status: BusinessSupplierPaymentStatus) -> Bool {
        status == .recorded && allows(BusinessProcurementPermission.supplierPaymentsVoid)
    }

    func canAllocate(_ status: BusinessPayableEffectiveStatus) -> Bool {
        [.open, .partiallyPaid, .overdue].contains(status) && canRecordSupplierPayment
    }
}

enum BusinessProcurementContractDecision {
    static let version = "27R.M.2.v1"
    static let backendOwnsAuthoritativeTotals = true
    static let attachmentCollectionRouteExists = false
    static let inventClientStepUpRoute = false
    static let maximumAttachmentBytes = 10 * 1024 * 1024
}
