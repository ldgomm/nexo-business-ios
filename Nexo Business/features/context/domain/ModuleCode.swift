//
//  ModuleCode.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct ModuleCode: RawRepresentable, Codable, Equatable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let coreSales: ModuleCode = "core.sales"
    static let coreCash: ModuleCode = "core.cash"
    static let coreDocuments: ModuleCode = "core.documents"
    static let coreReceivables: ModuleCode = "core.receivables"
    static let foundationIdempotency: ModuleCode = "foundation.idempotency"
    static let foundationCatalogRevision: ModuleCode = "foundation.catalog_revision"
    static let foundationTaxRevision: ModuleCode = "foundation.tax_revision"
    static let foundationOutbox: ModuleCode = "foundation.outbox"
    static let foundationDeviceRegistry: ModuleCode = "foundation.device_registry"
}
