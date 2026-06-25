//
//  BusinessProformasAPIRepository.swift
//  Nexo Business
//
//  21J.10 — Business iOS Proformas MVP
//

import Foundation

enum BusinessProformaRoutes {
    static let base = "/api/v1/business/proformas"

    static func detail(_ proformaId: String) -> String {
        "\(base)/\(proformaId)"
    }

    static func send(_ proformaId: String) -> String {
        "\(base)/\(proformaId)/send"
    }

    static func accept(_ proformaId: String) -> String {
        "\(base)/\(proformaId)/accept"
    }

    static func reject(_ proformaId: String) -> String {
        "\(base)/\(proformaId)/reject"
    }

    static func expire(_ proformaId: String) -> String {
        "\(base)/\(proformaId)/expire"
    }

    static func revision(_ proformaId: String) -> String {
        "\(base)/\(proformaId)/revision"
    }

    static func convertToSale(_ proformaId: String) -> String {
        "\(base)/\(proformaId)/convert-to-sale"
    }

    static func documentHtml(_ proformaId: String) -> String {
        "\(base)/\(proformaId)/document.html"
    }
}

final class BusinessProformasAPIRepository: BusinessProformasRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let dataClient: APIDataClient?
    private let fileManager: FileManager
    private let documentsDirectory: URL

    init(
        apiClient: APIClient,
        fileManager: FileManager = .default,
        documentsDirectory: URL? = nil
    ) {
        self.apiClient = apiClient
        self.dataClient = apiClient as? APIDataClient
        self.fileManager = fileManager
        self.documentsDirectory = documentsDirectory ?? fileManager.temporaryDirectory.appendingPathComponent(
            "nexo-business-proformas",
            isDirectory: true
        )
    }

    func listProformas(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        status: BusinessProformaStatus?,
        search: String,
        limit: Int
    ) async throws -> [BusinessProforma] {
        var queryItems = [
            URLQueryItem(name: "branchId", value: branchId),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let status, status != .unknown {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }

        let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: trimmedSearch))
        }

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProformaRoutes.base,
                queryItems: queryItems,
                headers: contextHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: nil,
                    revisions: revisions
                )
            )
        )
    }

    func getProforma(
        organizationId: String,
        proformaId: String
    ) async throws -> BusinessProforma {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProformaRoutes.detail(proformaId),
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }

    func createProforma(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: CreateBusinessProformaRequest
    ) async throws -> BusinessProforma {
        try await apiClient.send(
            try APIRequest<BusinessProforma>.json(
                method: .post,
                path: BusinessProformaRoutes.base,
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: body.branchId,
                    activityId: body.activityId,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func updateDraft(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: UpdateDraftBusinessProformaRequest
    ) async throws -> BusinessProforma {
        try await apiClient.send(
            try APIRequest<BusinessProforma>.json(
                method: .put,
                path: BusinessProformaRoutes.detail(proformaId),
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func send(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProforma {
        try await mutationWithoutBody(
            organizationId: organizationId,
            proformaId: proformaId,
            path: BusinessProformaRoutes.send(proformaId),
            revisions: revisions,
            idempotencyKey: idempotencyKey
        )
    }

    func accept(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProforma {
        try await mutationWithoutBody(
            organizationId: organizationId,
            proformaId: proformaId,
            path: BusinessProformaRoutes.accept(proformaId),
            revisions: revisions,
            idempotencyKey: idempotencyKey
        )
    }

    func reject(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        reason: String
    ) async throws -> BusinessProforma {
        try await apiClient.send(
            try APIRequest<BusinessProforma>.json(
                method: .post,
                path: BusinessProformaRoutes.reject(proformaId),
                body: ChangeBusinessProformaStatusRequest(reason: reason),
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func expire(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProforma {
        try await mutationWithoutBody(
            organizationId: organizationId,
            proformaId: proformaId,
            path: BusinessProformaRoutes.expire(proformaId),
            revisions: revisions,
            idempotencyKey: idempotencyKey
        )
    }

    func createRevision(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request body: CreateBusinessProformaRevisionRequest
    ) async throws -> BusinessProforma {
        try await apiClient.send(
            try APIRequest<BusinessProforma>.json(
                method: .post,
                path: BusinessProformaRoutes.revision(proformaId),
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func convertToSale(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProformaConvertToSaleResponse {
        let response: BusinessProformaConvertToSaleResponse = try await apiClient.send(
            try APIRequest<BusinessProformaConvertToSaleResponse>.json(
                method: .post,
                path: BusinessProformaRoutes.convertToSale(proformaId),
                body: ConvertBusinessProformaToSaleRequest(idempotencyKey: idempotencyKey.rawValue),
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )

        if response.hasForbiddenSideEffects {
            throw APIError.transport("La conversión reportó efectos prohibidos: pago, caja, factura, XML, RIDE o SRI.")
        }

        return response
    }

    func downloadDocumentHtml(
        organizationId: String,
        proformaId: String
    ) async throws -> BusinessProformaDownloadedDocument {
        guard let dataClient else {
            throw APIError.transport("El cliente HTTP no soporta descarga del documento comercial.")
        }

        let response = try await dataClient.sendData(
            APIRequest<EmptyResponse>(
                method: .get,
                path: BusinessProformaRoutes.documentHtml(proformaId),
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )

        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        let disposition = response.headerValue("Content-Disposition")
        let fileName = Self.fileName(fromContentDisposition: disposition) ?? "proforma-\(proformaId).html"
        let safeFileName = Self.safeFileName(fileName, fallback: "proforma-\(proformaId).html")
        let localURL = uniqueURL(for: safeFileName)
        try response.data.write(to: localURL, options: [.atomic])

        return BusinessProformaDownloadedDocument(
            localURL: localURL,
            fileName: safeFileName,
            contentType: response.headerValue("Content-Type") ?? "text/html",
            sizeBytes: response.data.count
        )
    }

    private func mutationWithoutBody(
        organizationId: String,
        proformaId: String,
        path: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) async throws -> BusinessProforma {
        try await apiClient.send(
            APIRequest(
                method: .post,
                path: path,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: nil,
                    activityId: nil,
                    revisions: revisions,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    private func contextHeaders(
        organizationId: String,
        branchId: String?,
        activityId: String?,
        revisions: BusinessRevisions
    ) -> [String: String] {
        var headers = revisions.headers
        headers[BusinessHeaders.organizationId] = organizationId

        if let branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines), !branchId.isEmpty {
            headers[BusinessHeaders.branchId] = branchId
        }

        if let activityId = activityId?.trimmingCharacters(in: .whitespacesAndNewlines), !activityId.isEmpty {
            headers[BusinessHeaders.activityId] = activityId
        }

        return headers
    }

    private func mutationHeaders(
        organizationId: String,
        branchId: String?,
        activityId: String?,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey
    ) -> [String: String] {
        var headers = contextHeaders(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            revisions: revisions
        )
        headers[BusinessHeaders.idempotencyKey] = idempotencyKey.rawValue
        return headers
    }

    private func uniqueURL(for fileName: String) -> URL {
        let candidate = documentsDirectory.appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let nsName = fileName as NSString
        let base = nsName.deletingPathExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "proforma"
            : nsName.deletingPathExtension
        let ext = nsName.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let unique = ext.isEmpty
            ? "\(base)-\(UUID().uuidString)"
            : "\(base)-\(UUID().uuidString).\(ext)"
        return documentsDirectory.appendingPathComponent(unique, isDirectory: false)
    }

    private static func fileName(fromContentDisposition value: String?) -> String? {
        guard let value else { return nil }
        return value
            .components(separatedBy: ";")
            .compactMap { part -> String? in
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.lowercased().hasPrefix("filename=") else { return nil }
                return trimmed
                    .dropFirst("filename=".count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            .first
    }

    private static func safeFileName(_ rawFileName: String, fallback: String) -> String {
        let lastPathComponent = rawFileName
            .components(separatedBy: CharacterSet(charactersIn: "/\\"))
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let candidate = (lastPathComponent?.isEmpty == false ? lastPathComponent : fallback) ?? fallback
        let sanitized = candidate
            .replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
            .prefix(160)
        let result = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return result.isEmpty ? fallback : result
    }
}
