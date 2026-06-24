//
//  BusinessExportsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 23/6/26.
//

import Foundation

enum BusinessExportsRoutes {
    static let exports = "/api/v1/business/exports"
    static let daily = "/api/v1/business/exports/daily"
    static let dailyZip = "/api/v1/business/exports/daily.zip"
    static let operationalSummary = "/api/v1/business/exports/operational/summary"
    static let operationalZip = "/api/v1/business/exports/operational.zip"
}

final class BusinessExportsAPIRepository: BusinessExportsRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let fileManager: FileManager
    private let baseDirectory: URL

    init(
        apiClient: APIClient,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.apiClient = apiClient
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? fileManager.temporaryDirectory.appendingPathComponent("nexo-business-exports", isDirectory: true)
    }

    func catalog(organizationId: String) async throws -> BusinessExportsCatalogResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessExportsRoutes.exports,
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }

    func operationalSummary(
        organizationId: String,
        branchId: String? = nil,
        from: String,
        to: String,
        label: String? = nil
    ) async throws -> BusinessOperationalSummaryResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessExportsRoutes.operationalSummary,
                queryItems: Self.periodQueryItems(branchId: branchId, from: from, to: to, label: label),
                headers: Self.headers(organizationId: organizationId, branchId: branchId)
            )
        )
    }

    func downloadOperationalZip(
        organizationId: String,
        branchId: String? = nil,
        from: String,
        to: String,
        label: String? = nil
    ) async throws -> BusinessExportDownloadedFile {
        guard let dataClient = apiClient as? APIDataClient else {
            throw APIError.transport("El cliente HTTP no soporta descarga de archivos.")
        }

        let response = try await dataClient.sendData(
            APIRequest<EmptyResponse>(
                method: .get,
                path: BusinessExportsRoutes.operationalZip,
                queryItems: Self.periodQueryItems(branchId: branchId, from: from, to: to, label: label),
                headers: Self.headers(organizationId: organizationId, branchId: branchId)
            )
        )

        return try persistDownloadedFile(
            response: response,
            fallbackFileName: "nexo_informe_operativo_inteligente.zip"
        )
    }

    func dailyMetadata(
        organizationId: String,
        branchId: String? = nil,
        businessDate: String? = nil
    ) async throws -> BusinessExportGenerateResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessExportsRoutes.daily,
                queryItems: Self.queryItems(branchId: branchId, businessDate: businessDate),
                headers: Self.headers(organizationId: organizationId, branchId: branchId)
            )
        )
    }

    func generateDaily(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request body: BusinessExportGenerateRequest
    ) async throws -> BusinessExportGenerateResponse {
        try await apiClient.send(
            try APIRequest<BusinessExportGenerateResponse>.json(
                method: .post,
                path: BusinessExportsRoutes.daily,
                body: body,
                headers: Self.headers(
                    organizationId: organizationId,
                    branchId: body.branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func downloadDailyZip(
        organizationId: String,
        branchId: String? = nil,
        businessDate: String? = nil
    ) async throws -> BusinessExportDownloadedFile {
        guard let dataClient = apiClient as? APIDataClient else {
            throw APIError.transport("El cliente HTTP no soporta descarga de archivos.")
        }

        let response = try await dataClient.sendData(
            APIRequest<EmptyResponse>(
                method: .get,
                path: BusinessExportsRoutes.dailyZip,
                queryItems: Self.queryItems(branchId: branchId, businessDate: businessDate),
                headers: Self.headers(organizationId: organizationId, branchId: branchId)
            )
        )

        return try persistDownloadedFile(
            response: response,
            fallbackFileName: "nexo_exportacion_operativa_diaria.zip"
        )
    }

    private static func periodQueryItems(branchId: String?, from: String, to: String, label: String?) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        if let branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines), !branchId.isEmpty {
            queryItems.append(URLQueryItem(name: "branchId", value: branchId))
        }
        queryItems.append(URLQueryItem(name: "from", value: from))
        queryItems.append(URLQueryItem(name: "to", value: to))
        queryItems.append(URLQueryItem(name: "timezone", value: "America/Guayaquil"))
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            queryItems.append(URLQueryItem(name: "label", value: label))
        }
        return queryItems
    }

    private static func queryItems(branchId: String?, businessDate: String?) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        if let branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines), !branchId.isEmpty {
            queryItems.append(URLQueryItem(name: "branchId", value: branchId))
        }
        if let businessDate = businessDate?.trimmingCharacters(in: .whitespacesAndNewlines), !businessDate.isEmpty {
            queryItems.append(URLQueryItem(name: "date", value: businessDate))
        }
        return queryItems
    }

    private static func headers(
        organizationId: String,
        branchId: String? = nil,
        idempotencyKey: IdempotencyKey? = nil
    ) -> [String: String] {
        var headers = [BusinessHeaders.organizationId: organizationId]
        if let branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines), !branchId.isEmpty {
            headers[BusinessHeaders.branchId] = branchId
        }
        if let idempotencyKey {
            headers[BusinessHeaders.idempotencyKey] = idempotencyKey.rawValue
        }
        return headers
    }

    private func persistDownloadedFile(
        response: APIDataResponse,
        fallbackFileName: String
    ) throws -> BusinessExportDownloadedFile {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let fileName = Self.safeFileName(
            Self.fileName(fromContentDisposition: response.headerValue("Content-Disposition")) ?? fallbackFileName
        )
        let localURL = uniqueURL(for: fileName)
        try response.data.write(to: localURL, options: [.atomic])

        return BusinessExportDownloadedFile(
            localURL: localURL,
            fileName: fileName,
            contentType: response.headerValue("Content-Type") ?? "application/zip",
            sizeBytes: response.data.count,
            sha256: response.headerValue("X-Nexo-Artifact-Sha256")
        )
    }

    private func uniqueURL(for fileName: String) -> URL {
        let candidate = baseDirectory.appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let nsName = fileName as NSString
        let base = nsName.deletingPathExtension.isEmpty ? "exportacion" : nsName.deletingPathExtension
        let ext = nsName.pathExtension.isEmpty ? "zip" : nsName.pathExtension
        return baseDirectory.appendingPathComponent("\(base)-\(UUID().uuidString).\(ext)", isDirectory: false)
    }

    private static func fileName(fromContentDisposition contentDisposition: String?) -> String? {
        guard let contentDisposition else { return nil }
        let parts = contentDisposition.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for part in parts {
            let lowercased = part.lowercased()
            if lowercased.hasPrefix("filename*=utf-8''") {
                let encoded = String(part.dropFirst("filename*=utf-8''".count))
                return encoded.removingPercentEncoding ?? encoded
            }
            if lowercased.hasPrefix("filename=") {
                return String(part.dropFirst("filename=".count)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }

    private static func safeFileName(_ rawFileName: String) -> String {
        let lastPathComponent = rawFileName
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .last
            .map(String.init) ?? rawFileName
        let sanitized = lastPathComponent
            .replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return sanitized.isEmpty ? "nexo_exportacion_operativa.zip" : sanitized
    }
}
