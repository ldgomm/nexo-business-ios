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

    private enum CodingKeys: String, CodingKey {
        case id
        case catalogItemId
        case quantity
        case note
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        catalogItemId = try container.decode(String.self, forKey: .catalogItemId)

        if let quantity = try container.decodeIfPresent(String.self, forKey: .quantity) {
            self.quantity = quantity
        } else if let quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) {
            self.quantity = String(quantity)
        } else if let quantity = try container.decodeIfPresent(BusinessSaleQuantityRequest.self, forKey: .quantity) {
            self.quantity = quantity.value
        } else {
            self.quantity = "1"
        }

        note = try container.decodeIfPresent(String.self, forKey: .note)
            ?? container.decodeIfPresent(String.self, forKey: .notes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(catalogItemId, forKey: .catalogItemId)
        try container.encode(quantity, forKey: .quantity)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

public enum BusinessSalePriceTaxMode: String, Codable, CaseIterable, Sendable {
    case taxExclusive = "TAX_EXCLUSIVE"
    case taxInclusive = "TAX_INCLUSIVE"
}

public struct BusinessSaleQuantityRequest: Codable, Equatable, Sendable {
    public let value: String
    public let unitCode: String
    public let allowsDecimal: Bool

    public init(
        value: String,
        unitCode: String = "unit",
        allowsDecimal: Bool = false
    ) {
        self.value = value
        self.unitCode = unitCode
        self.allowsDecimal = allowsDecimal
    }
}

public struct BusinessSaleItemRequest: Codable, Equatable, Sendable {
    public let catalogItemId: String
    public let quantity: BusinessSaleQuantityRequest
    public let priceTaxMode: String
    public let notes: String?

    public init(
        catalogItemId: String,
        quantity: BusinessSaleQuantityRequest,
        priceTaxMode: String = BusinessSalePriceTaxMode.taxExclusive.rawValue,
        notes: String? = nil
    ) {
        self.catalogItemId = catalogItemId
        self.quantity = quantity
        self.priceTaxMode = priceTaxMode
        self.notes = notes
    }
}

public struct BusinessSaleCustomerSnapshot: Codable, Equatable, Sendable {
    public let id: String?
    public let displayName: String
    public let identificationType: String?
    public let identificationNumber: String?
    public let email: String?

    public init(
        id: String? = nil,
        displayName: String,
        identificationType: String? = nil,
        identificationNumber: String? = nil,
        email: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.identificationType = identificationType
        self.identificationNumber = identificationNumber
        self.email = email
    }
}

public struct SalesPreviewRequest: Encodable, Equatable, Sendable {
    public let branchId: String
    public let activityId: String
    public let customerId: String?
    public let customerSnapshot: BusinessSaleCustomerSnapshot?
    public let catalogRevision: String?
    public let taxConfigurationRevision: String?
    public let items: [BusinessSaleItemRequest]

    public init(
        branchId: String,
        activityId: String,
        customerId: String? = nil,
        customerSnapshot: BusinessSaleCustomerSnapshot? = nil,
        catalogRevision: String? = nil,
        taxConfigurationRevision: String? = nil,
        items: [BusinessSaleItemRequest]
    ) {
        self.branchId = branchId
        self.activityId = activityId
        self.customerId = customerId
        self.customerSnapshot = customerSnapshot
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
        self.items = items
    }
}

public struct QuickSaleRequest: Encodable, Equatable, Sendable {
    public let requestId: String
    public let branchId: String
    public let activityId: String
    public let customerId: String?
    public let customerSnapshot: BusinessSaleCustomerSnapshot?
    public let cashSessionId: String?
    public let autoConfirm: Bool
    public let catalogRevision: String
    public let taxConfigurationRevision: String
    public let items: [BusinessSaleItemRequest]
    public let notes: String?

    public init(
        requestId: String = "quick-sale-\(UUID().uuidString.lowercased())",
        branchId: String,
        activityId: String,
        customerId: String? = nil,
        customerSnapshot: BusinessSaleCustomerSnapshot? = nil,
        cashSessionId: String? = nil,
        autoConfirm: Bool = true,
        catalogRevision: String,
        taxConfigurationRevision: String,
        items: [BusinessSaleItemRequest],
        notes: String? = nil
    ) {
        self.requestId = requestId
        self.branchId = branchId
        self.activityId = activityId
        self.customerId = customerId
        self.customerSnapshot = customerSnapshot
        self.cashSessionId = cashSessionId
        self.autoConfirm = autoConfirm
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
        self.items = items
        self.notes = notes
    }

    public init(
        requestId: String = "quick-sale-\(UUID().uuidString.lowercased())",
        branchId: String,
        activityId: String,
        customerId: String? = nil,
        customerSnapshot: BusinessSaleCustomerSnapshot? = nil,
        cashSessionId: String? = nil,
        autoConfirm: Bool = true,
        catalogRevision: String,
        taxConfigurationRevision: String,
        items: [BusinessSaleItemRequest],
        note: String?
    ) {
        self.init(
            requestId: requestId,
            branchId: branchId,
            activityId: activityId,
            customerId: customerId,
            customerSnapshot: customerSnapshot,
            cashSessionId: cashSessionId,
            autoConfirm: autoConfirm,
            catalogRevision: catalogRevision,
            taxConfigurationRevision: taxConfigurationRevision,
            items: items,
            notes: note
        )
    }
}

public struct ConfirmSaleRequest: Encodable, Equatable, Sendable {
    public let notes: String?

    public init(notes: String? = nil) {
        self.notes = notes
    }

    public init(note: String?) {
        self.notes = note
    }
}

public struct CancelSaleRequest: Encodable, Equatable, Sendable {
    public let reason: String
    public let notes: String?

    public init(reason: String, notes: String? = nil) {
        self.reason = reason
        self.notes = notes
    }

    public init(reason: String, note: String?) {
        self.reason = reason
        self.notes = note
    }
}

public struct BusinessSaleCustomer: Decodable, Equatable, Sendable {
    public let id: String?
    public let displayName: String
    public let identification: String?

    public init(id: String? = nil, displayName: String, identification: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.identification = identification
    }
}

public struct BusinessSaleTotals: Decodable, Equatable, Sendable {
    public let subtotal: MoneyAmount
    public let discount: MoneyAmount
    public let tax: MoneyAmount
    public let total: MoneyAmount

    public init(
        subtotal: MoneyAmount,
        discount: MoneyAmount,
        tax: MoneyAmount,
        total: MoneyAmount
    ) {
        self.subtotal = subtotal
        self.discount = discount
        self.tax = tax
        self.total = total
    }

    private enum CodingKeys: String, CodingKey {
        case subtotal
        case subtotalWithoutTaxes
        case discount
        case discountTotal
        case tax
        case taxTotal
        case total
        case grandTotal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subtotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .subtotal)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .subtotalWithoutTaxes)
            ?? MoneyAmount(amount: "0.00")
        discount = try container.decodeIfPresent(MoneyAmount.self, forKey: .discount)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .discountTotal)
            ?? MoneyAmount(amount: "0.00")
        tax = try container.decodeIfPresent(MoneyAmount.self, forKey: .tax)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .taxTotal)
            ?? MoneyAmount(amount: "0.00")
        total = try container.decodeIfPresent(MoneyAmount.self, forKey: .total)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .grandTotal)
            ?? MoneyAmount(amount: "0.00")
    }
}


