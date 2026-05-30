//
//  BusinessContextModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct BusinessUser: Decodable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let email: String

    public init(id: String, displayName: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}

public struct BusinessOrganization: Decodable, Equatable, Sendable {
    public let id: String
    public let commercialName: String
    public let legalName: String
    public let taxId: String
    public let countryCode: String

    public init(
        id: String,
        commercialName: String,
        legalName: String,
        taxId: String,
        countryCode: String
    ) {
        self.id = id
        self.commercialName = commercialName
        self.legalName = legalName
        self.taxId = taxId
        self.countryCode = countryCode
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case commercialName
        case legalName
        case taxId
        case countryCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        commercialName = try container.decodeIfPresent(String.self, forKey: .commercialName) ?? ""
        legalName = try container.decodeIfPresent(String.self, forKey: .legalName) ?? commercialName
        taxId = try container.decodeIfPresent(String.self, forKey: .taxId) ?? ""
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode) ?? "EC"
    }
}

public struct BusinessBranch: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let code: String?
    public let status: String

    public init(id: String, name: String, code: String? = nil, status: String) {
        self.id = id
        self.name = name
        self.code = code
        self.status = status
    }
}

public struct BusinessActivity: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let code: String
    public let name: String
    public let activityType: String
    public let workflowMode: String
    public let status: String
    public let requiresScheduling: Bool?

    public init(
        id: String,
        code: String? = nil,
        name: String? = nil,
        activityType: String,
        workflowMode: String,
        status: String,
        requiresScheduling: Bool? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.workflowMode = workflowMode
        self.status = status
        self.requiresScheduling = requiresScheduling
        self.code = code?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            ?? activityType
        self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            ?? BusinessActivity.defaultName(activityType: activityType, workflowMode: workflowMode)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case activityType
        case workflowMode
        case status
        case requiresScheduling
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let activityType = try container.decodeIfPresent(String.self, forKey: .activityType) ?? "business"
        let workflowMode = try container.decodeIfPresent(String.self, forKey: .workflowMode) ?? "quick_sale"
        let status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        let requiresScheduling = try container.decodeIfPresent(Bool.self, forKey: .requiresScheduling)

        self.init(
            id: id,
            code: try container.decodeIfPresent(String.self, forKey: .code),
            name: try container.decodeIfPresent(String.self, forKey: .name),
            activityType: activityType,
            workflowMode: workflowMode,
            status: status,
            requiresScheduling: requiresScheduling
        )
    }

    private static func defaultName(activityType: String, workflowMode: String) -> String {
        let base = activityType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return base.isEmpty ? workflowMode.replacingOccurrences(of: "_", with: " ").capitalized : base
    }
}

public struct BusinessRealtimeSettings: Decodable, Equatable, Sendable {
    public let enabled: Bool?
    public let transport: String?

    public init(enabled: Bool? = nil, transport: String? = nil) {
        self.enabled = enabled
        self.transport = transport
    }
}

public struct BusinessModuleReadiness: Decodable, Equatable, Sendable {
    public let status: String
    public let blockers: [String]
    public let warnings: [String]

    public init(
        status: String = "ready",
        blockers: [String] = [],
        warnings: [String] = []
    ) {
        self.status = status
        self.blockers = blockers
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case blockers
        case warnings
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let status = try? single.decode(String.self) {
            self.init(status: status)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            status: try container.decodeIfPresent(String.self, forKey: .status) ?? "ready",
            blockers: try container.decodeIfPresent([String].self, forKey: .blockers) ?? [],
            warnings: try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        )
    }
}

public struct BusinessReadiness: Decodable, Equatable, Sendable {
    public let status: String
    public let score: Int?
    public let blockers: [String]
    public let warnings: [String]

    public init(
        status: String,
        score: Int? = nil,
        blockers: [String] = [],
        warnings: [String] = []
    ) {
        self.status = status
        self.score = score
        self.blockers = blockers
        self.warnings = warnings
    }

    public static func derived(from moduleReadiness: [String: BusinessModuleReadiness]) -> BusinessReadiness {
        let blockers = moduleReadiness
            .flatMap { module, readiness in readiness.blockers.map { "\(module): \($0)" } }
            .sorted()

        let warnings = moduleReadiness
            .flatMap { module, readiness in readiness.warnings.map { "\(module): \($0)" } }
            .sorted()

        let hasBlockedModule = moduleReadiness.values.contains {
            ["blocked", "not_ready", "disabled"].contains($0.status.lowercased())
        }

        let status: String
        if !blockers.isEmpty || hasBlockedModule {
            status = "blocked"
        } else if !warnings.isEmpty {
            status = "warning"
        } else {
            status = "ready"
        }

        return BusinessReadiness(
            status: status,
            score: nil,
            blockers: blockers,
            warnings: warnings
        )
    }
}

