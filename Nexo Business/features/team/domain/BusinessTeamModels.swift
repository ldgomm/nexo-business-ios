//
//  BusinessTeamModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

struct BusinessTeamUser: Identifiable, Equatable, Decodable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let phone: String?
    let status: String
    let scopeType: String
    let scopeId: String
    let branchId: String?
    let roleIds: Set<String>
    let roleNames: [String]
    let effectivePermissions: Set<String>?
    let highestRank: Int
    let isOrganizationSuperAdmin: Bool
    let activeSessionCount: Int
    let membershipId: String?
    let membershipStatus: String?
    let invitedBy: String?
    let acceptedAt: Date?
    let blockedAt: Date?
    let blockedReason: String?
    let createdAt: Date
    let updatedAt: Date
    let version: Int?

    init(
        id: String,
        email: String,
        displayName: String,
        phone: String? = nil,
        status: String,
        scopeType: String,
        scopeId: String,
        branchId: String? = nil,
        roleIds: Set<String>,
        roleNames: [String],
        effectivePermissions: Set<String>? = nil,
        highestRank: Int,
        isOrganizationSuperAdmin: Bool,
        activeSessionCount: Int,
        membershipId: String? = nil,
        membershipStatus: String? = nil,
        invitedBy: String? = nil,
        acceptedAt: Date? = nil,
        blockedAt: Date? = nil,
        blockedReason: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        version: Int? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.phone = phone
        self.status = status
        self.scopeType = scopeType
        self.scopeId = scopeId
        self.branchId = branchId
        self.roleIds = roleIds
        self.roleNames = roleNames
        self.effectivePermissions = effectivePermissions
        self.highestRank = highestRank
        self.isOrganizationSuperAdmin = isOrganizationSuperAdmin
        self.activeSessionCount = activeSessionCount
        self.membershipId = membershipId
        self.membershipStatus = membershipStatus
        self.invitedBy = invitedBy
        self.acceptedAt = acceptedAt
        self.blockedAt = blockedAt
        self.blockedReason = blockedReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case phone
        case status
        case scopeType
        case scopeId
        case branchId
        case roleIds
        case roleNames
        case roles
        case effectivePermissions
        case highestRank
        case isOrganizationSuperAdmin
        case activeSessionCount
        case membershipId
        case membershipStatus
        case invitedBy
        case acceptedAt
        case blockedAt
        case blockedReason
        case createdAt
        case updatedAt
        case version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedBranchId = try container.decodeIfPresent(String.self, forKey: .branchId)
        let decodedRoles = try container.decodeIfPresent([BusinessTeamRole].self, forKey: .roles) ?? []
        let decodedRoleIds = try container.decodeIfPresent(Set<String>.self, forKey: .roleIds) ?? Set(decodedRoles.map(\.id))
        let decodedRoleNames = try container.decodeIfPresent([String].self, forKey: .roleNames) ?? decodedRoles.map(\.name)
        let decodedEffectivePermissions = try container.decodeIfPresent(Set<String>.self, forKey: .effectivePermissions)
        let decodedStatus = try container.decode(String.self, forKey: .status)
        let decodedMembershipStatus = try container.decodeIfPresent(String.self, forKey: .membershipStatus)
        let decodedScopeType = try container.decodeIfPresent(String.self, forKey: .scopeType)
            ?? (decodedBranchId == nil ? "ORGANIZATION" : "BRANCH")
        
        let decodedMembershipId = try container.decodeIfPresent(String.self, forKey: .membershipId)

        let decodedScopeId = try container.decodeIfPresent(String.self, forKey: .scopeId)
            ?? decodedBranchId
            ?? decodedMembershipId
            ?? ""
        
        let decodedHighestRank = try container.decodeIfPresent(Int.self, forKey: .highestRank)
            ?? decodedRoles.map(\.rank).max()
            ?? (decodedRoleNames.contains { $0.localizedCaseInsensitiveContains("super") } ? 900 : 100)
        let decodedIsSuperAdmin = try container.decodeIfPresent(Bool.self, forKey: .isOrganizationSuperAdmin)
            ?? decodedRoleNames.contains { $0.localizedCaseInsensitiveContains("super") }

        self.id = try container.decode(String.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.status = decodedStatus
        self.scopeType = decodedScopeType
        self.scopeId = decodedScopeId
        self.branchId = decodedBranchId
        self.roleIds = decodedRoleIds
        self.roleNames = decodedRoleNames
        self.effectivePermissions = decodedEffectivePermissions
        self.highestRank = decodedHighestRank
        self.isOrganizationSuperAdmin = decodedIsSuperAdmin
        self.activeSessionCount = try container.decodeIfPresent(Int.self, forKey: .activeSessionCount) ?? 0
        self.membershipId = try container.decodeIfPresent(String.self, forKey: .membershipId)
        self.membershipStatus = decodedMembershipStatus
        self.invitedBy = try container.decodeIfPresent(String.self, forKey: .invitedBy)
        self.acceptedAt = try container.decodeIfPresent(Date.self, forKey: .acceptedAt)
        self.blockedAt = try container.decodeIfPresent(Date.self, forKey: .blockedAt)
        self.blockedReason = try container.decodeIfPresent(String.self, forKey: .blockedReason)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? self.createdAt
        self.version = try container.decodeIfPresent(Int.self, forKey: .version)
    }

    var isBlocked: Bool {
        status.uppercased() == "BLOCKED" || membershipStatus?.uppercased() == "SUSPENDED"
    }

    var rolesSummary: String {
        roleNames.isEmpty ? "Sin roles" : roleNames.joined(separator: ", ")
    }
}