public extension BusinessSaleTotals {
    var subtotalWithoutTaxes: MoneyAmount { subtotal }
    var discountTotal: MoneyAmount { discount }
    var taxTotal: MoneyAmount { tax }
    var grandTotal: MoneyAmount { total }

    init(
        subtotalWithoutTaxes: MoneyAmount,
        discountTotal: MoneyAmount,
        taxTotal: MoneyAmount,
        grandTotal: MoneyAmount
    ) {
        self.init(
            subtotal: subtotalWithoutTaxes,
            discount: discountTotal,
            tax: taxTotal,
            total: grandTotal
        )
    }
}

public typealias SaleTotals = BusinessSaleTotals

public struct BusinessSaleItem: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let catalogItemId: String?
    public let name: String
    public let quantity: String
    public let unitPrice: MoneyAmount?
    public let subtotal: MoneyAmount?
    public let total: MoneyAmount?
    public let note: String?

    public init(
        id: String,
        catalogItemId: String? = nil,
        name: String,
        quantity: String,
        unitPrice: MoneyAmount? = nil,
        subtotal: MoneyAmount? = nil,
        total: MoneyAmount? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.catalogItemId = catalogItemId
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.subtotal = subtotal
        self.total = total
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case catalogItemId
        case name
        case description
        case quantity
        case unitPrice
        case subtotal
        case total
        case note
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        catalogItemId = try container.decodeIfPresent(String.self, forKey: .catalogItemId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? "Ítem"
        if let value = try container.decodeIfPresent(String.self, forKey: .quantity) {
            quantity = value
        } else if let value = try container.decodeIfPresent(Double.self, forKey: .quantity) {
            quantity = String(value)
        } else if let value = try container.decodeIfPresent(BusinessSaleQuantityRequest.self, forKey: .quantity) {
            quantity = value.value
        } else {
            quantity = "1"
        }
        unitPrice = try container.decodeIfPresent(MoneyAmount.self, forKey: .unitPrice)
        subtotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .subtotal)
        total = try container.decodeIfPresent(MoneyAmount.self, forKey: .total)
        note = try container.decodeIfPresent(String.self, forKey: .note)
            ?? container.decodeIfPresent(String.self, forKey: .notes)
    }
}

