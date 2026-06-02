//
//  BusinessRevisionRegistry.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

actor BusinessRevisionRegistry {
    static let shared = BusinessRevisionRegistry()

    private var catalogRevisionsByContext: [String: String] = [:]
    private var taxRevisionsByContext: [String: String] = [:]

    private init() {}

    func observeCatalogRevision(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String?
    ) {
        guard let catalogRevision = catalogRevision?.trimmedNonEmpty else { return }
        catalogRevisionsByContext[key(organizationId: organizationId, branchId: branchId, activityId: activityId)] = catalogRevision
    }

    func observeTaxConfigurationRevision(
        organizationId: String,
        branchId: String,
        activityId: String,
        taxConfigurationRevision: String?
    ) {
        guard let taxConfigurationRevision = taxConfigurationRevision?.trimmedNonEmpty else { return }
        taxRevisionsByContext[key(organizationId: organizationId, branchId: branchId, activityId: activityId)] = taxConfigurationRevision
    }

    func observeRevisions(
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions
    ) {
        observeCatalogRevision(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            catalogRevision: revisions.catalogRevision
        )
        observeTaxConfigurationRevision(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            taxConfigurationRevision: revisions.taxConfigurationRevision
        )
    }

    func latestRevisions(
        organizationId: String,
        branchId: String,
        activityId: String,
        fallback: BusinessRevisions
    ) -> BusinessRevisions {
        let contextKey = key(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId
        )

        let catalogRevision = catalogRevisionsByContext[contextKey]?.trimmedNonEmpty
            ?? fallback.catalogRevision.trimmedNonEmpty
            ?? ""

        let taxConfigurationRevision = taxRevisionsByContext[contextKey]?.trimmedNonEmpty
            ?? fallback.taxConfigurationRevision.trimmedNonEmpty
            ?? ""

        return BusinessRevisions(
            catalogRevision: catalogRevision,
            taxConfigurationRevision: taxConfigurationRevision
        )
    }

    func clear() {
        catalogRevisionsByContext.removeAll()
        taxRevisionsByContext.removeAll()
    }

    private func key(
        organizationId: String,
        branchId: String,
        activityId: String
    ) -> String {
        [organizationId, branchId, activityId]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "|")
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
