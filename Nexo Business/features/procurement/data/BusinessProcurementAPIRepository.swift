//
//  BusinessProcurementAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation

final class BusinessProcurementAPIRepository: BusinessProcurementRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let dataClient: APIDataClient?
    private let fileManager: FileManager
    private let downloadDirectory: URL
    private let boundaryProvider: @Sendable () -> String

    init(
        apiClient: APIClient,
        fileManager: FileManager = .default,
        downloadDirectory: URL? = nil,
        boundaryProvider: @escaping @Sendable () -> String = {
            "nexo-procurement-\(UUID().uuidString.lowercased())"
        }
    ) {
        self.apiClient = apiClient
        self.dataClient = apiClient as? APIDataClient
        self.fileManager = fileManager
        self.downloadDirectory = downloadDirectory ?? fileManager.temporaryDirectory.appendingPathComponent(
            "nexo-business-procurement",
            isDirectory: true
        )
        self.boundaryProvider = boundaryProvider
    }

    // MARK: - Suppliers

    func listSuppliers(
        organizationId: String,
        filters: BusinessProcurementSupplierFilters
    ) async throws -> BusinessProcurementSupplierListResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "query", value: filters.query)
        queryItems.appendRaw(name: "status", value: filters.status?.rawValue)
        queryItems.appendTrimmed(name: "category", value: filters.category)
        queryItems.appendTrimmed(name: "updatedFrom", value: filters.updatedFrom)
        queryItems.appendTrimmed(name: "updatedTo", value: filters.updatedTo)
        queryItems.appendRaw(name: "limit", value: String(filters.limit))
        queryItems.appendTrimmed(name: "cursor", value: filters.cursor)

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.suppliers,
                queryItems: queryItems,
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func getSupplier(
        organizationId: String,
        supplierId: String
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.supplier(supplierId),
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func createSupplier(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierWriteRequest
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.suppliers,
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func updateSupplier(
        organizationId: String,
        supplierId: String,
        request: BusinessProcurementSupplierWriteRequest
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierEnvelopeResponse>.json(
                method: .put,
                path: BusinessProcurementRoutes.supplier(supplierId),
                body: request,
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func changeSupplierStatus(
        organizationId: String,
        supplierId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierStatusRequest
    ) async throws -> BusinessProcurementSupplierEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.supplierStatus(supplierId),
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    // MARK: - Purchase orders

    func listPurchaseOrders(
        organizationId: String,
        filters: BusinessProcurementPurchaseOrderFilters
    ) async throws -> BusinessProcurementPurchaseOrderListResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "branchId", value: filters.branchId)
        queryItems.appendTrimmed(name: "supplierId", value: filters.supplierId)
        queryItems.appendCSV(name: "status", values: filters.statuses.map(\.rawValue))
        queryItems.appendTrimmed(name: "expectedFrom", value: filters.expectedFrom)
        queryItems.appendTrimmed(name: "expectedTo", value: filters.expectedTo)
        queryItems.appendTrimmed(name: "query", value: filters.query)
        queryItems.appendRaw(name: "limit", value: String(filters.limit))
        queryItems.appendTrimmed(name: "cursor", value: filters.cursor)

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.purchaseOrders,
                queryItems: queryItems,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
    }

    func getPurchaseOrder(
        organizationId: String,
        orderId: String
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.purchaseOrder(orderId),
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func createPurchaseOrder(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseOrderWriteRequest
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementPurchaseOrderEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.purchaseOrders,
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: request.branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func updatePurchaseOrder(
        organizationId: String,
        orderId: String,
        request: BusinessProcurementPurchaseOrderWriteRequest
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementPurchaseOrderEnvelopeResponse>.json(
                method: .put,
                path: BusinessProcurementRoutes.purchaseOrder(orderId),
                body: request,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: request.branchId
                )
            )
        )
    }

    func performPurchaseOrderAction(
        organizationId: String,
        orderId: String,
        action: BusinessPurchaseOrderAction,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseOrderActionRequest
    ) async throws -> BusinessProcurementPurchaseOrderEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementPurchaseOrderEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.purchaseOrderAction(action, orderId: orderId),
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    // MARK: - Purchase receipts

    func listPurchaseReceipts(
        organizationId: String,
        filters: BusinessProcurementPurchaseReceiptFilters
    ) async throws -> BusinessProcurementPurchaseReceiptListResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "branchId", value: filters.branchId)
        queryItems.appendTrimmed(name: "supplierId", value: filters.supplierId)
        queryItems.appendTrimmed(name: "purchaseOrderId", value: filters.purchaseOrderId)
        queryItems.appendCSV(name: "status", values: filters.statuses.map(\.rawValue))
        queryItems.appendTrimmed(name: "receivedFrom", value: filters.receivedFrom)
        queryItems.appendTrimmed(name: "receivedTo", value: filters.receivedTo)
        queryItems.appendRaw(name: "limit", value: String(filters.limit))
        queryItems.appendTrimmed(name: "cursor", value: filters.cursor)

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.purchaseReceipts,
                queryItems: queryItems,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
    }

    func getPurchaseReceipt(
        organizationId: String,
        receiptId: String
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.purchaseReceipt(receiptId),
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func createPurchaseReceipt(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseReceiptWriteRequest
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementPurchaseReceiptEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.purchaseReceipts,
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: request.branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func updatePurchaseReceipt(
        organizationId: String,
        receiptId: String,
        request: BusinessProcurementPurchaseReceiptWriteRequest
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementPurchaseReceiptEnvelopeResponse>.json(
                method: .put,
                path: BusinessProcurementRoutes.purchaseReceipt(receiptId),
                body: request,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: request.branchId
                )
            )
        )
    }

    func performPurchaseReceiptAction(
        organizationId: String,
        receiptId: String,
        action: BusinessPurchaseReceiptAction,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementPurchaseReceiptActionRequest
    ) async throws -> BusinessProcurementPurchaseReceiptEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementPurchaseReceiptEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.purchaseReceiptAction(action, receiptId: receiptId),
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    // MARK: - Supplier documents

    func listSupplierDocuments(
        organizationId: String,
        filters: BusinessProcurementSupplierDocumentFilters
    ) async throws -> BusinessProcurementSupplierDocumentListResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "branchId", value: filters.branchId)
        queryItems.appendTrimmed(name: "supplierId", value: filters.supplierId)
        queryItems.appendCSV(name: "documentType", values: filters.documentTypes)
        queryItems.appendCSV(name: "status", values: filters.statuses.map(\.rawValue))
        queryItems.appendTrimmed(name: "documentDateFrom", value: filters.documentDateFrom)
        queryItems.appendTrimmed(name: "documentDateTo", value: filters.documentDateTo)
        queryItems.appendTrimmed(name: "dueDateFrom", value: filters.dueDateFrom)
        queryItems.appendTrimmed(name: "dueDateTo", value: filters.dueDateTo)
        queryItems.appendTrimmed(name: "query", value: filters.query)
        queryItems.appendRaw(name: "limit", value: String(filters.limit))
        queryItems.appendTrimmed(name: "cursor", value: filters.cursor)

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.supplierDocuments,
                queryItems: queryItems,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
    }

    func getSupplierDocument(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.supplierDocument(documentId),
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func createSupplierDocument(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierDocumentWriteRequest
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierDocumentEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.supplierDocuments,
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: request.branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func updateSupplierDocument(
        organizationId: String,
        documentId: String,
        request: BusinessProcurementSupplierDocumentWriteRequest
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierDocumentEnvelopeResponse>.json(
                method: .put,
                path: BusinessProcurementRoutes.supplierDocument(documentId),
                body: request,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: request.branchId
                )
            )
        )
    }

    func performSupplierDocumentAction(
        organizationId: String,
        documentId: String,
        action: BusinessSupplierDocumentAction,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierDocumentActionRequest
    ) async throws -> BusinessProcurementSupplierDocumentEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierDocumentEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.supplierDocumentAction(action, documentId: documentId),
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    // MARK: - Payables

    func listPayables(
        organizationId: String,
        filters: BusinessProcurementPayableFilters
    ) async throws -> BusinessProcurementPayableListResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "branchId", value: filters.branchId)
        queryItems.appendTrimmed(name: "supplierId", value: filters.supplierId)
        queryItems.appendCSV(name: "settlementStatus", values: filters.settlementStatuses)
        queryItems.appendCSV(name: "effectiveStatus", values: filters.effectiveStatuses.map(\.rawValue))
        queryItems.appendTrimmed(name: "dueFrom", value: filters.dueFrom)
        queryItems.appendTrimmed(name: "dueTo", value: filters.dueTo)
        queryItems.appendTrimmed(name: "currency", value: filters.currency)
        queryItems.appendTrimmed(name: "asOf", value: filters.asOf)
        queryItems.appendRaw(name: "limit", value: String(filters.limit))
        queryItems.appendTrimmed(name: "cursor", value: filters.cursor)

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.payables,
                queryItems: queryItems,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
    }

    func getPayable(
        organizationId: String,
        payableId: String,
        asOf: String?
    ) async throws -> BusinessProcurementPayableEnvelopeResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "asOf", value: asOf)
        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.payable(payableId),
                queryItems: queryItems,
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func getPayableAging(
        organizationId: String,
        filters: BusinessProcurementPayableAgingFilters
    ) async throws -> BusinessProcurementPayableAgingResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "branchId", value: filters.branchId)
        queryItems.appendTrimmed(name: "supplierId", value: filters.supplierId)
        queryItems.appendTrimmed(name: "currency", value: filters.currency)
        queryItems.appendTrimmed(name: "asOf", value: filters.asOf)
        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.payableAging,
                queryItems: queryItems,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
    }

    // MARK: - Supplier payments

    func listSupplierPayments(
        organizationId: String,
        filters: BusinessProcurementSupplierPaymentFilters
    ) async throws -> BusinessProcurementSupplierPaymentListResponse {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "branchId", value: filters.branchId)
        queryItems.appendTrimmed(name: "supplierId", value: filters.supplierId)
        queryItems.appendCSV(name: "status", values: filters.statuses.map(\.rawValue))
        queryItems.appendTrimmed(name: "paymentFrom", value: filters.paymentFrom)
        queryItems.appendTrimmed(name: "paymentTo", value: filters.paymentTo)
        queryItems.appendTrimmed(name: "method", value: filters.method)
        queryItems.appendTrimmed(name: "query", value: filters.query)
        queryItems.appendRaw(name: "limit", value: String(filters.limit))
        queryItems.appendTrimmed(name: "cursor", value: filters.cursor)

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.supplierPayments,
                queryItems: queryItems,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
    }

    func getSupplierPayment(
        organizationId: String,
        paymentId: String
    ) async throws -> BusinessProcurementSupplierPaymentEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.supplierPayment(paymentId),
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    func recordSupplierPayment(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierPaymentCreateRequest
    ) async throws -> BusinessProcurementSupplierPaymentEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierPaymentEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.supplierPayments,
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: request.branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func voidSupplierPayment(
        organizationId: String,
        paymentId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessProcurementSupplierPaymentVoidRequest
    ) async throws -> BusinessProcurementSupplierPaymentEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<BusinessProcurementSupplierPaymentEnvelopeResponse>.json(
                method: .post,
                path: BusinessProcurementRoutes.voidSupplierPayment(paymentId),
                body: request,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    // MARK: - Supplier statement

    func getSupplierStatement(
        organizationId: String,
        supplierId: String,
        filters: BusinessProcurementSupplierStatementFilters
    ) async throws -> BusinessProcurementSupplierStatementResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProcurementRoutes.supplierStatement(supplierId),
                queryItems: statementQueryItems(filters: filters, includesPaging: true),
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
    }

    func downloadSupplierStatementCSV(
        organizationId: String,
        supplierId: String,
        filters: BusinessProcurementSupplierStatementFilters
    ) async throws -> BusinessProcurementDownloadedFile {
        let dataClient = try requiredDataClient()
        let response = try await dataClient.sendData(
            APIRequest<EmptyResponse>(
                method: .get,
                path: BusinessProcurementRoutes.supplierStatementCSV(supplierId),
                queryItems: statementQueryItems(filters: filters, includesPaging: false),
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: filters.branchId
                )
            )
        )
        return try persist(
            response: response,
            fallbackFileName: "supplier-statement-\(supplierId).csv",
            fallbackContentType: "text/csv; charset=utf-8"
        )
    }

    // MARK: - Attachments

    func uploadAttachment(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        upload: BusinessProcurementAttachmentUpload
    ) async throws -> BusinessProcurementAttachmentEnvelopeResponse {
        let multipart = try makeMultipart(upload: upload)
        var headers = mutationHeaders(
            organizationId: organizationId,
            idempotencyKey: idempotencyKey
        )
        headers["Content-Type"] = "multipart/form-data; boundary=\(multipart.boundary)"

        return try await apiClient.send(
            APIRequest<BusinessProcurementAttachmentEnvelopeResponse>(
                method: .post,
                path: BusinessProcurementRoutes.attachments,
                headers: headers,
                body: multipart.body
            )
        )
    }

    func downloadAttachment(
        organizationId: String,
        attachmentId: String
    ) async throws -> BusinessProcurementDownloadedFile {
        let dataClient = try requiredDataClient()
        let response = try await dataClient.sendData(
            APIRequest<EmptyResponse>(
                method: .get,
                path: BusinessProcurementRoutes.attachment(attachmentId),
                headers: contextHeaders(organizationId: organizationId)
            )
        )
        return try persist(
            response: response,
            fallbackFileName: "attachment-\(attachmentId)",
            fallbackContentType: "application/octet-stream"
        )
    }

    func deleteAttachment(
        organizationId: String,
        attachmentId: String,
        expectedSourceVersion: Int64
    ) async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .delete,
                path: BusinessProcurementRoutes.attachment(attachmentId),
                queryItems: [
                    URLQueryItem(
                        name: "expectedSourceVersion",
                        value: String(expectedSourceVersion)
                    )
                ],
                headers: contextHeaders(organizationId: organizationId)
            )
        )
    }

    // MARK: - Transport helpers

    private func contextHeaders(
        organizationId: String,
        branchId: String? = nil
    ) -> [String: String] {
        var headers = [BusinessHeaders.organizationId: organizationId]
        if let branchId = branchId?.trimmedNonEmpty {
            headers[BusinessHeaders.branchId] = branchId
        }
        return headers
    }

    private func mutationHeaders(
        organizationId: String,
        branchId: String? = nil,
        idempotencyKey: IdempotencyKey
    ) -> [String: String] {
        var headers = contextHeaders(
            organizationId: organizationId,
            branchId: branchId
        )
        headers[BusinessHeaders.idempotencyKey] = idempotencyKey.rawValue
        return headers
    }

    private func statementQueryItems(
        filters: BusinessProcurementSupplierStatementFilters,
        includesPaging: Bool
    ) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        queryItems.appendTrimmed(name: "branchId", value: filters.branchId)
        queryItems.appendTrimmed(name: "currency", value: filters.currency)
        queryItems.appendTrimmed(name: "from", value: filters.from)
        queryItems.appendTrimmed(name: "to", value: filters.to)
        queryItems.appendTrimmed(name: "asOf", value: filters.asOf)
        if includesPaging {
            queryItems.appendRaw(name: "limit", value: String(filters.limit))
            queryItems.appendTrimmed(name: "cursor", value: filters.cursor)
        }
        return queryItems
    }

    private func requiredDataClient() throws -> APIDataClient {
        guard let dataClient else {
            throw BusinessProcurementRepositoryError.binaryClientUnavailable
        }
        return dataClient
    }

    private func persist(
        response: APIDataResponse,
        fallbackFileName: String,
        fallbackContentType: String
    ) throws -> BusinessProcurementDownloadedFile {
        try fileManager.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        let dispositionName = Self.fileName(
            fromContentDisposition: response.headerValue("Content-Disposition")
        )
        let safeName = Self.safeFileName(
            dispositionName ?? fallbackFileName,
            fallback: fallbackFileName
        )
        let localURL = uniqueURL(fileName: safeName)
        try response.data.write(to: localURL, options: [.atomic])
        return BusinessProcurementDownloadedFile(
            localURL: localURL,
            fileName: safeName,
            contentType: response.headerValue("Content-Type") ?? fallbackContentType,
            sizeBytes: response.data.count,
            responseHeaders: response.headers
        )
    }

    private func uniqueURL(fileName: String) -> URL {
        let first = downloadDirectory.appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: first.path) else { return first }

        let nsName = fileName as NSString
        let base = nsName.deletingPathExtension.isEmpty ? "procurement-file" : nsName.deletingPathExtension
        let ext = nsName.pathExtension
        let uniqueName = ext.isEmpty
            ? "\(base)-\(UUID().uuidString.lowercased())"
            : "\(base)-\(UUID().uuidString.lowercased()).\(ext)"
        return downloadDirectory.appendingPathComponent(uniqueName, isDirectory: false)
    }

    private func makeMultipart(
        upload: BusinessProcurementAttachmentUpload
    ) throws -> (boundary: String, body: Data) {
        guard upload.sourceId.trimmedNonEmpty != nil else {
            throw BusinessProcurementRepositoryError.attachmentSourceIdRequired
        }
        guard upload.expectedSourceVersion > 0 else {
            throw BusinessProcurementRepositoryError.attachmentSourceVersionInvalid
        }
        guard !upload.data.isEmpty else {
            throw BusinessProcurementRepositoryError.attachmentEmpty
        }
        let maximumBytes = BusinessProcurementContractDecision.maximumAttachmentBytes
        guard upload.data.count <= maximumBytes else {
            throw BusinessProcurementRepositoryError.attachmentTooLarge(maximumBytes: maximumBytes)
        }
        guard let uploadName = Self.multipartFileName(upload.fileName) else {
            throw BusinessProcurementRepositoryError.attachmentFileNameRequired
        }

        let boundary = boundaryProvider()
        var body = Data()
        body.appendMultipartField(
            name: "sourceType",
            value: upload.sourceType.rawValue,
            boundary: boundary
        )
        body.appendMultipartField(
            name: "sourceId",
            value: upload.sourceId.trimmingCharacters(in: .whitespacesAndNewlines),
            boundary: boundary
        )
        body.appendMultipartField(
            name: "expectedSourceVersion",
            value: String(upload.expectedSourceVersion),
            boundary: boundary
        )
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(uploadName)\"\r\n")
        body.appendUTF8("Content-Type: \(upload.mediaType.rawValue)\r\n\r\n")
        body.append(upload.data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        return (boundary, body)
    }

    private static func fileName(fromContentDisposition value: String?) -> String? {
        guard let value else { return nil }
        let parts = value.components(separatedBy: ";")

        if let encoded = parts.compactMap({ part -> String? in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("filename*=") else { return nil }
            let raw = String(trimmed.dropFirst("filename*=".count))
            let value = raw.components(separatedBy: "''").last ?? raw
            return value.removingPercentEncoding
        }).first {
            return encoded
        }

        return parts.compactMap { part -> String? in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("filename=") else { return nil }
            return String(trimmed.dropFirst("filename=".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }.first
    }

    private static func multipartFileName(_ rawName: String) -> String? {
        guard let last = rawName
            .components(separatedBy: CharacterSet(charactersIn: "/\\"))
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !last.isEmpty else {
            return nil
        }
        let value = last
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
        return value.isEmpty ? nil : String(value.prefix(160))
    }

    private static func safeFileName(_ rawName: String, fallback: String) -> String {
        let last = rawName
            .components(separatedBy: CharacterSet(charactersIn: "/\\"))
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = last?.isEmpty == false ? last! : fallback
        let sanitized = candidate
            .replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
            .prefix(160)
        let result = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return result.isEmpty ? fallback : result
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Array where Element == URLQueryItem {
    mutating func appendTrimmed(name: String, value: String?) {
        guard let value = value?.trimmedNonEmpty else { return }
        append(URLQueryItem(name: name, value: value))
    }

    mutating func appendRaw(name: String, value: String?) {
        guard let value else { return }
        append(URLQueryItem(name: name, value: value))
    }

    mutating func appendCSV(name: String, values: [String]) {
        let values = values.compactMap(\.trimmedNonEmpty)
        guard !values.isEmpty else { return }
        append(URLQueryItem(name: name, value: values.joined(separator: ",")))
    }
}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(contentsOf: value.utf8)
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendUTF8("--\(boundary)\r\n")
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendUTF8("\(value)\r\n")
    }
}
