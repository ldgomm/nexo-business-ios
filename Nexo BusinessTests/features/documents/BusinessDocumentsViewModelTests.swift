//
//  BusinessDocumentsViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

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
        let viewModel = makeViewModel(
            permissions: ["documents.view"],
            repository: repository
        )

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
        repository.error = APIError.server(
            statusCode: 403,
            code: "forbidden",
            message: "Forbidden",
            requestId: "req_1"
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para realizar esta acción.")
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

private final class MockBusinessDocumentsRepository: BusinessDocumentsRepository, @unchecked Sendable {
    var listCalls = 0
    var generateCalls = 0
    var registerPhysicalCalls = 0
    var lastGenerateIdempotencyKey: String?
    var lastPhysicalIdempotencyKey: String?
    var lastPhysicalNumber: String?
    var error: Error?

    func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse {
        if let error { throw error }
        listCalls += 1
        return BusinessDocumentsResponse(
            documents: [
                BusinessDocument(
                    id: "doc_listed",
                    saleId: saleId,
                    type: "internal_ticket",
                    status: "generated",
                    number: "T-001",
                    createdAt: Date()
                )
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
            document: BusinessDocument(
                id: "doc_generated",
                saleId: saleId,
                type: "internal_ticket",
                status: "generated",
                number: "T-002",
                createdAt: Date()
            ),
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
            document: BusinessDocument(
                id: "doc_physical",
                saleId: saleId,
                type: "physical_sale_note",
                status: "registered",
                number: request.physicalNumber,
                createdAt: Date()
            ),
            idempotencyReplayed: false
        )
    }
}
