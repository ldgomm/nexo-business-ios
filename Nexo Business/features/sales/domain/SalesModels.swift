//
//  SalesModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
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
    let unitPrice: MoneyAmount?
    let discount: MoneyAmount?
    let priceTaxMode: String
    let taxProfileCode: String?
    let notes: String?

    init(
        catalogItemId: String,
        quantity: BusinessSaleQuantityRequest,
        unitPrice: MoneyAmount? = nil,
        discount: MoneyAmount? = nil,
        priceTaxMode: String = BusinessSalePriceTaxMode.taxExclusive.rawValue,
        taxProfileCode: String? = nil,
        notes: String? = nil
    ) {
        self.catalogItemId = catalogItemId
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.discount = discount
        self.priceTaxMode = priceTaxMode
        self.taxProfileCode = taxProfileCode
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

    private enum CodingKeys: String, CodingKey {
        case id
        case customerId
        case displayName
        case identificationType
        case identificationNumber
        case taxIdType
        case taxId
        case email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(String.self, forKey: .customerId))
        ?? (try? container.decodeIfPresent(String.self, forKey: .id))
        displayName = (try? container.decodeIfPresent(String.self, forKey: .displayName)) ?? "Consumidor final"
        identificationType = (try? container.decodeIfPresent(String.self, forKey: .taxIdType))
        ?? (try? container.decodeIfPresent(String.self, forKey: .identificationType))
        identificationNumber = (try? container.decodeIfPresent(String.self, forKey: .taxId))
        ?? (try? container.decodeIfPresent(String.self, forKey: .identificationNumber))
        email = try? container.decodeIfPresent(String.self, forKey: .email)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .customerId)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(identificationNumber, forKey: .taxId)
        try container.encodeIfPresent(identificationType, forKey: .taxIdType)
        try container.encodeIfPresent(email, forKey: .email)
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

private struct BusinessSaleItemTaxProfileSnapshot: Decodable, Equatable, Sendable {
    let code: String?
    let name: String?
    let treatment: String?
    let rate: String?
    let sriTaxCode: String?
    let sriRateCode: String?

    private enum CodingKeys: String, CodingKey {
        case code
        case taxProfileCode
        case name
        case displayName
        case treatment
        case taxTreatment
        case rate
        case taxRate
        case sriTaxCode
        case sriRateCode
        case codigo
        case codigoPorcentaje
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decodeIfPresent(String.self, forKey: .code))
        ?? (try? container.decodeIfPresent(String.self, forKey: .taxProfileCode))
        name = (try? container.decodeIfPresent(String.self, forKey: .name))
        ?? (try? container.decodeIfPresent(String.self, forKey: .displayName))
        treatment = (try? container.decodeIfPresent(String.self, forKey: .treatment))
        ?? (try? container.decodeIfPresent(String.self, forKey: .taxTreatment))
        rate = (try? container.decodeFlexibleStringIfPresent(forKey: .rate))
        ?? (try? container.decodeFlexibleStringIfPresent(forKey: .taxRate))
        sriTaxCode = (try? container.decodeFlexibleStringIfPresent(forKey: .sriTaxCode))
        ?? (try? container.decodeFlexibleStringIfPresent(forKey: .codigo))
        sriRateCode = (try? container.decodeFlexibleStringIfPresent(forKey: .sriRateCode))
        ?? (try? container.decodeFlexibleStringIfPresent(forKey: .codigoPorcentaje))
    }
}

