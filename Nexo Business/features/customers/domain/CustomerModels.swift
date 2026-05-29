//
//  CustomerModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessCustomerIdentificationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case finalConsumer = "final_consumer"
    case cedula = "cedula"
    case ruc = "ruc"
    case passport = "passport"
    case foreign = "foreign"
    case unknown = "unknown"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .finalConsumer:
            return "Consumidor final"
        case .cedula:
            return "Cédula"
        case .ruc:
            return "RUC"
        case .passport:
            return "Pasaporte"
        case .foreign:
            return "Exterior"
        case .unknown:
            return "Otro"
        }
    }
}

public struct BusinessCustomer: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let identificationType: BusinessCustomerIdentificationType
    public let identificationNumber: String
    public let email: String?
    public let phone: String?
    public let address: String?
    public let status: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: String,
        displayName: String,
        identificationType: BusinessCustomerIdentificationType,
        identificationNumber: String,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        status: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.identificationType = identificationType
        self.identificationNumber = identificationNumber
        self.email = email
        self.phone = phone
        self.address = address
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case displayName
        case name
        case legalName
        case razonSocial
        case customerName
        case identificationType
        case idType
        case type
        case identificationNumber
        case identification
        case taxId
        case documentNumber
        case email
        case phone
        case address
        case status
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId])
        displayName = try container.decodeFirstString(
            for: [.displayName, .name, .legalName, .razonSocial, .customerName]
        )

        let rawIdentificationType = try container.decodeFirstStringIfPresent(
            for: [.identificationType, .idType, .type]
        ) ?? "unknown"
        identificationType = BusinessCustomerIdentificationType(rawValue: rawIdentificationType) ?? .unknown

        identificationNumber = try container.decodeFirstStringIfPresent(
            for: [.identificationNumber, .identification, .taxId, .documentNumber]
        ) ?? ""

        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

public struct CustomersSearchResponse: Decodable, Equatable, Sendable {
    public let customers: [BusinessCustomer]
    public let nextCursor: String?

    public init(
        customers: [BusinessCustomer],
        nextCursor: String? = nil
    ) {
        self.customers = customers
        self.nextCursor = nextCursor
    }

    private enum CodingKeys: String, CodingKey {
        case customers
        case items
        case results
        case data
        case nextCursor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        customers = try container.decodeIfPresent([BusinessCustomer].self, forKey: .customers)
            ?? container.decodeIfPresent([BusinessCustomer].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessCustomer].self, forKey: .results)
            ?? container.decodeIfPresent([BusinessCustomer].self, forKey: .data)
            ?? []

        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

public struct CreateCustomerRequest: Encodable, Equatable, Sendable {
    public let identificationType: String
    public let identificationNumber: String
    public let displayName: String
    public let email: String?
    public let phone: String?
    public let address: String?

    public init(
        identificationType: BusinessCustomerIdentificationType,
        identificationNumber: String,
        displayName: String,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil
    ) {
        self.identificationType = identificationType.rawValue
        self.identificationNumber = identificationNumber
        self.displayName = displayName
        self.email = email
        self.phone = phone
        self.address = address
    }
}

public struct CustomerResponse: Decodable, Equatable, Sendable {
    public let customer: BusinessCustomer
    public let idempotencyReplayed: Bool?

    public init(
        customer: BusinessCustomer,
        idempotencyReplayed: Bool? = nil
    ) {
        self.customer = customer
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case customer
        case idempotencyReplayed
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let customer = try? container.decode(BusinessCustomer.self, forKey: .customer) {
            self.customer = customer
            self.idempotencyReplayed = try container.decodeIfPresent(
                Bool.self,
                forKey: .idempotencyReplayed
            )
            return
        }

        customer = try BusinessCustomer(from: decoder)
        idempotencyReplayed = nil
    }
}

private extension KeyedDecodingContainer where Key == BusinessCustomer.CodingKeys {
    func decodeFirstString(for keys: [BusinessCustomer.CodingKeys]) throws -> String {
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

    func decodeFirstStringIfPresent(for keys: [BusinessCustomer.CodingKeys]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key) {
                return value
            }

            if let value = try decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
        }

        return nil
    }
}

public enum BusinessCustomerPresentation {
    public static let finalConsumerIdentificationNumber = "9999999999999"

    public static var finalConsumer: BusinessCustomer {
        BusinessCustomer(
            id: "final_consumer",
            displayName: "Consumidor final",
            identificationType: .finalConsumer,
            identificationNumber: finalConsumerIdentificationNumber,
            status: "active"
        )
    }

    public static func subtitle(for customer: BusinessCustomer) -> String {
        let type = customer.identificationType.displayName
        let number = customer.identificationNumber.isEmpty ? "Sin identificación" : customer.identificationNumber
        return "\(type): \(number)"
    }
}
