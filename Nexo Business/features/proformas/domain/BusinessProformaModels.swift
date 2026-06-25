//
//  BusinessProformaModels.swift
//  Nexo Business
//
//  21J.10 — Business iOS Proformas MVP
//

import Foundation

enum BusinessProformaStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft = "DRAFT"
    case sent = "SENT"
    case accepted = "ACCEPTED"
    case rejected = "REJECTED"
    case expired = "EXPIRED"
    case converted = "CONVERTED"
    case unknown = "UNKNOWN"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "Borrador"
        case .sent: return "Compartida"
        case .accepted: return "Aceptada"
        case .rejected: return "Rechazada"
        case .expired: return "Expirada"
        case .converted: return "Convertida"
        case .unknown: return "Desconocida"
        }
    }

    var systemImage: String {
        switch self {
        case .draft: return "pencil"
        case .sent: return "paperplane"
        case .accepted: return "checkmark.seal"
        case .rejected: return "xmark.circle"
        case .expired: return "clock.badge.exclamationmark"
        case .converted: return "arrow.triangle.branch"
        case .unknown: return "questionmark.circle"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BusinessProformaStatus(rawValue: raw.uppercased()) ?? .unknown
    }
}

struct BusinessProformaCustomerSnapshot: Codable, Equatable, Sendable {
    let customerId: String?
    let displayName: String
    let identification: String?
    let email: String?
    let phone: String?
    let address: String?

    init(
        customerId: String? = nil,
        displayName: String,
        identification: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil
    ) {
        self.customerId = customerId
        self.displayName = displayName
        self.identification = identification
        self.email = email
        self.phone = phone
        self.address = address
    }
}

struct BusinessProformaLine: Codable, Equatable, Identifiable, Sendable {
    let lineId: String
    let productId: String?
    let sku: String?
    let displayName: String
    let quantity: String
    let unitPrice: String
    let rawSubtotal: String
    let discountAmount: String
    let netSubtotal: String
    let taxAmount: String
    let grandTotal: String
    let notes: String?

    var id: String { lineId }

    init(
        lineId: String,
        productId: String? = nil,
        sku: String? = nil,
        displayName: String,
        quantity: String,
        unitPrice: String,
        rawSubtotal: String,
        discountAmount: String,
        netSubtotal: String,
        taxAmount: String,
        grandTotal: String,
        notes: String? = nil
    ) {
        self.lineId = lineId
        self.productId = productId
        self.sku = sku
        self.displayName = displayName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.rawSubtotal = rawSubtotal
        self.discountAmount = discountAmount
        self.netSubtotal = netSubtotal
        self.taxAmount = taxAmount
        self.grandTotal = grandTotal
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case lineId
        case id
        case productId
        case catalogItemId
        case sku
        case displayName
        case name
        case quantity
        case unitPrice
        case rawSubtotal
        case discountAmount
        case netSubtotal
        case taxAmount
        case grandTotal
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineId = try container.decodeIfPresent(String.self, forKey: .lineId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? UUID().uuidString
        productId = try container.decodeIfPresent(String.self, forKey: .productId)
            ?? container.decodeIfPresent(String.self, forKey: .catalogItemId)
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? "Ítem"
        quantity = try container.decodeFlexibleStringIfPresent(forKey: .quantity) ?? "1"
        unitPrice = try container.decodeFlexibleStringIfPresent(forKey: .unitPrice) ?? "0.00"
        rawSubtotal = try container.decodeFlexibleStringIfPresent(forKey: .rawSubtotal) ?? "0.00"
        discountAmount = try container.decodeFlexibleStringIfPresent(forKey: .discountAmount) ?? "0.00"
        netSubtotal = try container.decodeFlexibleStringIfPresent(forKey: .netSubtotal) ?? "0.00"
        taxAmount = try container.decodeFlexibleStringIfPresent(forKey: .taxAmount) ?? "0.00"
        grandTotal = try container.decodeFlexibleStringIfPresent(forKey: .grandTotal) ?? "0.00"
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lineId, forKey: .lineId)
        try container.encodeIfPresent(productId, forKey: .productId)
        try container.encodeIfPresent(sku, forKey: .sku)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unitPrice, forKey: .unitPrice)
        try container.encode(rawSubtotal, forKey: .rawSubtotal)
        try container.encode(discountAmount, forKey: .discountAmount)
        try container.encode(netSubtotal, forKey: .netSubtotal)
        try container.encode(taxAmount, forKey: .taxAmount)
        try container.encode(grandTotal, forKey: .grandTotal)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

struct BusinessProformaTotals: Codable, Equatable, Sendable {
    let subtotal: String
    let discountTotal: String
    let taxTotal: String
    let grandTotal: String

    init(
        subtotal: String = "0.00",
        discountTotal: String = "0.00",
        taxTotal: String = "0.00",
        grandTotal: String = "0.00"
    ) {
        self.subtotal = subtotal
        self.discountTotal = discountTotal
        self.taxTotal = taxTotal
        self.grandTotal = grandTotal
    }

