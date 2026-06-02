//
//  BusinessSelectionStore.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct BusinessSelectionSnapshot: Codable, Equatable, Sendable {
    let organizationId: String?
    let branchId: String?
    let activityId: String?

    init(
        organizationId: String? = nil,
        branchId: String? = nil,
        activityId: String? = nil
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
    }

    var hasOrganization: Bool {
        organizationId?.isEmpty == false
    }

    var hasOperationalContext: Bool {
        branchId?.isEmpty == false && activityId?.isEmpty == false
    }
}

struct BusinessOperationalSelection: Codable, Equatable, Sendable {
    let organizationId: String
    let branchId: String
    let activityId: String

    init(
        organizationId: String,
        branchId: String,
        activityId: String
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
    }
}

protocol BusinessSelectionStoring: Sendable {
    func snapshot() async -> BusinessSelectionSnapshot
    func saveOrganizationId(_ organizationId: String) async throws
    func saveOperationalContext(branchId: String, activityId: String) async throws
    func clearOperationalContext() async throws
    func clearAll() async throws
}

actor InMemoryBusinessSelectionStore: BusinessSelectionStoring {
    private var storedSnapshot: BusinessSelectionSnapshot

    init(snapshot: BusinessSelectionSnapshot = BusinessSelectionSnapshot()) {
        self.storedSnapshot = snapshot
    }

    func snapshot() async -> BusinessSelectionSnapshot {
        storedSnapshot
    }

    func saveOrganizationId(_ organizationId: String) async throws {
        storedSnapshot = BusinessSelectionSnapshot(
            organizationId: organizationId,
            branchId: nil,
            activityId: nil
        )
    }

    func saveOperationalContext(branchId: String, activityId: String) async throws {
        storedSnapshot = BusinessSelectionSnapshot(
            organizationId: storedSnapshot.organizationId,
            branchId: branchId,
            activityId: activityId
        )
    }

    func clearOperationalContext() async throws {
        storedSnapshot = BusinessSelectionSnapshot(
            organizationId: storedSnapshot.organizationId,
            branchId: nil,
            activityId: nil
        )
    }

    func clearAll() async throws {
        storedSnapshot = BusinessSelectionSnapshot()
    }
}

actor UserDefaultsBusinessSelectionStore: BusinessSelectionStoring {
    private enum Keys {
        static let organizationId = "nexo.business.selection.organizationId"
        static let branchId = "nexo.business.selection.branchId"
        static let activityId = "nexo.business.selection.activityId"
    }

    private let defaults: UserDefaults
    private let preferredOrganizationId: String?

    init(
        defaults: UserDefaults = .standard,
        preferredOrganizationId: String? = nil
    ) {
        self.defaults = defaults
        self.preferredOrganizationId = preferredOrganizationId
    }

    func snapshot() async -> BusinessSelectionSnapshot {
        BusinessSelectionSnapshot(
            organizationId: stored(Keys.organizationId) ?? preferredOrganizationId,
            branchId: stored(Keys.branchId),
            activityId: stored(Keys.activityId)
        )
    }

    func saveOrganizationId(_ organizationId: String) async throws {
        defaults.set(organizationId, forKey: Keys.organizationId)
        defaults.removeObject(forKey: Keys.branchId)
        defaults.removeObject(forKey: Keys.activityId)
    }

    func saveOperationalContext(branchId: String, activityId: String) async throws {
        defaults.set(branchId, forKey: Keys.branchId)
        defaults.set(activityId, forKey: Keys.activityId)
    }

    func clearOperationalContext() async throws {
        defaults.removeObject(forKey: Keys.branchId)
        defaults.removeObject(forKey: Keys.activityId)
    }

    func clearAll() async throws {
        defaults.removeObject(forKey: Keys.organizationId)
        defaults.removeObject(forKey: Keys.branchId)
        defaults.removeObject(forKey: Keys.activityId)
    }

    private func stored(_ key: String) -> String? {
        let value = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
