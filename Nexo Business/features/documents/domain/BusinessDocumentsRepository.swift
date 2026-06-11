import Foundation

protocol BusinessDocumentsRepository: Sendable {
    func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse

    func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse

    func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse

    func issueElectronicInvoice(
        organizationId: String,
        saleId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: IssueBusinessElectronicDocumentRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse

    func retryElectronicInvoiceReception(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RetryBusinessElectronicInvoiceReceptionRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse

    func listElectronicDocuments(
        organizationId: String,
        filters: BusinessElectronicDocumentFilters
    ) async throws -> BusinessElectronicDocumentsResponse

    func electronicDocumentDetail(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessElectronicDocumentDetailEnvelopeResponse

    func electronicDocumentRide(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse

    func electronicDocumentXml(
        organizationId: String,
        documentId: String,
        authorizedOnly: Bool
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse

    func electronicDocumentTimeline(
        organizationId: String,
        documentId: String,
        limit: Int
    ) async throws -> BusinessElectronicDocumentTimelineResponse

    func resendElectronicDocumentEmail(
        organizationId: String,
        documentId: String,
        request: BusinessDocumentEmailResendRequest
    ) async throws -> BusinessDocumentEmailResendResponse
}