struct BusinessTeamUserDetail: Identifiable, Equatable, Decodable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let phone: String?
    let status: String
    let scopeType: String
    let scopeId: String
    let branchId: String?
    let roles: [BusinessTeamRole]
    let effectivePermissions: Set<String>
    let highestRank: Int
    let isOrganizationSuperAdmin: Bool
    let activeSessionCount: Int
    let createdAt: Date
    let updatedAt: Date
    let version: Int
}

struct BusinessTeamRole: Identifiable, Equatable, Decodable, Sendable {
    let id: String
    let code: String
    let organizationId: String?
    let scope: String
    let type: String
    let name: String
    let description: String
    let scopeType: String
    let rank: Int
    let permissionKeys: Set<String>
    let systemRole: Bool
    let critical: Bool
    let editable: Bool
    let status: String
    let schemaVersion: Int

    init(
        id: String,
        code: String,
        organizationId: String? = nil,
        scope: String? = nil,
        type: String = "CUSTOM",
        name: String,
        description: String,
        scopeType: String,
        rank: Int,
        permissionKeys: Set<String>,
        systemRole: Bool,
        critical: Bool,
        editable: Bool,
        status: String,
        schemaVersion: Int
    ) {
        self.id = id
        self.code = code
        self.organizationId = organizationId
        self.scope = scope ?? scopeType
        self.type = type
        self.name = name
        self.description = description
        self.scopeType = scopeType
        self.rank = rank
        self.permissionKeys = permissionKeys
        self.systemRole = systemRole
        self.critical = critical
        self.editable = editable
        self.status = status
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case organizationId
        case scope
        case type
        case name
        case description
        case scopeType
        case rank
        case permissionKeys
        case systemRole
        case critical
        case editable
        case status
        case schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedScope = try container.decodeIfPresent(String.self, forKey: .scope)
        let decodedScopeType = try container.decodeIfPresent(String.self, forKey: .scopeType) ?? decodedScope ?? "ORGANIZATION"
        let decodedSystemRole = try container.decodeIfPresent(Bool.self, forKey: .systemRole) ?? false
        let decodedCritical = try container.decodeIfPresent(Bool.self, forKey: .critical) ?? false

        self.id = try container.decode(String.self, forKey: .id)
        self.code = try container.decode(String.self, forKey: .code)
        self.organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        self.scope = decodedScope ?? decodedScopeType
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? (decodedSystemRole ? "SYSTEM" : "CUSTOM")
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.scopeType = decodedScopeType
        self.rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? (decodedCritical ? 900 : 100)
        self.permissionKeys = try container.decodeIfPresent(Set<String>.self, forKey: .permissionKeys) ?? []
        self.systemRole = decodedSystemRole
        self.critical = decodedCritical
        self.editable = try container.decodeIfPresent(Bool.self, forKey: .editable) ?? !decodedSystemRole
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "ACTIVE"
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }

    var canBeAssignedFromBusiness: Bool {
        scopeType.uppercased() != "PLATFORM" && status.uppercased() == "ACTIVE"
    }
}

