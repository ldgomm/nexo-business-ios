//
//  BusinessProcurementModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation

struct BusinessProcurementResponseMeta: Codable, Equatable, Sendable {
    let requestId: String?
    let idempotencyReplayed: Bool?
}

struct BusinessProcurementMoneyResponse: Codable, Equatable, Sendable {
    let amount: String
    let currency: String
}

struct BusinessProcurementQuantityResponse: Codable, Equatable, Sendable {
    let value: String
    let unitCode: String
    let allowsDecimal: Bool
}

struct BusinessProcurementPurchaseTaxResponse: Codable, Equatable, Sendable {
    let taxCode: String?
    let rateCode: String?
    let rate: String
    let taxableBase: BusinessProcurementMoneyResponse
    let amount: BusinessProcurementMoneyResponse
}

struct BusinessProcurementPurchaseItemSnapshotResponse: Codable, Equatable, Sendable {
    let catalogItemId: String
    let localName: String
    let sku: String?
    let unitCode: String
    let taxProfileId: String
    let taxProfileVersion: Int64
}

// MARK: - Suppliers

struct BusinessProcurementSupplierContactRequest: Codable, Equatable, Sendable {
    let id: String?
    let name: String
    let role: String?
    let email: String?
    let phone: String?
    let isPrimary: Bool
    let notes: String?
}

struct BusinessProcurementPaymentTermsRequest: Codable, Equatable, Sendable {
    let mode: String
    let netDays: Int?
    let label: String?
    let notes: String?

    init(
        mode: String = "IMMEDIATE",
        netDays: Int? = nil,
        label: String? = nil,
        notes: String? = nil
    ) {
        self.mode = mode
        self.netDays = netDays
        self.label = label
        self.notes = notes
    }
}

struct BusinessProcurementSupplierWriteRequest: Codable, Equatable, Sendable {
    let legalName: String
    let tradeName: String?
    let identificationType: String?
    let identificationNumber: String?
    let email: String?
    let phone: String?
    let address: String?
    let categories: [String]
    let contacts: [BusinessProcurementSupplierContactRequest]
    let paymentTerms: BusinessProcurementPaymentTermsRequest
    let defaultCurrency: String?
    let notes: String?
    let expectedVersion: Int64?
}

struct BusinessProcurementSupplierStatusRequest: Codable, Equatable, Sendable {
    let status: BusinessSupplierStatus
    let reason: String
    let expectedVersion: Int64?
}

struct BusinessProcurementSupplierContactResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let role: String?
    let email: String?
    let phone: String?
    let isPrimary: Bool
    let notes: String?
}

struct BusinessProcurementPaymentTermsResponse: Codable, Equatable, Sendable {
    let mode: String
    let netDays: Int?
    let label: String?
    let notes: String?
}

struct BusinessProcurementSupplierResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let legalName: String
    let tradeName: String?
    let identificationType: String?
    let identificationNumber: String?
    let email: String?
    let phone: String?
    let address: String?
    let categories: [String]
    let contacts: [BusinessProcurementSupplierContactResponse]?
    let paymentTerms: BusinessProcurementPaymentTermsResponse
    let defaultCurrency: String
    let status: BusinessSupplierStatus
    let notes: String?
    let createdAt: String
    let createdBy: String
    let updatedAt: String
    let updatedBy: String
    let version: Int64
}

struct BusinessProcurementSupplierListResponse: Codable, Equatable, Sendable {
    let suppliers: [BusinessProcurementSupplierResponse]
    let nextCursor: String?
    let hasMore: Bool
}

struct BusinessProcurementSupplierEnvelopeResponse: Codable, Equatable, Sendable {
    let data: BusinessProcurementSupplierResponse
    let meta: BusinessProcurementResponseMeta
}

// MARK: - Purchase orders

struct BusinessProcurementPurchaseOrderLineRequest: Codable, Equatable, Sendable {
    let id: String?
    let kind: String
    let catalogItemId: String?
    let description: String?
    let orderedQuantity: String
    let unitCode: String
    let allowsDecimal: Bool
    let unitCost: String
    let discountAmount: String
    let priceTaxMode: String
    let taxProfileId: String?
    let targetWarehouseId: String?
    let notes: String?
}