struct BusinessSaleItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let catalogItemId: String?
    let name: String
    let quantity: String
    let unitPrice: MoneyAmount?
    let subtotal: MoneyAmount?
    let total: MoneyAmount?
    let discount: MoneyAmount?
    let status: String?
    let taxProfileCode: String?
    let taxProfileName: String?
    let taxTreatment: String?
    let taxRate: String?
    let sriTaxCode: String?
    let sriRateCode: String?
    let taxableBase: MoneyAmount?
    let taxAmount: MoneyAmount?
    let note: String?

    init(
        id: String,
        catalogItemId: String? = nil,
        name: String,
        quantity: String,
        unitPrice: MoneyAmount? = nil,
        subtotal: MoneyAmount? = nil,
        total: MoneyAmount? = nil,
        discount: MoneyAmount? = nil,
        status: String? = nil,
        taxProfileCode: String? = nil,
        taxProfileName: String? = nil,
        taxTreatment: String? = nil,
        taxRate: String? = nil,
        sriTaxCode: String? = nil,
        sriRateCode: String? = nil,
        taxableBase: MoneyAmount? = nil,
        taxAmount: MoneyAmount? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.catalogItemId = catalogItemId
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.subtotal = subtotal
        self.total = total
        self.discount = discount
        self.status = status
        self.taxProfileCode = taxProfileCode
        self.taxProfileName = taxProfileName
        self.taxTreatment = taxTreatment
        self.taxRate = taxRate
        self.sriTaxCode = sriTaxCode
        self.sriRateCode = sriRateCode
        self.taxableBase = taxableBase
        self.taxAmount = taxAmount
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
        case discount
        case status
        case taxProfileCode
        case taxProfileSnapshot
        case taxProfileName
        case treatment
        case taxTreatment
        case taxRate
        case rate
        case sriTaxCode
        case sriRateCode
        case codigo
        case codigoPorcentaje
        case taxAmount
        case tax
        case taxTotal
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
        discount = try? container.decodeIfPresent(MoneyAmount.self, forKey: .discount)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        let taxSnapshot = try? container.decodeIfPresent(BusinessSaleItemTaxProfileSnapshot.self, forKey: .taxProfileSnapshot)
        taxProfileCode = (try? container.decodeIfPresent(String.self, forKey: .taxProfileCode)) ?? taxSnapshot?.code
        taxProfileName = (try? container.decodeIfPresent(String.self, forKey: .taxProfileName)) ?? taxSnapshot?.name
        taxTreatment = (try? container.decodeIfPresent(String.self, forKey: .taxTreatment))
        ?? (try? container.decodeIfPresent(String.self, forKey: .treatment))
        ?? taxSnapshot?.treatment
        taxRate = (try? container.decodeFlexibleStringIfPresent(forKey: .taxRate))
        ?? (try? container.decodeFlexibleStringIfPresent(forKey: .rate))
        ?? taxSnapshot?.rate
        sriTaxCode = (try? container.decodeFlexibleStringIfPresent(forKey: .sriTaxCode))
        ?? (try? container.decodeFlexibleStringIfPresent(forKey: .codigo))
        ?? taxSnapshot?.sriTaxCode
        sriRateCode = (try? container.decodeFlexibleStringIfPresent(forKey: .sriRateCode))
        ?? (try? container.decodeFlexibleStringIfPresent(forKey: .codigoPorcentaje))
        ?? taxSnapshot?.sriRateCode
        taxableBase = try? container.decodeIfPresent(MoneyAmount.self, forKey: .taxableBase)
        taxAmount = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .taxAmount))
        ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .tax))
        ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .taxTotal))
        note = (try? container.decodeIfPresent(String.self, forKey: .note))
        ?? (try? container.decodeIfPresent(String.self, forKey: .notes))
    }
}

struct ElectronicInvoiceReadinessBlocker: Equatable, Identifiable, Sendable {
    let id: String
    let code: String
    let message: String
    let itemId: String?
    let itemName: String?
    let technicalValue: String?

    init(
        id: String = UUID().uuidString,
        code: String,
        message: String,
        itemId: String? = nil,
        itemName: String? = nil,
        technicalValue: String? = nil
    ) {
        self.id = id
        self.code = code
        self.message = message
        self.itemId = itemId
        self.itemName = itemName
        self.technicalValue = technicalValue
    }
}

struct ElectronicInvoiceReadiness: Equatable, Sendable {
    let blockers: [ElectronicInvoiceReadinessBlocker]