    private enum CodingKeys: String, CodingKey {
        case subtotal
        case discountTotal
        case taxTotal
        case grandTotal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subtotal = try container.decodeFlexibleStringIfPresent(forKey: .subtotal) ?? "0.00"
        discountTotal = try container.decodeFlexibleStringIfPresent(forKey: .discountTotal) ?? "0.00"
        taxTotal = try container.decodeFlexibleStringIfPresent(forKey: .taxTotal) ?? "0.00"
        grandTotal = try container.decodeFlexibleStringIfPresent(forKey: .grandTotal) ?? "0.00"
    }
}

struct BusinessProforma: Decodable, Equatable, Hashable, Identifiable, Sendable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: String
    let organizationId: String
    let branchId: String
    let activityId: String
    let proformaNumber: String
    let status: BusinessProformaStatus
    let issueDate: String
    let validUntil: String?
    let currency: String
    let customerId: String?
    let customerSnapshot: BusinessProformaCustomerSnapshot?
    let lines: [BusinessProformaLine]
    let totals: BusinessProformaTotals
    let notes: String?
    let terms: String?
    let sourceContext: String?
    let convertedSaleId: String?
    let nonFiscalLegend: String?
    let isFiscalDocument: Bool
    let hasSriAuthorization: Bool
    let sriAuthorizationNumber: String?
    let accessKey: String?
    let rideUrl: String?
    let xmlUrl: String?
    let createdAt: String?
    let updatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case organizationId
        case branchId
        case activityId
        case proformaNumber
        case number
        case status
        case issueDate
        case validUntil
        case currency
        case customerId
        case customerSnapshot
        case lines
        case totals
        case notes
        case terms
        case sourceContext
        case convertedSaleId
        case nonFiscalLegend
        case isFiscalDocument
        case hasSriAuthorization
        case sriAuthorizationNumber
        case accessKey
        case rideUrl
        case xmlUrl
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId) ?? ""
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId) ?? ""
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId) ?? ""
        proformaNumber = try container.decodeIfPresent(String.self, forKey: .proformaNumber)
            ?? container.decodeIfPresent(String.self, forKey: .number)
            ?? id
        status = try container.decodeIfPresent(BusinessProformaStatus.self, forKey: .status) ?? .unknown
        issueDate = try container.decodeIfPresent(String.self, forKey: .issueDate) ?? ""
        validUntil = try container.decodeIfPresent(String.self, forKey: .validUntil)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        customerId = try container.decodeIfPresent(String.self, forKey: .customerId)
        customerSnapshot = try container.decodeIfPresent(BusinessProformaCustomerSnapshot.self, forKey: .customerSnapshot)
        lines = try container.decodeIfPresent([BusinessProformaLine].self, forKey: .lines) ?? []
        totals = try container.decodeIfPresent(BusinessProformaTotals.self, forKey: .totals) ?? BusinessProformaTotals()
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        terms = try container.decodeIfPresent(String.self, forKey: .terms)
        sourceContext = try container.decodeIfPresent(String.self, forKey: .sourceContext)
        convertedSaleId = try container.decodeIfPresent(String.self, forKey: .convertedSaleId)
        nonFiscalLegend = try container.decodeIfPresent(String.self, forKey: .nonFiscalLegend)
        isFiscalDocument = try container.decodeIfPresent(Bool.self, forKey: .isFiscalDocument) ?? false
        hasSriAuthorization = try container.decodeIfPresent(Bool.self, forKey: .hasSriAuthorization) ?? false
        sriAuthorizationNumber = try container.decodeIfPresent(String.self, forKey: .sriAuthorizationNumber)
        accessKey = try container.decodeIfPresent(String.self, forKey: .accessKey)
        rideUrl = try container.decodeIfPresent(String.self, forKey: .rideUrl)
        xmlUrl = try container.decodeIfPresent(String.self, forKey: .xmlUrl)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

extension BusinessProforma {
    var customerDisplayName: String {
        customerSnapshot?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProforma
            ?? customerId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProforma
            ?? "Cliente no definido"
    }

    var hasRealCustomer: Bool {
        guard let customerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !customerId.isEmpty,
              !Self.isFinalConsumerIdentifier(customerId)
        else {
            return false
        }
        return true
    }

    var canEditDraft: Bool { status == .draft }
    var canSend: Bool { status == .draft && hasRealCustomer }
    var canAccept: Bool { status == .sent && hasRealCustomer }
    var canReject: Bool { status == .sent || status == .accepted }
    var canExpire: Bool { status == .sent }
    var canCreateRevision: Bool { status == .sent || status == .accepted || status == .rejected || status == .expired }
    var canConvertToSale: Bool { status == .accepted && convertedSaleId == nil && hasRealCustomer }
    var canOpenConvertedSale: Bool { convertedSaleId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }

    var fiscalBoundarySummary: String {
        "No es factura. No genera XML, RIDE ni autorización SRI. La conversión crea una venta borrador sin cobrar."
    }

    private static func isFinalConsumerIdentifier(_ value: String) -> Bool {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return normalized == "cus_final_consumer" ||
            normalized == "final_consumer" ||
            normalized == "consumidor_final" ||
            normalized.contains("final_consumer") ||
            normalized.contains("consumidor_final")
    }
}

struct BusinessProformaLineInput: Codable, Equatable, Sendable {
    let productId: String?
    let sku: String?
    let displayName: String
    let quantity: String
    let unitPrice: String
    let discountAmount: String
    let taxAmount: String
    let notes: String?

    init(
        productId: String? = nil,
        sku: String? = nil,
        displayName: String,
        quantity: String,
        unitPrice: String,
        discountAmount: String = "0.00",
        taxAmount: String = "0.00",
        notes: String? = nil
    ) {
        self.productId = productId
        self.sku = sku
        self.displayName = displayName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.discountAmount = discountAmount
        self.taxAmount = taxAmount
        self.notes = notes
    }
}

struct CreateBusinessProformaRequest: Encodable, Equatable, Sendable {
    let branchId: String
    let activityId: String
    let customerId: String?
    let customerSnapshot: BusinessProformaCustomerSnapshot?
    let issueDate: String
    let validUntil: String?
    let currency: String
    let lines: [BusinessProformaLineInput]
    let notes: String?
    let terms: String?
    let sourceContext: String?
}

struct UpdateDraftBusinessProformaRequest: Encodable, Equatable, Sendable {
    let customerId: String?
    let customerSnapshot: BusinessProformaCustomerSnapshot?
    let validUntil: String?
    let currency: String
    let lines: [BusinessProformaLineInput]
    let notes: String?
    let terms: String?
    let sourceContext: String?
}

struct CreateBusinessProformaRevisionRequest: Encodable, Equatable, Sendable {
    let validUntil: String?
    let lines: [BusinessProformaLineInput]?
    let notes: String?
    let terms: String?
    let reason: String
}

struct ChangeBusinessProformaStatusRequest: Encodable, Equatable, Sendable {
    let reason: String?
}

struct ConvertBusinessProformaToSaleRequest: Encodable, Equatable, Sendable {
    let idempotencyKey: String?
}

struct BusinessProformaConvertToSaleResponse: Decodable, Equatable, Sendable {
    let saleId: String
    let proforma: BusinessProforma?
    let wasAlreadyConverted: Bool
    let createdPaymentId: String?
    let createdInvoiceId: String?
    let createdCashSessionId: String?
    let createdXmlUrl: String?
    let createdRideUrl: String?
    let calledSri: Bool

    private enum CodingKeys: String, CodingKey {
        case saleId
        case convertedSaleId
        case proforma
        case wasAlreadyConverted
        case createdPaymentId
        case createdInvoiceId
        case createdCashSessionId
        case createdXmlUrl
        case createdRideUrl
        case calledSri
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedProforma = try container.decodeIfPresent(BusinessProforma.self, forKey: .proforma)
        proforma = decodedProforma
        saleId = try container.decodeIfPresent(String.self, forKey: .saleId)
            ?? container.decodeIfPresent(String.self, forKey: .convertedSaleId)
            ?? decodedProforma?.convertedSaleId
            ?? ""
        wasAlreadyConverted = try container.decodeIfPresent(Bool.self, forKey: .wasAlreadyConverted) ?? false
        createdPaymentId = try container.decodeIfPresent(String.self, forKey: .createdPaymentId)
        createdInvoiceId = try container.decodeIfPresent(String.self, forKey: .createdInvoiceId)
        createdCashSessionId = try container.decodeIfPresent(String.self, forKey: .createdCashSessionId)
        createdXmlUrl = try container.decodeIfPresent(String.self, forKey: .createdXmlUrl)
        createdRideUrl = try container.decodeIfPresent(String.self, forKey: .createdRideUrl)
        calledSri = try container.decodeIfPresent(Bool.self, forKey: .calledSri) ?? false
    }

    var hasForbiddenSideEffects: Bool {
        createdPaymentId != nil ||
        createdInvoiceId != nil ||
        createdCashSessionId != nil ||
        createdXmlUrl != nil ||
        createdRideUrl != nil ||
        calledSri
    }
}

struct BusinessProformaDownloadedDocument: Identifiable, Equatable, Sendable {
    let id = UUID()
    let localURL: URL
    let fileName: String
    let contentType: String
    let sizeBytes: Int
}

extension BusinessCustomer {
    var proformaCustomerSnapshot: BusinessProformaCustomerSnapshot {
        BusinessProformaCustomerSnapshot(
            customerId: id,
            displayName: displayName,
            identification: identificationNumber,
            email: email,
            phone: phone,
            address: address
        )
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
}

private extension String {
    var nilIfEmptyForProforma: String? {
        isEmpty ? nil : self
    }
}
