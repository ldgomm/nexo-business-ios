//
//  SalesModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct SaleDraftItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let catalogItemId: String
    let quantity: String
    let note: String?

    init(
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        catalogItemId = try container.decode(String.self, forKey: .catalogItemId)

        if let quantity = try? container.decodeIfPresent(String.self, forKey: .quantity) {
            self.quantity = quantity
        } else if let quantity = try? container.decodeIfPresent(Double.self, forKey: .quantity) {
            self.quantity = String(quantity)
        } else if let quantity = try? container.decodeIfPresent(BusinessSaleQuantityRequest.self, forKey: .quantity) {
            self.quantity = quantity.value
        } else {
            self.quantity = "1"
        }

        note = (try? container.decodeIfPresent(String.self, forKey: .note))
            ?? (try? container.decodeIfPresent(String.self, forKey: .notes))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(catalogItemId, forKey: .catalogItemId)
        try container.encode(quantity, forKey: .quantity)
        try container.encodeIfPresent(note, forKey: .notes)
    }
}

enum BusinessSalePriceTaxMode: String, Codable, CaseIterable, Sendable {
    case taxExclusive = "TAX_EXCLUSIVE"
    case taxInclusive = "TAX_INCLUSIVE"
}

struct BusinessSaleQuantityRequest: Codable, Equatable, Sendable {
    let value: String
    let unitCode: String
    let allowsDecimal: Bool

    init(
        value: String,
        unitCode: String = "unit",
        allowsDecimal: Bool = false
    ) {
        self.value = value
        self.unitCode = unitCode
        self.allowsDecimal = allowsDecimal
    }
}

struct BusinessSaleItemRequest: Codable, Equatable, Sendable {
    let catalogItemId: String
    let quantity: BusinessSaleQuantityRequest
    let priceTaxMode: String
    let notes: String?

    init(
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

struct BusinessSaleCustomerSnapshot: Codable, Equatable, Sendable {
    let id: String?
    let displayName: String
    let identificationType: String?
    let identificationNumber: String?
    let email: String?

    init(
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

struct SalesPreviewRequest: Encodable, Equatable, Sendable {
    let branchId: String
    let activityId: String
    let customerId: String?
    let customerSnapshot: BusinessSaleCustomerSnapshot?
    let catalogRevision: String?
    let taxConfigurationRevision: String?
    let items: [BusinessSaleItemRequest]

    init(
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

struct QuickSaleRequest: Encodable, Equatable, Sendable {
    let requestId: String
    let branchId: String
    let activityId: String
    let customerId: String?
    let customerSnapshot: BusinessSaleCustomerSnapshot?
    let cashSessionId: String?
    let autoConfirm: Bool
    let catalogRevision: String
    let taxConfigurationRevision: String
    let items: [BusinessSaleItemRequest]
    let notes: String?

    init(
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

    init(
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

struct ConfirmSaleRequest: Encodable, Equatable, Sendable {
    let notes: String?

    init(notes: String? = nil) {
        self.notes = notes
    }

    init(note: String?) {
        self.notes = note
    }
}

struct CancelSaleRequest: Encodable, Equatable, Sendable {
    let reason: String
    let notes: String?

    init(reason: String, notes: String? = nil) {
        self.reason = reason
        self.notes = notes
    }

    init(reason: String, note: String?) {
        self.reason = reason
        self.notes = note
    }
}

struct BusinessSaleCustomer: Decodable, Equatable, Sendable {
    let id: String?
    let displayName: String
    let identification: String?

    init(id: String? = nil, displayName: String, identification: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.identification = identification
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case customerId
        case displayName
        case name
        case taxId
        case identification
        case identificationNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? (try? container.decodeIfPresent(String.self, forKey: .customerId))
        displayName = (try? container.decodeIfPresent(String.self, forKey: .displayName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? "Consumidor final"
        identification = (try? container.decodeIfPresent(String.self, forKey: .identification))
            ?? (try? container.decodeIfPresent(String.self, forKey: .identificationNumber))
            ?? (try? container.decodeIfPresent(String.self, forKey: .taxId))
    }
}

struct BusinessSaleTotals: Decodable, Equatable, Sendable {
    let subtotal: MoneyAmount
    let discount: MoneyAmount
    let tax: MoneyAmount
    let total: MoneyAmount

    init(
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
        case grossSubtotal
        case subtotalTaxable
        case discount
        case discountTotal
        case totalDiscount
        case tax
        case taxTotal
        case totalTax
        case total
        case grandTotal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subtotal = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .subtotal))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .subtotalWithoutTaxes))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .grossSubtotal))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .subtotalTaxable))
            ?? MoneyAmount(amount: "0.00")
        discount = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .discount))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .discountTotal))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .totalDiscount))
            ?? MoneyAmount(amount: "0.00")
        tax = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .tax))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .taxTotal))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .totalTax))
            ?? MoneyAmount(amount: "0.00")
        total = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .total))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .grandTotal))
            ?? MoneyAmount(amount: "0.00")
    }
}

