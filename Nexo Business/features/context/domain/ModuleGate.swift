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
        let normalized = permission.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        return effectivePermissions.contains("*") || effectivePermissions.contains(normalized)
    }

    func allowsAny(_ permissions: [String]) -> Bool {
        permissions.contains { allows($0) }
    }
}

struct BusinessCapabilityGate: Equatable, Sendable {
    private let capabilities: BusinessCapabilities

    init(capabilities: BusinessCapabilities) {
        self.capabilities = capabilities
    }

    var canAccessSales: Bool {
        capabilities.sales.canCreate ||
        capabilities.sales.canPreview ||
        capabilities.sales.canConfirm
    }

    var canAccessToday: Bool {
        capabilities.reports.canViewToday ||
        capabilities.reports.canViewDashboard ||
        capabilities.reports.canViewSales ||
        capabilities.reports.canViewCash ||
        capabilities.reports.canViewDocuments ||
        capabilities.sales.canView ||
        capabilities.cash.canViewCurrent ||
        capabilities.receivables.canView ||
        capabilities.documents.canView
    }

    var canAccessCash: Bool {
        capabilities.cash.canViewCurrent ||
        capabilities.cash.canOpen ||
        capabilities.cash.canClose ||
        capabilities.cash.canRegisterInflow ||
        capabilities.cash.canRegisterOutflow ||
        capabilities.cash.canAdjust
    }

    var canAccessHistory: Bool {
        capabilities.sales.canView || capabilities.reports.canViewSales
    }

    var canAccessCustomers: Bool {
        capabilities.customers.canView || capabilities.customers.canCreate || capabilities.customers.canUpdate
    }

    var canAccessInventory: Bool {
        capabilities.inventory.canView || capabilities.inventory.canViewMovements || capabilities.inventory.canAdjust
    }

    var canAccessDocuments: Bool {
        capabilities.documents.canView ||
        capabilities.documents.canGenerateInternalTicket ||
        capabilities.documents.canRegisterPhysicalSaleNote ||
        capabilities.documents.canIssueElectronicInvoice
    }
}