struct BusinessProcurementPurchaseOrderWriteRequest: Codable, Equatable, Sendable {
    let branchId: String?
    let supplierId: String
    let currency: String
    let lines: [BusinessProcurementPurchaseOrderLineRequest]
    let expectedDate: String?
    let notes: String?
    let attachmentIds: [String]
    let expectedVersion: Int64?
}

struct BusinessProcurementPurchaseOrderActionRequest: Codable, Equatable, Sendable {
    let expectedVersion: Int64?
    let reason: String?
}

struct BusinessProcurementPurchaseOrderLineResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: String
    let catalogItemId: String?
    let catalogItemSnapshot: BusinessProcurementPurchaseItemSnapshotResponse?
    let descriptionSnapshot: String
    let orderedQuantity: BusinessProcurementQuantityResponse
    let receivedQuantity: String
    let unitCost: BusinessProcurementMoneyResponse?
    let discountAmount: BusinessProcurementMoneyResponse?
    let priceTaxMode: String
    let taxProfileId: String
    let taxProfileVersion: Int64
    let taxes: [BusinessProcurementPurchaseTaxResponse]?
    let grossAmount: BusinessProcurementMoneyResponse?
    let netAmount: BusinessProcurementMoneyResponse?
    let taxAmount: BusinessProcurementMoneyResponse?
    let lineTotal: BusinessProcurementMoneyResponse?
    let targetWarehouseId: String?
    let notes: String?
}

struct BusinessProcurementSupplierSnapshotResponse: Codable, Equatable, Sendable {
    let supplierId: String
    let legalName: String
    let tradeName: String?
    let identificationType: String?
    let identificationNumber: String?
    let paymentTerms: BusinessProcurementPaymentTermsResponse
    let defaultCurrency: String
}

struct BusinessProcurementPurchaseOrderResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String
    let supplierId: String
    let orderNumber: String
    let status: BusinessPurchaseOrderStatus
    let currency: String
    let lines: [BusinessProcurementPurchaseOrderLineResponse]
    let subtotal: BusinessProcurementMoneyResponse?
    let discountTotal: BusinessProcurementMoneyResponse?
    let taxTotal: BusinessProcurementMoneyResponse?
    let total: BusinessProcurementMoneyResponse?
    let expectedDate: String?
    let supplierSnapshot: BusinessProcurementSupplierSnapshotResponse
    let paymentTermsSnapshot: BusinessProcurementPaymentTermsResponse
    let notes: String?
    let attachmentIds: [String]
    let createdAt: String
    let createdBy: String
    let updatedAt: String
    let updatedBy: String
    let sentAt: String?
    let sentBy: String?
    let closedAt: String?
    let closedBy: String?
    let closeReason: String?
    let cancelledAt: String?
    let cancelledBy: String?
    let cancellationReason: String?
    let version: Int64
}

struct BusinessProcurementPurchaseOrderListResponse: Codable, Equatable, Sendable {
    let purchaseOrders: [BusinessProcurementPurchaseOrderResponse]
    let nextCursor: String?
    let hasMore: Bool
}

struct BusinessProcurementPurchaseOrderEnvelopeResponse: Codable, Equatable, Sendable {
    let data: BusinessProcurementPurchaseOrderResponse
    let meta: BusinessProcurementResponseMeta
}

// MARK: - Purchase receipts

struct BusinessProcurementPurchaseTrackedUnitRequest: Codable, Equatable, Sendable {
    let trackingType: String
    let trackingValue: String
    let notes: String?
}

struct BusinessProcurementPurchaseReceiptLineRequest: Codable, Equatable, Sendable {
    let id: String?
    let purchaseOrderLineId: String?
    let kind: String?
    let catalogItemId: String?
    let receivedQuantity: String
    let acceptedQuantity: String
    let rejectedQuantity: String
    let unitCode: String
    let allowsDecimal: Bool
    let unitCost: String?
    let warehouseId: String?
    let trackedUnits: [BusinessProcurementPurchaseTrackedUnitRequest]
    let notes: String?
}

