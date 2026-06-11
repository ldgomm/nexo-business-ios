import Foundation

enum BusinessDocumentsRoutes {
    static let electronicDocuments = "/api/v1/business/electronic-documents"
    
    static func list(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/documents"
    }
    
    static func internalTicket(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/documents/internal-ticket"
    }
    
    static func physicalSaleNote(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/documents/physical-sale-note"
    }
    
    static func issueElectronicInvoice(saleId: String) -> String {
        "/api/v1/business/sales/\(saleId)/electronic-documents/invoice"
    }
    
    static func electronicDocumentDetail(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)"
    }
    
    static func electronicDocumentRide(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/ride"
    }
    
    static func electronicDocumentXml(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/xml"
    }
    
    static func electronicDocumentTimeline(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/timeline"
    }
    
    static func electronicDocumentResendEmail(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/resend-email"
    }
    
    static func retryElectronicInvoiceReception(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/retry-reception"
    }
}

final class BusinessDocumentsAPIRepository: BusinessDocumentsRepository, @unchecked Sendable {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDocumentsRoutes.list(saleId: saleId),
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }
    
    func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request body: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse {
        try await apiClient.send(
            try APIRequest<BusinessDocumentResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.internalTicket(saleId: saleId),
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
    
    func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request body: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse {
        try await apiClient.send(
            try APIRequest<BusinessDocumentResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.physicalSaleNote(saleId: saleId),
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
    
    func issueElectronicInvoice(
        organizationId: String,
        saleId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: IssueBusinessElectronicDocumentRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse {
        try await apiClient.send(
            try APIRequest<BusinessElectronicDocumentIssueResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.issueElectronicInvoice(saleId: saleId),
                body: body,
                headers: electronicDocumentHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }
    
    func retryElectronicInvoiceReception(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request body: RetryBusinessElectronicInvoiceReceptionRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse {
        try await apiClient.send(
            try APIRequest<BusinessElectronicDocumentIssueResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.retryElectronicInvoiceReception(documentId: documentId),
                body: body,
                headers: electronicDocumentHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    revisions: nil,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }
    
    func listElectronicDocuments(
        organizationId: String,
        filters: BusinessElectronicDocumentFilters = BusinessElectronicDocumentFilters()
    ) async throws -> BusinessElectronicDocumentsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDocumentsRoutes.electronicDocuments,
                queryItems: filters.queryItems,
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }
    
    func electronicDocumentDetail(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessElectronicDocumentDetailEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDocumentsRoutes.electronicDocumentDetail(documentId: documentId),
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }
    
    func electronicDocumentRide(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDocumentsRoutes.electronicDocumentRide(documentId: documentId),
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }
    
    func electronicDocumentXml(
        organizationId: String,
        documentId: String,
        authorizedOnly: Bool = true
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDocumentsRoutes.electronicDocumentXml(documentId: documentId),
                queryItems: [URLQueryItem(name: "authorizedOnly", value: authorizedOnly ? "true" : "false")],
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }
    
    func electronicDocumentTimeline(
        organizationId: String,
        documentId: String,
        limit: Int = 100
    ) async throws -> BusinessElectronicDocumentTimelineResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessDocumentsRoutes.electronicDocumentTimeline(documentId: documentId),
                queryItems: [URLQueryItem(name: "limit", value: String(max(1, min(limit, 250))))],
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }
    
    func resendElectronicDocumentEmail(
        organizationId: String,
        documentId: String,
        request body: BusinessDocumentEmailResendRequest
    ) async throws -> BusinessDocumentEmailResendResponse {
        try await apiClient.send(
            try APIRequest<BusinessDocumentEmailResendResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.electronicDocumentResendEmail(documentId: documentId),
                body: body,
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }
    
    private func electronicDocumentHeaders(
        organizationId: String,
        branchId: String?,
        activityId: String?,
        revisions: BusinessRevisions?,
        idempotencyKey: IdempotencyKey
    ) -> [String: String] {
        var headers: [String: String] = [
            BusinessHeaders.organizationId: organizationId,
            BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
        ]
        
        if let branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines), !branchId.isEmpty {
            headers[BusinessHeaders.branchId] = branchId
        }
        
        if let activityId = activityId?.trimmingCharacters(in: .whitespacesAndNewlines), !activityId.isEmpty {
            headers[BusinessHeaders.activityId] = activityId
        }
        
        if let catalogRevision = revisions?.catalogRevision.trimmingCharacters(in: .whitespacesAndNewlines), !catalogRevision.isEmpty {
            headers[BusinessHeaders.catalogRevision] = catalogRevision
        }
        
        if let taxConfigurationRevision = revisions?.taxConfigurationRevision.trimmingCharacters(in: .whitespacesAndNewlines), !taxConfigurationRevision.isEmpty {
            headers[BusinessHeaders.taxConfigurationRevision] = taxConfigurationRevision
        }
        
        return headers
    }
}
