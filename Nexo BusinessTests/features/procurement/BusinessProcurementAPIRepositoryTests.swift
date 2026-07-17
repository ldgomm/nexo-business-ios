//
//  BusinessProcurementAPIRepositoryTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

final class BusinessProcurementAPIRepositoryTests: XCTestCase {
    func testListFiltersUseCanonicalQueriesAndContextHeaders() async throws {
        let client = CapturingProcurementAPIClient(responseJSON: Self.emptySupplierListJSON)
        let repository = BusinessProcurementAPIRepository(apiClient: client)

        _ = try await repository.listSuppliers(
            organizationId: "org_1",
            filters: BusinessProcurementSupplierFilters(
                query: "  proveedor  ",
                status: .active,
                category: "  hardware  ",
                updatedFrom: "2026-07-01T00:00:00Z",
                updatedTo: "2026-07-31T23:59:59Z",
                limit: 25,
                cursor: "cursor_sup"
            )
        )

        let supplierRequest = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(supplierRequest.method, .get)
        XCTAssertEqual(supplierRequest.path, BusinessProcurementRoutes.suppliers)
        XCTAssertEqual(supplierRequest.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertNil(supplierRequest.headers[BusinessHeaders.idempotencyKey])
        XCTAssertEqual(supplierRequest.queryDictionary, [
            "query": "proveedor",
            "status": "ACTIVE",
            "category": "hardware",
            "updatedFrom": "2026-07-01T00:00:00Z",
            "updatedTo": "2026-07-31T23:59:59Z",
            "limit": "25",
            "cursor": "cursor_sup",
        ])

        client.responseData = Data(Self.emptyPurchaseOrderListJSON.utf8)
        _ = try await repository.listPurchaseOrders(
            organizationId: "org_1",
            filters: BusinessProcurementPurchaseOrderFilters(
                branchId: "br_1",
                supplierId: "sup_1",
                statuses: [.sent, .partiallyReceived],
                expectedFrom: "2026-07-01",
                expectedTo: "2026-07-31",
                query: "OC-",
                limit: 40,
                cursor: "cursor_po"
            )
        )

        let orderRequest = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(orderRequest.path, BusinessProcurementRoutes.purchaseOrders)
        XCTAssertEqual(orderRequest.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(orderRequest.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(orderRequest.queryDictionary["status"], "SENT,PARTIALLY_RECEIVED")
        XCTAssertEqual(orderRequest.queryDictionary["supplierId"], "sup_1")
        XCTAssertEqual(orderRequest.queryDictionary["expectedFrom"], "2026-07-01")
        XCTAssertEqual(orderRequest.queryDictionary["expectedTo"], "2026-07-31")
        XCTAssertEqual(orderRequest.queryDictionary["query"], "OC-")
        XCTAssertEqual(orderRequest.queryDictionary["limit"], "40")
        XCTAssertEqual(orderRequest.queryDictionary["cursor"], "cursor_po")
    }

    func testPurchaseMutationMapsJSONBranchVersionAndIdempotencyExactly() async throws {
        let client = CapturingProcurementAPIClient(responseJSON: Self.purchaseOrderEnvelopeJSON)
        let repository = BusinessProcurementAPIRepository(apiClient: client)
        let body = BusinessProcurementPurchaseOrderWriteRequest(
            branchId: "br_1",
            supplierId: "sup_1",
            currency: "USD",
            lines: [],
            expectedDate: "2026-07-20",
            notes: "Reposición",
            attachmentIds: [],
            expectedVersion: nil
        )

        let created = try await repository.createPurchaseOrder(
            organizationId: "org_1",
            idempotencyKey: IdempotencyKey(rawValue: "po-create-1"),
            request: body
        )

        XCTAssertEqual(created.data.id, "po_1")
        let createRequest = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(createRequest.method, .post)
        XCTAssertEqual(createRequest.path, BusinessProcurementRoutes.purchaseOrders)
        XCTAssertEqual(createRequest.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(createRequest.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(createRequest.headers[BusinessHeaders.idempotencyKey], "po-create-1")
        XCTAssertEqual(createRequest.headers["Content-Type"], "application/json")
        let createBody = try createRequest.jsonObject()
        XCTAssertEqual(createBody["supplierId"] as? String, "sup_1")
        XCTAssertEqual(createBody["branchId"] as? String, "br_1")
        XCTAssertNil(createBody["expectedVersion"])

        let update = BusinessProcurementPurchaseOrderWriteRequest(
            branchId: "br_1",
            supplierId: "sup_1",
            currency: "USD",
            lines: [],
            expectedDate: "2026-07-21",
            notes: nil,
            attachmentIds: [],
            expectedVersion: 7
        )
        _ = try await repository.updatePurchaseOrder(
            organizationId: "org_1",
            orderId: "po_1",
            request: update
        )
        let updateRequest = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(updateRequest.method, .put)
        XCTAssertEqual(updateRequest.path, BusinessProcurementRoutes.purchaseOrder("po_1"))
        XCTAssertNil(updateRequest.headers[BusinessHeaders.idempotencyKey])
        XCTAssertEqual(try updateRequest.jsonObject()["expectedVersion"] as? Int, 7)

        _ = try await repository.performPurchaseOrderAction(
            organizationId: "org_1",
            orderId: "po_1",
            action: .send,
            idempotencyKey: IdempotencyKey(rawValue: "po-send-1"),
            request: BusinessProcurementPurchaseOrderActionRequest(
                expectedVersion: 7,
                reason: nil
            )
        )
        let actionRequest = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(actionRequest.path, BusinessProcurementRoutes.purchaseOrderAction(.send, orderId: "po_1"))
        XCTAssertEqual(actionRequest.headers[BusinessHeaders.idempotencyKey], "po-send-1")
        XCTAssertEqual(try actionRequest.jsonObject()["expectedVersion"] as? Int, 7)
    }

    func testAllOperationalListFamiliesMapAcceptedFilterNames() async throws {
        let client = CapturingProcurementAPIClient(responseJSON: Self.emptyReceiptListJSON)
        let repository = BusinessProcurementAPIRepository(apiClient: client)

        _ = try await repository.listPurchaseReceipts(
            organizationId: "org_1",
            filters: BusinessProcurementPurchaseReceiptFilters(
                branchId: "br_1",
                supplierId: "sup_1",
                purchaseOrderId: "po_1",
                statuses: [.draft, .confirmed],
                receivedFrom: "2026-07-01T00:00:00Z",
                receivedTo: "2026-07-31T23:59:59Z",
                limit: 20,
                cursor: "cursor_receipt"
            )
        )
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["purchaseOrderId"], "po_1")
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["status"], "DRAFT,CONFIRMED")

        client.responseData = Data(Self.emptySupplierDocumentListJSON.utf8)
        _ = try await repository.listSupplierDocuments(
            organizationId: "org_1",
            filters: BusinessProcurementSupplierDocumentFilters(
                branchId: "br_1",
                supplierId: "sup_1",
                documentTypes: ["INVOICE", "EXPENSE"],
                statuses: [.draft, .confirmed],
                documentDateFrom: "2026-07-01",
                documentDateTo: "2026-07-31",
                dueDateFrom: "2026-08-01",
                dueDateTo: "2026-08-31",
                query: "001-001",
                limit: 30,
                cursor: "cursor_document"
            )
        )
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["documentType"], "INVOICE,EXPENSE")
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["dueDateTo"], "2026-08-31")

        client.responseData = Data(Self.emptyPayableListJSON.utf8)
        _ = try await repository.listPayables(
            organizationId: "org_1",
            filters: BusinessProcurementPayableFilters(
                branchId: "br_1",
                supplierId: "sup_1",
                settlementStatuses: ["OPEN", "PARTIALLY_PAID"],
                effectiveStatuses: [.open, .overdue],
                dueFrom: "2026-07-01",
                dueTo: "2026-08-31",
                currency: "USD",
                asOf: "2026-07-31",
                limit: 35,
                cursor: "cursor_payable"
            )
        )
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["settlementStatus"], "OPEN,PARTIALLY_PAID")
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["effectiveStatus"], "OPEN,OVERDUE")
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["asOf"], "2026-07-31")

        client.responseData = Data(Self.emptySupplierPaymentListJSON.utf8)
        _ = try await repository.listSupplierPayments(
            organizationId: "org_1",
            filters: BusinessProcurementSupplierPaymentFilters(
                branchId: "br_1",
                supplierId: "sup_1",
                statuses: [.recorded, .voided],
                paymentFrom: "2026-07-01",
                paymentTo: "2026-07-31",
                method: "BANK_TRANSFER",
                query: "TRX-1",
                limit: 45,
                cursor: "cursor_payment"
            )
        )
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["status"], "RECORDED,VOIDED")
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["paymentFrom"], "2026-07-01")
        XCTAssertEqual(client.capturedRequests.last?.queryDictionary["method"], "BANK_TRANSFER")
    }

    func testStatementJSONAndCSVKeepDateCurrencyAndPagingBoundariesSeparate() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nexo-procurement-repository-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let client = CapturingProcurementAPIClient(responseJSON: Self.statementJSON)
        let repository = BusinessProcurementAPIRepository(
            apiClient: client,
            downloadDirectory: tempDirectory
        )
        let filters = BusinessProcurementSupplierStatementFilters(
            currency: "USD",
            branchId: "br_1",
            from: "2026-07-01",
            to: "2026-07-31",
            asOf: "2026-07-31",
            limit: 75,
            cursor: "cursor_statement"
        )

        let statement = try await repository.getSupplierStatement(
            organizationId: "org_1",
            supplierId: "sup_1",
            filters: filters
        )
        XCTAssertEqual(statement.closingBalance.amount, "100.00")
        let jsonRequest = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(jsonRequest.path, BusinessProcurementRoutes.supplierStatement("sup_1"))
        XCTAssertEqual(jsonRequest.queryDictionary["limit"], "75")
        XCTAssertEqual(jsonRequest.queryDictionary["cursor"], "cursor_statement")

        client.dataResponse = APIDataResponse(
            data: Data("fecha,documento,debito,credito,saldo\n".utf8),
            statusCode: 200,
            headers: [
                "content-type": "text/csv; charset=utf-8",
                "Content-Disposition": "attachment; filename=\"../supplier-statement.csv\"",
                "X-Nexo-Export-Type": "supplier_statement",
                "X-Nexo-Export-Version": "27R.J.v1",
            ]
        )
        let downloaded = try await repository.downloadSupplierStatementCSV(
            organizationId: "org_1",
            supplierId: "sup_1",
            filters: filters
        )

        let csvRequest = try XCTUnwrap(client.capturedDataRequests.last)
        XCTAssertEqual(csvRequest.path, BusinessProcurementRoutes.supplierStatementCSV("sup_1"))
        XCTAssertEqual(csvRequest.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertNil(csvRequest.queryDictionary["limit"])
        XCTAssertNil(csvRequest.queryDictionary["cursor"])
        XCTAssertEqual(csvRequest.queryDictionary["currency"], "USD")
        XCTAssertEqual(downloaded.fileName, "supplier-statement.csv")
        XCTAssertEqual(downloaded.contentType, "text/csv; charset=utf-8")
        XCTAssertEqual(downloaded.responseHeaders["X-Nexo-Export-Version"], "27R.J.v1")
        XCTAssertEqual(try Data(contentsOf: downloaded.localURL), client.dataResponse.data)
    }

    func testAttachmentUploadUsesExactMultipartFieldsAndCanonicalIdempotencyHeader() async throws {
        let client = CapturingProcurementAPIClient(responseJSON: Self.attachmentEnvelopeJSON)
        let repository = BusinessProcurementAPIRepository(
            apiClient: client,
            boundaryProvider: { "nexo-test-boundary" }
        )
        let response = try await repository.uploadAttachment(
            organizationId: "org_1",
            idempotencyKey: IdempotencyKey(rawValue: "attachment-upload-1"),
            upload: BusinessProcurementAttachmentUpload(
                sourceType: .supplierDocument,
                sourceId: "sdoc_1",
                expectedSourceVersion: 3,
                fileName: "../factura 001.pdf",
                mediaType: .pdf,
                data: Data("%PDF-1.4".utf8)
            )
        )

        XCTAssertEqual(response.data.id, "patt_1")
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.attachments)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.idempotencyKey], "attachment-upload-1")
        XCTAssertEqual(
            request.headers["Content-Type"],
            "multipart/form-data; boundary=nexo-test-boundary"
        )
        let body = try XCTUnwrap(request.body)
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(text.contains("name=\"sourceType\"\r\n\r\nSUPPLIER_DOCUMENT\r\n"))
        XCTAssertTrue(text.contains("name=\"sourceId\"\r\n\r\nsdoc_1\r\n"))
        XCTAssertTrue(text.contains("name=\"expectedSourceVersion\"\r\n\r\n3\r\n"))
        XCTAssertTrue(text.contains("name=\"file\"; filename=\"factura 001.pdf\""))
        XCTAssertTrue(text.contains("Content-Type: application/pdf\r\n\r\n%PDF-1.4"))
        XCTAssertTrue(text.hasSuffix("\r\n--nexo-test-boundary--\r\n"))
        XCTAssertEqual(text.components(separatedBy: "name=\"file\"").count - 1, 1)
    }

    func testAttachmentDownloadAndDeleteUseOnlyAcceptedRouteAndVersionQuery() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nexo-procurement-attachment-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let client = CapturingProcurementAPIClient(responseJSON: "{}")
        client.dataResponse = APIDataResponse(
            data: Data("image".utf8),
            statusCode: 200,
            headers: [
                "Content-Type": "image/png",
                "Content-Disposition": "attachment; filename=\"..\\private\\evidence.png\"",
                "X-Content-Type-Options": "nosniff",
            ]
        )
        let repository = BusinessProcurementAPIRepository(
            apiClient: client,
            downloadDirectory: tempDirectory
        )

        let file = try await repository.downloadAttachment(
            organizationId: "org_1",
            attachmentId: "patt_1"
        )
        XCTAssertEqual(file.fileName, "evidence.png")
        XCTAssertEqual(file.contentType, "image/png")
        XCTAssertEqual(try Data(contentsOf: file.localURL), Data("image".utf8))
        XCTAssertEqual(client.capturedDataRequests.last?.path, BusinessProcurementRoutes.attachment("patt_1"))

        _ = try await repository.deleteAttachment(
            organizationId: "org_1",
            attachmentId: "patt_1",
            expectedSourceVersion: 4
        )
        let deleteRequest = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(deleteRequest.method, .delete)
        XCTAssertEqual(deleteRequest.path, BusinessProcurementRoutes.attachment("patt_1"))
        XCTAssertEqual(deleteRequest.queryDictionary, ["expectedSourceVersion": "4"])
        XCTAssertNil(deleteRequest.headers[BusinessHeaders.idempotencyKey])
    }

    func testOversizedAttachmentFailsBeforeAnyNetworkRequest() async throws {
        let client = CapturingProcurementAPIClient(responseJSON: Self.attachmentEnvelopeJSON)
        let repository = BusinessProcurementAPIRepository(apiClient: client)
        let data = Data(repeating: 0, count: BusinessProcurementContractDecision.maximumAttachmentBytes + 1)

        do {
            _ = try await repository.uploadAttachment(
                organizationId: "org_1",
                idempotencyKey: IdempotencyKey(rawValue: "attachment-too-large"),
                upload: BusinessProcurementAttachmentUpload(
                    sourceType: .supplier,
                    sourceId: "sup_1",
                    expectedSourceVersion: 1,
                    fileName: "large.pdf",
                    mediaType: .pdf,
                    data: data
                )
            )
            XCTFail("Expected the local size guard to reject the upload.")
        } catch let error as BusinessProcurementRepositoryError {
            XCTAssertEqual(
                error,
                .attachmentTooLarge(
                    maximumBytes: BusinessProcurementContractDecision.maximumAttachmentBytes
                )
            )
        }

        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    private static let emptySupplierListJSON = #"{"suppliers":[],"nextCursor":null,"hasMore":false}"#
    private static let emptyPurchaseOrderListJSON = #"{"purchaseOrders":[],"nextCursor":null,"hasMore":false}"#
    private static let emptyReceiptListJSON = #"{"purchaseReceipts":[],"nextCursor":null,"hasMore":false}"#
    private static let emptySupplierDocumentListJSON = #"{"supplierDocuments":[],"nextCursor":null,"hasMore":false}"#
    private static let emptySupplierPaymentListJSON = #"{"supplierPayments":[],"nextCursor":null,"hasMore":false}"#
    private static let emptyPayableListJSON = #"{"payables":[],"nextCursor":null,"hasMore":false,"asOf":"2026-07-31"}"#

    private static let purchaseOrderEnvelopeJSON = #"""
    {
      "data": {
        "id":"po_1","branchId":"br_1","supplierId":"sup_1","orderNumber":"OC-0001","status":"DRAFT","currency":"USD","lines":[],
        "subtotal":null,"discountTotal":null,"taxTotal":null,"total":null,"expectedDate":"2026-07-20",
        "supplierSnapshot":{"supplierId":"sup_1","legalName":"Proveedor Uno","tradeName":null,"identificationType":null,"identificationNumber":null,"paymentTerms":{"mode":"IMMEDIATE","netDays":0,"label":null,"notes":null},"defaultCurrency":"USD"},
        "paymentTermsSnapshot":{"mode":"IMMEDIATE","netDays":0,"label":null,"notes":null},"notes":null,"attachmentIds":[],
        "createdAt":"2026-07-15T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T12:00:00Z","updatedBy":"usr_1",
        "sentAt":null,"sentBy":null,"closedAt":null,"closedBy":null,"closeReason":null,"cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":1
      },
      "meta":{"requestId":"req_po","idempotencyReplayed":false}
    }
    """#

    private static let statementJSON = #"""
    {
      "supplierId":"sup_1","branchId":"br_1","currency":"USD","from":"2026-07-01","to":"2026-07-31","asOf":"2026-07-31",
      "openingBalance":{"amount":"0.00","currency":"USD"},"lines":[],"closingBalance":{"amount":"100.00","currency":"USD"},
      "nextCursor":null,"hasMore":false
    }
    """#

    private static let attachmentEnvelopeJSON = #"""
    {
      "data":{"id":"patt_1","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","fileName":"factura 001.pdf","mediaType":"application/pdf","sizeBytes":8,"checksumSha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","uploadedAt":"2026-07-15T12:00:00Z","uploadedBy":"usr_1","version":1},
      "meta":{"requestId":"req_attachment","idempotencyReplayed":false}
    }
    """#
}

private struct CapturedProcurementRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }

    func jsonObject() throws -> [String: Any] {
        let body = try XCTUnwrap(body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private final class CapturingProcurementAPIClient: APIDataClient, @unchecked Sendable {
    var responseData: Data
    var dataResponse = APIDataResponse(data: Data(), statusCode: 200, headers: [:])
    private(set) var capturedRequests: [CapturedProcurementRequest] = []
    private(set) var capturedDataRequests: [CapturedProcurementRequest] = []

    init(responseJSON: String) {
        responseData = Data(responseJSON.utf8)
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedProcurementRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers,
                body: request.body
            )
        )
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        return try JSONDecoder.nexoDefault.decode(Response.self, from: responseData)
    }

    func sendData(_ request: APIRequest<EmptyResponse>) async throws -> APIDataResponse {
        capturedDataRequests.append(
            CapturedProcurementRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers,
                body: request.body
            )
        )
        return dataResponse
    }
}