struct BusinessProcurementPurchaseReceiptWriteRequest: Codable, Equatable, Sendable {
    let branchId: String?
    let supplierId: String
    let purchaseOrderId: String?
    let warehouseId: String
    let receivedAt: String
    let lines: [BusinessProcurementPurchaseReceiptLineRequest]
    let notes: String?
    let attachmentIds: [String]
    let expectedVersion: Int64?
}

struct BusinessProcurementPurchaseReceiptActionRequest: Codable, Equatable, Sendable {
    let expectedVersion: Int64?
    let reason: String?
}

struct BusinessProcurementPurchaseTrackedUnitResponse: Codable, Equatable, Sendable {
    let trackingType: String
    let trackingValue: String
    let notes: String?
}

struct BusinessProcurementPurchaseReceiptLineResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let purchaseOrderLineId: String?
    let kind: String
    let catalogItemId: String?
    let itemSnapshot: BusinessProcurementPurchaseItemSnapshotResponse?
    let receivedQuantity: BusinessProcurementQuantityResponse
    let acceptedQuantity: String
    let rejectedQuantity: String
    let unitCode: String
    let unitCost: BusinessProcurementMoneyResponse?
    let warehouseId: String
    let trackedUnits: [BusinessProcurementPurchaseTrackedUnitResponse]
    let inventoryMovementId: String?
    let notes: String?
}

struct BusinessProcurementPurchaseReceiptResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String
    let supplierId: String
    let purchaseOrderId: String?
    let receiptNumber: String
    let status: BusinessPurchaseReceiptStatus
    let warehouseId: String
    let receivedAt: String
    let lines: [BusinessProcurementPurchaseReceiptLineResponse]
    let inventoryMovementIds: [String]
    let attachmentIds: [String]
    let notes: String?
    let createdAt: String
    let createdBy: String
    let updatedAt: String
    let updatedBy: String
    let confirmedAt: String?
    let confirmedBy: String?
    let cancelledAt: String?
    let cancelledBy: String?
    let cancellationReason: String?
    let version: Int64
}

struct BusinessProcurementPurchaseReceiptListResponse: Codable, Equatable, Sendable {
    let purchaseReceipts: [BusinessProcurementPurchaseReceiptResponse]
    let nextCursor: String?
    let hasMore: Bool
}

struct BusinessProcurementPurchaseReceiptEnvelopeResponse: Codable, Equatable, Sendable {
    let data: BusinessProcurementPurchaseReceiptResponse
    let meta: BusinessProcurementResponseMeta
}

// MARK: - Supplier documents

struct BusinessProcurementSupplierDocumentLineRequest: Codable, Equatable, Sendable {
    let id: String?
    let kind: String
    let catalogItemId: String?
    let purchaseOrderLineId: String?
    let purchaseReceiptLineId: String?
    let description: String?
    let quantity: String
    let unitCode: String
    let allowsDecimal: Bool
    let unitCost: String
    let discountAmount: String
    let priceTaxMode: String
    let taxProfileId: String?
    let expenseCategoryCode: String?
    let notes: String?
}

struct BusinessProcurementSupplierSourceTotalsRequest: Codable, Equatable, Sendable {
    let total: String
    let taxTotal: String
}

struct BusinessProcurementSourcePaymentEvidenceRequest: Codable, Equatable, Sendable {
    let amount: String
    let method: String
    let paymentDate: String
    let reference: String?
}

struct BusinessProcurementSupplierDocumentWriteRequest: Codable, Equatable, Sendable {
    let branchId: String?
    let supplierId: String
    let documentType: String
    let documentNumber: String
    let accessKey: String?
    let authorizationNumber: String?
    let documentDate: String
    let dueDate: String?
    let currency: String
    let purchaseOrderIds: [String]
    let purchaseReceiptIds: [String]
    let lines: [BusinessProcurementSupplierDocumentLineRequest]
    let sourceTotals: BusinessProcurementSupplierSourceTotalsRequest?
    let sourcePayment: BusinessProcurementSourcePaymentEvidenceRequest?
    let attachmentIds: [String]
    let notes: String?
    let expectedVersion: Int64?
}

struct BusinessProcurementSupplierDocumentActionRequest: Codable, Equatable, Sendable {
    let expectedVersion: Int64?
    let reason: String?
}

