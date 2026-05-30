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

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case name
        case identificationType
        case identificationNumber
        case identification
        case email
        case phone
        case address
        case status
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? "Cliente"
        identificationType = try container.decodeIfPresent(BusinessCustomerIdentificationType.self, forKey: .identificationType)
            ?? .unknown
        identificationNumber = try container.decodeIfPresent(String.self, forKey: .identificationNumber)
            ?? container.decodeIfPresent(String.self, forKey: .identification)
            ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

public struct CreateCustomerRequest: Encodable, Equatable, Sendable {
    public let displayName: String
    public let identificationType: BusinessCustomerIdentificationType
    public let identificationNumber: String
    public let email: String?
    public let phone: String?
    public let address: String?
    public let notes: String?

    public init(
        displayName: String,
        identificationType: BusinessCustomerIdentificationType,
        identificationNumber: String,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        notes: String? = nil
    ) {
        self.displayName = displayName
        self.identificationType = identificationType
        self.identificationNumber = identificationNumber
        self.email = email
        self.phone = phone
        self.address = address
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case displayName
        case identificationType
        case identification
        case email
        case phone
        case address
        case notes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(identificationType, forKey: .identificationType)
        try container.encode(identificationNumber, forKey: .identification)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

public struct CustomersSearchResponse: Decodable, Equatable, Sendable {
    public let customers: [BusinessCustomer]

    public init(customers: [BusinessCustomer]) {
        self.customers = customers
    }
}

public struct CustomerResponse: Decodable, Equatable, Sendable {
    public let customer: BusinessCustomer
    public let idempotencyReplayed: Bool?

    public init(customer: BusinessCustomer, idempotencyReplayed: Bool? = nil) {
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
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.customer = try BusinessCustomer(from: decoder)
        self.idempotencyReplayed = nil
    }
}
