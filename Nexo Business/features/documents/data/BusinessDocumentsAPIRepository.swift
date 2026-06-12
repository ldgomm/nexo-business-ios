//
//  BusinessDocumentsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

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

    static func electronicDocumentRideFile(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/ride/file"
    }

    static func electronicDocumentXml(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/xml"
    }

    static func electronicDocumentXmlFile(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/xml/file"
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

    static func retryElectronicInvoiceAuthorization(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/retry-authorization"
    }

    static func regenerateElectronicDocumentRide(documentId: String) -> String {
        "/api/v1/business/electronic-documents/\(documentId)/ride"
    }
}

final class BusinessDocumentsAPIRepository: BusinessDocumentsRepository, BusinessDocumentFileDownloadingRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let temporaryFileStore: BusinessDocumentTemporaryFileStore

    init(
        apiClient: APIClient,
        temporaryFileStore: BusinessDocumentTemporaryFileStore = BusinessDocumentTemporaryFileStore()
    ) {
        self.apiClient = apiClient
        self.temporaryFileStore = temporaryFileStore
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

    func retryElectronicInvoiceAuthorization(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request body: RetryBusinessElectronicInvoiceAuthorizationRequest
    ) async throws -> BusinessElectronicDocumentActionResponse {
        try await apiClient.send(
            try APIRequest<BusinessElectronicDocumentActionResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.retryElectronicInvoiceAuthorization(documentId: documentId),
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

    func regenerateElectronicDocumentRide(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request body: RegenerateBusinessElectronicDocumentRideRequest
    ) async throws -> BusinessElectronicDocumentActionResponse {
        try await apiClient.send(
            try APIRequest<BusinessElectronicDocumentActionResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.regenerateElectronicDocumentRide(documentId: documentId),
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

    func downloadElectronicDocumentRideFile(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessDocumentDownloadedFile {
        try await downloadElectronicDocumentFile(
            organizationId: organizationId,
            path: BusinessDocumentsRoutes.electronicDocumentRideFile(documentId: documentId),
            queryItems: [],
            kind: .ride,
            fallbackFileName: "\(documentId)_RIDE.pdf",
            fallbackContentType: "application/pdf"
        )
    }

    func downloadElectronicDocumentXmlFile(
        organizationId: String,
        documentId: String,
        authorizedOnly: Bool = true
    ) async throws -> BusinessDocumentDownloadedFile {
        try await downloadElectronicDocumentFile(
            organizationId: organizationId,
            path: BusinessDocumentsRoutes.electronicDocumentXmlFile(documentId: documentId),
            queryItems: [URLQueryItem(name: "authorizedOnly", value: authorizedOnly ? "true" : "false")],
            kind: authorizedOnly ? .authorizedXml : .signedXml,
            fallbackFileName: authorizedOnly ? "\(documentId)_authorized.xml" : "\(documentId)_signed.xml",
            fallbackContentType: "application/xml; charset=UTF-8"
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
        idempotencyKey: IdempotencyKey,
        request body: BusinessDocumentEmailResendRequest
    ) async throws -> BusinessDocumentEmailResendResponse {
        try await apiClient.send(
            try APIRequest<BusinessDocumentEmailResendResponse>.json(
                method: .post,
                path: BusinessDocumentsRoutes.electronicDocumentResendEmail(documentId: documentId),
                body: body,
                headers: electronicDocumentHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: nil,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    private func downloadElectronicDocumentFile(
        organizationId: String,
        path: String,
        queryItems: [URLQueryItem],
        kind: BusinessDocumentArtifactKind,
        fallbackFileName: String,
        fallbackContentType: String
    ) async throws -> BusinessDocumentDownloadedFile {
        guard let dataClient = apiClient as? APIDataClient else {
            throw APIError.transport("El cliente HTTP no soporta descarga de archivos.")
        }

        let response = try await dataClient.sendData(
            APIRequest<EmptyResponse>(
                method: .get,
                path: path,
                queryItems: queryItems,
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )

        let contentType = response.headerValue("Content-Type")?.trimmedNilIfBlank ?? fallbackContentType
        let fileName = Self.fileName(fromContentDisposition: response.headerValue("Content-Disposition"))
        let sha256 = response.headerValue("X-Nexo-Artifact-Sha256")?.trimmedNilIfBlank

        return try temporaryFileStore.write(
            data: response.data,
            preferredFileName: fileName,
            fallbackFileName: fallbackFileName,
            contentType: contentType,
            sha256: sha256,
            kind: kind
        )
    }

    private static func fileName(fromContentDisposition contentDisposition: String?) -> String? {
        guard let contentDisposition else { return nil }

        let parts = contentDisposition.split(separator: ";").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for part in parts {
            let lowercased = part.lowercased()
            if lowercased.hasPrefix("filename*=utf-8''") {
                let encoded = String(part.dropFirst("filename*=utf-8''".count))
                return encoded.removingPercentEncoding ?? encoded
            }

            if lowercased.hasPrefix("filename=") {
                return String(part.dropFirst("filename=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    .trimmedNilIfBlank
            }
        }

        return nil
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
            BusinessHeaders.idempotencyKey: idempotencyKey.rawValue,
            "X-Idempotency-Key": idempotencyKey.rawValue
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

private extension String {
    var trimmedNilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
