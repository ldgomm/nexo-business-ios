//
//  BusinessContextModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import Foundation

struct BusinessUser: Decodable, Equatable, Sendable {
    let id: String
    let displayName: String
    let email: String
}

struct BusinessOrganization: Decodable, Equatable, Sendable {
    let id: String
    let commercialName: String
    let legalName: String
    let taxId: String
    let countryCode: String
}

struct BusinessBranch: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let code: String?
    let status: String
}

struct BusinessActivity: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let code: String
    let name: String
    let activityType: String
    let workflowMode: String
    let status: String

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case activityType
        case workflowMode
        case status
    }

    init(
        id: String,
        code: String,
        name: String,
        activityType: String,
        workflowMode: String,
        status: String
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.activityType = activityType
        self.workflowMode = workflowMode
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(String.self, forKey: .id)
        let activityType = try container.decodeIfPresent(String.self, forKey: .activityType) ?? "unknown"
        let workflowMode = try container.decodeIfPresent(String.self, forKey: .workflowMode) ?? "quick_sale"

        self.id = id
        self.activityType = activityType
        self.workflowMode = workflowMode
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        self.code = try container.decodeIfPresent(String.self, forKey: .code) ?? activityType
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? BusinessActivity.defaultName(for: activityType)
    }

    private static func defaultName(for activityType: String) -> String {
        switch activityType {
        case "restaurant":
            return "Restaurant"
        case "retail":
            return "Tienda"
        case "tourism":
            return "Turismo"
        default:
            return activityType
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}

struct BusinessReadiness: Decodable, Equatable, Sendable {
    let status: String
    let score: Int?
    let blockers: [String]
    let warnings: [String]

    init(
        status: String,
        score: Int?,
        blockers: [String],
        warnings: [String]
    ) {
        self.status = status
        self.score = score
        self.blockers = blockers
        self.warnings = warnings
    }
}

struct BusinessModuleReadiness: Decodable, Equatable, Sendable {
    let code: String
    let ready: Bool
    let active: Bool
    let missingDependencies: [String]
    let warnings: [String]
    let blockers: [String]

    init(
        code: String,
        ready: Bool,
        active: Bool,
        missingDependencies: [String] = [],
        warnings: [String] = [],
        blockers: [String] = []
    ) {
        self.code = code
        self.ready = ready
        self.active = active
        self.missingDependencies = missingDependencies
        self.warnings = warnings
        self.blockers = blockers
    }
}

struct BusinessCapabilities: Decodable, Equatable, Sendable {
    let sales: SalesCapabilities
    let cash: CashCapabilities
    let payments: PaymentCapabilities
    let receivables: ReceivableCapabilities
    let documents: DocumentCapabilities
    let reports: ReportCapabilities
    let catalog: CatalogCapabilities
    let customers: CustomerCapabilities
    let inventory: InventoryCapabilities

    init(
        sales: SalesCapabilities = SalesCapabilities(),
        cash: CashCapabilities = CashCapabilities(),
        payments: PaymentCapabilities = PaymentCapabilities(),
        receivables: ReceivableCapabilities = ReceivableCapabilities(),
        documents: DocumentCapabilities = DocumentCapabilities(),
        reports: ReportCapabilities = ReportCapabilities(),
        catalog: CatalogCapabilities = CatalogCapabilities(),
        customers: CustomerCapabilities = CustomerCapabilities(),
        inventory: InventoryCapabilities = InventoryCapabilities()
    ) {
        self.sales = sales
        self.cash = cash
        self.payments = payments
        self.receivables = receivables
        self.documents = documents
        self.reports = reports
        self.catalog = catalog
        self.customers = customers
        self.inventory = inventory
    }

    private enum CodingKeys: String, CodingKey {
        case sales
        case cash
        case payments
        case receivables
        case documents
        case reports
        case catalog
        case customers
        case inventory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sales = try container.decodeIfPresent(SalesCapabilities.self, forKey: .sales) ?? SalesCapabilities()
        self.cash = try container.decodeIfPresent(CashCapabilities.self, forKey: .cash) ?? CashCapabilities()
        self.payments = try container.decodeIfPresent(PaymentCapabilities.self, forKey: .payments) ?? PaymentCapabilities()
        self.receivables = try container.decodeIfPresent(ReceivableCapabilities.self, forKey: .receivables) ?? ReceivableCapabilities()
        self.documents = try container.decodeIfPresent(DocumentCapabilities.self, forKey: .documents) ?? DocumentCapabilities()
        self.reports = try container.decodeIfPresent(ReportCapabilities.self, forKey: .reports) ?? ReportCapabilities()
        self.catalog = try container.decodeIfPresent(CatalogCapabilities.self, forKey: .catalog) ?? CatalogCapabilities()
        self.customers = try container.decodeIfPresent(CustomerCapabilities.self, forKey: .customers) ?? CustomerCapabilities()
        self.inventory = try container.decodeIfPresent(InventoryCapabilities.self, forKey: .inventory) ?? InventoryCapabilities()
    }

    static func fallback(activeModules: Set<ModuleCode>, effectivePermissions: Set<String>) -> BusinessCapabilities {
        BusinessCapabilitiesFallbackResolver.resolve(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
    }
}

struct SalesCapabilities: Decodable, Equatable, Sendable {
    let canView: Bool
    let canCreate: Bool
    let canPreview: Bool
    let canConfirm: Bool
    let canCancel: Bool

    init(
        canView: Bool = false,
        canCreate: Bool = false,
        canPreview: Bool = false,
        canConfirm: Bool = false,
        canCancel: Bool = false
    ) {
        self.canView = canView
        self.canCreate = canCreate
        self.canPreview = canPreview
        self.canConfirm = canConfirm
        self.canCancel = canCancel
    }

    private enum CodingKeys: String, CodingKey {
        case canView
        case canCreate
        case canPreview
        case canConfirm
        case canCancel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? false
        self.canCreate = try container.decodeIfPresent(Bool.self, forKey: .canCreate) ?? false
        self.canPreview = try container.decodeIfPresent(Bool.self, forKey: .canPreview) ?? false
        self.canConfirm = try container.decodeIfPresent(Bool.self, forKey: .canConfirm) ?? false
        self.canCancel = try container.decodeIfPresent(Bool.self, forKey: .canCancel) ?? false
    }
}

struct CashCapabilities: Decodable, Equatable, Sendable {
    let canViewCurrent: Bool
    let canViewHistory: Bool
    let canOpen: Bool
    let canClose: Bool
    let canRegisterInflow: Bool
    let canRegisterOutflow: Bool
    let canAdjust: Bool

    init(
        canViewCurrent: Bool = false,
        canViewHistory: Bool = false,
        canOpen: Bool = false,
        canClose: Bool = false,
        canRegisterInflow: Bool = false,
        canRegisterOutflow: Bool = false,
        canAdjust: Bool = false
    ) {
        self.canViewCurrent = canViewCurrent
        self.canViewHistory = canViewHistory
        self.canOpen = canOpen
        self.canClose = canClose
        self.canRegisterInflow = canRegisterInflow
        self.canRegisterOutflow = canRegisterOutflow
        self.canAdjust = canAdjust
    }

    private enum CodingKeys: String, CodingKey {
        case canViewCurrent
        case canViewHistory
        case canOpen
        case canClose
        case canRegisterInflow
        case canRegisterOutflow
        case canAdjust
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canViewCurrent = try container.decodeIfPresent(Bool.self, forKey: .canViewCurrent) ?? false
        self.canViewHistory = try container.decodeIfPresent(Bool.self, forKey: .canViewHistory) ?? false
        self.canOpen = try container.decodeIfPresent(Bool.self, forKey: .canOpen) ?? false
        self.canClose = try container.decodeIfPresent(Bool.self, forKey: .canClose) ?? false
        self.canRegisterInflow = try container.decodeIfPresent(Bool.self, forKey: .canRegisterInflow) ?? false
        self.canRegisterOutflow = try container.decodeIfPresent(Bool.self, forKey: .canRegisterOutflow) ?? false
        self.canAdjust = try container.decodeIfPresent(Bool.self, forKey: .canAdjust) ?? false
    }
}

struct PaymentCapabilities: Decodable, Equatable, Sendable {
    let canView: Bool
    let canCollect: Bool
    let canRegister: Bool
    let canMarkAsCredit: Bool
    let canRefund: Bool
    let canReverse: Bool

    init(
        canView: Bool = false,
        canCollect: Bool = false,
        canRegister: Bool = false,
        canMarkAsCredit: Bool = false,
        canRefund: Bool = false,
        canReverse: Bool = false
    ) {
        self.canView = canView
        self.canCollect = canCollect
        self.canRegister = canRegister
        self.canMarkAsCredit = canMarkAsCredit
        self.canRefund = canRefund
        self.canReverse = canReverse
    }

    private enum CodingKeys: String, CodingKey {
        case canView
        case canCollect
        case canRegister
        case canMarkAsCredit
        case canRefund
        case canReverse
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? false
        self.canCollect = try container.decodeIfPresent(Bool.self, forKey: .canCollect) ?? false
        self.canRegister = try container.decodeIfPresent(Bool.self, forKey: .canRegister) ?? false
        self.canMarkAsCredit = try container.decodeIfPresent(Bool.self, forKey: .canMarkAsCredit) ?? false
        self.canRefund = try container.decodeIfPresent(Bool.self, forKey: .canRefund) ?? false
        self.canReverse = try container.decodeIfPresent(Bool.self, forKey: .canReverse) ?? false
    }
}

struct ReceivableCapabilities: Decodable, Equatable, Sendable {
    let canView: Bool
    let canCreate: Bool
    let canRegisterPayment: Bool
    let canCollect: Bool

    init(
        canView: Bool = false,
        canCreate: Bool = false,
        canRegisterPayment: Bool = false,
        canCollect: Bool = false
    ) {
        self.canView = canView
        self.canCreate = canCreate
        self.canRegisterPayment = canRegisterPayment
        self.canCollect = canCollect
    }

    private enum CodingKeys: String, CodingKey {
        case canView
        case canCreate
        case canRegisterPayment
        case canCollect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? false
        self.canCreate = try container.decodeIfPresent(Bool.self, forKey: .canCreate) ?? false
        self.canRegisterPayment = try container.decodeIfPresent(Bool.self, forKey: .canRegisterPayment) ?? false
        self.canCollect = try container.decodeIfPresent(Bool.self, forKey: .canCollect) ?? false
    }
}

struct DocumentCapabilities: Decodable, Equatable, Sendable {
    let canView: Bool
    let canGenerateInternalTicket: Bool
    let canRegisterPhysicalSaleNote: Bool
    let canIssueElectronicInvoice: Bool
    let canDownloadPdf: Bool
    let canDownloadXml: Bool

    init(
        canView: Bool = false,
        canGenerateInternalTicket: Bool = false,
        canRegisterPhysicalSaleNote: Bool = false,
        canIssueElectronicInvoice: Bool = false,
        canDownloadPdf: Bool = false,
        canDownloadXml: Bool = false
    ) {
        self.canView = canView
        self.canGenerateInternalTicket = canGenerateInternalTicket
        self.canRegisterPhysicalSaleNote = canRegisterPhysicalSaleNote
        self.canIssueElectronicInvoice = canIssueElectronicInvoice
        self.canDownloadPdf = canDownloadPdf
        self.canDownloadXml = canDownloadXml
    }

    private enum CodingKeys: String, CodingKey {
        case canView
        case canGenerateInternalTicket
        case canRegisterPhysicalSaleNote
        case canIssueElectronicInvoice
        case canDownloadPdf
        case canDownloadXml
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? false
        self.canGenerateInternalTicket = try container.decodeIfPresent(Bool.self, forKey: .canGenerateInternalTicket) ?? false
        self.canRegisterPhysicalSaleNote = try container.decodeIfPresent(Bool.self, forKey: .canRegisterPhysicalSaleNote) ?? false
        self.canIssueElectronicInvoice = try container.decodeIfPresent(Bool.self, forKey: .canIssueElectronicInvoice) ?? false
        self.canDownloadPdf = try container.decodeIfPresent(Bool.self, forKey: .canDownloadPdf) ?? false
        self.canDownloadXml = try container.decodeIfPresent(Bool.self, forKey: .canDownloadXml) ?? false
    }
}

struct ReportCapabilities: Decodable, Equatable, Sendable {
    let canViewDashboard: Bool
    let canViewToday: Bool
    let canViewSales: Bool
    let canViewCash: Bool
    let canViewTax: Bool
    let canViewDocuments: Bool

    init(
        canViewDashboard: Bool = false,
        canViewToday: Bool = false,
        canViewSales: Bool = false,
        canViewCash: Bool = false,
        canViewTax: Bool = false,
        canViewDocuments: Bool = false
    ) {
        self.canViewDashboard = canViewDashboard
        self.canViewToday = canViewToday
        self.canViewSales = canViewSales
        self.canViewCash = canViewCash
        self.canViewTax = canViewTax
        self.canViewDocuments = canViewDocuments
    }

    private enum CodingKeys: String, CodingKey {
        case canViewDashboard
        case canViewToday
        case canViewSales
        case canViewCash
        case canViewTax
        case canViewDocuments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canViewDashboard = try container.decodeIfPresent(Bool.self, forKey: .canViewDashboard) ?? false
        self.canViewToday = try container.decodeIfPresent(Bool.self, forKey: .canViewToday) ?? false
        self.canViewSales = try container.decodeIfPresent(Bool.self, forKey: .canViewSales) ?? false
        self.canViewCash = try container.decodeIfPresent(Bool.self, forKey: .canViewCash) ?? false
        self.canViewTax = try container.decodeIfPresent(Bool.self, forKey: .canViewTax) ?? false
        self.canViewDocuments = try container.decodeIfPresent(Bool.self, forKey: .canViewDocuments) ?? false
    }
}

struct CatalogCapabilities: Decodable, Equatable, Sendable {
    let canView: Bool
    let canManageLocal: Bool
    let canChangePrice: Bool
    let canChangeTaxProfile: Bool

    init(
        canView: Bool = false,
        canManageLocal: Bool = false,
        canChangePrice: Bool = false,
        canChangeTaxProfile: Bool = false
    ) {
        self.canView = canView
        self.canManageLocal = canManageLocal
        self.canChangePrice = canChangePrice
        self.canChangeTaxProfile = canChangeTaxProfile
    }

    private enum CodingKeys: String, CodingKey {
        case canView
        case canManageLocal
        case canChangePrice
        case canChangeTaxProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? false
        self.canManageLocal = try container.decodeIfPresent(Bool.self, forKey: .canManageLocal) ?? false
        self.canChangePrice = try container.decodeIfPresent(Bool.self, forKey: .canChangePrice) ?? false
        self.canChangeTaxProfile = try container.decodeIfPresent(Bool.self, forKey: .canChangeTaxProfile) ?? false
    }
}

struct CustomerCapabilities: Decodable, Equatable, Sendable {
    let canView: Bool
    let canCreate: Bool
    let canUpdate: Bool

    init(
        canView: Bool = false,
        canCreate: Bool = false,
        canUpdate: Bool = false
    ) {
        self.canView = canView
        self.canCreate = canCreate
        self.canUpdate = canUpdate
    }

    private enum CodingKeys: String, CodingKey {
        case canView
        case canCreate
        case canUpdate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? false
        self.canCreate = try container.decodeIfPresent(Bool.self, forKey: .canCreate) ?? false
        self.canUpdate = try container.decodeIfPresent(Bool.self, forKey: .canUpdate) ?? false
    }
}

struct InventoryCapabilities: Decodable, Equatable, Sendable {
    let canView: Bool
    let canViewMovements: Bool
    let canAdjust: Bool

    init(
        canView: Bool = false,
        canViewMovements: Bool = false,
        canAdjust: Bool = false
    ) {
        self.canView = canView
        self.canViewMovements = canViewMovements
        self.canAdjust = canAdjust
    }

    private enum CodingKeys: String, CodingKey {
        case canView
        case canViewMovements
        case canAdjust
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? false
        self.canViewMovements = try container.decodeIfPresent(Bool.self, forKey: .canViewMovements) ?? false
        self.canAdjust = try container.decodeIfPresent(Bool.self, forKey: .canAdjust) ?? false
    }
}

struct BusinessContextResponse: Decodable, Equatable, Sendable {
    let user: BusinessUser
    let organization: BusinessOrganization
    let branches: [BusinessBranch]
    let activities: [BusinessActivity]
    let activeModules: Set<ModuleCode>
    let effectivePermissions: Set<String>
    let capabilities: BusinessCapabilities
    let revisions: BusinessRevisions
    let readiness: BusinessReadiness

    let activeBranchId: String?
    let activeActivityId: String?
    let moduleReadiness: [BusinessModuleReadiness]

    private enum CodingKeys: String, CodingKey {
        case user
        case organization
        case branches
        case activities
        case activeModules
        case effectivePermissions
        case capabilities
        case revisions
        case readiness
        case catalogRevision
        case taxConfigurationRevision
        case activeBranchId
        case activeActivityId
        case moduleReadiness
    }

    init(
        user: BusinessUser,
        organization: BusinessOrganization,
        branches: [BusinessBranch],
        activities: [BusinessActivity],
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        capabilities: BusinessCapabilities? = nil,
        revisions: BusinessRevisions,
        readiness: BusinessReadiness,
        activeBranchId: String? = nil,
        activeActivityId: String? = nil,
        moduleReadiness: [BusinessModuleReadiness] = []
    ) {
        self.user = user
        self.organization = organization
        self.branches = branches
        self.activities = activities
        self.activeModules = activeModules
        self.effectivePermissions = effectivePermissions
        self.capabilities = capabilities ?? BusinessCapabilities.fallback(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.revisions = revisions
        self.readiness = readiness
        self.activeBranchId = activeBranchId
        self.activeActivityId = activeActivityId
        self.moduleReadiness = moduleReadiness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.user = try container.decode(BusinessUser.self, forKey: .user)
        self.organization = try container.decode(BusinessOrganization.self, forKey: .organization)
        self.branches = try container.decodeIfPresent([BusinessBranch].self, forKey: .branches) ?? []
        self.activities = try container.decodeIfPresent([BusinessActivity].self, forKey: .activities) ?? []
        self.activeModules = try container.decodeIfPresent(Set<ModuleCode>.self, forKey: .activeModules) ?? []
        self.effectivePermissions = try container.decodeIfPresent(Set<String>.self, forKey: .effectivePermissions) ?? []

        self.activeBranchId = try container.decodeIfPresent(String.self, forKey: .activeBranchId)
        self.activeActivityId = try container.decodeIfPresent(String.self, forKey: .activeActivityId)
        self.moduleReadiness = try Self.decodeModuleReadiness(from: container)

        if let revisions = try container.decodeIfPresent(BusinessRevisions.self, forKey: .revisions) {
            self.revisions = revisions
        } else {
            let catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision) ?? ""
            let taxConfigurationRevision = try container.decodeIfPresent(String.self, forKey: .taxConfigurationRevision) ?? ""

            self.revisions = BusinessRevisions(
                catalogRevision: catalogRevision,
                taxConfigurationRevision: taxConfigurationRevision
            )
        }

        if let readiness = try container.decodeIfPresent(BusinessReadiness.self, forKey: .readiness) {
            self.readiness = readiness
        } else {
            let activeModuleReadiness = moduleReadiness.filter { $0.active }
            let blockers = activeModuleReadiness.flatMap(\.blockers)
            let warnings = activeModuleReadiness.flatMap(\.warnings)

            self.readiness = BusinessReadiness(
                status: blockers.isEmpty ? "ready" : "blocked",
                score: blockers.isEmpty ? 100 : 0,
                blockers: blockers,
                warnings: warnings
            )
        }

        self.capabilities = try container.decodeIfPresent(BusinessCapabilities.self, forKey: .capabilities)
            ?? BusinessCapabilities.fallback(
                activeModules: activeModules,
                effectivePermissions: effectivePermissions
            )
    }

    private static func decodeModuleReadiness(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [BusinessModuleReadiness] {
        if let array = try? container.decodeIfPresent([BusinessModuleReadiness].self, forKey: .moduleReadiness) {
            return array
        }

        if let map = try? container.decodeIfPresent([String: LegacyModuleReadiness].self, forKey: .moduleReadiness) {
            return map
                .map { code, value in
                    BusinessModuleReadiness(
                        code: code,
                        ready: value.status.lowercased() == "ready",
                        active: value.active,
                        missingDependencies: value.missingDependencies,
                        warnings: value.warnings,
                        blockers: value.blockers
                    )
                }
                .sorted { $0.code < $1.code }
        }

        return []
    }
}

private struct LegacyModuleReadiness: Decodable {
    let status: String
    let active: Bool
    let missingDependencies: [String]
    let warnings: [String]
    let blockers: [String]

    private enum CodingKeys: String, CodingKey {
        case status
        case ready
        case active
        case missingDependencies
        case warnings
        case blockers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ready = try container.decodeIfPresent(Bool.self, forKey: .ready) ?? false
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? (ready ? "ready" : "blocked")
        self.active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
        self.missingDependencies = try container.decodeIfPresent([String].self, forKey: .missingDependencies) ?? []
        self.warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        self.blockers = try container.decodeIfPresent([String].self, forKey: .blockers) ?? []
    }
}

private enum BusinessCapabilitiesFallbackResolver {
    static func resolve(activeModules: Set<ModuleCode>, effectivePermissions: Set<String>) -> BusinessCapabilities {
        let gate = PermissionGate(effectivePermissions: effectivePermissions)
        let hasSalesModule = activeModules.contains(.coreSales)
        let hasCashModule = activeModules.contains(.coreCash)

        let salesCanView = hasSalesModule && gate.allowsAny([
            "sales.view",
            "business.sales.view",
            "sales.history",
            "business.sales.history"
        ])
        let salesCanCreate = hasSalesModule && gate.allowsAny([
            "sales.create",
            "business.sales.create"
        ])
        let salesCanPreview = hasSalesModule && gate.allowsAny([
            "sales.create",
            "business.sales.create",
            "sales.preview",
            "business.sales.preview"
        ])
        let salesCanConfirm = hasSalesModule && gate.allowsAny([
            "sales.confirm",
            "business.sales.confirm",
            "sales.create",
            "business.sales.create"
        ])

        let cashCanViewCurrent = hasCashModule && gate.allowsAny([
            "cash.view",
            "cash.session.view_current",
            "cash.view_current",
            "business.cash.view_current"
        ])
        let cashCanOpen = hasCashModule && gate.allowsAny([
            "cash.open",
            "cash.session.open",
            "business.cash.open"
        ])
        let cashCanClose = hasCashModule && gate.allowsAny([
            "cash.close",
            "cash.session.close",
            "business.cash.close"
        ])

        let documentsCanView = gate.allowsAny([
            "documents.view",
            "business.documents.view"
        ])
        let documentsCanGenerateInternalTicket = gate.allowsAny([
            "documents.generate_internal_ticket",
            "documents.issue_internal_ticket",
            "business.documents.issue_internal_ticket"
        ])
        let documentsCanRegisterPhysicalSaleNote = gate.allowsAny([
            "documents.generate_physical_sale_note_registry",
            "documents.register_physical_sale_note",
            "business.documents.register_physical_sale_note"
        ])
        let reportsCanViewSales = gate.allowsAny([
            "reports.sales.view",
            "sales.view",
            "business.sales.view",
            "reports.today",
            "business.reports.today",
            "reports.daily",
            "business.reports.daily"
        ])
        let reportsCanViewCash = gate.allowsAny([
            "reports.cash.view",
            "cash.view",
            "cash.session.view_current",
            "cash.view_current",
            "business.cash.view_current"
        ])
        let reportsCanViewDocuments = gate.allowsAny([
            "reports.documents.view",
            "documents.view",
            "business.documents.view"
        ])
        let reportsCanViewDashboard = gate.allowsAny([
            "reports.dashboard.view",
            "reports.today",
            "business.reports.today",
            "reports.daily",
            "business.reports.daily"
        ])

        return BusinessCapabilities(
            sales: SalesCapabilities(
                canView: salesCanView,
                canCreate: salesCanCreate,
                canPreview: salesCanPreview,
                canConfirm: salesCanConfirm,
                canCancel: hasSalesModule && gate.allowsAny([
                    "sales.cancel",
                    "sales.cancel_after_payment",
                    "business.sales.cancel"
                ])
            ),
            cash: CashCapabilities(
                canViewCurrent: cashCanViewCurrent,
                canViewHistory: hasCashModule && gate.allowsAny([
                    "cash.view",
                    "cash.session.view_history",
                    "cash.view_history",
                    "business.cash.view_history"
                ]),
                canOpen: cashCanOpen,
                canClose: cashCanClose,
                canRegisterInflow: hasCashModule && gate.allowsAny([
                    "cash.movements.register_inflow",
                    "cash.register_inflow",
                    "business.cash.register_inflow"
                ]),
                canRegisterOutflow: hasCashModule && gate.allowsAny([
                    "cash.movements.register_outflow",
                    "cash.register_outflow",
                    "business.cash.register_outflow"
                ]),
                canAdjust: hasCashModule && gate.allowsAny([
                    "cash.movements.adjust",
                    "cash.adjust",
                    "business.cash.adjust"
                ])
            ),
            payments: PaymentCapabilities(
                canView: gate.allowsAny([
                    "payments.view",
                    "payments.collect",
                    "business.payments.view"
                ]),
                canCollect: gate.allowsAny([
                    "payments.collect",
                    "payments.register",
                    "business.payments.register",
                    "business.payments.collect"
                ]),
                canRegister: gate.allowsAny([
                    "payments.collect",
                    "payments.register",
                    "business.payments.register",
                    "business.payments.collect"
                ]),
                canMarkAsCredit: gate.allowsAny([
                    "payments.mark_as_credit",
                    "business.payments.mark_as_credit"
                ]),
                canRefund: gate.allows("payments.refund"),
                canReverse: gate.allows("payments.reverse")
            ),
            receivables: ReceivableCapabilities(
                canView: gate.allowsAny([
                    "receivables.view",
                    "business.receivables.view"
                ]),
                canCreate: gate.allowsAny([
                    "receivables.create",
                    "business.receivables.create"
                ]),
                canRegisterPayment: gate.allowsAny([
                    "receivables.register_payment",
                    "receivables.collect",
                    "business.receivables.collect"
                ]),
                canCollect: gate.allowsAny([
                    "receivables.register_payment",
                    "receivables.collect",
                    "business.receivables.collect"
                ])
            ),
            documents: DocumentCapabilities(
                canView: documentsCanView,
                canGenerateInternalTicket: documentsCanGenerateInternalTicket,
                canRegisterPhysicalSaleNote: documentsCanRegisterPhysicalSaleNote,
                canIssueElectronicInvoice: gate.allowsAny([
                    "documents.issue_electronic_invoice",
                    "documents.electronic_invoice.issue",
                    "business.documents.issue_electronic_invoice"
                ]),
                canDownloadPdf: gate.allowsAny([
                    "documents.download_pdf",
                    "documents.electronic_invoice.download_ride"
                ]),
                canDownloadXml: gate.allowsAny([
                    "documents.download_xml",
                    "documents.electronic_invoice.download_xml"
                ])
            ),
            reports: ReportCapabilities(
                canViewDashboard: reportsCanViewDashboard,
                canViewToday: reportsCanViewDashboard || reportsCanViewSales || reportsCanViewCash || reportsCanViewDocuments,
                canViewSales: reportsCanViewSales,
                canViewCash: reportsCanViewCash,
                canViewTax: gate.allows("reports.tax.view"),
                canViewDocuments: reportsCanViewDocuments
            ),
            catalog: CatalogCapabilities(
                canView: gate.allowsAny([
                    "catalog.view",
                    "catalog.local.view",
                    "business.catalog.view"
                ]),
                canManageLocal: gate.allowsAny([
                    "catalog.manage_local",
                    "catalog.local.update_local_copy"
                ]),
                canChangePrice: gate.allows("catalog.local.change_price"),
                canChangeTaxProfile: gate.allows("catalog.local.change_tax_profile")
            ),
            customers: CustomerCapabilities(
                canView: gate.allowsAny([
                    "customers.view",
                    "business.customers.view"
                ]),
                canCreate: gate.allowsAny([
                    "customers.create",
                    "business.customers.create"
                ]),
                canUpdate: gate.allowsAny([
                    "customers.update",
                    "business.customers.update"
                ])
            ),
            inventory: InventoryCapabilities(
                canView: gate.allowsAny([
                    "inventory.view",
                    "business.inventory.view"
                ]),
                canViewMovements: gate.allowsAny([
                    "inventory.view",
                    "business.inventory.view",
                    "inventory.view_movements",
                    "business.inventory.view_movements"
                ]),
                canAdjust: gate.allowsAny([
                    "inventory.adjust",
                    "business.inventory.adjust"
                ])
            )
        )
    }
}
