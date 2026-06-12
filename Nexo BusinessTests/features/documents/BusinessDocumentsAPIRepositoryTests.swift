import XCTest
@testable import Nexo_Business

final class BusinessDocumentsAPIRepositoryTests: XCTestCase {
    func testIssueElectronicInvoiceUsesCanonicalRouteAndBusinessHeaders() async throws {
        let apiClient = CapturingDocumentsAPIClient(responseJSON: Self.electronicIssueResponseJSON)
        let repository = BusinessDocumentsAPIRepository(apiClient: apiClient)

        _ = try await repository.issueElectronicInvoice(
            organizationId: "org_1",
            saleId: "sale_1",
            branchId: "br_1",
            activityId: "act_1",
            revisions: BusinessRevisions(catalogRevision: "cat_rev_1", taxConfigurationRevision: "tax_rev_1"),
            idempotencyKey: IdempotencyKey(rawValue: "document-electronic-invoice-1"),
            request: IssueBusinessElectronicDocumentRequest(signatureId: "sig_1")
        )

        let request = try XCTUnwrap(apiClient.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/business/sales/sale_1/electronic-documents/invoice")
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.headers[BusinessHeaders.activityId], "act_1")
        XCTAssertEqual(request.headers[BusinessHeaders.catalogRevision], "cat_rev_1")
        XCTAssertEqual(request.headers[BusinessHeaders.taxConfigurationRevision], "tax_rev_1")
        XCTAssertEqual(request.headers[BusinessHeaders.idempotencyKey], "document-electronic-invoice-1")
        XCTAssertEqual(request.headers["X-Idempotency-Key"], "document-electronic-invoice-1")
        XCTAssertNotNil(request.body)
    }

    func testRetryElectronicInvoiceReceptionUsesCanonicalRouteAndIdempotencyHeader() async throws {
        let apiClient = CapturingDocumentsAPIClient(responseJSON: Self.electronicIssueResponseJSON)
        let repository = BusinessDocumentsAPIRepository(apiClient: apiClient)

        _ = try await repository.retryElectronicInvoiceReception(
            organizationId: "org_1",
            documentId: "edoc_1",
            branchId: "br_1",
            activityId: "act_1",
            idempotencyKey: IdempotencyKey(rawValue: "document-electronic-invoice-retry-1"),
            request: RetryBusinessElectronicInvoiceReceptionRequest(queryAuthorizationImmediately: true)
        )

        let request = try XCTUnwrap(apiClient.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/v1/business/electronic-documents/edoc_1/retry-reception")
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.headers[BusinessHeaders.activityId], "act_1")
        XCTAssertEqual(request.headers[BusinessHeaders.idempotencyKey], "document-electronic-invoice-retry-1")
        XCTAssertEqual(request.headers["X-Idempotency-Key"], "document-electronic-invoice-retry-1")
        XCTAssertNil(request.headers[BusinessHeaders.catalogRevision])
        XCTAssertNil(request.headers[BusinessHeaders.taxConfigurationRevision])
        XCTAssertNotNil(request.body)
    }

    func testBusinessOperationalMutationsUseCanonicalRoutesAndIdempotencyHeaders() async throws {
        let apiClient = CapturingDocumentsAPIClient(responseJSON: Self.actionResponseJSON)
        let repository = BusinessDocumentsAPIRepository(apiClient: apiClient)

        _ = try await repository.retryElectronicInvoiceAuthorization(
            organizationId: "org_1",
            documentId: "edoc_1",
            branchId: "br_1",
            activityId: "act_1",
            idempotencyKey: IdempotencyKey(rawValue: "document-retry-authorization-1"),
            request: RetryBusinessElectronicInvoiceAuthorizationRequest(reason: "manual")
        )

        _ = try await repository.regenerateElectronicDocumentRide(
            organizationId: "org_1",
            documentId: "edoc_1",
            branchId: "br_1",
            activityId: "act_1",
            idempotencyKey: IdempotencyKey(rawValue: "document-regenerate-ride-1"),
            request: RegenerateBusinessElectronicDocumentRideRequest(reason: "manual")
        )

        XCTAssertEqual(apiClient.capturedRequests[0].path, "/api/v1/business/electronic-documents/edoc_1/retry-authorization")
        XCTAssertEqual(apiClient.capturedRequests[0].headers[BusinessHeaders.idempotencyKey], "document-retry-authorization-1")
        XCTAssertEqual(apiClient.capturedRequests[0].headers["X-Idempotency-Key"], "document-retry-authorization-1")
        XCTAssertEqual(apiClient.capturedRequests[1].path, "/api/v1/business/electronic-documents/edoc_1/ride")
        XCTAssertEqual(apiClient.capturedRequests[1].headers[BusinessHeaders.idempotencyKey], "document-regenerate-ride-1")
        XCTAssertEqual(apiClient.capturedRequests[1].headers["X-Idempotency-Key"], "document-regenerate-ride-1")
    }

