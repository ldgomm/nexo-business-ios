//
//  PreviewPilotChecklistStore.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public actor PreviewPilotChecklistStore: PilotChecklistStoring {
    private var itemsByOrganizationId: [String: [PilotChecklistItem]] = [:]

    public init(items: [PilotChecklistItem]? = nil) {
        if let items {
            self.itemsByOrganizationId[PreviewData.businessContext.organization.id] = items
        }
    }

    public func load(organizationId: String) async -> [PilotChecklistItem]? {
        itemsByOrganizationId[organizationId]
    }

    public func save(_ items: [PilotChecklistItem], organizationId: String) async throws {
        itemsByOrganizationId[organizationId] = items
    }

    public func reset(organizationId: String) async throws {
        itemsByOrganizationId.removeValue(forKey: organizationId)
    }
}
