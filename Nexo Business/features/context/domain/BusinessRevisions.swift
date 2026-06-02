//
//  BusinessRevisions.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct BusinessRevisions: Codable, Equatable, Sendable {
    let catalogRevision: String
    let taxConfigurationRevision: String

    init(
        catalogRevision: String,
        taxConfigurationRevision: String
    ) {
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
    }

    var headers: [String: String] {
        [
            BusinessHeaders.catalogRevision: catalogRevision,
            BusinessHeaders.taxConfigurationRevision: taxConfigurationRevision
        ]
    }
}