public typealias SalePreviewItem = BusinessSaleItem

public struct BusinessSale: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: String?
    public let organizationId: String?
    public let branchId: String
    public let activityId: String?
    public let customerId: String?
    public let customerName: String?
    public let customer: BusinessSaleCustomer?
    public let status: String
    public let paymentStatus: String?
    public let documentStatus: String?
    public let totals: BusinessSaleTotals
    public let items: [BusinessSaleItem]
    public let createdAt: Date?
    public let confirmedAt: Date?
    public let closedAt: Date?
    public let updatedAt: Date?

    public init(
        id: String,
        number: String? = nil,
        organizationId: String? = nil,
        branchId: String,
        activityId: String? = nil,
        customerId: String? = nil,
        customerName: String? = nil,
        customer: BusinessSaleCustomer? = nil,
        status: String,
        paymentStatus: String? = nil,
        documentStatus: String? = nil,
        totals: BusinessSaleTotals,
        items: [BusinessSaleItem] = [],
        createdAt: Date? = nil,
        confirmedAt: Date? = nil,
        closedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.number = number
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.customerId = customerId
        self.customerName = customerName
        self.customer = customer
        self.status = status
        self.paymentStatus = paymentStatus
        self.documentStatus = documentStatus
        self.totals = totals
        self.items = items
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
        self.closedAt = closedAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case organizationId
        case branchId
        case activityId
        case customerId
        case customerName
        case customer
        case status
        case paymentStatus
        case documentStatus
        case totals
        case total
        case items
        case createdAt
        case confirmedAt
        case closedAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        number = try container.decodeIfPresent(String.self, forKey: .number)
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId) ?? ""
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId)
        customerId = try container.decodeIfPresent(String.self, forKey: .customerId)
        customerName = try container.decodeIfPresent(String.self, forKey: .customerName)
        customer = try container.decodeIfPresent(BusinessSaleCustomer.self, forKey: .customer)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        paymentStatus = try container.decodeIfPresent(String.self, forKey: .paymentStatus)
        documentStatus = try container.decodeIfPresent(String.self, forKey: .documentStatus)
        if let totals = try container.decodeIfPresent(BusinessSaleTotals.self, forKey: .totals) {
            self.totals = totals
        } else if let total = try container.decodeIfPresent(MoneyAmount.self, forKey: .total) {
            self.totals = BusinessSaleTotals(
                subtotal: total,
                discount: MoneyAmount(amount: "0.00"),
                tax: MoneyAmount(amount: "0.00"),
                total: total
            )
        } else {
            self.totals = BusinessSaleTotals(
                subtotal: MoneyAmount(amount: "0.00"),
                discount: MoneyAmount(amount: "0.00"),
                tax: MoneyAmount(amount: "0.00"),
                total: MoneyAmount(amount: "0.00")
            )
        }
        items = try container.decodeIfPresent([BusinessSaleItem].self, forKey: .items) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        confirmedAt = try container.decodeIfPresent(Date.self, forKey: .confirmedAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

public typealias BusinessSaleSummary = BusinessSale

public struct SalesPreviewResponse: Decodable, Equatable, Sendable {
    public let items: [BusinessSaleItem]
    public let totals: BusinessSaleTotals
    public let warnings: [String]

    public init(
        items: [BusinessSaleItem],
        totals: BusinessSaleTotals,
        warnings: [String] = []
    ) {
        self.items = items
        self.totals = totals
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case totals
        case preview
        case warnings
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let preview = try? container.decode(SalesPreviewResponse.self, forKey: .preview) {
                self = preview
                return
            }

            items = try container.decodeIfPresent([BusinessSaleItem].self, forKey: .items) ?? []
            totals = try container.decodeIfPresent(BusinessSaleTotals.self, forKey: .totals)
                ?? BusinessSaleTotals(
                    subtotal: MoneyAmount(amount: "0.00"),
                    discount: MoneyAmount(amount: "0.00"),
                    tax: MoneyAmount(amount: "0.00"),
                    total: MoneyAmount(amount: "0.00")
                )
            warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
            return
        }

        items = []
        totals = BusinessSaleTotals(
            subtotal: MoneyAmount(amount: "0.00"),
            discount: MoneyAmount(amount: "0.00"),
            tax: MoneyAmount(amount: "0.00"),
            total: MoneyAmount(amount: "0.00")
        )
        warnings = []
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

    public init(sale: BusinessSale, idempotencyReplayed: Bool? = nil) {
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

    public init(sale: BusinessSale, idempotencyReplayed: Bool? = nil) {
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

    public init(sale: BusinessSale, idempotencyReplayed: Bool? = nil) {
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

public typealias BusinessSalesListResponse = BusinessSalesHistoryResponse
