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

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Self.fromBackend(raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func fromBackend(_ raw: String) -> BusinessCustomerIdentificationType {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_EC"))
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "final_consumer", "finalconsumer", "consumidor_final", "consumidorfinal":
            return .finalConsumer
        case "cedula", "cedula_ec", "ci", "id", "id_card", "identity_card":
            return .cedula
        case "ruc", "tax_id", "taxid":
            return .ruc
        case "passport", "pasaporte":
            return .passport
        case "foreign", "foreigner", "exterior", "extranjero":
            return .foreign
        default:
            return BusinessCustomerIdentificationType(rawValue: normalized) ?? .unknown
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
        case fullName
        case legalName
        case businessName
        case customerName
        case identificationType
        case idType
        case documentType
        case type
        case identificationNumber
        case identification
        case taxId
        case documentNumber
        case idNumber
        case legalId
        case ruc
        case cedula
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

        displayName = try container.decodeFlexibleStringIfPresent(forKey: .displayName)
            ?? container.decodeFlexibleStringIfPresent(forKey: .name)
            ?? container.decodeFlexibleStringIfPresent(forKey: .fullName)
            ?? container.decodeFlexibleStringIfPresent(forKey: .legalName)
            ?? container.decodeFlexibleStringIfPresent(forKey: .businessName)
            ?? container.decodeFlexibleStringIfPresent(forKey: .customerName)
            ?? "Cliente"

        identificationType = (try? container.decodeIfPresent(BusinessCustomerIdentificationType.self, forKey: .identificationType))
            ?? (try? container.decodeIfPresent(BusinessCustomerIdentificationType.self, forKey: .idType))
            ?? (try? container.decodeIfPresent(BusinessCustomerIdentificationType.self, forKey: .documentType))
            ?? (try? container.decodeIfPresent(BusinessCustomerIdentificationType.self, forKey: .type))
            ?? .unknown

        identificationNumber = try container.decodeFlexibleStringIfPresent(forKey: .identificationNumber)
            ?? container.decodeFlexibleStringIfPresent(forKey: .identification)
            ?? container.decodeFlexibleStringIfPresent(forKey: .taxId)
            ?? container.decodeFlexibleStringIfPresent(forKey: .documentNumber)
            ?? container.decodeFlexibleStringIfPresent(forKey: .idNumber)
            ?? container.decodeFlexibleStringIfPresent(forKey: .legalId)
            ?? container.decodeFlexibleStringIfPresent(forKey: .ruc)
            ?? container.decodeFlexibleStringIfPresent(forKey: .cedula)
            ?? ""

        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decodeFlexibleDateIfPresent(forKey: .createdAt)
        updatedAt = try container.decodeFlexibleDateIfPresent(forKey: .updatedAt)
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

    init(from decoder: Decoder) throws {
        customers = try CustomerCollectionEnvelope(from: decoder).customers
    }
}

private struct CustomerCollectionEnvelope: Decodable {
    let customers: [BusinessCustomer]

    private enum CodingKeys: String, CodingKey {
        case customers
        case items
        case data
        case results
        case records
        case content
        case payload
        case result
    }

    init(from decoder: Decoder) throws {
        if let array = try? [BusinessCustomer](from: decoder) {
            customers = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        for key in [CodingKeys.customers, .items, .data, .results, .records, .content] {
            if let array = try? container.decodeIfPresent([BusinessCustomer].self, forKey: key) {
                customers = array
                return
            }
        }

        for key in [CodingKeys.data, .payload, .result] {
            if let envelope = try? container.decodeIfPresent(CustomerCollectionEnvelope.self, forKey: key) {
                customers = envelope.customers
                return
            }
        }

        customers = []
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
        case data
        case payload
        case result
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let customer = try? container.decode(BusinessCustomer.self, forKey: .customer) {
                self.customer = customer
                self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
                return
            }

            for key in [CodingKeys.data, .payload, .result] {
                if let nested = try? container.decodeIfPresent(CustomerResponse.self, forKey: key) {
                    self.customer = nested.customer
                    self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
                        ?? nested.idempotencyReplayed
                    return
                }
            }
        }

        self.customer = try BusinessCustomer(from: decoder)
        self.idempotencyReplayed = nil
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try decodeIfPresent(Decimal.self, forKey: key) {
            return NSDecimalNumber(decimal: value).stringValue
        }
        return nil
    }

    func decodeFlexibleDateIfPresent(forKey key: Key) throws -> Date? {
        if let date = try? decodeIfPresent(Date.self, forKey: key) {
            return date
        }

        guard let raw = try decodeFlexibleStringIfPresent(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }

        if let milliseconds = Double(raw), milliseconds > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: milliseconds / 1_000)
        }
        if let seconds = Double(raw), seconds > 1_000_000_000 {
            return Date(timeIntervalSince1970: seconds)
        }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: raw) {
            return date
        }

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) {
            return date
        }

        return nil
    }
}
