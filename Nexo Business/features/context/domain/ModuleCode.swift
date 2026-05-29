//
//  ModuleCode.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct ModuleCode: RawRepresentable, Codable, Equatable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let coreSales: ModuleCode = "core.sales"
    public static let coreCash: ModuleCode = "core.cash"
    public static let coreDocuments: ModuleCode = "core.documents"
    public static let coreReceivables: ModuleCode = "core.receivables"
    public static let foundationIdempotency: ModuleCode = "foundation.idempotency"
    public static let foundationCatalogRevision: ModuleCode = "foundation.catalog_revision"
    public static let foundationTaxRevision: ModuleCode = "foundation.tax_revision"
    public static let foundationOutbox: ModuleCode = "foundation.outbox"
    public static let foundationDeviceRegistry: ModuleCode = "foundation.device_registry"
}