public struct BusinessContextResponse: Decodable, Equatable, Sendable {
    public let user: BusinessUser
    public let organization: BusinessOrganization
    public let branches: [BusinessBranch]
    public let activeBranchId: String?
    public let activities: [BusinessActivity]
    public let activeModules: Set<ModuleCode>
    public let effectivePermissions: Set<String>

    public let catalogRevision: String
    public let taxConfigurationRevision: String
    public let realtime: BusinessRealtimeSettings?
    public let moduleReadiness: [String: BusinessModuleReadiness]
    public let environment: String?
    public let serverTime: Date?

    private let decodedReadiness: BusinessReadiness?

    public var revisions: BusinessRevisions {
        BusinessRevisions(
            catalogRevision: catalogRevision,
            taxConfigurationRevision: taxConfigurationRevision
        )
    }

    public var readiness: BusinessReadiness {
        decodedReadiness ?? BusinessReadiness.derived(from: moduleReadiness)
    }

    public init(
        user: BusinessUser,
        organization: BusinessOrganization,
        branches: [BusinessBranch],
        activeBranchId: String? = nil,
        activities: [BusinessActivity],
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        catalogRevision: String,
        taxConfigurationRevision: String,
        realtime: BusinessRealtimeSettings? = nil,
        moduleReadiness: [String: BusinessModuleReadiness] = [:],
        environment: String? = nil,
        serverTime: Date? = nil,
        readiness: BusinessReadiness? = nil
    ) {
        self.user = user
        self.organization = organization
        self.branches = branches
        self.activeBranchId = activeBranchId
        self.activities = activities
        self.activeModules = activeModules
        self.effectivePermissions = effectivePermissions
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
        self.realtime = realtime
        self.moduleReadiness = moduleReadiness
        self.environment = environment
        self.serverTime = serverTime
        self.decodedReadiness = readiness
    }

    public init(
        user: BusinessUser,
        organization: BusinessOrganization,
        branches: [BusinessBranch],
        activities: [BusinessActivity],
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        revisions: BusinessRevisions,
        readiness: BusinessReadiness
    ) {
        self.init(
            user: user,
            organization: organization,
            branches: branches,
            activities: activities,
            activeModules: activeModules,
            effectivePermissions: effectivePermissions,
            catalogRevision: revisions.catalogRevision,
            taxConfigurationRevision: revisions.taxConfigurationRevision,
            readiness: readiness
        )
    }

    private enum CodingKeys: String, CodingKey {
        case user
        case organization
        case branches
        case activeBranchId
        case activities
        case activeModules
        case effectivePermissions
        case revisions
        case readiness
        case catalogRevision
        case taxConfigurationRevision
        case realtime
        case moduleReadiness
        case environment
        case serverTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        user = try container.decode(BusinessUser.self, forKey: .user)
        organization = try container.decode(BusinessOrganization.self, forKey: .organization)
        branches = try container.decodeIfPresent([BusinessBranch].self, forKey: .branches) ?? []
        activeBranchId = try container.decodeIfPresent(String.self, forKey: .activeBranchId)
        activities = try container.decodeIfPresent([BusinessActivity].self, forKey: .activities) ?? []
        activeModules = try container.decodeIfPresent(Set<ModuleCode>.self, forKey: .activeModules) ?? []
        effectivePermissions = try container.decodeIfPresent(Set<String>.self, forKey: .effectivePermissions) ?? []

        let revisions = try container.decodeIfPresent(BusinessRevisions.self, forKey: .revisions)
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
            ?? revisions?.catalogRevision
            ?? ""
        taxConfigurationRevision = try container.decodeIfPresent(String.self, forKey: .taxConfigurationRevision)
            ?? revisions?.taxConfigurationRevision
            ?? ""

        realtime = try container.decodeIfPresent(BusinessRealtimeSettings.self, forKey: .realtime)
        moduleReadiness = try container.decodeIfPresent([String: BusinessModuleReadiness].self, forKey: .moduleReadiness) ?? [:]
        environment = try container.decodeIfPresent(String.self, forKey: .environment)
        serverTime = try container.decodeIfPresent(Date.self, forKey: .serverTime)
        decodedReadiness = try container.decodeIfPresent(BusinessReadiness.self, forKey: .readiness)
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
