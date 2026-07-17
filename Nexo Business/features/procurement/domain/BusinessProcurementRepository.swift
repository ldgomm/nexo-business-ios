//
//  BusinessProcurementRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation

struct BusinessProcurementSupplierFilters: Equatable, Sendable {
    var query: String? = nil
    var status: BusinessSupplierStatus? = nil
    var category: String? = nil
    var updatedFrom: String? = nil
    var updatedTo: String? = nil
    var limit: Int = 50
    var cursor: String? = nil
}

struct BusinessProcurementPurchaseOrderFilters: Equatable, Sendable {
    var branchId: String? = nil
    var supplierId: String? = nil
    var statuses: [BusinessPurchaseOrderStatus] = []
    var expectedFrom: String? = nil
    var expectedTo: String? = nil
    var query: String? = nil
    var limit: Int = 50
    var cursor: String? = nil
}

struct BusinessProcurementPurchaseReceiptFilters: Equatable, Sendable {
    var branchId: String? = nil
    var supplierId: String? = nil
    var purchaseOrderId: String? = nil
    var statuses: [BusinessPurchaseReceiptStatus] = []
    var receivedFrom: String? = nil
    var receivedTo: String? = nil
    var limit: Int = 50
    var cursor: String? = nil
}

struct BusinessProcurementSupplierDocumentFilters: Equatable, Sendable {
    var branchId: String? = nil
    var supplierId: String? = nil
    var documentTypes: [String] = []
    var statuses: [BusinessSupplierDocumentStatus] = []
    var documentDateFrom: String? = nil
    var documentDateTo: String? = nil
    var dueDateFrom: String? = nil
    var dueDateTo: String? = nil
    var query: String? = nil
    var limit: Int = 50
    var cursor: String? = nil
}

struct BusinessProcurementPayableFilters: Equatable, Sendable {
    var branchId: String? = nil
    var supplierId: String? = nil
    var settlementStatuses: [String] = []
    var effectiveStatuses: [BusinessPayableEffectiveStatus] = []
    var dueFrom: String? = nil
    var dueTo: String? = nil
    var currency: String? = nil
    var asOf: String? = nil
    var limit: Int = 50
    var cursor: String? = nil
}

struct BusinessProcurementPayableAgingFilters: Equatable, Sendable {
    var branchId: String? = nil
    var supplierId: String? = nil
    var currency: String? = nil
    var asOf: String? = nil
}

struct BusinessProcurementSupplierPaymentFilters: Equatable, Sendable {
    var branchId: String? = nil
    var supplierId: String? = nil
    var statuses: [BusinessSupplierPaymentStatus] = []
    var paymentFrom: String? = nil
    var paymentTo: String? = nil
    var method: String? = nil
    var query: String? = nil
    var limit: Int = 50
    var cursor: String? = nil
}

struct BusinessProcurementSupplierStatementFilters: Equatable, Sendable {
    let currency: String
    var branchId: String? = nil
    var from: String? = nil
    var to: String? = nil
    var asOf: String? = nil
    var limit: Int = 100
    var cursor: String? = nil
}

struct BusinessProcurementAttachmentUpload: Equatable, Sendable {
    let sourceType: BusinessProcurementAttachmentSourceType
    let sourceId: String
    let expectedSourceVersion: Int64
    let fileName: String
    let mediaType: BusinessProcurementAttachmentMediaType
    let data: Data
}

struct BusinessProcurementDownloadedFile: Equatable, Sendable {
    let localURL: URL
    let fileName: String
    let contentType: String
    let sizeBytes: Int
    let responseHeaders: [String: String]
}

enum BusinessProcurementRepositoryError: LocalizedError, Equatable, Sendable {
    case binaryClientUnavailable
    case attachmentFileNameRequired
    case attachmentSourceIdRequired
    case attachmentSourceVersionInvalid
    case attachmentEmpty
    case attachmentTooLarge(maximumBytes: Int)

    var errorDescription: String? {
        switch self {
        case .binaryClientUnavailable:
            return "El cliente HTTP no soporta descargas binarias."
        case .attachmentFileNameRequired:
            return "El archivo adjunto requiere un nombre."
        case .attachmentSourceIdRequired:
            return "El archivo adjunto requiere un recurso de origen."
        case .attachmentSourceVersionInvalid:
            return "La versión del recurso adjunto debe ser positiva."
        case .attachmentEmpty:
            return "El archivo adjunto está vacío."
        case .attachmentTooLarge(let maximumBytes):
            return "El archivo adjunto supera el máximo de \(maximumBytes) bytes."
        }
    }
}

