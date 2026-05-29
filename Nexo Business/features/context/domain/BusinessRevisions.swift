//
//  BusinessRevisions.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct BusinessRevisions: Codable, Equatable, Sendable {
    public let catalogRevision: String
    public let taxConfigurationRevision: String

    public init(
        catalogRevision: String,
        taxConfigurationRevision: String
    ) {
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
    }

    public var headers: [String: String] {
        [
            BusinessHeaders.catalogRevision: catalogRevision,
            BusinessHeaders.taxConfigurationRevision: taxConfigurationRevision
        ]
    }
}
