//
//  BusinessContextModels.swift
//  Nexo Admin
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
}

public struct BusinessReadiness: Decodable, Equatable, Sendable {
    public let status: String
    public let score: Int?
    public let blockers: [String]
    public let warnings: [String]
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
}
