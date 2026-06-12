//
//  CustomerModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessCustomerIdentificationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case finalConsumer = "final_consumer"
    case cedula = "cedula"
    case ruc = "ruc"
    case passport = "passport"
    case foreign = "foreign"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
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

struct BusinessCustomer: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let identificationType: BusinessCustomerIdentificationType
    let identificationNumber: String
    let email: String?
    let phone: String?
    let address: String?
    let status: String?
    let createdAt: Date?
    let updatedAt: Date?

    init(
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
        case mongoId = "_id"
        case displayName
        case name
        case identificationType
        case idType
        case identificationNumber
        case identification
        case taxId
        case email
        case phone
        case address
        case status
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .mongoId)
            ?? ""

        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? "Cliente"

        identificationType = try container.decodeIfPresent(BusinessCustomerIdentificationType.self, forKey: .identificationType)
            ?? container.decodeIfPresent(BusinessCustomerIdentificationType.self, forKey: .idType)
            ?? .unknown

        identificationNumber = try container.decodeIfPresent(String.self, forKey: .identificationNumber)
            ?? container.decodeIfPresent(String.self, forKey: .identification)
            ?? container.decodeIfPresent(String.self, forKey: .taxId)
            ?? ""

        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct CreateCustomerRequest: Encodable, Equatable, Sendable {
    let displayName: String
    let identificationType: BusinessCustomerIdentificationType
    let identificationNumber: String
    let email: String?
    let phone: String?
    let address: String?
    let notes: String?

    init(
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

    func encode(to encoder: Encoder) throws {
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

struct CustomersSearchResponse: Decodable, Equatable, Sendable {
    let customers: [BusinessCustomer]

    init(customers: [BusinessCustomer]) {
        self.customers = customers
    }

    private enum CodingKeys: String, CodingKey {
        case customers
        case items
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        customers = try container.decodeIfPresent([BusinessCustomer].self, forKey: .customers)
            ?? container.decodeIfPresent([BusinessCustomer].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessCustomer].self, forKey: .data)
            ?? []
    }
}

struct CustomerResponse: Decodable, Equatable, Sendable {
    let customer: BusinessCustomer
    let idempotencyReplayed: Bool?

    init(customer: BusinessCustomer, idempotencyReplayed: Bool? = nil) {
        self.customer = customer
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case customer
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
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