protocol BusinessProcurementRepository: Sendable {
    func listSuppliers(
        organizationId: String,
        filters: BusinessProcurementSupplierFilters
    ) async throws -> BusinessProcurementSupplierListResponse

    func getSupplier(
        organizationId: String,
        supplierId: String
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse

    func createSupplier(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierWriteRequest
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse

    func updateSupplier(
        organizationId: String,
        supplierId: String,
        request: BusinessProcurementSupplierWriteRequest
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse

    func changeSupplierStatus(
        organizationId: String,
        supplierId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierStatusRequest
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse

    func listPurchaseOrders(
        organizationId: String,
        filters: BusinessProcurementPurchaseOrderFilters
    ) async throws -> BusinessProcurementPurchaseOrderListResponse

    func getPurchaseOrder(
        organizationId: String,
        orderId: String
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse

    func createPurchaseOrder(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseOrderWriteRequest
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse

    func updatePurchaseOrder(
        organizationId: String,
        orderId: String,
        request: BusinessProcurementPurchaseOrderWriteRequest
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse

    func performPurchaseOrderAction(
        organizationId: String,
        orderId: String,
        action: BusinessPurchaseOrderAction,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseOrderActionRequest
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse

    func listPurchaseReceipts(
        organizationId: String,
        filters: BusinessProcurementPurchaseReceiptFilters
    ) async throws -> BusinessProcurementPurchaseReceiptListResponse

    func getPurchaseReceipt(
        organizationId: String,
        receiptId: String
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse

    func createPurchaseReceipt(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseReceiptWriteRequest
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse

    func updatePurchaseReceipt(
        organizationId: String,
        receiptId: String,
        request: BusinessProcurementPurchaseReceiptWriteRequest
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse

    func performPurchaseReceiptAction(
        organizationId: String,
        receiptId: String,
        action: BusinessPurchaseReceiptAction,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseReceiptActionRequest
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse

    func listSupplierDocuments(
        organizationId: String,
        filters: BusinessProcurementSupplierDocumentFilters
    ) async throws -> BusinessProcurementSupplierDocumentListResponse

    func getSupplierDocument(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse

    func createSupplierDocument(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierDocumentWriteRequest
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse

    func updateSupplierDocument(
        organizationId: String,
        documentId: String,
        request: BusinessProcurementSupplierDocumentWriteRequest
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse

    func performSupplierDocumentAction(
        organizationId: String,
        documentId: String,
        action: BusinessSupplierDocumentAction,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierDocumentActionRequest
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse

    func listPayables(
        organizationId: String,
        filters: BusinessProcurementPayableFilters
    ) async throws -> BusinessProcurementPayableListResponse

    func getPayable(
        organizationId: String,
        payableId: String,
        asOf: String?
    ) async throws -> BusinessProcurementPayableEnvelopeResponse

    func getPayableAging(
        organizationId: String,
        filters: BusinessProcurementPayableAgingFilters
    ) async throws -> BusinessProcurementPayableAgingResponse

    func listSupplierPayments(
        organizationId: String,
        filters: BusinessProcurementSupplierPaymentFilters
    ) async throws -> BusinessProcurementSupplierPaymentListResponse

    func getSupplierPayment(
        organizationId: String,
        paymentId: String
    ) async throws -> BusinessProcurementSupplierPaymentEnvelopeResponse

    func recordSupplierPayment(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierPaymentCreateRequest
    ) async throws -> BusinessProcurementSupplierPaymentEnvelopeResponse

    func voidSupplierPayment(
        organizationId: String,
        paymentId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierPaymentVoidRequest
    ) async throws -> BusinessProcurementSupplierPaymentEnvelopeResponse

    func getSupplierStatement(
        organizationId: String,
        supplierId: String,
        filters: BusinessProcurementSupplierStatementFilters
    ) async throws -> BusinessProcurementSupplierStatementResponse

    func downloadSupplierStatementCSV(
        organizationId: String,
        supplierId: String,
        filters: BusinessProcurementSupplierStatementFilters
    ) async throws -> BusinessProcurementDownloadedFile

    func uploadAttachment(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        upload: BusinessProcurementAttachmentUpload
    ) async throws -> BusinessProcurementAttachmentEnvelopeResponse

    func downloadAttachment(
        organizationId: String,
        attachmentId: String
    ) async throws -> BusinessProcurementDownloadedFile

    func deleteAttachment(
        organizationId: String,
        attachmentId: String,
        expectedSourceVersion: Int64
    ) async throws
}