    init(blockers: [ElectronicInvoiceReadinessBlocker] = []) {
        self.blockers = blockers
    }

    var canIssue: Bool {
        blockers.isEmpty
    }

    var primaryMessage: String? {
        guard let first = blockers.first else { return nil }

        if blockers.count == 1 {
            return first.message
        }

        return "Esta venta contiene \(blockers.count) productos configurados como “Solo registro” o sin código tributario válido para factura electrónica."
    }

    var detailedMessage: String? {
        guard !blockers.isEmpty else { return nil }

        let names = blockers
            .prefix(3)
            .map { blocker in blocker.itemName?.nilIfBlankForReadiness ?? "Ítem sin nombre" }
            .joined(separator: ", ")

        if blockers.count <= 3 {
            return "Productos a revisar antes de facturar: \(names)."
        }

        return "Productos a revisar antes de facturar: \(names) y \(blockers.count - 3) más."
    }
}

enum ElectronicInvoiceReadinessEvaluator {
    static func invalidTaxProfileBlocker(
        itemId: String?,
        itemName: String?,
        taxProfileCode: String?,
        taxTreatment: String?,
        sriTaxCode: String?,
        sriRateCode: String?
    ) -> ElectronicInvoiceReadinessBlocker? {
        let checks: [(value: String?, label: String)] = [
            (sriTaxCode, "sriTaxCode"),
            (sriRateCode, "sriRateCode"),
            (taxProfileCode, "taxProfileCode"),
            (taxTreatment, "taxTreatment")
        ]

        guard let failed = checks.first(where: { isInvalidForElectronicInvoice($0.value) }) else {
            return nil
        }

        let name = itemName?.nilIfBlankForReadiness ?? "ítem"
        return ElectronicInvoiceReadinessBlocker(
            code: "invalid_tax_profile",
            message: "\(name) está configurado como “Solo registro” o sin código tributario válido para factura electrónica. Puedes cobrarlo como venta interna, pero no emitir factura electrónica.",
            itemId: itemId,
            itemName: itemName,
            technicalValue: "\(failed.label)=\(failed.value ?? "")"
        )
    }

    static func isInvalidForElectronicInvoice(_ value: String?) -> Bool {
        guard let normalized = normalized(value), !normalized.isEmpty else { return false }

        let compact = normalized
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        let invalidValues: Set<String> = [
            "no_sri_tax_code",
            "no_sri_code",
            "no_tax_internal",
            "internal_no_tax",
            "altos_staging_no_tax_internal",
            "operational_no_tax",
            "operationalnotax",
            "solo_registro",
            "solo_registro_interno"
        ]

        return invalidValues.contains(compact) || compact.contains("no_sri_tax_code")
    }

