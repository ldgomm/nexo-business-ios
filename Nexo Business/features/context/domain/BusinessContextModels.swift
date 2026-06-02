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
}

public struct BusinessOrganization: Decodable, Equatable, Sendable {
    public let id: String
    public let commercialName: String
    public let legalName: String
    public let taxId: String
    public let countryCode: String
}

public struct BusinessBranch: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let code: String?
    public let status: String
}

public struct BusinessActivity: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let code: String
    public let name: String
    public let activityType: String
    public let workflowMode: String
    public let status: String

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case activityType
        case workflowMode
        case status
    }

    public init(
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

    public init(from decoder: Decoder) throws {
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
            return "Restaurante"
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

public struct BusinessReadiness: Decodable, Equatable, Sendable {
    public let status: String
    public let score: Int?
    public let blockers: [String]
    public let warnings: [String]

    public init(
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

public struct BusinessModuleReadiness: Decodable, Equatable, Sendable {
    public let code: String
    public let ready: Bool
    public let active: Bool
    public let missingDependencies: [String]
    public let warnings: [String]
    public let blockers: [String]
}

public struct BusinessContextResponse: Decodable, Equatable, Sendable {
    public let user: BusinessUser
    public let organization: BusinessOrganization
    public let branches: [BusinessBranch]
    public let activities: [BusinessActivity]
    public let activeModules: Set<ModuleCode>
    public let effectivePermissions: Set<String>
    public let revisions: BusinessRevisions
    public let readiness: BusinessReadiness

    public let activeBranchId: String?
    public let activeActivityId: String?
    public let moduleReadiness: [BusinessModuleReadiness]

    private enum CodingKeys: String, CodingKey {
        case user
        case organization
        case branches
        case activities
        case activeModules
        case effectivePermissions
        case revisions
        case readiness
        case catalogRevision
        case taxConfigurationRevision
        case activeBranchId
        case activeActivityId
        case moduleReadiness
    }

    public init(
        user: BusinessUser,
        organization: BusinessOrganization,
        branches: [BusinessBranch],
        activities: [BusinessActivity],
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
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
        self.revisions = revisions
        self.readiness = readiness
        self.activeBranchId = activeBranchId
        self.activeActivityId = activeActivityId
        self.moduleReadiness = moduleReadiness
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.user = try container.decode(BusinessUser.self, forKey: .user)
        self.organization = try container.decode(BusinessOrganization.self, forKey: .organization)
        self.branches = try container.decodeIfPresent([BusinessBranch].self, forKey: .branches) ?? []
        self.activities = try container.decodeIfPresent([BusinessActivity].self, forKey: .activities) ?? []
        self.activeModules = try container.decodeIfPresent(Set<ModuleCode>.self, forKey: .activeModules) ?? []
        self.effectivePermissions = try container.decodeIfPresent(Set<String>.self, forKey: .effectivePermissions) ?? []

        self.activeBranchId = try container.decodeIfPresent(String.self, forKey: .activeBranchId)
        self.activeActivityId = try container.decodeIfPresent(String.self, forKey: .activeActivityId)
        self.moduleReadiness = try container.decodeIfPresent([BusinessModuleReadiness].self, forKey: .moduleReadiness) ?? []

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
    }
}