extension BusinessSaleTotals {
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

typealias SaleTotals = BusinessSaleTotals

struct BusinessSaleItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let catalogItemId: String?
    let name: String
    let quantity: String
    let unitPrice: MoneyAmount?
    let subtotal: MoneyAmount?
    let total: MoneyAmount?
    let note: String?

    init(
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
        case lineId
        case catalogItemId
        case name
        case catalogItemName
        case description
        case quantity
        case unitPrice
        case grossAmount
        case grossTotal
        case subtotal
        case taxableBase
        case total
        case lineTotal
        case netTotal
        case note
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? (try? container.decodeIfPresent(String.self, forKey: .lineId))
            ?? UUID().uuidString
        catalogItemId = try? container.decodeIfPresent(String.self, forKey: .catalogItemId)
        name = (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? (try? container.decodeIfPresent(String.self, forKey: .catalogItemName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .description))
            ?? "Ítem"

        if let value = try? container.decodeIfPresent(String.self, forKey: .quantity) {
            quantity = value
        } else if let value = try? container.decodeIfPresent(Double.self, forKey: .quantity) {
            quantity = String(value)
        } else if let value = try? container.decodeIfPresent(BusinessSaleQuantityRequest.self, forKey: .quantity) {
            quantity = value.value
        } else {
            quantity = "1"
        }

        unitPrice = try? container.decodeIfPresent(MoneyAmount.self, forKey: .unitPrice)
        subtotal = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .subtotal))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .grossAmount))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .grossTotal))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .taxableBase))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .netTotal))
        total = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .total))
            ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .lineTotal))
        note = (try? container.decodeIfPresent(String.self, forKey: .note))
            ?? (try? container.decodeIfPresent(String.self, forKey: .notes))
    }
}

typealias SalePreviewItem = BusinessSaleItem