struct BusinessProcurementSupplierSourceTotalsResponse: Codable, Equatable, Sendable {
    let total: BusinessProcurementMoneyResponse
    let taxTotal: BusinessProcurementMoneyResponse
}

struct BusinessProcurementSourcePaymentEvidenceResponse: Codable, Equatable, Sendable {
    let amount: BusinessProcurementMoneyResponse
    let method: String
    let paymentDate: String
    let reference: String?
}

struct BusinessProcurementSupplierDocumentLineResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: String
    let catalogItemId: String?
    let catalogItemSnapshot: BusinessProcurementPurchaseItemSnapshotResponse?
    let purchaseOrderLineId: String?
    let purchaseReceiptLineId: String?
    let descriptionSnapshot: String
    let quantity: BusinessProcurementQuantityResponse
    let unitCost: BusinessProcurementMoneyResponse
    let discountAmount: BusinessProcurementMoneyResponse
    let priceTaxMode: String
    let taxProfileId: String
    let taxProfileVersion: Int64
    let taxes: [BusinessProcurementPurchaseTaxResponse]
    let grossAmount: BusinessProcurementMoneyResponse
    let netAmount: BusinessProcurementMoneyResponse
    let taxAmount: BusinessProcurementMoneyResponse
    let lineTotal: BusinessProcurementMoneyResponse
    let expenseCategoryCode: String?
    let notes: String?
}

struct BusinessProcurementSupplierDocumentResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String
    let supplierId: String
    let documentType: String
    let status: BusinessSupplierDocumentStatus
    let documentNumber: String
    let documentNumberNormalized: String
    let accessKey: String?
    let authorizationNumber: String?
    let documentDate: String
    let dueDate: String?
    let currency: String
    let purchaseOrderIds: [String]
    let purchaseReceiptIds: [String]
    let lines: [BusinessProcurementSupplierDocumentLineResponse]
    let subtotal: BusinessProcurementMoneyResponse
    let discountTotal: BusinessProcurementMoneyResponse
    let taxTotal: BusinessProcurementMoneyResponse
    let total: BusinessProcurementMoneyResponse
    let sourceTotals: BusinessProcurementSupplierSourceTotalsResponse?
    let sourcePayment: BusinessProcurementSourcePaymentEvidenceResponse?
    let payableAmount: BusinessProcurementMoneyResponse
    let payableId: String?
    let attachmentIds: [String]
    let accountingStatus: String
    let notes: String?
    let createdAt: String
    let createdBy: String
    let updatedAt: String
    let updatedBy: String
    let confirmedAt: String?
    let confirmedBy: String?
    let cancelledAt: String?
    let cancelledBy: String?
    let cancellationReason: String?
    let version: Int64
}

struct BusinessProcurementSupplierDocumentListResponse: Codable, Equatable, Sendable {
    let supplierDocuments: [BusinessProcurementSupplierDocumentResponse]
    let nextCursor: String?
    let hasMore: Bool
}

struct BusinessProcurementSupplierDocumentEnvelopeResponse: Codable, Equatable, Sendable {
    let data: BusinessProcurementSupplierDocumentResponse
    let payable: BusinessProcurementPayableResponse?
    let meta: BusinessProcurementResponseMeta
}

// MARK: - Payables

struct BusinessProcurementPayableResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String
    let supplierId: String
    let sourceType: String
    let sourceId: String
    let currency: String
    let originalAmount: BusinessProcurementMoneyResponse
    let paidAmount: BusinessProcurementMoneyResponse
    let balance: BusinessProcurementMoneyResponse
    let dueDate: String
    let settlementStatus: String
    let effectiveStatus: BusinessPayableEffectiveStatus
    let allocationIds: [String]
    let createdAt: String
    let createdBy: String
    let updatedAt: String
    let updatedBy: String
    let version: Int64
}

struct BusinessProcurementPayableListResponse: Codable, Equatable, Sendable {
    let payables: [BusinessProcurementPayableResponse]
    let nextCursor: String?
    let hasMore: Bool
    let asOf: String
}

struct BusinessProcurementPayableEnvelopeResponse: Codable, Equatable, Sendable {
    let data: BusinessProcurementPayableResponse
    let meta: BusinessProcurementResponseMeta
}

