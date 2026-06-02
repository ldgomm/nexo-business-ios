//
//  PreviewPilotChecklistStore.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

actor PreviewPilotChecklistStore: PilotChecklistStoring {
    private var itemsByOrganizationId: [String: [PilotChecklistItem]] = [:]

    init(items: [PilotChecklistItem]? = nil) {
        if let items {
            self.itemsByOrganizationId[PreviewData.businessContext.organization.id] = items
        }
    }

    func load(organizationId: String) async -> [PilotChecklistItem]? {
        itemsByOrganizationId[organizationId]
    }

    func save(_ items: [PilotChecklistItem], organizationId: String) async throws {
        itemsByOrganizationId[organizationId] = items
    }

    func reset(organizationId: String) async throws {
        itemsByOrganizationId.removeValue(forKey: organizationId)
    }
}