struct BusinessTeamPermission: Identifiable, Equatable, Decodable, Sendable {
    let code: String
    let name: String
    let description: String
    let category: String
    let humanLabel: String
    let assignable: Bool
    let scope: String?
    let riskLevel: String?
    let status: String?
    let systemManaged: Bool?
    let requiresAudit: Bool?
    let requiresReason: Bool?
    let requiresStepUp: Bool?
    let featureFlag: String?

    var id: String { code }

    init(
        code: String,
        name: String,
        description: String,
        category: String,
        humanLabel: String? = nil,
        assignable: Bool = true,
        scope: String? = nil,
        riskLevel: String? = nil,
        status: String? = nil,
        systemManaged: Bool? = nil,
        requiresAudit: Bool? = nil,
        requiresReason: Bool? = nil,
        requiresStepUp: Bool? = nil,
        featureFlag: String? = nil
    ) {
        self.code = code
        self.name = name
        self.description = description
        self.category = category
        self.humanLabel = humanLabel ?? name
        self.assignable = assignable
        self.scope = scope
        self.riskLevel = riskLevel
        self.status = status
        self.systemManaged = systemManaged
        self.requiresAudit = requiresAudit
        self.requiresReason = requiresReason
        self.requiresStepUp = requiresStepUp
        self.featureFlag = featureFlag
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case name
        case description
        case category
        case humanLabel
        case assignable
        case scope
        case riskLevel
        case status
        case systemManaged
        case requiresAudit
        case requiresReason
        case requiresStepUp
        case featureFlag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCode = try container.decode(String.self, forKey: .code)
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name) ?? decodedCode
        let decodedCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? "GENERAL"
        let decodedScope = try container.decodeIfPresent(String.self, forKey: .scope)
        let decodedAssignable = try container.decodeIfPresent(Bool.self, forKey: .assignable)
            ?? !(decodedCode.hasPrefix("platform.") || decodedScope?.uppercased() == "PLATFORM")

        self.code = decodedCode
        self.name = decodedName
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.category = decodedCategory
        self.humanLabel = try container.decodeIfPresent(String.self, forKey: .humanLabel) ?? decodedName
        self.assignable = decodedAssignable
        self.scope = decodedScope
        self.riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.systemManaged = try container.decodeIfPresent(Bool.self, forKey: .systemManaged)
        self.requiresAudit = try container.decodeIfPresent(Bool.self, forKey: .requiresAudit)
        self.requiresReason = try container.decodeIfPresent(Bool.self, forKey: .requiresReason)
        self.requiresStepUp = try container.decodeIfPresent(Bool.self, forKey: .requiresStepUp)
        self.featureFlag = try container.decodeIfPresent(String.self, forKey: .featureFlag)
    }
}

struct BusinessTeamBranch: Identifiable, Equatable, Decodable, Sendable {
    let id: String
    let name: String
    let code: String?
    let status: String
}

struct CreateBusinessTeamUserInput: Encodable, Equatable, Sendable {
    let email: String
    let displayName: String
    let phone: String?
    let scopeType: String
    let scopeId: String
    let roleIds: Set<String>
    let temporaryPassword: String?
    let reason: String

    init(
        email: String,
        displayName: String,
        roleIds: Set<String>,
        temporaryPassword: String? = nil,
        phone: String? = nil,
        reason: String,
        scopeType: String = "ORGANIZATION",
        scopeId: String = ""
    ) {
        self.email = email
        self.displayName = displayName
        self.phone = phone
        self.scopeType = scopeType
        self.scopeId = scopeId
        self.roleIds = roleIds
        self.temporaryPassword = temporaryPassword
        self.reason = reason
    }
}

struct UpdateBusinessTeamUserInput: Encodable, Equatable, Sendable {
    let displayName: String?
    let phone: String?
    let clearPhone: Bool
    let scopeType: String?
    let scopeId: String?
    let roleIds: Set<String>?
    let reason: String

    init(
        displayName: String? = nil,
        phone: String? = nil,
        clearPhone: Bool = false,
        roleIds: Set<String>? = nil,
        reason: String,
        scopeType: String? = nil,
        scopeId: String? = nil
    ) {
        self.displayName = displayName
        self.phone = phone
        self.clearPhone = clearPhone
        self.scopeType = scopeType
        self.scopeId = scopeId
        self.roleIds = roleIds
        self.reason = reason
    }
}