    func testBusinessVaultRoutesUseCanonicalElectronicDocumentsPaths() async throws {
        let apiClient = CapturingDocumentsAPIClient(responseJSON: Self.electronicDocumentsListJSON)
        let repository = BusinessDocumentsAPIRepository(apiClient: apiClient)

        _ = try await repository.listElectronicDocuments(
            organizationId: "org_1",
            filters: BusinessElectronicDocumentFilters(saleId: "sale_1", status: "AUTHORIZED", environment: "test", limit: 50)
        )

        apiClient.responseData = Data(Self.electronicDetailJSON.utf8)
        _ = try await repository.electronicDocumentDetail(organizationId: "org_1", documentId: "edoc_1")

        apiClient.responseData = Data(Self.artifactEnvelopeJSON.utf8)
        _ = try await repository.electronicDocumentRide(organizationId: "org_1", documentId: "edoc_1")
        _ = try await repository.electronicDocumentXml(organizationId: "org_1", documentId: "edoc_1", authorizedOnly: true)

        apiClient.responseData = Data(Self.timelineJSON.utf8)
        _ = try await repository.electronicDocumentTimeline(organizationId: "org_1", documentId: "edoc_1", limit: 25)

        apiClient.responseData = Data(Self.emailResponseJSON.utf8)
        _ = try await repository.resendElectronicDocumentEmail(
            organizationId: "org_1",
            documentId: "edoc_1",
            idempotencyKey: IdempotencyKey(rawValue: "document-resend-email-1"),
            request: BusinessDocumentEmailResendRequest(
                recipientOverride: "cliente@example.com",
                reason: "Reenvío solicitado por cliente"
            )
        )

        let paths = apiClient.capturedRequests.map(\.path)
        XCTAssertEqual(paths[0], "/api/v1/business/electronic-documents")
        XCTAssertEqual(paths[1], "/api/v1/business/electronic-documents/edoc_1")
        XCTAssertEqual(paths[2], "/api/v1/business/electronic-documents/edoc_1/ride")
        XCTAssertEqual(paths[3], "/api/v1/business/electronic-documents/edoc_1/xml")
        XCTAssertEqual(paths[4], "/api/v1/business/electronic-documents/edoc_1/timeline")
        XCTAssertEqual(paths[5], "/api/v1/business/electronic-documents/edoc_1/resend-email")
        let legacyInvoices = "electronic-" + "invoices"
        XCTAssertTrue(apiClient.capturedRequests.allSatisfy { !$0.path.contains(legacyInvoices) })
        let legacyIssue = "documents/" + "electronic-invoice"
        XCTAssertTrue(apiClient.capturedRequests.allSatisfy { !$0.path.contains(legacyIssue) })
        XCTAssertEqual(apiClient.capturedRequests[5].headers[BusinessHeaders.idempotencyKey], "document-resend-email-1")
        XCTAssertEqual(apiClient.capturedRequests[5].headers["X-Idempotency-Key"], "document-resend-email-1")
        XCTAssertNotNil(apiClient.capturedRequests[5].body)
    }



    func testBusinessVaultDownloadsUseCanonicalFileRoutesAndWriteTempFiles() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("nexo-business-documents-api-tests-\(UUID().uuidString)", isDirectory: true)
        let apiClient = CapturingDocumentsAPIClient(responseJSON: Self.artifactEnvelopeJSON)
        let repository = BusinessDocumentsAPIRepository(
            apiClient: apiClient,
            temporaryFileStore: BusinessDocumentTemporaryFileStore(baseDirectory: tempDirectory)
        )

