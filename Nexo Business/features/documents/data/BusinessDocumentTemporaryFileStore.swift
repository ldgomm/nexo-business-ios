//
//  BusinessDocumentTemporaryFileStore.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

final class BusinessDocumentTemporaryFileStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let baseDirectory: URL

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? fileManager.temporaryDirectory.appendingPathComponent(
            "nexo-business-document-vault",
            isDirectory: true
        )
    }

    func write(
        data: Data,
        preferredFileName: String?,
        fallbackFileName: String,
        contentType: String,
        sha256: String?,
        kind: BusinessDocumentArtifactKind
    ) throws -> BusinessDocumentDownloadedFile {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        let fileName = Self.safeFileName(
            preferredFileName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? fallbackFileName,
            fallback: fallbackFileName
        )
        let localURL = uniqueURL(for: fileName)
        try data.write(to: localURL, options: [.atomic])

        return BusinessDocumentDownloadedFile(
            localURL: localURL,
            fileName: fileName,
            contentType: contentType.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "application/octet-stream",
            sizeBytes: data.count,
            sha256: sha256?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            kind: kind
        )
    }

    func removeAllTemporaryDocumentFiles() throws {
        guard fileManager.fileExists(atPath: baseDirectory.path) else { return }
        try fileManager.removeItem(at: baseDirectory)
    }

    private func uniqueURL(for fileName: String) -> URL {
        let candidate = baseDirectory.appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let nsName = fileName as NSString
        let base = nsName.deletingPathExtension.nilIfBlank ?? "documento"
        let ext = nsName.pathExtension.nilIfBlank
        let uniqueName = [base, UUID().uuidString]
            .joined(separator: "-")
            .appending(ext.map { ".\($0)" } ?? "")

        return baseDirectory.appendingPathComponent(uniqueName, isDirectory: false)
    }

    static func safeFileName(_ rawFileName: String, fallback: String) -> String {
        let lastPathComponent = rawFileName
            .components(separatedBy: CharacterSet(charactersIn: "/\\"))
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let candidate = lastPathComponent?.nilIfBlank ?? fallback
        let sanitized = candidate
            .replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
            .prefix(160)

        let result = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return result.nilIfBlank ?? "documento-electronico.bin"
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