struct CreateBusinessTeamRoleInput: Encodable, Equatable, Sendable {
    let code: String
    let name: String
    let description: String
    let scopeType: String
    let rank: Int
    let permissionKeys: Set<String>
    let reason: String

    init(
        code: String,
        name: String,
        description: String,
        permissionKeys: Set<String>,
        reason: String,
        scopeType: String = "BRANCH",
        rank: Int = 100
    ) {
        self.code = code
        self.name = name
        self.description = description
        self.scopeType = scopeType
        self.rank = rank
        self.permissionKeys = permissionKeys
        self.reason = reason
    }
}

struct UpdateBusinessTeamRoleInput: Encodable, Equatable, Sendable {
    let name: String?
    let description: String?
    let rank: Int?
    let permissionKeys: Set<String>?
    let reason: String

    init(
        name: String? = nil,
        description: String? = nil,
        permissionKeys: Set<String>? = nil,
        reason: String,
        rank: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.rank = rank
        self.permissionKeys = permissionKeys
        self.reason = reason
    }
}

struct ResetBusinessTeamPasswordInput: Encodable, Equatable, Sendable {
    let temporaryPassword: String?
    let revokeSessions: Bool
    let reason: String
}

struct BusinessTeamTemporaryPasswordResult: Decodable, Equatable, Sendable {
    let userId: String
    let temporaryPassword: String
    let mustChangePassword: Bool
    let revokedSessions: Int
    let changedAt: Date
}

struct BusinessTeamPasswordResetResponse: Decodable, Equatable, Sendable {
    let userId: String
    let credentialId: String?
    let temporaryPassword: String
    let mustChangePassword: Bool
    let revokedSessions: Int
    let revokedRefreshTokens: Int?
    let changedAt: Date
}

struct BusinessTeamSessionRevocationResult: Decodable, Equatable, Sendable {
    let userId: String
    let revokedSessions: Int
    let revokedRefreshTokens: Int
    let revokedAt: Date
    let reason: String?

    init(
        userId: String,
        revokedSessions: Int,
        revokedRefreshTokens: Int,
        revokedAt: Date,
        reason: String? = nil
    ) {
        self.userId = userId
        self.revokedSessions = revokedSessions
        self.revokedRefreshTokens = revokedRefreshTokens
        self.revokedAt = revokedAt
        self.reason = reason
    }
}

typealias BusinessTeamSessionRevocationResponse = BusinessTeamSessionRevocationResult


struct BusinessHumanCapabilityGroup: Identifiable, Equatable, Decodable, Sendable {
    let code: String
    let title: String
    let description: String
    let humanBullets: [String]
    let permissionKeys: Set<String>
    let requiredModules: Set<String>
    let sensitive: Bool
    let rank: Int

    var id: String { code }

    init(
        code: String,
        title: String,
        description: String = "",
        humanBullets: [String] = [],
        permissionKeys: Set<String> = [],
        requiredModules: Set<String> = [],
        sensitive: Bool = false,
        rank: Int = 0
    ) {
        self.code = code
        self.title = title
        self.description = description
        self.humanBullets = humanBullets
        self.permissionKeys = permissionKeys
        self.requiredModules = requiredModules
        self.sensitive = sensitive
        self.rank = rank
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case title
        case description
        case humanBullets
        case permissionKeys
        case requiredModules
        case sensitive
        case rank
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCode = try container.decode(String.self, forKey: .code)

        self.code = decodedCode
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? decodedCode
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.humanBullets = try container.decodeIfPresent([String].self, forKey: .humanBullets) ?? []
        self.permissionKeys = try container.decodeIfPresent(Set<String>.self, forKey: .permissionKeys) ?? []
        self.requiredModules = try container.decodeIfPresent(Set<String>.self, forKey: .requiredModules) ?? []
        self.sensitive = try container.decodeIfPresent(Bool.self, forKey: .sensitive) ?? false
        self.rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? 0
    }
}

struct BusinessRoleTemplate: Identifiable, Equatable, Decodable, Sendable {
    let templateCode: String
    let vertical: String
    let roleCode: String
    let name: String
    let description: String
    let permissionKeys: Set<String>
    let requiredModules: Set<String>
    let assignableByBusiness: Bool
    let editableByBusiness: Bool
    let critical: Bool
    let rank: Int
    let permissionCount: Int
    let knownPermissionCount: Int
    let capabilityGroupCodes: Set<String>
    let capabilityGroups: [BusinessHumanCapabilityGroup]