    private static func normalized(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

extension BusinessSaleItem {
    var isActiveForCartEditing: Bool {
        let normalized = status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return normalized.map { !["canceled", "cancelled", "voided", "removed", "deleted"].contains($0) } ?? true
    }
}

extension BusinessSaleItem {
    var electronicInvoiceReadinessBlocker: ElectronicInvoiceReadinessBlocker? {
        ElectronicInvoiceReadinessEvaluator.invalidTaxProfileBlocker(
            itemId: id,
            itemName: name,
            taxProfileCode: taxProfileCode,
            taxTreatment: taxTreatment,
            sriTaxCode: sriTaxCode,
            sriRateCode: sriRateCode
        )
    }
}

extension BusinessSale {
    var electronicInvoiceReadiness: ElectronicInvoiceReadiness {
        ElectronicInvoiceReadiness(
            blockers: items.compactMap { $0.electronicInvoiceReadinessBlocker }
        )
    }
}

enum SaleCollectionState: Equatable, Sendable {
    case paid
    case realReceivable
    case receivableNeedsReview
    case partialWithoutReceivable
    case unpaidSavedSale
    case cancelled
    case unknown

    var displayName: String {
        switch self {
        case .paid:
            return "Pagada"
        case .realReceivable:
            return "Por cobrar"
        case .receivableNeedsReview:
            return "Revisar por cobrar"
        case .partialWithoutReceivable:
            return "Pago parcial · Sin cuenta por cobrar"
        case .unpaidSavedSale:
            return "Sin cobrar"
        case .cancelled:
            return "Cancelada"
        case .unknown:
            return "Sin estado claro"
        }
    }

    var shortName: String {
        switch self {
        case .paid:
            return "Pagada"
        case .realReceivable:
            return "Por cobrar"
        case .receivableNeedsReview:
            return "Revisar"
        case .partialWithoutReceivable:
            return "Parcial sin deuda"
        case .unpaidSavedSale:
            return "Sin cobrar"
        case .cancelled:
            return "Cancelada"
        case .unknown:
            return "Revisar"
        }
    }

    var systemImage: String {
        switch self {
        case .paid:
            return "checkmark.circle"
        case .realReceivable:
            return "person.crop.circle.badge.clock"
        case .receivableNeedsReview:
            return "exclamationmark.triangle"
        case .partialWithoutReceivable:
            return "clock.badge.checkmark"
        case .unpaidSavedSale:
            return "bookmark"
        case .cancelled:
            return "xmark.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

extension BusinessSale {
    var collectionState: SaleCollectionState {
        let saleStatus = SaleCollectionResolver.normalized(status)

        if SaleCollectionResolver.isCancelledSaleStatus(saleStatus) {
            return .cancelled
        }

        let payment = SaleCollectionResolver.normalized(paymentStatus ?? "")

        if SaleCollectionResolver.isPaidPaymentStatus(payment) {
            return .paid
        }

        if hasReceivableReference {
            return hasRealReceivable ? .realReceivable : .receivableNeedsReview
        }

        if SaleCollectionResolver.isPartiallyPaidPaymentStatus(payment) {
            return .partialWithoutReceivable
        }

        if SaleCollectionResolver.isUnpaidPaymentStatus(payment) {
            return .unpaidSavedSale
        }

        return .unknown
    }

    var hasReceivableReference: Bool {
        SaleCollectionResolver.hasText(receivableId)
    }

    var hasRealReceivable: Bool {
        hasReceivableReference && hasIdentifiedCustomerForReceivable
    }

    var hasIdentifiedCustomerForReceivable: Bool {
        let candidates = [
            receivableCustomerId,
            customerId,
            customer?.id
        ]

        return candidates.contains { candidate in
            guard SaleCollectionResolver.hasText(candidate) else {
                return false
            }

            return !BusinessElectronicInvoiceCustomerPolicy.isFinalConsumerCustomerId(candidate)
        }
    }

    var hasPositiveReceivableBalance: Bool {
        SaleCollectionResolver.isPositiveAmount(receivableBalance?.amount)
    }

    var isSavedSaleWithoutReceivable: Bool {
        switch collectionState {
        case .unpaidSavedSale, .partialWithoutReceivable:
            return true
        case .paid, .realReceivable, .receivableNeedsReview, .cancelled, .unknown:
            return false
        }
    }

    var normalizedOperationalStatus: String {
        Self.normalizedOperationalValue(status)
    }

    var normalizedPaymentStatus: String {
        Self.normalizedOperationalValue(paymentStatus)
    }

    var isCancelledOperationally: Bool {
        [
            "voided",
            "cancelled",
            "canceled",
            "annulled",
            "cancelled_internal",
            "canceled_internal"
        ].contains(normalizedOperationalStatus)
    }

    var isClosedOperationally: Bool {
        [
            "closed",
            "closed_day",
            "day_closed"
        ].contains(normalizedOperationalStatus)
    }

    var isTerminalOperationally: Bool {
        isCancelledOperationally || isClosedOperationally
    }

    var hasPaymentImpactForOperationalChanges: Bool {
        if collectionState == .paid || collectionState == .partialWithoutReceivable {
            return true
        }

        let payment = normalizedPaymentStatus
        let impactedStatuses: Set<String> = [
            "paid",
            "pagada",
            "collected",
            "registered",
            "confirmed",
            "payment_confirmed",
            "payment_registered",
            "payment_received",
            "received",
            "captured",
            "settled",
            "completed",
            "fully_paid",
            "overpaid",
            "partially_paid",
            "partial",
            "partial_payment",
            "partially_collected",
            "refunded",
            "refund_pending",
            "reversed",
            "chargeback"
        ]

        return impactedStatuses.contains(payment)
    }

    var operationalEditBlockReason: String? {
        if isCancelledOperationally {
            return "Esta venta está cancelada. Solo consulta: no se puede editar, cobrar ni emitir comprobante electrónico."
        }

        if isClosedOperationally {
            return "Esta venta está cerrada. Solo puedes consultar historial y documentos existentes."
        }

        if hasPaymentImpactForOperationalChanges {
            return "Esta venta ya tiene cobro registrado. No se puede editar directamente; usa un flujo de reverso/corrección con auditoría."
        }

        if hasReceivableReference {
            return "Esta venta ya tiene una cuenta por cobrar asociada. No se puede editar directamente desde el carrito."
        }

        if hasBlockingElectronicDocumentForOperationalChanges {
            return "Esta venta ya tiene comprobante electrónico generado, enviado o autorizado. Usa un flujo correctivo."
        }

        return nil
    }

    var cancellationBlockReason: String? {
        if isCancelledOperationally {
            return "Esta venta ya está cancelada. Solo consulta; conserva la evidencia operativa."
        }

        if isClosedOperationally {
            return "Esta venta está cerrada. No se puede cancelar nuevamente desde Business."
        }

        if hasPaymentImpactForOperationalChanges {
            return "Esta venta ya tiene cobro registrado. No uses Cancelar venta; primero debe existir un reverso controlado de cobro y caja."
        }

        if hasReceivableReference {
            return "Esta venta tiene cuenta por cobrar asociada. No puede cancelarse desde este flujo."
        }

        if hasAuthorizedElectronicDocument {
            return "Esta venta ya tiene comprobante autorizado. Solo aplica flujo correctivo documental."
        }

        return nil
    }

    var isEditableForOperationalChanges: Bool {
        operationalEditBlockReason == nil
    }

    var isCancellableOperationally: Bool {
        cancellationBlockReason == nil
    }

    var isCollectableForOperationalFlow: Bool {
        guard !isTerminalOperationally else { return false }
        guard !hasPaymentImpactForOperationalChanges else { return false }
        guard !hasReceivableReference else { return false }

        switch normalizedOperationalStatus {
        case "confirmed", "delivered", "ready", "in_progress", "pending":
            return true
        default:
            return false
        }
    }

    var isPaidOrFormalCreditForElectronicDocument: Bool {
        switch collectionState {
        case .paid, .realReceivable:
            return true
        case .receivableNeedsReview, .partialWithoutReceivable, .unpaidSavedSale, .cancelled, .unknown:
            return false
        }
    }

    var hasAuthorizedElectronicDocument: Bool {
        Self.isAuthorizedElectronicDocumentStatus(documentStatus ?? electronicDocumentSummary?.effectiveStatus)
    }

    var hasBlockingElectronicDocumentForOperationalChanges: Bool {
        Self.electronicDocumentBlocksOperationalChanges(documentStatus ?? electronicDocumentSummary?.effectiveStatus)
    }

    var canStartNewElectronicDocumentUnderPilotPolicy: Bool {
        !isTerminalOperationally &&
        !hasBlockingElectronicDocumentForOperationalChanges &&
        isPaidOrFormalCreditForElectronicDocument
    }

    static func normalizedOperationalValue(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func isAuthorizedElectronicDocumentStatus(_ value: String?) -> Bool {
        let normalized = normalizedOperationalValue(value)
        return [
            "authorized",
            "autorizado",
            "sri_authorized",
            "delivered"
        ].contains(normalized)
    }

    private static func electronicDocumentBlocksOperationalChanges(_ value: String?) -> Bool {
        let normalized = normalizedOperationalValue(value)
        guard !normalized.isEmpty else { return false }

        switch normalized {
        case "none", "not_required", "no_required", "without_document", "sin_documento", "missing", "not_missing", "no_document":
            return false
        case "not_authorized", "notauthorized", "no_autorizada", "returned", "returned_by_sri", "devuelta", "xsd_invalid", "signature_failed", "reception_transport_failed", "failed", "error", "rejected", "rechazada":
            return false
        default:
            return true
        }
    }
}

private enum SaleCollectionResolver {
    static func hasText(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
    }

    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    static func compactNormalized(_ value: String) -> String {
        normalized(value)
            .replacingOccurrences(of: "_", with: "")
    }

    static func isPositiveAmount(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let decimal = Decimal(
            string: cleaned,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return false
        }

        return NSDecimalNumber(decimal: decimal)
            .compare(NSDecimalNumber.zero) == .orderedDescending
    }

    static func isCancelledSaleStatus(_ value: String) -> Bool {
        let normalized = normalized(value)

        return [
            "voided",
            "cancelled",
            "canceled",
            "annulled",
            "cancelled_internal",
            "canceled_internal"
        ].contains(normalized)
    }

    static func isPaidPaymentStatus(_ value: String) -> Bool {
        let normalized = normalized(value)
        let compact = compactNormalized(value)

        return [
            "paid",
            "collected",
            "registered",
            "confirmed",
            "overpaid",
            "fully_paid",
            "settled",
            "completed"
        ].contains(normalized) || [
            "fullypaid"
        ].contains(compact)
    }

    static func isPartiallyPaidPaymentStatus(_ value: String) -> Bool {
        let normalized = normalized(value)
        let compact = compactNormalized(value)

        return [
            "partially_paid",
            "partial",
            "partial_payment",
            "partially_collected"
        ].contains(normalized) || [
            "partiallypaid",
            "partialpayment",
            "partiallycollected"
        ].contains(compact)
    }

    static func isUnpaidPaymentStatus(_ value: String) -> Bool {
        let normalized = normalized(value)

        return normalized.isEmpty || [
            "unpaid",
            "pending",
            "pending_payment",
            "not_paid",
            "none",
            "uncollected"
        ].contains(normalized)
    }
}

private extension String {
    var nilIfBlankForReadiness: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            let rounded = double.rounded()
            return rounded == double ? String(Int(rounded)) : String(double)
        }
        return nil
    }
}


enum BusinessElectronicInvoiceCustomerPolicy {
    static let finalConsumerIdentification = "9999999999999"
    static let finalConsumerMaxAmount = Decimal(50)
    static let finalConsumerMaxAmountText = "USD 50.00"

    static func requiresIdentifiedCustomerForInvoice(
        total: MoneyAmount,
        selectedCustomer: BusinessCustomer?
    ) -> Bool {
        isFinalConsumer(selectedCustomer) && decimal(total.amount) > finalConsumerMaxAmount
    }

    static func requiresIdentifiedCustomerForInvoice(sale: BusinessSale) -> Bool {
        isFinalConsumer(sale: sale) && decimal(sale.totals.grandTotal.amount) > finalConsumerMaxAmount
    }

    static func warningMessage(total: MoneyAmount, selectedCustomer: BusinessCustomer?) -> String? {
        guard requiresIdentifiedCustomerForInvoice(total: total, selectedCustomer: selectedCustomer) else { return nil }
        return "Esta venta supera \(finalConsumerMaxAmountText). Para emitir factura electrónica debes seleccionar un cliente con cédula, RUC o pasaporte."
    }

    static func blockingMessageForInvoice(total: MoneyAmount, selectedCustomer: BusinessCustomer?) -> String? {
        guard requiresIdentifiedCustomerForInvoice(total: total, selectedCustomer: selectedCustomer) else { return nil }
        return "No se puede emitir factura electrónica como Consumidor final porque la venta supera \(finalConsumerMaxAmountText). Selecciona un cliente identificado antes de facturar."
    }

    static func blockingMessageForInvoice(sale: BusinessSale) -> String? {
        guard requiresIdentifiedCustomerForInvoice(sale: sale) else { return nil }
        return "No se puede emitir factura electrónica como Consumidor final porque la venta supera \(finalConsumerMaxAmountText). Selecciona un cliente con cédula, RUC o pasaporte antes de facturar."
    }

    static func isFinalConsumer(_ customer: BusinessCustomer?) -> Bool {
        guard let customer else { return true }
        return customer.identificationType == .finalConsumer || normalized(customer.identificationNumber) == finalConsumerIdentification
    }

    static func isFinalConsumer(sale: BusinessSale) -> Bool {
        if let customerId = sale.customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            return isFinalConsumerCustomerId(customerId)
        }

        if let identification = sale.customer?.identification, normalized(identification) == finalConsumerIdentification {
            return true
        }

        let saleName = normalized(sale.customer?.displayName ?? sale.customerName ?? "")
        return sale.customer == nil || saleName == "consumidor final"
    }

    static func isFinalConsumerCustomerId(_ value: String?) -> Bool {
        let normalizedId = normalized(value ?? "")
            .replacingOccurrences(of: "-", with: "_")
        return [
            "final_consumer",
            "consumidor_final",
            "cus_final_consumer",
            "customer_final_consumer"
        ].contains(normalizedId)
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(
            string: value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? .zero
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive], locale: .current)
    }
}

typealias SalePreviewItem = BusinessSaleItem

struct BusinessSaleReceivableSummary: Decodable, Equatable, Sendable {
    let id: String?
    let customerId: String?
    let status: String?
    let balance: MoneyAmount?

    private enum CodingKeys: String, CodingKey {
        case id
        case receivableId
        case customerId
        case status
        case balance
        case balanceDue
        case remainingAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(String.self, forKey: .receivableId))
        ?? (try? container.decodeIfPresent(String.self, forKey: .id))
        customerId = try? container.decodeIfPresent(String.self, forKey: .customerId)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        balance = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .balance))
        ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .balanceDue))
        ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .remainingAmount))
    }
}

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
    let electronicDocumentSummary: BusinessDocument?
    let receivableId: String?
    let receivableCustomerId: String?
    let receivableStatus: String?
    let receivableBalance: MoneyAmount?
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
        electronicDocumentSummary: BusinessDocument? = nil,
        receivableId: String? = nil,
        receivableCustomerId: String? = nil,
        receivableStatus: String? = nil,
        receivableBalance: MoneyAmount? = nil,
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
        self.electronicDocumentSummary = electronicDocumentSummary
        self.receivableId = receivableId
        self.receivableCustomerId = receivableCustomerId
        self.receivableStatus = receivableStatus
        self.receivableBalance = receivableBalance
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
        case serviceType
        case service
        case documentStatus
        case electronicDocumentSummary
        case latestElectronicDocument
        case primaryElectronicDocument
        case electronicDocument
        case documentSummary
        case receivableId
        case receivableCustomerId
        case accountReceivableId
        case accountsReceivableId
        case receivableStatus
        case receivableBalance
        case balanceDue
        case receivable
        case receivableSummary
        case accountReceivable
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

        case mongoId = "_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? container.decodeIfPresent(String.self, forKey: .mongoId) ?? ""
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
        electronicDocumentSummary = (try? container.decodeIfPresent(BusinessDocument.self, forKey: .electronicDocumentSummary))
        ?? (try? container.decodeIfPresent(BusinessDocument.self, forKey: .latestElectronicDocument))
        ?? (try? container.decodeIfPresent(BusinessDocument.self, forKey: .primaryElectronicDocument))
        ?? (try? container.decodeIfPresent(BusinessDocument.self, forKey: .electronicDocument))
        ?? (try? container.decodeIfPresent(BusinessDocument.self, forKey: .documentSummary))
        documentStatus = (try? container.decodeIfPresent(String.self, forKey: .documentStatus))
        ?? electronicDocumentSummary?.effectiveStatus

        let receivableSummary = (try? container.decodeIfPresent(BusinessSaleReceivableSummary.self, forKey: .receivable))
        ?? (try? container.decodeIfPresent(BusinessSaleReceivableSummary.self, forKey: .receivableSummary))
        ?? (try? container.decodeIfPresent(BusinessSaleReceivableSummary.self, forKey: .accountReceivable))
        receivableId = (try? container.decodeIfPresent(String.self, forKey: .receivableId))
        ?? (try? container.decodeIfPresent(String.self, forKey: .accountReceivableId))
        ?? (try? container.decodeIfPresent(String.self, forKey: .accountsReceivableId))
        ?? receivableSummary?.id
        receivableCustomerId = (try? container.decodeIfPresent(String.self, forKey: .receivableCustomerId))
        ?? receivableSummary?.customerId
        receivableStatus = (try? container.decodeIfPresent(String.self, forKey: .receivableStatus))
        ?? receivableSummary?.status
        receivableBalance = (try? container.decodeIfPresent(MoneyAmount.self, forKey: .receivableBalance))
        ?? (try? container.decodeIfPresent(MoneyAmount.self, forKey: .balanceDue))
        ?? receivableSummary?.balance

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


