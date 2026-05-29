//
//  BusinessSelectionStore.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct BusinessSelectionSnapshot: Codable, Equatable, Sendable {
    public let organizationId: String?
    public let branchId: String?
    public let activityId: String?

    public init(
        organizationId: String? = nil,
        branchId: String? = nil,
        activityId: String? = nil
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
    }

    public var hasOrganization: Bool {
        organizationId?.isEmpty == false
    }

    public var hasOperationalContext: Bool {
        branchId?.isEmpty == false && activityId?.isEmpty == false
    }
}

public struct BusinessOperationalSelection: Codable, Equatable, Sendable {
    public let organizationId: String
    public let branchId: String
    public let activityId: String

    public init(
        organizationId: String,
        branchId: String,
        activityId: String
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
    }
}

public protocol BusinessSelectionStoring: Sendable {
    func snapshot() async -> BusinessSelectionSnapshot
    func saveOrganizationId(_ organizationId: String) async throws
    func saveOperationalContext(branchId: String, activityId: String) async throws
    func clearOperationalContext() async throws
    func clearAll() async throws
}

public actor InMemoryBusinessSelectionStore: BusinessSelectionStoring {
    private var storedSnapshot: BusinessSelectionSnapshot

    public init(snapshot: BusinessSelectionSnapshot = BusinessSelectionSnapshot()) {
        self.storedSnapshot = snapshot
    }

    public func snapshot() async -> BusinessSelectionSnapshot {
        storedSnapshot
    }

    public func saveOrganizationId(_ organizationId: String) async throws {
        storedSnapshot = BusinessSelectionSnapshot(
            organizationId: organizationId,
            branchId: nil,
            activityId: nil
        )
    }

    public func saveOperationalContext(branchId: String, activityId: String) async throws {
        storedSnapshot = BusinessSelectionSnapshot(
            organizationId: storedSnapshot.organizationId,
            branchId: branchId,
            activityId: activityId
        )
    }

    public func clearOperationalContext() async throws {
        storedSnapshot = BusinessSelectionSnapshot(
            organizationId: storedSnapshot.organizationId,
            branchId: nil,
            activityId: nil
        )
    }

    public func clearAll() async throws {
        storedSnapshot = BusinessSelectionSnapshot()
    }
}

public actor UserDefaultsBusinessSelectionStore: BusinessSelectionStoring {
    private enum Keys {
        static let organizationId = "nexo.business.selection.organizationId"
        static let branchId = "nexo.business.selection.branchId"
        static let activityId = "nexo.business.selection.activityId"
    }

    private let defaults: UserDefaults
    private let preferredOrganizationId: String?

    public init(
        defaults: UserDefaults = .standard,
        preferredOrganizationId: String? = nil
    ) {
        self.defaults = defaults
        self.preferredOrganizationId = preferredOrganizationId
    }

    public func snapshot() async -> BusinessSelectionSnapshot {
        BusinessSelectionSnapshot(
            organizationId: stored(Keys.organizationId) ?? preferredOrganizationId,
            branchId: stored(Keys.branchId),
            activityId: stored(Keys.activityId)
        )
    }

    public func saveOrganizationId(_ organizationId: String) async throws {
        defaults.set(organizationId, forKey: Keys.organizationId)
        defaults.removeObject(forKey: Keys.branchId)
        defaults.removeObject(forKey: Keys.activityId)
    }

    public func saveOperationalContext(branchId: String, activityId: String) async throws {
        defaults.set(branchId, forKey: Keys.branchId)
        defaults.set(activityId, forKey: Keys.activityId)
    }

    public func clearOperationalContext() async throws {
        defaults.removeObject(forKey: Keys.branchId)
        defaults.removeObject(forKey: Keys.activityId)
    }

    public func clearAll() async throws {
        defaults.removeObject(forKey: Keys.organizationId)
        defaults.removeObject(forKey: Keys.branchId)
        defaults.removeObject(forKey: Keys.activityId)
    }

    private func stored(_ key: String) -> String? {
        let value = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
