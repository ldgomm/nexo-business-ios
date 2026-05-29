//
//  BusinessOrganizationAccessModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct BusinessOrganizationAccess: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let commercialName: String
    public let legalName: String?
    public let taxId: String?
    public let countryCode: String?
    public let roleName: String?
    public let status: String?

    public init(
        id: String,
        commercialName: String,
        legalName: String? = nil,
        taxId: String? = nil,
        countryCode: String? = nil,
        roleName: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.commercialName = commercialName
        self.legalName = legalName
        self.taxId = taxId
        self.countryCode = countryCode
        self.roleName = roleName
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case organizationId
        case commercialName
        case name
        case legalName
        case taxId
        case ruc
        case countryCode
        case roleName
        case role
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFirstString(for: [.id, .organizationId, .mongoId])
        commercialName = try container.decodeFirstString(for: [.commercialName, .name, .legalName])
        legalName = try container.decodeFirstStringIfPresent(for: [.legalName])
        taxId = try container.decodeFirstStringIfPresent(for: [.taxId, .ruc])
        countryCode = try container.decodeFirstStringIfPresent(for: [.countryCode])
        roleName = try container.decodeFirstStringIfPresent(for: [.roleName, .role])
        status = try container.decodeFirstStringIfPresent(for: [.status])
    }
}

public struct BusinessOrganizationAccessResponse: Decodable, Equatable, Sendable {
    public let organizations: [BusinessOrganizationAccess]

    public init(organizations: [BusinessOrganizationAccess]) {
        self.organizations = organizations
    }

    private enum CodingKeys: String, CodingKey {
        case organizations
        case businesses
        case data
        case results
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        organizations = try container.decodeIfPresent([BusinessOrganizationAccess].self, forKey: .organizations)
            ?? container.decodeIfPresent([BusinessOrganizationAccess].self, forKey: .businesses)
            ?? container.decodeIfPresent([BusinessOrganizationAccess].self, forKey: .data)
            ?? container.decodeIfPresent([BusinessOrganizationAccess].self, forKey: .results)
            ?? []
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) throws -> String {
        for key in keys {
            if let value = try decodeFirstStringIfPresent(for: [key]), !value.isEmpty {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected one of keys: \(keys.map(\.stringValue).joined(separator: ", "))"
            )
        )
    }

    func decodeFirstStringIfPresent(for keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }

            if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }

            if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            }
        }

        return nil
    }
}