struct BulkAddSaleItemsRequest: Encodable, Equatable, Sendable {
    let requestId: String
    let catalogRevision: String?
    let taxConfigurationRevision: String?
    let items: [BusinessSaleItemRequest]

    init(
        requestId: String = "sale-items-add-\(UUID().uuidString.lowercased())",
        catalogRevision: String? = nil,
        taxConfigurationRevision: String? = nil,
        items: [BusinessSaleItemRequest]
    ) {
        self.requestId = requestId
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
        self.items = items
    }
}

struct BulkUpdateSaleItemRequest: Encodable, Equatable, Sendable {
    let saleItemId: String
    let replacement: BusinessSaleItemRequest
}

struct BulkUpdateSaleItemsRequest: Encodable, Equatable, Sendable {
    let requestId: String
    let reason: String
    let catalogRevision: String?
    let taxConfigurationRevision: String?
    let items: [BulkUpdateSaleItemRequest]

    init(
        requestId: String = "sale-items-update-\(UUID().uuidString.lowercased())",
        reason: String,
        catalogRevision: String? = nil,
        taxConfigurationRevision: String? = nil,
        items: [BulkUpdateSaleItemRequest]
    ) {
        self.requestId = requestId
        self.reason = reason
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
        self.items = items
    }
}

struct BulkRemoveSaleItemsRequest: Encodable, Equatable, Sendable {
    let requestId: String
    let reason: String
    let catalogRevision: String?
    let taxConfigurationRevision: String?
    let saleItemIds: [String]

    init(
        requestId: String = "sale-items-remove-\(UUID().uuidString.lowercased())",
        reason: String,
        catalogRevision: String? = nil,
        taxConfigurationRevision: String? = nil,
        saleItemIds: [String]
    ) {
        self.requestId = requestId
        self.reason = reason
        self.catalogRevision = catalogRevision
        self.taxConfigurationRevision = taxConfigurationRevision
        self.saleItemIds = saleItemIds
    }
}


struct UpdateSaleCustomerRequest: Encodable, Equatable, Sendable {
    let requestId: String
    let customerId: String?
    let customerSnapshot: BusinessSaleCustomerSnapshot?
    let reason: String

    init(
        requestId: String = "sale-customer-update-\(UUID().uuidString.lowercased())",
        customerId: String? = nil,
        customerSnapshot: BusinessSaleCustomerSnapshot? = nil,
        reason: String = "Corrección de cliente antes de emitir factura electrónica"
    ) {
        self.requestId = requestId
        self.customerId = customerId
        self.customerSnapshot = customerSnapshot
        self.reason = reason
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
