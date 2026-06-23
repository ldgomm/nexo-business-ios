//
//  BusinessExportsModels.swift
//  Nexo Business
//

import Foundation

enum BusinessExportKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case dailyOperational = "daily_operational"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dailyOperational:
            return "Exportación operativa diaria"
        }
    }
}

struct BusinessExportDescriptor: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: String
    let version: String?
    let title: String
    let description: String?
    let contentType: String?
    let fileName: String?
    let generatedAt: Date?
    let sizeBytes: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case exportId
        case kind
        case type
        case version
        case exportVersion
        case title
        case name
        case description
        case contentType
        case fileName
        case generatedAt
        case sizeBytes
    }

    init(
        id: String,
        kind: String,
        version: String? = nil,
        title: String,
        description: String? = nil,
        contentType: String? = nil,
        fileName: String? = nil,
        generatedAt: Date? = nil,
        sizeBytes: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.version = version
        self.title = title
        self.description = description
        self.contentType = contentType
        self.fileName = fileName
        self.generatedAt = generatedAt
        self.sizeBytes = sizeBytes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? BusinessExportKind.dailyOperational.rawValue
        version = try container.decodeIfPresent(String.self, forKey: .version)
            ?? container.decodeIfPresent(String.self, forKey: .exportVersion)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .exportId)
            ?? [kind, version].compactMap { $0 }.joined(separator: ":")
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? BusinessExportKind.dailyOperational.displayName
        description = try container.decodeIfPresent(String.self, forKey: .description)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
        sizeBytes = try container.decodeIfPresent(Int.self, forKey: .sizeBytes)
    }
}

struct BusinessExportsCatalogResponse: Decodable, Equatable, Sendable {
    let exports: [BusinessExportDescriptor]

    private enum CodingKeys: String, CodingKey {
        case exports
        case items
        case availableExports
        case data
    }

    init(exports: [BusinessExportDescriptor]) {
        self.exports = exports
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exports = try container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .exports)
            ?? container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .availableExports)
            ?? container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .data)
            ?? []
    }
}

struct BusinessExportGenerateRequest: Encodable, Equatable, Sendable {
    let kind: String
    let businessDate: String?
    let branchId: String?

    init(
        kind: String = BusinessExportKind.dailyOperational.rawValue,
        businessDate: String? = nil,
        branchId: String? = nil
    ) {
        self.kind = kind
        self.businessDate = businessDate
        self.branchId = branchId
    }
}

struct BusinessExportGenerateResponse: Decodable, Equatable, Sendable {
    let export: BusinessExportDescriptor

    private enum CodingKeys: String, CodingKey {
        case export
        case descriptor
        case data
    }

    init(export: BusinessExportDescriptor) {
        self.export = export
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let export = try? container.decode(BusinessExportDescriptor.self, forKey: .export) {
                self.export = export
                return
            }
            if let export = try? container.decode(BusinessExportDescriptor.self, forKey: .descriptor) {
                self.export = export
                return
            }
            if let export = try? container.decode(BusinessExportDescriptor.self, forKey: .data) {
                self.export = export
                return
            }
        }

        self.export = try BusinessExportDescriptor(from: decoder)
    }
}

struct BusinessExportDownloadedFile: Identifiable, Equatable, Sendable {
    let id: String
    let localURL: URL
    let fileName: String
    let contentType: String
    let sizeBytes: Int
    let sha256: String?

    init(localURL: URL, fileName: String, contentType: String, sizeBytes: Int, sha256: String? = nil) {
        self.localURL = localURL
        self.fileName = fileName
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.id = localURL.absoluteString
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}
