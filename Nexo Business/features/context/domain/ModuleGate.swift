//
//  ModuleGate.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct ModuleGate: Equatable, Sendable {
    private let activeModules: Set<ModuleCode>

    public init(activeModules: Set<ModuleCode>) {
        self.activeModules = activeModules
    }

    public func allows(_ module: ModuleCode) -> Bool {
        activeModules.contains(module)
    }
}

public struct PermissionGate: Equatable, Sendable {
    private let effectivePermissions: Set<String>

    public init(effectivePermissions: Set<String>) {
        self.effectivePermissions = effectivePermissions
    }

    public func allows(_ permission: String) -> Bool {
        effectivePermissions.contains(permission)
    }
}