struct BusinessSale: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let number: String?
    let organizationId: String?
    let branchId: String
    let activityId: String?
    let customerId: String?
    let customerName: String?
    let customer: BusinessSaleCustomer?
    let status: String
    let paymentStatus: String?
    let documentStatus: String?
    let totals: BusinessSaleTotals
    let items: [BusinessSaleItem]
    let createdAt: Date?
    let confirmedAt: Date?
    let closedAt: Date?
    let updatedAt: Date?

    init(
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
        case saleNumber
        case organizationId
        case branchId
        case activityId
        case customerId
        case customerName
        case customer
        case customerSnapshot
        case status
        case operationalStatus
        case paymentStatus
        case documentStatus
        case totals
        case summary
        case total
        case grandTotal
        case items
        case lines
        case createdAt
        case confirmedAt
        case closedAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        number = (try? container.decodeIfPresent(String.self, forKey: .number))
            ?? (try? container.decodeIfPresent(String.self, forKey: .saleNumber))
        organizationId = try? container.decodeIfPresent(String.self, forKey: .organizationId)
        branchId = (try? container.decodeIfPresent(String.self, forKey: .branchId)) ?? ""
        activityId = try? container.decodeIfPresent(String.self, forKey: .activityId)
        customerId = try? container.decodeIfPresent(String.self, forKey: .customerId)
        customerName = try? container.decodeIfPresent(String.self, forKey: .customerName)
        customer = (try? container.decodeIfPresent(BusinessSaleCustomer.self, forKey: .customer))
            ?? (try? container.decodeIfPresent(BusinessSaleCustomer.self, forKey: .customerSnapshot))
        status = (try? container.decodeIfPresent(String.self, forKey: .status))
            ?? (try? container.decodeIfPresent(String.self, forKey: .operationalStatus))
            ?? "pending"
        paymentStatus = try? container.decodeIfPresent(String.self, forKey: .paymentStatus)
        documentStatus = try? container.decodeIfPresent(String.self, forKey: .documentStatus)

        if let totals = try? container.decodeIfPresent(BusinessSaleTotals.self, forKey: .totals) {
            self.totals = totals
        } else if let totals = try? container.decodeIfPresent(BusinessSaleTotals.self, forKey: .summary) {
            self.totals = totals
        } else if let total = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .total))
                    ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .grandTotal)) {
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

        items = (try? container.decodeIfPresent([BusinessSaleItem].self, forKey: .items))
            ?? (try? container.decodeIfPresent([BusinessSaleItem].self, forKey: .lines))
            ?? []
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        confirmedAt = try? container.decodeIfPresent(Date.self, forKey: .confirmedAt)
        closedAt = try? container.decodeIfPresent(Date.self, forKey: .closedAt)
        updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

typealias BusinessSaleSummary = BusinessSale

struct SalesPreviewResponse: Decodable, Equatable, Sendable {
    let items: [BusinessSaleItem]
    let totals: BusinessSaleTotals
    let warnings: [String]

    init(
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
        case lines
        case totals
        case summary
        case preview
        case warnings
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let preview = try? container.decode(SalesPreviewResponse.self, forKey: .preview) {
                self = preview
                return
            }

            items = (try? container.decodeIfPresent([BusinessSaleItem].self, forKey: .items))
                ?? (try? container.decodeIfPresent([BusinessSaleItem].self, forKey: .lines))
                ?? []
            totals = (try? container.decodeIfPresent(BusinessSaleTotals.self, forKey: .totals))
                ?? (try? container.decodeIfPresent(BusinessSaleTotals.self, forKey: .summary))
                ?? BusinessSaleTotals(
                    subtotal: MoneyAmount(amount: "0.00"),
                    discount: MoneyAmount(amount: "0.00"),
                    tax: MoneyAmount(amount: "0.00"),
                    total: MoneyAmount(amount: "0.00")
                )
            warnings = (try? container.decodeIfPresent([String].self, forKey: .warnings)) ?? []
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

struct BusinessSaleDetailResponse: Decodable, Equatable, Sendable {
    let sale: BusinessSale

    init(sale: BusinessSale) {
        self.sale = sale
    }

    private enum CodingKeys: String, CodingKey {
        case sale
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            return
        }

        self.sale = try BusinessSale(from: decoder)
    }
}

struct QuickSaleResponse: Decodable, Equatable, Sendable {
    let sale: BusinessSale
    let idempotencyReplayed: Bool?

    init(sale: BusinessSale, idempotencyReplayed: Bool? = nil) {
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case sale
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            self.idempotencyReplayed = try? container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.sale = try BusinessSale(from: decoder)
        self.idempotencyReplayed = nil
    }
}

struct ConfirmSaleResponse: Decodable, Equatable, Sendable {
    let sale: BusinessSale
    let idempotencyReplayed: Bool?

    init(sale: BusinessSale, idempotencyReplayed: Bool? = nil) {
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case sale
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            self.idempotencyReplayed = try? container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.sale = try BusinessSale(from: decoder)
        self.idempotencyReplayed = nil
    }
}

struct CancelSaleResponse: Decodable, Equatable, Sendable {
    let sale: BusinessSale
    let idempotencyReplayed: Bool?

    init(sale: BusinessSale, idempotencyReplayed: Bool? = nil) {
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }

    private enum CodingKeys: String, CodingKey {
        case sale
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let sale = try? container.decode(BusinessSale.self, forKey: .sale) {
            self.sale = sale
            self.idempotencyReplayed = try? container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
            return
        }

        self.sale = try BusinessSale(from: decoder)
        self.idempotencyReplayed = nil
    }
}

typealias BusinessSalesListResponse = BusinessSalesHistoryResponse
