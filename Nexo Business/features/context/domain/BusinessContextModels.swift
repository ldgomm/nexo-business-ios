//
//  BusinessContextModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
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
}

struct BusinessContextResponse: Decodable, Equatable, Sendable {
    let user: BusinessUser
    let organization: BusinessOrganization
    let branches: [BusinessBranch]
    let activities: [BusinessActivity]
    let activeModules: Set<ModuleCode>
    let effectivePermissions: Set<String>
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
