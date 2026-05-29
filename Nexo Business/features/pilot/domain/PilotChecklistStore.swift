//
//  PilotChecklistStore.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol PilotChecklistStoring: Sendable {
    func load(organizationId: String) async -> [PilotChecklistItem]?
    func save(_ items: [PilotChecklistItem], organizationId: String) async throws
    func reset(organizationId: String) async throws
}

public final class UserDefaultsPilotChecklistStore: PilotChecklistStoring, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = .nexoDefault,
        decoder: JSONDecoder = .nexoDefault
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    public func load(organizationId: String) async -> [PilotChecklistItem]? {
        guard let data = userDefaults.data(forKey: key(organizationId: organizationId)) else {
            return nil
        }

        return try? decoder.decode([PilotChecklistItem].self, from: data)
    }

    public func save(_ items: [PilotChecklistItem], organizationId: String) async throws {
        let data = try encoder.encode(items)
        userDefaults.set(data, forKey: key(organizationId: organizationId))
    }

    public func reset(organizationId: String) async throws {
        userDefaults.removeObject(forKey: key(organizationId: organizationId))
    }

    private func key(organizationId: String) -> String {
        "nexo.business.pilot.checklist.\(organizationId)"
    }
}
