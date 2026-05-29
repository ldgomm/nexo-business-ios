//
//  SalesModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct SaleDraftItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let catalogItemId: String
    public let quantity: String
    public let note: String?

    public init(
        id: String = UUID().uuidString,
        catalogItemId: String,
        quantity: String,
        note: String? = nil
    ) {
        self.id = id
        self.catalogItemId = catalogItemId
        self.quantity = quantity
        self.note = note
    }
}

public struct SalesPreviewRequest: Encodable, Equatable, Sendable {
    public let branchId: String
    public let activityId: String
    public let customerId: String?
    public let items: [SaleDraftItem]

    public init(
        branchId: String,
        activityId: String,
        customerId: String? = nil,
        items: [SaleDraftItem]
    ) {
        self.branchId = branchId
        self.activityId = activityId
        self.customerId = customerId
        self.items = items
    }
}

public struct QuickSaleRequest: Encodable, Equatable, Sendable {
    public let branchId: String
    public let activityId: String
    public let customerId: String?
    public let items: [SaleDraftItem]
    public let note: String?

    public init(
        branchId: String,
        activityId: String,
        customerId: String? = nil,
        items: [SaleDraftItem],
        note: String? = nil
    ) {
        self.branchId = branchId
        self.activityId = activityId
        self.customerId = customerId
        self.items = items
        self.note = note
    }
}

public struct ConfirmSaleRequest: Encodable, Equatable, Sendable {
    public let note: String?

    public init(note: String? = nil) {
        self.note = note
    }
}

public struct CancelSaleRequest: Encodable, Equatable, Sendable {
    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }
}

public struct SaleTotals: Decodable, Equatable, Sendable {
    public let subtotalWithoutTaxes: MoneyAmount
    public let discountTotal: MoneyAmount
    public let taxTotal: MoneyAmount
    public let grandTotal: MoneyAmount

    public init(
        subtotalWithoutTaxes: MoneyAmount,
        discountTotal: MoneyAmount,
        taxTotal: MoneyAmount,
        grandTotal: MoneyAmount
    ) {
        self.subtotalWithoutTaxes = subtotalWithoutTaxes
        self.discountTotal = discountTotal
        self.taxTotal = taxTotal
        self.grandTotal = grandTotal
    }
}

public struct SaleLinePreview: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let catalogItemId: String
    public let name: String
    public let quantity: String
    public let unitPrice: MoneyAmount
    public let lineSubtotal: MoneyAmount
    public let taxTotal: MoneyAmount
    public let lineTotal: MoneyAmount

    public init(
        id: String,
        catalogItemId: String,
        name: String,
        quantity: String,
        unitPrice: MoneyAmount,
        lineSubtotal: MoneyAmount,
        taxTotal: MoneyAmount,
        lineTotal: MoneyAmount
    ) {
        self.id = id
        self.catalogItemId = catalogItemId
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineSubtotal = lineSubtotal
        self.taxTotal = taxTotal
        self.lineTotal = lineTotal
    }
}

public struct SalesPreviewResponse: Decodable, Equatable, Sendable {
    public let previewId: String?
    public let totals: SaleTotals
    public let items: [SaleLinePreview]
    public let warnings: [String]
    public let revisions: BusinessRevisions?

    public init(
        previewId: String? = nil,
        totals: SaleTotals,
        items: [SaleLinePreview],
        warnings: [String] = [],
        revisions: BusinessRevisions? = nil
    ) {
        self.previewId = previewId
        self.totals = totals
        self.items = items
        self.warnings = warnings
        self.revisions = revisions
    }
}

public struct BusinessSale: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let organizationId: String
    public let branchId: String
    public let activityId: String
    public let customerId: String?
    public let status: String
    public let paymentStatus: String?
    public let documentStatus: String?
    public let totals: SaleTotals
    public let items: [SaleLinePreview]
    public let note: String?
    public let createdAt: Date?
    public let confirmedAt: Date?
    public let canceledAt: Date?
    public let closedAt: Date?
    public let updatedAt: Date?

    public init(
        id: String,
        organizationId: String,
        branchId: String,
        activityId: String,
        customerId: String? = nil,
        status: String,
        paymentStatus: String? = nil,
        documentStatus: String? = nil,
        totals: SaleTotals,
        items: [SaleLinePreview] = [],
        note: String? = nil,
        createdAt: Date? = nil,
        confirmedAt: Date? = nil,
        canceledAt: Date? = nil,
        closedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.customerId = customerId
        self.status = status
        self.paymentStatus = paymentStatus
        self.documentStatus = documentStatus
        self.totals = totals
        self.items = items
        self.note = note
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
        self.canceledAt = canceledAt
        self.closedAt = closedAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case organizationId
        case branchId
        case activityId
        case customerId
        case status
        case paymentStatus
        case documentStatus
        case totals
        case items
        case lines
        case note
        case createdAt
        case confirmedAt
        case canceledAt
        case closedAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId])
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId) ?? ""
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId) ?? ""
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId) ?? ""
        customerId = try container.decodeIfPresent(String.self, forKey: .customerId)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        paymentStatus = try container.decodeIfPresent(String.self, forKey: .paymentStatus)
        documentStatus = try container.decodeIfPresent(String.self, forKey: .documentStatus)
        totals = try container.decode(SaleTotals.self, forKey: .totals)
        items = try container.decodeFirstLinesIfPresent(for: [.items, .lines]) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        confirmedAt = try container.decodeIfPresent(Date.self, forKey: .confirmedAt)
        canceledAt = try container.decodeIfPresent(Date.self, forKey: .canceledAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) throws -> String {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
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

    func decodeFirstLinesIfPresent(for keys: [Key]) throws -> [SaleLinePreview]? {
        for key in keys {
            if let value = try decodeIfPresent([SaleLinePreview].self, forKey: key) {
                return value
            }
        }

        return nil
    }
}

public struct BusinessSaleDetailResponse: Decodable, Equatable, Sendable {
    public let sale: BusinessSale

    public init(sale: BusinessSale) {
        self.sale = sale
    }

    private enum CodingKeys: String, CodingKey {
        case sale
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            return
        }

        self.sale = try BusinessSale(from: decoder)
    }
}

public struct QuickSaleResponse: Decodable, Equatable, Sendable {
    public let sale: BusinessSale
    public let idempotencyReplayed: Bool?

    public init(
        sale: BusinessSale,
        idempotencyReplayed: Bool? = nil
    ) {
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case sale
        case idempotencyReplayed
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.sale = try BusinessSale(from: decoder)
        self.idempotencyReplayed = nil
    }
}

public struct ConfirmSaleResponse: Decodable, Equatable, Sendable {
    public let sale: BusinessSale
    public let idempotencyReplayed: Bool?

    public init(
        sale: BusinessSale,
        idempotencyReplayed: Bool? = nil
    ) {
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case sale
        case idempotencyReplayed
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.sale = try BusinessSale(from: decoder)
        self.idempotencyReplayed = nil
    }
}

public struct CancelSaleResponse: Decodable, Equatable, Sendable {
    public let sale: BusinessSale
    public let idempotencyReplayed: Bool?

    public init(
        sale: BusinessSale,
        idempotencyReplayed: Bool? = nil
    ) {
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case sale
        case idempotencyReplayed
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            self.idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.sale = try BusinessSale(from: decoder)
        self.idempotencyReplayed = nil
    }
}
