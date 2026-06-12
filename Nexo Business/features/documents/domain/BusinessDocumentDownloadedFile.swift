//
//  BusinessDocumentDownloadedFile.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

struct BusinessDocumentDownloadedFile: Identifiable, Equatable, Sendable {
    let id: String
    let localURL: URL
    let fileName: String
    let contentType: String
    let sizeBytes: Int
    let sha256: String?
    let kind: BusinessDocumentArtifactKind

    init(
        localURL: URL,
        fileName: String,
        contentType: String,
        sizeBytes: Int,
        sha256: String?,
        kind: BusinessDocumentArtifactKind
    ) {
        self.localURL = localURL
        self.fileName = fileName
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.kind = kind
        self.id = localURL.absoluteString
    }

    var humanName: String {
        switch kind {
        case .ride, .ridePdf:
            return "RIDE PDF"
        case .authorizedXml, .xml:
            return "XML autorizado"
        case .signedXml:
            return "XML firmado"
        default:
            return kind.displayName
        }
    }
}

protocol BusinessDocumentFileDownloadingRepository: BusinessDocumentsRepository {
    func downloadElectronicDocumentRideFile(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessDocumentDownloadedFile

    func downloadElectronicDocumentXmlFile(
        organizationId: String,
        documentId: String,
        authorizedOnly: Bool
    ) async throws -> BusinessDocumentDownloadedFile
}
