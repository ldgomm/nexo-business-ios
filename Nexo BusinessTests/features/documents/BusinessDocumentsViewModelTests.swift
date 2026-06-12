import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessDocumentsViewModelTests: XCTestCase {
    func testLoadDocumentsUsesRepository() async {
        let repository = MockBusinessDocumentsRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(repository.listCalls, 1)
        XCTAssertEqual(viewModel.documents.count, 1)
        XCTAssertEqual(viewModel.documents.first?.type, "internal_ticket")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testGenerateInternalTicketRequiresPermission() async {
        let repository = MockBusinessDocumentsRepository()
        let viewModel = makeViewModel(permissions: ["documents.view"], repository: repository)

        await viewModel.generateInternalTicket()

        XCTAssertEqual(repository.generateCalls, 0)
        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para generar ticket interno.")
    }

    func testGenerateInternalTicketUpsertsDocument() async {
        let repository = MockBusinessDocumentsRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.generateInternalTicket()

        XCTAssertEqual(repository.generateCalls, 1)
        XCTAssertEqual(repository.lastGenerateIdempotencyKey?.hasPrefix("document-internal-ticket-"), true)
        XCTAssertEqual(viewModel.documents.first?.id, "doc_generated")
        XCTAssertEqual(viewModel.infoMessage, "Ticket interno generado correctamente.")
    }

    func testRegisterPhysicalSaleNoteRequiresNumber() async {
        let repository = MockBusinessDocumentsRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.registerPhysicalSaleNote()

        XCTAssertEqual(repository.registerPhysicalCalls, 0)
        XCTAssertEqual(viewModel.errorMessage, "Ingresa el número físico de la nota de venta.")
    }

    func testRegisterPhysicalSaleNoteSendsNumberAndIdempotencyKey() async {
        let repository = MockBusinessDocumentsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.physicalSaleNoteNumber = " 001-001-000000123 "

        await viewModel.registerPhysicalSaleNote()

        XCTAssertEqual(repository.registerPhysicalCalls, 1)
        XCTAssertEqual(repository.lastPhysicalNumber, "001-001-000000123")
        XCTAssertEqual(repository.lastPhysicalIdempotencyKey?.hasPrefix("document-physical-sale-note-"), true)
        XCTAssertEqual(viewModel.documents.first?.type, "physical_sale_note")
    }

    func testServerErrorShowsHumanMessage() async {
        let repository = MockBusinessDocumentsRepository()
        repository.error = APIError.server(statusCode: 403, code: "forbidden", message: "Forbidden", requestId: "req_1")
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para realizar esta acción.")
    }

    func testElectronicDocumentsVaultLoadsList() async {
        let repository = MockBusinessDocumentsRepository()
        let viewModel = BusinessElectronicDocumentsViewModel(
            organizationId: "org_1",
            effectivePermissions: ["documents.electronic_invoice.list"],
            documentsRepository: repository
        )

        await viewModel.load()

        XCTAssertEqual(repository.listElectronicDocumentsCalls, 1)
        XCTAssertEqual(viewModel.documents.first?.id, "edoc_1")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testElectronicDocumentDetailDownloadsArtifactsAndResendsEmail() async {
        let repository = MockBusinessDocumentsRepository()
        let viewModel = BusinessElectronicDocumentDetailViewModel(
            organizationId: "org_1",
            documentId: "edoc_1",
            effectivePermissions: [
                "documents.electronic_invoice.view",
                "documents.electronic_invoice.download_ride",
                "documents.electronic_invoice.download_xml",
                "documents.electronic_invoice.email",
                "documents.electronic_invoice.view_audit"
            ],
            documentsRepository: repository
        )

        await viewModel.load()
        await viewModel.downloadRide()
        await viewModel.downloadXml()
        await viewModel.shareRide()
        await viewModel.shareXml()
        await viewModel.loadTimeline()
        await viewModel.resendEmail()

        XCTAssertEqual(repository.detailCalls, 2)
        XCTAssertEqual(repository.rideFileDownloadCalls, 2)
        XCTAssertEqual(repository.xmlFileDownloadCalls, 2)
        XCTAssertEqual(repository.timelineCalls, 1)
        XCTAssertEqual(repository.resendEmailCalls, 1)
        XCTAssertEqual(viewModel.lastDownloadedFile?.humanName, "XML autorizado")
        XCTAssertNotNil(viewModel.previewFile)
        XCTAssertNotNil(viewModel.shareFile)
    }

    private func makeViewModel(
        permissions: Set<String> = [
            "documents.view",
            "documents.issue_internal_ticket",
            "documents.register_physical_sale_note"
        ],
        repository: MockBusinessDocumentsRepository
    ) -> BusinessDocumentsViewModel {
        BusinessDocumentsViewModel(
            organizationId: "org_1",
            sale: PreviewData.confirmedSaleResponse.sale,
            effectivePermissions: permissions,
            documentsRepository: repository
        )
    }
}

final class MockBusinessDocumentsRepository: BusinessDocumentFileDownloadingRepository, @unchecked Sendable {
    var listCalls = 0
    var generateCalls = 0
    var registerPhysicalCalls = 0
    var issueElectronicInvoiceCalls = 0
    var retryElectronicInvoiceReceptionCalls = 0
    var listElectronicDocumentsCalls = 0
    var detailCalls = 0
    var rideCalls = 0
    var xmlCalls = 0
    var timelineCalls = 0
    var resendEmailCalls = 0
    var rideFileDownloadCalls = 0
    var xmlFileDownloadCalls = 0
    var lastGenerateIdempotencyKey: String?
    var lastPhysicalIdempotencyKey: String?
    var lastElectronicInvoiceIdempotencyKey: String?
    var lastRetryReceptionIdempotencyKey: String?
    var lastPhysicalNumber: String?
    var error: Error?

    func list(organizationId: String, saleId: String) async throws -> BusinessDocumentsResponse {
        if let error { throw error }
        listCalls += 1
        return BusinessDocumentsResponse(
            documents: [
                BusinessDocument(id: "doc_listed", saleId: saleId, type: "internal_ticket", status: "generated", number: "T-001", createdAt: Date())
            ]
        )
    }

    func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse {
        if let error { throw error }
        generateCalls += 1
        lastGenerateIdempotencyKey = idempotencyKey.rawValue
        return BusinessDocumentResponse(
            document: BusinessDocument(id: "doc_generated", saleId: saleId, type: "internal_ticket", status: "generated", number: "T-002", createdAt: Date()),
            idempotencyReplayed: false
        )
    }

    func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse {
        if let error { throw error }
        registerPhysicalCalls += 1
        lastPhysicalIdempotencyKey = idempotencyKey.rawValue
        lastPhysicalNumber = request.physicalNumber
        return BusinessDocumentResponse(
            document: BusinessDocument(id: "doc_physical", saleId: saleId, type: "physical_sale_note", status: "registered", number: request.physicalNumber, createdAt: Date()),
            idempotencyReplayed: false
        )
    }

    func issueElectronicInvoice(
        organizationId: String,
        saleId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: IssueBusinessElectronicDocumentRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse {
        if let error { throw error }
        issueElectronicInvoiceCalls += 1
        lastElectronicInvoiceIdempotencyKey = idempotencyKey.rawValue
        return BusinessElectronicDocumentIssueResponse(
            document: BusinessDocument(id: "edoc_issued", saleId: saleId, type: "electronic_invoice", status: "RECEIVED_BY_SRI", number: "001-001-000000123", accessKey: "1234567890123456789012345678901234567890123456789", createdAt: Date()),
            authorized: false,
            stoppedBeforeSri: false,
            receptionStatus: "RECIBIDA",
            authorizationStatus: nil,
            replayed: false
        )
    }

    func retryElectronicInvoiceReception(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RetryBusinessElectronicInvoiceReceptionRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse {
        if let error { throw error }
        retryElectronicInvoiceReceptionCalls += 1
        lastRetryReceptionIdempotencyKey = idempotencyKey.rawValue
        return BusinessElectronicDocumentIssueResponse(
            document: BusinessDocument(id: documentId, saleId: "sale_1", type: "electronic_invoice", status: "RECEIVED_BY_SRI", number: "001-001-000000123", accessKey: "1234567890123456789012345678901234567890123456789", createdAt: Date()),
            authorized: false,
            stoppedBeforeSri: false,
            receptionStatus: "RECIBIDA",
            authorizationStatus: nil,
            replayed: false
        )
    }

    func listElectronicDocuments(
        organizationId: String,
        filters: BusinessElectronicDocumentFilters
    ) async throws -> BusinessElectronicDocumentsResponse {
        if let error { throw error }
        listElectronicDocumentsCalls += 1
        return BusinessElectronicDocumentsResponse(
            documents: [
                BusinessDocument(
                    id: "edoc_1",
                    saleId: "sale_1",
                    type: "electronic_invoice",
                    status: "AUTHORIZED",
                    number: "001-001-000000123",
                    authorizationNumber: "1234567890123456789012345678901234567890123456789",
                    accessKey: "1234567890123456789012345678901234567890123456789",
                    customerEmail: "cliente@nexo.test",
                    createdAt: Date(),
                    authorizedAt: Date(),
                    documentId: "edoc_1",
                    organizationId: organizationId,
                    environment: "test",
                    sriStatus: "AUTORIZADO",
                    hasRide: true,
                    hasXml: true
                )
            ]
        )
    }

    func electronicDocumentDetail(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessElectronicDocumentDetailEnvelopeResponse {
        if let error { throw error }
        detailCalls += 1
        let json = #"""
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
        """#.data(using: .utf8)!
        return try JSONDecoder.nexoDefault.decode(BusinessElectronicDocumentDetailEnvelopeResponse.self, from: json)
    }

    func electronicDocumentRide(organizationId: String, documentId: String) async throws -> BusinessDocumentArtifactEnvelopeResponse {
        if let error { throw error }
        rideCalls += 1
        let artifact = BusinessDocumentArtifact(kind: "ride", fileName: "001-001-000000123.pdf", contentType: "application/pdf")
        return BusinessDocumentArtifactEnvelopeResponse(artifact: artifact, ride: artifact, xml: nil)
    }

    func electronicDocumentXml(organizationId: String, documentId: String, authorizedOnly: Bool) async throws -> BusinessDocumentArtifactEnvelopeResponse {
        if let error { throw error }
        xmlCalls += 1
        let artifact = BusinessDocumentArtifact(kind: "authorizedXml", fileName: "001-001-000000123-authorized.xml", contentType: "application/xml")
        return BusinessDocumentArtifactEnvelopeResponse(artifact: artifact, ride: nil, xml: artifact)
    }

    func downloadElectronicDocumentRideFile(organizationId: String, documentId: String) async throws -> BusinessDocumentDownloadedFile {
        if let error { throw error }
        rideFileDownloadCalls += 1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("001-001-000000123_RIDE.pdf")
        try Data("%PDF-1.4 ride".utf8).write(to: url, options: [.atomic])
        return BusinessDocumentDownloadedFile(
            localURL: url,
            fileName: "001-001-000000123_RIDE.pdf",
            contentType: "application/pdf",
            sizeBytes: 13,
            sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            kind: .ride
        )
    }

    func downloadElectronicDocumentXmlFile(organizationId: String, documentId: String, authorizedOnly: Bool) async throws -> BusinessDocumentDownloadedFile {
        if let error { throw error }
        xmlFileDownloadCalls += 1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("001-001-000000123_authorized.xml")
        try Data("<autorizacion/>".utf8).write(to: url, options: [.atomic])
        return BusinessDocumentDownloadedFile(
            localURL: url,
            fileName: "001-001-000000123_authorized.xml",
            contentType: "application/xml; charset=UTF-8",
            sizeBytes: 15,
            sha256: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            kind: authorizedOnly ? .authorizedXml : .signedXml
        )
    }

    func electronicDocumentTimeline(organizationId: String, documentId: String, limit: Int) async throws -> BusinessElectronicDocumentTimelineResponse {
        if let error { throw error }
        timelineCalls += 1
        return BusinessElectronicDocumentTimelineResponse(
            documentId: documentId,
            events: [
                BusinessElectronicDocumentTimelineEvent(id: "evt_1", type: "AUTHORIZED", title: "Autorizado", message: "Comprobante autorizado", actor: "system", createdAt: Date(), severity: "info")
            ]
        )
    }

    func resendElectronicDocumentEmail(
        organizationId: String,
        documentId: String,
        request: BusinessDocumentEmailResendRequest
    ) async throws -> BusinessDocumentEmailResendResponse {
        if let error { throw error }
        resendEmailCalls += 1
        return BusinessDocumentEmailResendResponse(
            documentId: documentId,
            accepted: true,
            recipient: request.recipientOverride ?? "cliente@nexo.test",
            message: "Email resend requested.",
            requestedAt: Date()
        )
    }
}
