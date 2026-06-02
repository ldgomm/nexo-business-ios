//
//  ModuleGate.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct ModuleGate: Equatable, Sendable {
    private let activeModules: Set<ModuleCode>

    init(activeModules: Set<ModuleCode>) {
        self.activeModules = activeModules
    }

    func allows(_ module: ModuleCode) -> Bool {
        activeModules.contains(module)
    }
}

struct PermissionGate: Equatable, Sendable {
    private let effectivePermissions: Set<String>

    init(effectivePermissions: Set<String>) {
        self.effectivePermissions = effectivePermissions
    }

    func allows(_ permission: String) -> Bool {
        effectivePermissions.contains(permission)
    }
}