    var id: String { templateCode }

    init(
        templateCode: String,
        vertical: String,
        roleCode: String,
        name: String,
        description: String,
        permissionKeys: Set<String>,
        requiredModules: Set<String>,
        assignableByBusiness: Bool,
        editableByBusiness: Bool,
        critical: Bool,
        rank: Int,
        permissionCount: Int? = nil,
        knownPermissionCount: Int? = nil,
        capabilityGroupCodes: Set<String> = [],
        capabilityGroups: [BusinessHumanCapabilityGroup] = []
    ) {
        self.templateCode = templateCode
        self.vertical = vertical
        self.roleCode = roleCode
        self.name = name
        self.description = description
        self.permissionKeys = permissionKeys
        self.requiredModules = requiredModules
        self.assignableByBusiness = assignableByBusiness
        self.editableByBusiness = editableByBusiness
        self.critical = critical
        self.rank = rank
        self.permissionCount = permissionCount ?? permissionKeys.count
        self.knownPermissionCount = knownPermissionCount ?? permissionKeys.count
        self.capabilityGroupCodes = capabilityGroupCodes
        self.capabilityGroups = capabilityGroups
    }

    private enum CodingKeys: String, CodingKey {
        case templateCode
        case vertical
        case roleCode
        case name
        case description
        case permissionKeys
        case requiredModules
        case assignableByBusiness
        case editableByBusiness
        case critical
        case rank
        case permissionCount
        case knownPermissionCount
        case capabilityGroupCodes
        case capabilityGroups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPermissionKeys = try container.decodeIfPresent(Set<String>.self, forKey: .permissionKeys) ?? []

        let decodedTemplateCode = try container.decode(String.self, forKey: .templateCode)

        self.templateCode = decodedTemplateCode
        self.vertical = try container.decodeIfPresent(String.self, forKey: .vertical) ?? "CORE"
        self.roleCode = try container.decodeIfPresent(String.self, forKey: .roleCode) ?? decodedTemplateCode
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.permissionKeys = decodedPermissionKeys
        self.requiredModules = try container.decodeIfPresent(Set<String>.self, forKey: .requiredModules) ?? []
        self.assignableByBusiness = try container.decodeIfPresent(Bool.self, forKey: .assignableByBusiness) ?? true
        self.editableByBusiness = try container.decodeIfPresent(Bool.self, forKey: .editableByBusiness) ?? true
        self.critical = try container.decodeIfPresent(Bool.self, forKey: .critical) ?? false
        self.rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? 100
        self.permissionCount = try container.decodeIfPresent(Int.self, forKey: .permissionCount) ?? decodedPermissionKeys.count
        self.knownPermissionCount = try container.decodeIfPresent(Int.self, forKey: .knownPermissionCount) ?? decodedPermissionKeys.count
        self.capabilityGroupCodes = try container.decodeIfPresent(Set<String>.self, forKey: .capabilityGroupCodes) ?? []
        self.capabilityGroups = try container.decodeIfPresent([BusinessHumanCapabilityGroup].self, forKey: .capabilityGroups) ?? []
    }

    var readableVertical: String {
        switch vertical.uppercased() {
        case "CORE": return "General"
        case "RESTAURANT": return "Restaurante"
        case "RETAIL": return "Tienda"
        case "HARDWARE_STORE": return "Ferretería"
        case "PHARMACY": return "Farmacia"
        case "HEALTH_CENTER": return "Centro de salud"
        case "CLOTHING_STORE": return "Ropa"
        case "SHOE_STORE": return "Zapatos"
        case "SERVICES": return "Servicios"
        case "TOURISM": return "Turismo"
        default: return vertical
        }
    }
}

struct BusinessRoleTemplatesResponse: Decodable, Equatable, Sendable {
    let templates: [BusinessRoleTemplate]
}

struct BusinessHumanCapabilityGroupsResponse: Decodable, Equatable, Sendable {
    let groups: [BusinessHumanCapabilityGroup]
}

struct CreateBusinessRoleFromTemplateInput: Encodable, Equatable, Sendable {
    let templateCode: String
    let code: String?
    let name: String?
    let description: String?
    let reason: String

    init(
        templateCode: String,
        code: String? = nil,
        name: String? = nil,
        description: String? = nil,
        reason: String
    ) {
        self.templateCode = templateCode
        self.code = code
        self.name = name
        self.description = description
        self.reason = reason
    }
}