        apiClient.dataResponse = APIDataResponse(
            data: Data("%PDF-1.4 ride".utf8),
            statusCode: 200,
            headers: [
                "Content-Type": "application/pdf",
                "Content-Disposition": "attachment; filename=\"../private/tmp/001-001-000000123_RIDE.pdf\"",
                "X-Nexo-Artifact-Kind": "ride",
                "X-Nexo-Artifact-Sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            ]
        )
        let ride = try await repository.downloadElectronicDocumentRideFile(
            organizationId: "org_1",
            documentId: "edoc_1"
        )

        apiClient.dataResponse = APIDataResponse(
            data: Data("<autorizacion></autorizacion>".utf8),
            statusCode: 200,
            headers: [
                "Content-Type": "application/xml; charset=UTF-8",
                "Content-Disposition": "attachment; filename=\"..\\internal\\001-001-000000123_authorized.xml\"",
                "X-Nexo-Artifact-Kind": "authorizedXml",
                "X-Nexo-Artifact-Sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            ]
        )
        let xml = try await repository.downloadElectronicDocumentXmlFile(
            organizationId: "org_1",
            documentId: "edoc_1",
            authorizedOnly: true
        )

        XCTAssertEqual(apiClient.capturedDataRequests.map(\.path), [
            "/api/v1/business/electronic-documents/edoc_1/ride/file",
            "/api/v1/business/electronic-documents/edoc_1/xml/file"
        ])
        XCTAssertEqual(apiClient.capturedDataRequests[0].headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(apiClient.capturedDataRequests[1].queryItems, [URLQueryItem(name: "authorizedOnly", value: "true")])
        XCTAssertEqual(ride.contentType, "application/pdf")
        XCTAssertEqual(ride.fileName, "001-001-000000123_RIDE.pdf")
        XCTAssertEqual(ride.safeFileName, "001-001-000000123_RIDE.pdf")
        XCTAssertEqual(ride.sha256, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        XCTAssertTrue(FileManager.default.fileExists(atPath: ride.localURL.path))
        XCTAssertEqual(try Data(contentsOf: ride.localURL), Data("%PDF-1.4 ride".utf8))
        XCTAssertEqual(xml.contentType, "application/xml; charset=UTF-8")
        XCTAssertEqual(xml.fileName, "001-001-000000123_authorized.xml")
        XCTAssertEqual(xml.preparedSummaryText, "XML autorizado · 001-001-000000123_authorized.xml · 29 bytes")
        XCTAssertTrue(FileManager.default.fileExists(atPath: xml.localURL.path))
        XCTAssertEqual(try Data(contentsOf: xml.localURL), Data("<autorizacion></autorizacion>".utf8))
        XCTAssertFalse(ride.localURL.absoluteString.contains("objectKey"))
        XCTAssertFalse(xml.localURL.absoluteString.contains("bucket"))

        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private static let electronicIssueResponseJSON = #"""
    {
      "document": {
        "id": "edoc_1",
        "documentId": "edoc_1",
        "organizationId": "org_1",
        "branchId": "br_1",
        "emissionPointId": "ep_1",
        "saleId": "sale_1",
        "documentType": "electronic_invoice",
        "type": "electronic_invoice",
        "displayNumber": "001-001-000000123",
        "number": "001-001-000000123",
        "accessKey": "1234567890123456789012345678901234567890123456789",
        "claveAcceso": "1234567890123456789012345678901234567890123456789",
        "authorizationNumber": null,
        "numeroAutorizacion": null,
        "status": "RECEIVED_BY_SRI",
        "sriStatus": "RECEIVED_BY_SRI",
        "environment": "test",
        "issuedAt": "2026-06-11T14:00:00Z",
        "authorizedAt": null,
        "rideGeneratedAt": null,
        "deliveredAt": null,
        "customerEmail": "cliente@nexo.test",
        "pdfUrl": null,
        "xmlUrl": null,
        "hasRide": false,
        "hasXml": true,
        "hasErrors": false,
        "lastSriReceptionStatus": "RECIBIDA",
        "lastSriAuthorizationStatus": null,
        "lastErrorMessage": null,
        "createdAt": "2026-06-11T14:00:00Z",
        "updatedAt": "2026-06-11T14:00:30Z"
      },
      "authorized": false,
      "stoppedBeforeSri": false,
      "receptionStatus": "RECIBIDA",
      "authorizationStatus": null,
      "replayed": false
    }
    """#

    private static let electronicDocumentsListJSON = #"""
    {
      "documents": [
        {
          "id": "edoc_1",
          "documentId": "edoc_1",
          "organizationId": "org_1",
          "saleId": "sale_1",
          "documentType": "electronic_invoice",
          "displayNumber": "001-001-000000123",
          "accessKey": "1234567890123456789012345678901234567890123456789",
          "authorizationNumber": "1234567890123456789012345678901234567890123456789",
          "status": "AUTHORIZED",
          "sriStatus": "AUTORIZADO",
          "environment": "test",
          "issueDate": "2026-06-11T14:00:00Z",
          "authorizedAt": "2026-06-11T14:00:30Z",
          "updatedAt": "2026-06-11T14:00:40Z",
          "hasRide": true,
          "hasXml": true,
          "emailSentAt": "2026-06-11T14:01:00Z",
          "lastErrorMessage": null
        }
      ],
      "total": 1,
      "hasMore": false
    }
    """#

    private static let electronicDetailJSON = #"""
    {
      "document": {
        "id": "edoc_1",
        "documentId": "edoc_1",
        "summary": {
          "id": "edoc_1",
          "saleId": "sale_1",
          "documentType": "electronic_invoice",
          "displayNumber": "001-001-000000123",
          "accessKey": "1234567890123456789012345678901234567890123456789",
          "status": "AUTHORIZED",
          "environment": "test",
          "issueDate": "2026-06-11T14:00:00Z",
          "hasRide": true,
          "hasXml": true
        },
        "organizationId": "org_1",
        "saleId": "sale_1",
        "documentType": "electronic_invoice",
        "displayNumber": "001-001-000000123",
        "accessKey": "1234567890123456789012345678901234567890123456789",
        "status": "AUTHORIZED",
        "sriStatus": "AUTORIZADO",
        "environment": "test",
        "issueDate": "2026-06-11T14:00:00Z",
        "sri": { "environment": "test", "authorizationStatus": "AUTORIZADO" },
        "artifacts": {},
        "email": {},
        "timeline": [],
        "errors": [],
        "warnings": []
      }
    }
    """#

    private static let artifactEnvelopeJSON = #"""
    {
      "artifact": {
        "kind": "ride",
        "fileName": "001-001-000000123.pdf",
        "contentType": "application/pdf",
        "sizeBytes": 1234,
        "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      },
      "ride": {
        "kind": "ride",
        "fileName": "001-001-000000123.pdf",
        "contentType": "application/pdf",
        "sizeBytes": 1234,
        "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }
    }
    """#

    private static let timelineJSON = #"""
    {
      "documentId": "edoc_1",
      "events": [
        { "id": "evt_1", "action": "AUTHORIZED", "message": "Autorizado", "actorUserId": "usr_1", "occurredAt": "2026-06-11T14:00:30Z" }
      ]
    }
    """#

    private static let emailResponseJSON = #"""
    {
      "documentId": "edoc_1",
      "accepted": true,
      "recipient": "cliente@example.com",
      "message": "Email resend requested.",
      "requestedAt": "2026-06-11T15:00:00Z"
    }
    """#

    private static let actionResponseJSON = #"""
    {
      "documentId": "edoc_1",
      "accepted": true,
      "status": "queued",
      "message": "Action queued.",
      "requestedAt": "2026-06-11T15:00:00Z",
      "idempotencyReplayed": false
    }
    """#
}

private struct CapturedDocumentsAPIRequest: Equatable {
    let method: HTTPMethod
    let path: String
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Data?
}

private final class CapturingDocumentsAPIClient: APIDataClient, @unchecked Sendable {
    var responseData: Data
    var dataResponse = APIDataResponse(data: Data(), statusCode: 200, headers: [:])
    private(set) var capturedRequests: [CapturedDocumentsAPIRequest] = []
    private(set) var capturedDataRequests: [CapturedDocumentsAPIRequest] = []

    init(responseJSON: String) {
        self.responseData = Data(responseJSON.utf8)
    }

    func send<Response>(_ request: APIRequest<Response>) async throws -> Response where Response: Decodable {
        capturedRequests.append(
            CapturedDocumentsAPIRequest(
                method: request.method,
                path: request.path,
                headers: request.headers,
                queryItems: request.queryItems,
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
            CapturedDocumentsAPIRequest(
                method: request.method,
                path: request.path,
                headers: request.headers,
                queryItems: request.queryItems,
                body: request.body
            )
        )
        return dataResponse
    }
}