struct BusinessProcurementPayableAgingBucketResponse: Codable, Equatable, Sendable {
    let code: String
    let count: Int64
    let balance: BusinessProcurementMoneyResponse
}

struct BusinessProcurementPayableAgingResponse: Codable, Equatable, Sendable {
    let currency: String
    let asOf: String
    let buckets: [BusinessProcurementPayableAgingBucketResponse]
}

// MARK: - Supplier payments

struct BusinessProcurementSupplierPaymentAllocationRequest: Codable, Equatable, Sendable {
    let payableId: String
    let amount: String
}

struct BusinessProcurementSupplierPaymentCreateRequest: Codable, Equatable, Sendable {
    let branchId: String?
    let supplierId: String
    let paymentDate: String
    let currency: String
    let amount: String
    let method: String
    let reference: String?
    let allocations: [BusinessProcurementSupplierPaymentAllocationRequest]
    let attachmentIds: [String]
    let notes: String?
}

struct BusinessProcurementSupplierPaymentVoidRequest: Codable, Equatable, Sendable {
    let reason: String
    let expectedVersion: Int64?
}

struct BusinessProcurementSupplierPaymentAllocationResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let payableId: String
    let amount: BusinessProcurementMoneyResponse
    let payableBalanceBefore: BusinessProcurementMoneyResponse
    let payableBalanceAfter: BusinessProcurementMoneyResponse
    let status: String
    let createdAt: String
    let createdBy: String
    let reversedAt: String?
    let reversedBy: String?
    let reversalReason: String?
}

struct BusinessProcurementSupplierPaymentResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String
    let supplierId: String
    let paymentNumber: String
    let paymentDate: String
    let currency: String
    let amount: BusinessProcurementMoneyResponse
    let method: String?
    let reference: String?
    let status: BusinessSupplierPaymentStatus
    let allocations: [BusinessProcurementSupplierPaymentAllocationResponse]
    let attachmentIds: [String]?
    let cashMovementId: String?
    let notes: String?
    let createdAt: String
    let createdBy: String
    let updatedAt: String
    let updatedBy: String
    let recordedAt: String?
    let recordedBy: String?
    let voidedAt: String?
    let voidedBy: String?
    let voidReason: String?
    let version: Int64
}

struct BusinessProcurementSupplierPaymentListResponse: Codable, Equatable, Sendable {
    let supplierPayments: [BusinessProcurementSupplierPaymentResponse]
    let nextCursor: String?
    let hasMore: Bool
}

struct BusinessProcurementSupplierPaymentEnvelopeResponse: Codable, Equatable, Sendable {
    let data: BusinessProcurementSupplierPaymentResponse
    let meta: BusinessProcurementResponseMeta
}

// MARK: - Supplier statement

struct BusinessProcurementSupplierStatementLineResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let occurredAt: String
    let sourceType: String
    let sourceId: String
    let description: String
    let charge: BusinessProcurementMoneyResponse
    let credit: BusinessProcurementMoneyResponse
    let runningBalance: BusinessProcurementMoneyResponse
    let currency: String
    let auditResourceType: String
    let auditResourceId: String
}

struct BusinessProcurementSupplierStatementResponse: Codable, Equatable, Sendable {
    let supplierId: String
    let branchId: String?
    let currency: String
    let from: String?
    let to: String?
    let asOf: String
    let openingBalance: BusinessProcurementMoneyResponse
    let lines: [BusinessProcurementSupplierStatementLineResponse]
    let closingBalance: BusinessProcurementMoneyResponse
    let nextCursor: String?
    let hasMore: Bool
}

// MARK: - Attachments

struct BusinessProcurementAttachmentResponse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let sourceType: BusinessProcurementAttachmentSourceType
    let sourceId: String
    let fileName: String
    let mediaType: String
    let sizeBytes: Int64
    let checksumSha256: String
    let uploadedAt: String
    let uploadedBy: String
    let version: Int64
}

struct BusinessProcurementAttachmentEnvelopeResponse: Codable, Equatable, Sendable {
    let data: BusinessProcurementAttachmentResponse
    let meta: BusinessProcurementResponseMeta
}
