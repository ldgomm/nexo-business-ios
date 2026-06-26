//
//  SaleCartViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import Foundation
import Observation

enum SaleLineTaxTreatmentOption: String, CaseIterable, Identifiable, Sendable {
    case operationalNoTax
    case ivaCurrent
    case ivaTourism8
    case ivaZero
    case notSubject
    case exempt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .operationalNoTax:
            return "Solo registro"
        case .ivaCurrent:
            return "IVA vigente"
        case .ivaTourism8:
            return "IVA turismo 8%"
        case .ivaZero:
            return "IVA 0%"
        case .notSubject:
            return "No sujeto a IVA"
        case .exempt:
            return "Exento IVA"
        }
    }

    var detailText: String {
        switch self {
        case .operationalNoTax:
            return "Sin IVA y sin comprobante electrónico"
        case .ivaCurrent:
            return "Aplica IVA según configuración tributaria"
        case .ivaTourism8:
            return "Solo para servicios turísticos habilitados y fechas autorizadas"
        case .ivaZero:
            return "Base IVA 0%"
        case .notSubject:
            return "Base no objeto/no sujeta a IVA"
        case .exempt:
            return "Base exenta de IVA"
        }
    }

    var taxProfileCode: String {
        switch self {
        case .operationalNoTax:
            return "altos_staging_no_tax_internal"
        case .ivaCurrent:
            return "altos_staging_iva_current_full"
        case .ivaTourism8:
            return "altos_staging_iva_tourism_8"
        case .ivaZero:
            return "altos_staging_iva_0"
        case .notSubject:
            return "altos_staging_not_subject_to_iva"
        case .exempt:
            return "altos_staging_exempt_iva"
        }
    }

    static func defaultForNewLine() -> SaleLineTaxTreatmentOption {
        .ivaCurrent
    }

    static func defaultForCatalogItem(_ item: BusinessCatalogItem) -> SaleLineTaxTreatmentOption {
        fromTaxProfileCode(item.taxProfileCode)
        ?? fromTaxProfileCode(item.taxProfileId)
        ?? .defaultForNewLine()
    }

    static func fromTaxProfileCode(_ code: String?) -> SaleLineTaxTreatmentOption? {
        let normalized = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "altos_staging_no_tax_internal", "no_tax_internal", "internal_no_tax", "taxp_no_tax_internal", "taxp_internal_no_tax":
            return .operationalNoTax
        case "altos_staging_iva_current_full", "iva_current_full", "iva_full", "taxp_iva_current_full", "taxp_iva_full":
            return .ivaCurrent
        case "altos_staging_iva_tourism_8", "iva_tourism_8", "iva_reduced_tourism", "taxp_iva_tourism_8", "taxp_iva_reduced_tourism":
            return .ivaTourism8
        case "altos_staging_iva_0", "iva_0", "iva_zero", "taxp_iva_0", "taxp_iva_zero":
            return .ivaZero
        case "altos_staging_not_subject_to_iva", "not_subject_to_iva", "taxp_not_subject_to_iva":
            return .notSubject
        case "altos_staging_exempt_iva", "exempt_iva", "taxp_exempt_iva":
            return .exempt
        default:
            return nil
        }
    }
}


enum SaleDiscountInputType: String, CaseIterable, Identifiable, Sendable {
    case value
    case percentage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .value: return "Valor"
        case .percentage: return "Porcentaje"
        }
    }
}

enum SaleDiscountTarget: String, CaseIterable, Identifiable, Sendable {
    case wholeSale
    case selectedItems

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wholeSale: return "Toda la compra"
        case .selectedItems: return "Ítems seleccionados"
        }
    }
}

struct SaleCartItem: Equatable, Identifiable, Sendable {
    let id: String
    let catalogItem: BusinessCatalogItem
    var quantity: String
    var taxTreatment: SaleLineTaxTreatmentOption
    var discount: MoneyAmount?
    var note: String?
    
    init(
        id: String = UUID().uuidString,
        catalogItem: BusinessCatalogItem,
        quantity: String = "1",
        taxTreatment: SaleLineTaxTreatmentOption = .defaultForNewLine(),
        discount: MoneyAmount? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.catalogItem = catalogItem
        self.quantity = quantity
        self.taxTreatment = taxTreatment
        self.discount = discount
        self.note = note
    }
}


struct LocalSaleTaxConfiguration: Equatable, Sendable {
    let ivaCurrentRate: Decimal
    let ivaTourismRate: Decimal
    let currency: String

    init(
        ivaCurrentRate: Decimal,
        ivaTourismRate: Decimal,
        currency: String = "USD"
    ) {
        self.ivaCurrentRate = ivaCurrentRate
        self.ivaTourismRate = ivaTourismRate
        self.currency = currency
    }

    static let ecuadorStagingFallback = LocalSaleTaxConfiguration(
        ivaCurrentRate: Decimal(15),
        ivaTourismRate: Decimal(8),
        currency: "USD"
    )
}

struct LocalSaleLineCalculation: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let quantity: String
    let taxTreatment: SaleLineTaxTreatmentOption
    let unitPrice: MoneyAmount
    let subtotalWithoutDiscount: MoneyAmount
    let discount: MoneyAmount
    let taxableBase: MoneyAmount
    let taxRatePercent: String
    let taxAmount: MoneyAmount
    let total: MoneyAmount
    let warning: String?
}

struct LocalSaleCalculation: Equatable, Sendable {
    let lines: [LocalSaleLineCalculation]
    let totals: BusinessSaleTotals
    let warnings: [String]
    let canIssueElectronicInvoice: Bool
    let currency: String

    static let empty = LocalSaleCalculation(
        lines: [],
        totals: BusinessSaleTotals(
            subtotalWithoutTaxes: MoneyAmount(amount: "0.00"),
            discountTotal: MoneyAmount(amount: "0.00"),
            taxTotal: MoneyAmount(amount: "0.00"),
            grandTotal: MoneyAmount(amount: "0.00")
        ),
        warnings: [],
        canIssueElectronicInvoice: true,
        currency: "USD"
    )

    var hasDiscount: Bool {
        Self.decimal(from: totals.discountTotal.amount) > .zero
    }

    var primaryWarning: String? {
        warnings.first
    }

    static func make(
        cartItems: [SaleCartItem],
        taxConfiguration: LocalSaleTaxConfiguration = .ecuadorStagingFallback
    ) -> LocalSaleCalculation {
        guard !cartItems.isEmpty else { return .empty }

        var lines: [LocalSaleLineCalculation] = []
        var subtotal = Decimal.zero
        var discountTotal = Decimal.zero
        var taxTotal = Decimal.zero
        var grandTotal = Decimal.zero
        var warnings: [String] = []
        var canIssueElectronicInvoice = true

        for item in cartItems {
            let quantity = max(.zero, decimal(from: item.quantity))
            let unitPrice = max(.zero, decimal(from: item.catalogItem.price?.amount ?? "0"))
            let rawSubtotal = roundMoney(unitPrice * quantity)
            let requestedDiscount = max(.zero, decimal(from: item.discount?.amount ?? "0"))
            let appliedDiscount = min(rawSubtotal, requestedDiscount)
            let taxableBase = max(.zero, rawSubtotal - appliedDiscount)
            let taxRate = item.taxTreatment.localTaxRate(using: taxConfiguration)
            let taxAmount = roundMoney(taxableBase * taxRate / Decimal(100))
            let lineTotal = roundMoney(taxableBase + taxAmount)
            let warning = item.taxTreatment.localWarning(itemName: item.catalogItem.name)

            if let warning {
                warnings.append(warning)
            }
            if !item.taxTreatment.canIssueElectronicInvoiceLocally {
                canIssueElectronicInvoice = false
            }

            subtotal += rawSubtotal
            discountTotal += appliedDiscount
            taxTotal += taxAmount
            grandTotal += lineTotal

            lines.append(
                LocalSaleLineCalculation(
                    id: item.id,
                    name: item.catalogItem.name,
                    quantity: item.quantity,
                    taxTreatment: item.taxTreatment,
                    unitPrice: money(unitPrice, currency: taxConfiguration.currency),
                    subtotalWithoutDiscount: money(rawSubtotal, currency: taxConfiguration.currency),
                    discount: money(appliedDiscount, currency: taxConfiguration.currency),
                    taxableBase: money(taxableBase, currency: taxConfiguration.currency),
                    taxRatePercent: percentText(taxRate),
                    taxAmount: money(taxAmount, currency: taxConfiguration.currency),
                    total: money(lineTotal, currency: taxConfiguration.currency),
                    warning: warning
                )
            )
        }

        let roundedSubtotal = roundMoney(subtotal)
        let roundedDiscount = roundMoney(discountTotal)
        let roundedTax = roundMoney(taxTotal)
        let roundedGrandTotal = roundMoney(grandTotal)

        return LocalSaleCalculation(
            lines: lines,
            totals: BusinessSaleTotals(
                subtotalWithoutTaxes: money(roundedSubtotal, currency: taxConfiguration.currency),
                discountTotal: money(roundedDiscount, currency: taxConfiguration.currency),
                taxTotal: money(roundedTax, currency: taxConfiguration.currency),
                grandTotal: money(roundedGrandTotal, currency: taxConfiguration.currency)
            ),
            warnings: Array(NSOrderedSet(array: warnings).compactMap { $0 as? String }),
            canIssueElectronicInvoice: canIssueElectronicInvoice,
            currency: taxConfiguration.currency
        )
    }

    private static func decimal(from value: String) -> Decimal {
        Decimal(
            string: value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? .zero
    }

    private static func roundMoney(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    private static func money(_ value: Decimal, currency: String) -> MoneyAmount {
        MoneyAmount(amount: formatMoney(value), currency: currency)
    }

    private static func formatMoney(_ decimal: Decimal) -> String {
        let rounded = roundMoney(decimal)
        let number = NSDecimalNumber(decimal: rounded)
        return String(format: "%.2f", number.doubleValue)
    }

    private static func percentText(_ decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        let doubleValue = number.doubleValue
        if doubleValue.rounded() == doubleValue {
            return String(Int(doubleValue.rounded()))
        }
        return String(format: "%.2f", doubleValue)
    }
}

extension SaleLineTaxTreatmentOption {
    func localTaxRate(using configuration: LocalSaleTaxConfiguration) -> Decimal {
        switch self {
        case .operationalNoTax, .ivaZero, .notSubject, .exempt:
            return .zero
        case .ivaCurrent:
            return configuration.ivaCurrentRate
        case .ivaTourism8:
            return configuration.ivaTourismRate
        }
    }

    var canIssueElectronicInvoiceLocally: Bool {
        switch self {
        case .operationalNoTax:
            return false
        case .ivaCurrent, .ivaTourism8, .ivaZero, .notSubject, .exempt:
            return true
        }
    }

    func localWarning(itemName: String) -> String? {
        switch self {
        case .operationalNoTax:
            return "\(itemName) está como Solo registro; esa línea no podrá usarse para factura electrónica."
        case .ivaTourism8:
            return "\(itemName) usa IVA turismo 8%; verifica que aplique para el negocio y la fecha antes de facturar."
        case .ivaCurrent, .ivaZero, .notSubject, .exempt:
            return nil
        }
    }
}

enum SaleCartOrderState: Equatable, Sendable {
    case editing
    case previewing
    case creating
    case created
    
    var displayName: String {
        switch self {
        case .editing:
            return "En edición"
        case .previewing:
            return "Calculando"
        case .creating:
            return "Registrando"
        case .created:
            return "Registrada"
        }
    }
}

@MainActor
@Observable
final class SaleCartViewModel {
    var searchQuery = ""
    var cashSessionId: String?
    private(set) var searchResults: [BusinessCatalogItem] = []
    private(set) var suggestionResults: [PlatformCatalogTemplateSuggestion] = []
    private(set) var adoptingTemplateId: String?
    private(set) var cartItems: [SaleCartItem] = []
    private(set) var preview: SalesPreviewResponse?
    private(set) var localCalculation: LocalSaleCalculation = .empty
    private(set) var isPreviewDirty = false
    private(set) var createdSale: BusinessSale?
    private(set) var registeredSaleHasUnsavedChanges = false
    private var originalRegisteredCartItems: [SaleCartItem] = []
    private(set) var pendingSales: [BusinessSale] = []
    private(set) var isLoadingPendingSales = false
    private(set) var deletingPendingSaleId: String?
    private(set) var pendingSalesErrorMessage: String?

    private(set) var orderState: SaleCartOrderState = .editing
    private(set) var isSearching = false
    private(set) var isSearchingSuggestions = false
    private(set) var isPreviewing = false
    private(set) var isCreatingSale = false
    private(set) var selectedCustomer: BusinessCustomer?
    var selectedServiceType: BusinessSaleServiceType = .dineIn
    private var persistedServiceType: BusinessSaleServiceType?
    var errorMessage: String?
    var infoMessage: String?
    var discountTarget: SaleDiscountTarget = .wholeSale
    var discountType: SaleDiscountInputType = .percentage
    var discountValue: String = ""
    var discountReason: String = ""
    var selectedDiscountItemIds: Set<String> = []
    
    let organizationId: String
    let branchId: String
    let activityId: String
    private(set) var revisions: BusinessRevisions
    let effectivePermissions: Set<String>
    
    private let verticalContext: BusinessVerticalContext
    private let catalogRepository: CatalogRepository
    private let salesRepository: SalesRepository
    private let salesHistoryRepository: SalesHistoryRepository?
    private let contextRepository: BusinessContextRepository?
    private let revisionRegistry: BusinessRevisionRegistry
    private var scheduledPreviewTask: Task<Void, Never>?
    private var lastPendingSalesLoadedAt: Date?
    
    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String> = [],
        cashSessionId: String? = nil,
        verticalContext: BusinessVerticalContext = .empty,
        catalogRepository: CatalogRepository,
        salesRepository: SalesRepository,
        salesHistoryRepository: SalesHistoryRepository? = nil,
        contextRepository: BusinessContextRepository? = nil,
        editingSale: BusinessSale? = nil,
        revisionRegistry: BusinessRevisionRegistry = .shared
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.cashSessionId = cashSessionId
        self.verticalContext = verticalContext
        self.catalogRepository = catalogRepository
        self.salesRepository = salesRepository
        self.salesHistoryRepository = salesHistoryRepository
        self.contextRepository = contextRepository
        self.revisionRegistry = revisionRegistry

        if let editingSale {
            loadExistingSaleForEditing(editingSale)
        }
    }

    var verticalContextForSaleEditing: BusinessVerticalContext { verticalContext }
    var catalogRepositoryForSaleEditing: CatalogRepository { catalogRepository }
    var contextRepositoryForSaleEditing: BusinessContextRepository? { contextRepository }

    func cancelScheduledPreview() {
        scheduledPreviewTask?.cancel()
        scheduledPreviewTask = nil
    }
    
    var canSearchCatalog: Bool {
        !isSearching && !isSearchingSuggestions && adoptingTemplateId == nil && !isPreviewing && !isCreatingSale && (createdSale == nil || canEditRegisteredSaleItems)
    }

    var canAdoptCatalogSuggestion: Bool {
        canEditCart && adoptingTemplateId == nil && effectivePermissions.contains("catalog.local.copy_from_master")
    }
    
    var canEditCart: Bool {
        if createdSale != nil {
            return canEditRegisteredSaleItems && !isPreviewing && !isCreatingSale
        }
        return !isOrderLocked && !isPreviewing && !isCreatingSale
    }
    
    var canPreview: Bool {
        canEditCart && !cartItems.isEmpty
    }
    
    var canCreateSale: Bool {
        !isOrderLocked && !cartItems.isEmpty && !isCreatingSale && !isPreviewing
    }

    var supportsRestaurantServiceType: Bool {
        verticalContext.hasCapability("restaurant.service_type")
    }

    var availableServiceTypes: [BusinessSaleServiceType] {
        guard supportsRestaurantServiceType else { return [] }
        var values: [BusinessSaleServiceType] = [.dineIn, .takeaway, .manualDelivery]
        if verticalContext.hasCapability("restaurant.event_service") {
            values.append(.eventService)
        }
        return values
    }
    
    var canClearCart: Bool {
        canEditCart && !cartItems.isEmpty
    }


    var canEditRegisteredSaleItems: Bool {
        guard let sale = createdSale else { return false }
        guard !registeredSaleDocumentBlocksDirectItemEditing(sale) else { return false }
        let normalizedStatus = sale.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !["closed", "closed_day", "canceled", "cancelled", "voided"].contains(normalizedStatus)
    }

    var canSaveRegisteredSaleChanges: Bool {
        createdSale != nil &&
        registeredSaleHasUnsavedChanges &&
        canEditRegisteredSaleItems &&
        !cartItems.isEmpty &&
        cartItems.allSatisfy { isValidQuantity($0.quantity) } &&
        !isPreviewing &&
        !isCreatingSale
    }

    var registeredSaleEditBlockedMessage: String? {
        guard let sale = createdSale else { return nil }
        if registeredSaleDocumentBlocksDirectItemEditing(sale) {
            return "Esta venta ya tiene un comprobante electrónico generado, enviado o autorizado. Para cambiar productos debes usar un flujo fiscal correctivo, no edición directa."
        }
        if registeredSaleHasUnsavedChanges {
            return "Guarda los cambios de la venta antes de cobrar o emitir factura electrónica."
        }
        return nil
    }

    var finalConsumerInvoiceWarning: String? {
        if createdSale != nil && registeredSaleHasUnsavedChanges {
            return BusinessElectronicInvoiceCustomerPolicy.blockingMessageForInvoice(
                total: localCalculation.totals.grandTotal,
                selectedCustomer: selectedCustomer
            )
        }

        if let sale = createdSale {
            return BusinessElectronicInvoiceCustomerPolicy.blockingMessageForInvoice(sale: sale)
        }
        return BusinessElectronicInvoiceCustomerPolicy.warningMessage(
            total: localCalculation.totals.grandTotal,
            selectedCustomer: selectedCustomer
        )
    }


    var canApplyDiscount: Bool {
        canEditCart && !cartItems.isEmpty && hasDiscountPermission && normalizedDiscountValue() != nil
    }

    var canClearDiscounts: Bool {
        canEditCart && cartItems.contains { $0.discount != nil }
    }

    private var hasDiscountPermission: Bool {
        hasPermission([
            "business.sales.apply_discount",
            "sales.apply_discount"
        ])
    }
    
    var canStartNewOrder: Bool {
        createdSale != nil || !cartItems.isEmpty || preview != nil || selectedCustomer != nil
    }

    var visiblePendingSales: [BusinessSale] {
        let currentSaleId = createdSale?.id.trimmingCharacters(in: .whitespacesAndNewlines)
        return pendingSales
            .filter { sale in
                if let currentSaleId, sale.id.trimmingCharacters(in: .whitespacesAndNewlines) == currentSaleId {
                    return false
                }
                return Self.isPendingForCart(sale)
            }
            .sorted { lhs, rhs in
                (lhs.createdAt ?? lhs.updatedAt ?? .distantPast) > (rhs.createdAt ?? rhs.updatedAt ?? .distantPast)
            }
    }

    var shouldShowPendingSalesGroup: Bool {
        isLoadingPendingSales || pendingSalesErrorMessage != nil || !visiblePendingSales.isEmpty
    }

    var pendingSalesSubtitle: String {
        let count = visiblePendingSales.count
        if pendingSalesErrorMessage != nil { return "Revisa el estado de ventas guardadas sin salir de venta rápida" }
        if isLoadingPendingSales && count == 0 { return "Buscando ventas guardadas sin interrumpir la venta actual" }
        if count == 1 { return "1 venta requiere seguimiento" }
        return "\(count) ventas requieren seguimiento"
    }

    var pendingSalesBadgeTitle: String {
        let count = visiblePendingSales.count
        if isLoadingPendingSales && count == 0 { return "Buscando" }
        if pendingSalesErrorMessage != nil { return "Revisar" }
        if count == 1 { return "1 pendiente" }
        return "\(min(count, 99)) pendientes"
    }

    func canDeletePendingSale(_ sale: BusinessSale) -> Bool {
        deletingPendingSaleId == nil &&
        hasPermission(["business.sales.cancel", "sales.cancel"]) &&
        SaleStatusPresentation.canCancel(status: sale.status) &&
        Self.isPendingForCart(sale)
    }

    func isDeletingPendingSale(_ sale: BusinessSale) -> Bool {
        deletingPendingSaleId == sale.id
    }

    
    var isOrderLocked: Bool {
        createdSale != nil || orderState == .created || orderState == .creating
    }
    
    var canCollectCreatedSale: Bool {
        guard let sale = createdSale else { return false }
        return !registeredSaleHasUnsavedChanges &&
        SaleStatusPresentation.canCollect(status: sale.status) &&
        PaymentStatusPresentation.canCollect(status: sale.paymentStatus) &&
        (hasPaymentPermission || hasReceivablePermission)
    }

    var shouldShowCollectLockForCreatedSale: Bool {
        guard let sale = createdSale else { return false }
        return sale.needsCollection && !canCollectCreatedSale
    }

    var canOpenCreatedSaleDocuments: Bool {
        guard createdSale != nil else { return false }
        return hasPermission(documentViewPermissions + electronicInvoiceIssuePermissions)
    }

    var canIssueElectronicInvoiceForCreatedSale: Bool {
        guard let sale = createdSale else { return false }
        return !registeredSaleHasUnsavedChanges &&
        !sale.needsCollection &&
        BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.documentStatus) &&
        BusinessElectronicInvoiceCustomerPolicy.blockingMessageForInvoice(sale: sale) == nil &&
        hasPermission(electronicInvoiceIssuePermissions) &&
        !branchId.isEmpty &&
        !activityId.isEmpty
    }

    var createdSaleDocumentActionTitle: String {
        guard let sale = createdSale else { return "Ver comprobantes" }
        if canIssueElectronicInvoiceForCreatedSale {
            return "Emitir factura electrónica"
        }
        if BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.documentStatus) {
            return "Ver comprobantes"
        }
        return "Ver comprobante electrónico"
    }

    var createdSaleDocumentActionSystemImage: String {
        canIssueElectronicInvoiceForCreatedSale ? "doc.badge.plus" : "doc.text.magnifyingglass"
    }

    private var documentViewPermissions: [String] {
        [
            "business.documents.view",
            "documents.view",
            "business.electronic_documents.view",
            "electronic_documents.view",
            "documents.electronic_invoice.view"
        ]
    }

    private var electronicInvoiceIssuePermissions: [String] {
        [
            "business.documents.issue_electronic_invoice",
            "documents.issue_electronic_invoice",
            "documents.electronic_invoice.issue",
            "electronic_documents.issue",
            "business.electronic_documents.issue"
        ]
    }

    private var hasPaymentPermission: Bool {
        hasPermission([
            "business.payments.collect",
            "payments.collect",
            "business.payments.register",
            "payments.register"
        ])
    }

    private var hasReceivablePermission: Bool {
        hasPermission([
            "business.receivables.create",
            "receivables.create",
            "business.payments.mark_as_credit",
            "payments.mark_as_credit"
        ])
    }

    var customerIdForRequest: String? {
        guard let selectedCustomer else { return nil }
        return selectedCustomer.identificationType == .finalConsumer ? nil : selectedCustomer.id
    }
    
    var totalForDisplay: MoneyAmount? {
        createdSale?.totals.grandTotal ?? localCalculation.totals.grandTotal
    }

    var calculationStatusText: String? {
        guard createdSale == nil, !cartItems.isEmpty else { return nil }

        if isPreviewing {
            return "Validando total…"
        }

        if localCalculation.primaryWarning != nil {
            return nil
        }

        return nil
    }

    var createdSaleNeedsCollection: Bool {
        createdSale?.needsCollection == true
    }

    var createdSalePaymentStatusText: String {
        createdSale?.collectionState.displayName ?? PaymentStatusPresentation.displayName(createdSale?.paymentStatus)
    }

    var createdSaleDocumentStatusText: String {
        BusinessDocumentStatusPresentation.displayName(createdSale?.documentStatus ?? "not_required")
    }

    var createdSaleMessageStyle: NexoMessageStyle {
        createdSaleNeedsCollection ? .warning : .success
    }

    var startNewOrderConfirmationTitle: String {
        "Esta venta quedará sin cobrar"
    }

    var startNewOrderConfirmationMessage: String {
        "La venta fue registrada, pero todavía no se ha cobrado. Si continúas, aparecerá como venta sin cobrar y tendrás que cobrarla después."
    }

    func loadPendingSalesIfNeeded() async {
        guard salesHistoryRepository != nil else { return }
        if let lastPendingSalesLoadedAt, Date().timeIntervalSince(lastPendingSalesLoadedAt) < 20 {
            return
        }
        await refreshPendingSales()
    }

    func refreshPendingSales() async {
        guard let salesHistoryRepository else { return }
        guard hasPermission(["*", "business.sales.view", "sales.view"]) else { return }
        guard !isLoadingPendingSales else { return }

        isLoadingPendingSales = true
        pendingSalesErrorMessage = nil
        defer {
            isLoadingPendingSales = false
            lastPendingSalesLoadedAt = Date()
        }

        do {
            let response = try await salesHistoryRepository.searchSales(
                organizationId: organizationId,
                request: SalesHistorySearchRequest(
                    branchId: branchId,
                    statusValues: ["draft", "pending", "confirmed", "in_progress", "ready", "delivered"],
                    limit: 30
                )
            )
            pendingSales = response.sales.filter(Self.isPendingForCart)
        } catch let error as APIError {
            pendingSalesErrorMessage = error.userMessage
        } catch is CancellationError {
            // Ignore navigation refresh cancellation.
        } catch {
            pendingSalesErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func deletePendingSale(_ sale: BusinessSale) async -> Bool {
        guard canDeletePendingSale(sale) else {
            pendingSalesErrorMessage = "No puedes eliminar esta venta pendiente con tu usuario o estado actual."
            return false
        }

        let saleId = sale.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !saleId.isEmpty else {
            pendingSalesErrorMessage = "No se encontró el identificador de la venta pendiente."
            return false
        }

        deletingPendingSaleId = sale.id
        pendingSalesErrorMessage = nil
        infoMessage = nil

        defer {
            deletingPendingSaleId = nil
        }

        do {
            _ = try await salesRepository.cancel(
                organizationId: organizationId,
                saleId: saleId,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "sale-pending-delete"),
                request: CancelSaleRequest(
                    reason: "Eliminada desde ventas pendientes en Nexo Business"
                )
            )

            pendingSales.removeAll { $0.id == sale.id }
            infoMessage = "Venta eliminada de pendientes."
            return true
        } catch let error as APIError {
            pendingSalesErrorMessage = error.userMessage
        } catch is CancellationError {
            // Ignore navigation refresh cancellation.
        } catch {
            pendingSalesErrorMessage = error.localizedDescription
        }

        return false
    }

    func pendingSaleReasonText(for sale: BusinessSale) -> String {
        if SaleStatusPresentation.requiresConfirmationBeforeCollection(status: sale.status) {
            return "Borrador: se confirma en Sales antes de cobrar."
        }
        if PaymentStatusPresentation.isPendingCollection(sale.paymentStatus) || PaymentStatusPresentation.canCollect(status: sale.paymentStatus) {
            return "Pendiente de cobro en Sales."
        }
        return "Requiere revisión operativa."
    }

    private static func isPendingForCart(_ sale: BusinessSale) -> Bool {
        let status = sale.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "-", with: "_")
        guard !["closed", "canceled", "cancelled", "voided"].contains(status) else { return false }
        if SaleStatusPresentation.requiresConfirmationBeforeCollection(status: sale.status) { return true }
        return SaleStatusPresentation.canCollect(status: sale.status) && PaymentStatusPresentation.canCollect(status: sale.paymentStatus)
    }

    func updateCreatedSale(_ sale: BusinessSale) {
        guard createdSale?.id == sale.id else { return }
        createdSale = sale
        infoMessage = createdSaleSummaryMessage(for: sale, replayed: false)
    }

    func saveRegisteredSaleChanges() async {
        guard let sale = createdSale else {
            errorMessage = "No hay una venta registrada para actualizar."
            return
        }

        guard canSaveRegisteredSaleChanges else {
            errorMessage = registeredSaleEditBlockedMessage ?? "No hay cambios de productos pendientes."
            return
        }

        guard validateCart(showErrors: true) else { return }

        let originalSaleItemIds = Set(sale.items.map(\.id))
        let currentCartIds = Set(cartItems.map(\.id))
        let originalCartById = Dictionary(uniqueKeysWithValues: originalRegisteredCartItems.map { ($0.id, $0) })
        let existingCartItems = cartItems.filter { item in
            originalSaleItemIds.contains(item.id) && originalCartById[item.id] != item
        }
        let newCartItems = cartItems.filter { !originalSaleItemIds.contains($0.id) }
        let removedIds = sale.items.map(\.id).filter { !currentCartIds.contains($0) }

        isCreatingSale = true
        orderState = .creating
        errorMessage = nil
        infoMessage = "Guardando cambios de venta…"

        defer {
            isCreatingSale = false
            orderState = .created
        }

        do {
            var latestSale = sale
            let reason = "Corrección de productos antes de emitir factura electrónica"

            if !existingCartItems.isEmpty {
                let identity = BusinessMutationIdentity.generate(prefix: "sale-items-update")
                let response = try await salesRepository.bulkUpdateItems(
                    organizationId: organizationId,
                    saleId: latestSale.id,
                    revisions: revisions,
                    idempotencyKey: identity.idempotencyKey,
                    request: BulkUpdateSaleItemsRequest(
                        requestId: identity.requestId,
                        reason: reason,
                        catalogRevision: revisions.catalogRevision,
                        taxConfigurationRevision: revisions.taxConfigurationRevision,
                        items: existingCartItems.map { item in
                            BulkUpdateSaleItemRequest(
                                saleItemId: item.id,
                                replacement: saleItemRequest(for: item)
                            )
                        }
                    )
                )
                latestSale = response.sale
            }

            if !newCartItems.isEmpty {
                let identity = BusinessMutationIdentity.generate(prefix: "sale-items-add")
                let response = try await salesRepository.bulkAddItems(
                    organizationId: organizationId,
                    saleId: latestSale.id,
                    revisions: revisions,
                    idempotencyKey: identity.idempotencyKey,
                    request: BulkAddSaleItemsRequest(
                        requestId: identity.requestId,
                        catalogRevision: revisions.catalogRevision,
                        taxConfigurationRevision: revisions.taxConfigurationRevision,
                        items: newCartItems.map { saleItemRequest(for: $0) }
                    )
                )
                latestSale = response.sale
            }

            if !removedIds.isEmpty {
                let identity = BusinessMutationIdentity.generate(prefix: "sale-items-remove")
                let response = try await salesRepository.bulkRemoveItems(
                    organizationId: organizationId,
                    saleId: latestSale.id,
                    revisions: revisions,
                    idempotencyKey: identity.idempotencyKey,
                    request: BulkRemoveSaleItemsRequest(
                        requestId: identity.requestId,
                        reason: reason,
                        catalogRevision: revisions.catalogRevision,
                        taxConfigurationRevision: revisions.taxConfigurationRevision,
                        saleItemIds: removedIds
                    )
                )
                latestSale = response.sale
            }

            if registeredSaleServiceTypeChanged(from: latestSale) {
                let identity = BusinessMutationIdentity.generate(prefix: "sale-service-type-update")
                let response = try await salesRepository.updateServiceType(
                    organizationId: organizationId,
                    saleId: latestSale.id,
                    revisions: revisions,
                    idempotencyKey: identity.idempotencyKey,
                    request: UpdateSaleServiceTypeRequest(
                        requestId: identity.requestId,
                        serviceType: serviceTypeForRequest,
                        reason: "Corrección de tipo de servicio antes de cobrar o facturar"
                    )
                )
                latestSale = response.sale
            }

            if registeredSaleCustomerChanged(from: latestSale) {
                let identity = BusinessMutationIdentity.generate(prefix: "sale-customer-update")
                let response = try await salesRepository.updateCustomer(
                    organizationId: organizationId,
                    saleId: latestSale.id,
                    revisions: revisions,
                    idempotencyKey: identity.idempotencyKey,
                    request: UpdateSaleCustomerRequest(
                        requestId: identity.requestId,
                        customerId: customerIdForRequest,
                        customerSnapshot: customerSnapshotForRequest(),
                        reason: "Corrección de cliente antes de emitir factura electrónica"
                    )
                )
                latestSale = response.sale
            }

            let enrichedSale = latestSale.withLocalCartTaxProfileFallback(from: cartItems)
            createdSale = enrichedSale
            persistedServiceType = enrichedSale.serviceType
            realignCartItemsWithCreatedSale(enrichedSale)
            preview = nil
            registeredSaleHasUnsavedChanges = false
            originalRegisteredCartItems = cartItems
            isPreviewDirty = false
            recalculateLocalCalculation()
            infoMessage = "Cambios guardados. Ahora puedes cobrar o emitir factura con la venta corregida."
        } catch let error as APIError {
            orderState = .created
            handle(apiError: error)
        } catch {
            orderState = .created
            errorMessage = error.localizedDescription
        }
    }


    func recalculateLocalTotalsIfNeeded() {
        recalculateLocalCalculation()
    }
    
    func updateSelectedServiceType(_ serviceType: BusinessSaleServiceType) {
        guard ensureOrderIsEditable() else { return }
        selectedServiceType = serviceType
        errorMessage = nil
        if createdSale != nil {
            registeredSaleHasUnsavedChanges = registeredSaleServiceTypeChanged(from: createdSale) || registeredSaleHasUnsavedChanges
            infoMessage = nil
        }
    }

    func selectCustomer(_ customer: BusinessCustomer) {
        guard ensureOrderIsEditable() else { return }
        selectedCustomer = customer
        errorMessage = nil
        markCalculationDirty(shouldScheduleAutomaticPreview: true)
    }
    
    func clearCustomer() {
        guard ensureOrderIsEditable() else { return }
        selectedCustomer = createdSale == nil ? nil : BusinessCustomerPresentation.finalConsumer
        errorMessage = nil
        markCalculationDirty(shouldScheduleAutomaticPreview: true)
    }

    func updateLineNote(cartItemId: String, note: String) {
        guard ensureOrderIsEditable() else { return }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }
        cartItems[index].note = note
        errorMessage = nil
        markCalculationDirty(shouldScheduleAutomaticPreview: false)
    }

    func lineNote(for cartItemId: String) -> String {
        cartItems.first(where: { $0.id == cartItemId })?.note ?? ""
    }

    func updateTaxTreatment(cartItemId: String, taxTreatment: SaleLineTaxTreatmentOption) {
        guard ensureOrderIsEditable() else { return }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }
        cartItems[index].taxTreatment = taxTreatment
        errorMessage = nil
        markCalculationDirty(shouldScheduleAutomaticPreview: true)
    }

    func taxTreatment(for cartItemId: String) -> SaleLineTaxTreatmentOption {
        cartItems.first(where: { $0.id == cartItemId })?.taxTreatment ?? .defaultForNewLine()
    }
    
    func lineDiscount(for cartItemId: String) -> String {
        cartItems.first(where: { $0.id == cartItemId })?.discount?.amount ?? ""
    }

    func updateLineDiscount(cartItemId: String, discount: String) {
        guard ensureOrderIsEditable() else { return }
        guard hasDiscountPermission else {
            errorMessage = "No tienes permiso para aplicar descuentos."
            return
        }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }
        let normalized = discount.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if normalized.isEmpty {
            cartItems[index].discount = nil
        } else if let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value >= .zero {
            cartItems[index].discount = MoneyAmount(amount: formatMoney(value))
        } else {
            errorMessage = "El descuento debe ser un valor válido."
            return
        }
        markCalculationDirty(shouldScheduleAutomaticPreview: true)
    }

    func isSelectedForDiscount(_ cartItemId: String) -> Bool {
        selectedDiscountItemIds.contains(cartItemId)
    }

    func toggleDiscountSelection(_ cartItemId: String) {
        guard ensureOrderIsEditable() else { return }
        if selectedDiscountItemIds.contains(cartItemId) {
            selectedDiscountItemIds.remove(cartItemId)
        } else {
            selectedDiscountItemIds.insert(cartItemId)
        }
    }

    func applyDiscountDraft() {
        guard ensureOrderIsEditable() else { return }
        guard hasDiscountPermission else {
            errorMessage = "No tienes permiso para aplicar descuentos."
            return
        }
        guard let value = normalizedDiscountValue() else {
            errorMessage = "Ingresa un descuento válido."
            return
        }
        let targetIds: Set<String> = discountTarget == .wholeSale ? Set(cartItems.map(\.id)) : selectedDiscountItemIds
        guard !targetIds.isEmpty else {
            errorMessage = "Selecciona al menos un ítem para aplicar el descuento."
            return
        }
        let indexes = cartItems.indices.filter { targetIds.contains(cartItems[$0].id) }
        let grossByIndex = indexes.map { index in (index, grossAmount(for: cartItems[index])) }
        let totalGross = grossByIndex.reduce(Decimal.zero) { $0 + $1.1 }
        guard totalGross > .zero else {
            errorMessage = "No se pudo calcular la base del descuento."
            return
        }
        let totalDiscount: Decimal
        switch discountType {
        case .percentage:
            guard value <= Decimal(100) else {
                errorMessage = "El porcentaje no puede superar 100%."
                return
            }
            totalDiscount = totalGross * value / Decimal(100)
        case .value:
            guard value <= totalGross else {
                errorMessage = "El descuento no puede superar el subtotal seleccionado."
                return
            }
            totalDiscount = value
        }
        guard totalDiscount >= .zero else {
            errorMessage = "El descuento no puede ser negativo."
            return
        }
        var remaining = totalDiscount
        for pair in grossByIndex.dropLast() {
            let index = pair.0
            let gross = pair.1
            let allocated = min(gross, roundMoney(totalDiscount * gross / totalGross))
            cartItems[index].discount = allocated > .zero ? MoneyAmount(amount: formatMoney(allocated)) : nil
            remaining -= allocated
        }
        if let last = grossByIndex.last {
            let index = last.0
            let allocated = min(last.1, max(.zero, remaining))
            cartItems[index].discount = allocated > .zero ? MoneyAmount(amount: formatMoney(allocated)) : nil
        }
        markCalculationDirty(shouldScheduleAutomaticPreview: false)
        infoMessage = "Descuento aplicado."
    }

    func clearDiscounts() {
        guard ensureOrderIsEditable() else { return }
        cartItems = cartItems.map { item in
            var copy = item
            copy.discount = nil
            return copy
        }
        discountValue = ""
        discountReason = ""
        selectedDiscountItemIds = []
        markCalculationDirty(shouldScheduleAutomaticPreview: false)
        infoMessage = "Descuentos eliminados."
    }

    func searchCatalog() async {
        guard canSearchCatalog else {
            errorMessage = registeredSaleEditBlockedMessage ?? "Esta venta ya fue registrada y no se puede editar desde aquí."
            return
        }
        
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            searchResults = []
            errorMessage = "Busca por nombre, SKU o código."
            return
        }
        
        guard validateOperationalContext() else { return }
        guard !isSearching else { return }
        
        isSearching = true
        errorMessage = nil
        infoMessage = nil
        
        defer {
            isSearching = false
        }
        
        do {
            let response = try await catalogRepository.search(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: revisions.catalogRevision,
                query: query,
                limit: 25
            )
            
            searchResults = response.items
            if response.items.isEmpty {
                infoMessage = "No encontramos productos activos en tu negocio. Buscando sugerencias de Nexo…"
                await searchSuggestedCatalog(query: query)
            } else {
                suggestionResults = []
                infoMessage = nil
            }
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearSearch() {
        guard ensureOrderIsEditable() else { return }
        
        searchQuery = ""
        searchResults = []
        suggestionResults = []
        errorMessage = nil
        infoMessage = nil
    }
    
    private func searchSuggestedCatalog(query: String) async {
        guard !isSearchingSuggestions else { return }

        isSearchingSuggestions = true
        defer { isSearchingSuggestions = false }

        do {
            let response = try await catalogRepository.searchSuggestions(
                organizationId: organizationId,
                query: query,
                limit: 12
            )
            suggestionResults = response.templates
            if response.templates.isEmpty {
                infoMessage = "No encontramos productos activos ni sugerencias para esa búsqueda."
            } else {
                infoMessage = "Encontramos sugerencias de Nexo. Cópialas a tu negocio antes de vender."
            }
        } catch let error as APIError {
            suggestionResults = []
            errorMessage = error.userMessage
        } catch {
            suggestionResults = []
            errorMessage = error.localizedDescription
        }
    }

    func adoptSuggestion(_ suggestion: PlatformCatalogTemplateSuggestion) async {
        guard ensureOrderIsEditable() else { return }
        guard canAdoptCatalogSuggestion else {
            errorMessage = "No tienes permiso para copiar productos sugeridos al catálogo del negocio."
            return
        }
        guard let localPrice = suggestion.suggestedPrice else {
            errorMessage = "Esta sugerencia no tiene precio sugerido. Complétala desde Admin antes de copiarla."
            return
        }
        guard let taxProfileCode = suggestion.suggestedTaxProfileCode else {
            errorMessage = "Esta sugerencia no tiene perfil tributario sugerido. Complétala desde Admin antes de copiarla."
            return
        }

        adoptingTemplateId = suggestion.id
        errorMessage = nil
        infoMessage = nil

        defer { adoptingTemplateId = nil }

        do {
            let item = try await catalogRepository.adoptSuggestion(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                template: suggestion,
                localPrice: localPrice,
                taxProfileCode: taxProfileCode,
                reason: "Copiado desde sugerencias de Nexo en Business iOS"
            )

            suggestionResults.removeAll { $0.id == suggestion.id }
            searchResults.insert(item, at: 0)
            addToCart(item)
            await refreshBusinessContextAfterCatalogMutation()
            infoMessage = "Producto copiado a tu negocio y agregado al carrito."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshBusinessContextAfterCatalogMutation() async {
        guard let contextRepository else { return }
        do {
            let context = try await contextRepository.getContext(organizationId: organizationId)
            revisions = context.revisions
            await revisionRegistry.observeCatalogRevision(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: context.revisions.catalogRevision
            )
        } catch {
            // La adopción ya ocurrió; si el refresh falla, el próximo flujo con revisión stale lo resolverá.
        }
    }

    func addToCart(_ item: BusinessCatalogItem) {
        guard ensureOrderIsEditable() else { return }
        
        errorMessage = nil
        infoMessage = nil
        if let index = cartItems.firstIndex(where: { $0.catalogItem.id == item.id }) {
            cartItems[index].quantity = incrementQuantity(cartItems[index].quantity)
            markCalculationDirty(shouldScheduleAutomaticPreview: true)
            return
        }
        
        cartItems.append(
            SaleCartItem(
                catalogItem: item,
                quantity: "1",
                taxTreatment: .defaultForCatalogItem(item)
            )
        )
        markCalculationDirty(shouldScheduleAutomaticPreview: true)
    }
    
    func updateQuantity(cartItemId: String, quantity: String) {
        guard ensureOrderIsEditable() else { return }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }
        
        let normalized = normalizeQuantity(quantity)
        cartItems[index].quantity = normalized
        markCalculationDirty(shouldScheduleAutomaticPreview: true, showMessage: false)
    }
    
    func quantity(for cartItemId: String) -> String {
        cartItems.first(where: { $0.id == cartItemId })?.quantity ?? ""
    }
    
    func removeFromCart(cartItemId: String) {
        guard ensureOrderIsEditable() else { return }
        cartItems.removeAll { $0.id == cartItemId }
        markCalculationDirty(shouldScheduleAutomaticPreview: true)
    }
    
    func clearCart() {
        guard ensureOrderIsEditable() else { return }
        cartItems = []
        preview = nil
        localCalculation = .empty
        isPreviewDirty = false
        scheduledPreviewTask?.cancel()
        errorMessage = nil
        infoMessage = nil
        orderState = .editing
    }
    
    func startNewOrder() {
        searchQuery = ""
        searchResults = []
        cartItems = []
        preview = nil
        localCalculation = .empty
        isPreviewDirty = false
        scheduledPreviewTask?.cancel()
        createdSale = nil
        registeredSaleHasUnsavedChanges = false
        selectedCustomer = nil
        selectedServiceType = .dineIn
        errorMessage = nil
        infoMessage = nil
        orderState = .editing
    }
    
    func loadPreview() async {
        await loadPreview(showUserMessages: true)
    }

    private func loadPreview(showUserMessages: Bool) async {
        guard !isOrderLocked else {
            errorMessage = "Esta venta ya fue registrada. Inicia una nueva venta para continuar."
            return
        }

        guard validateCart(showErrors: showUserMessages) else { return }
        guard !isPreviewing, !isCreatingSale else { return }

        scheduledPreviewTask?.cancel()
        isPreviewing = true
        orderState = .previewing
        if showUserMessages {
            errorMessage = nil
            infoMessage = nil
        }

        defer {
            isPreviewing = false
            if createdSale == nil {
                orderState = .editing
            }
        }

        _ = await loadPreviewAttempt(allowContextRefreshRetry: true, showUserMessages: showUserMessages)
    }

    private func loadPreviewAttempt(allowContextRefreshRetry: Bool, showUserMessages: Bool) async -> Bool {
        do {
            let response = try await salesRepository.preview(
                organizationId: organizationId,
                revisions: revisions,
                request: previewRequest()
            )

            preview = response
            isPreviewDirty = false
            if !allowContextRefreshRetry && showUserMessages {
                infoMessage = "Contexto actualizado y total recalculado."
            }
            return true
        } catch let error as APIError {
            if error.isBusinessRevisionConflict,
               allowContextRefreshRetry,
               await refreshBusinessContextAfterRevisionConflict() {
                return await loadPreviewAttempt(allowContextRefreshRetry: false, showUserMessages: showUserMessages)
            }
            if showUserMessages {
                handle(apiError: error)
            }
            return false
        } catch {
            if showUserMessages {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    func createQuickSale() async {
        guard !isCreatingSale else { return }

        guard createdSale == nil else {
            orderState = .created
            errorMessage = "Esta venta ya fue registrada. Inicia una nueva venta para continuar."
            return
        }

        guard await ensureFreshPreviewBeforeCreatingSale() else { return }

        isCreatingSale = true
        orderState = .creating
        errorMessage = nil
        infoMessage = nil

        defer {
            isCreatingSale = false
        }

        do {
            let identity = BusinessMutationIdentity.generate(prefix: "quick-sale")
            let response = try await salesRepository.quickSale(
                organizationId: organizationId,
                revisions: revisions,
                idempotencyKey: identity.idempotencyKey,
                request: QuickSaleRequest(
                    requestId: identity.requestId,
                    branchId: branchId,
                    activityId: activityId,
                    customerId: customerIdForRequest,
                    customerSnapshot: customerSnapshotForRequest(),
                    cashSessionId: cashSessionId,
                    serviceType: serviceTypeForRequest,
                    autoConfirm: true,
                    catalogRevision: revisions.catalogRevision,
                    taxConfigurationRevision: revisions.taxConfigurationRevision,
                    items: draftItems()
                )
            )

            let saleWithLocalTaxFallback = response.sale.withLocalCartTaxProfileFallback(from: cartItems)
            createdSale = saleWithLocalTaxFallback
            persistedServiceType = saleWithLocalTaxFallback.serviceType
            realignCartItemsWithCreatedSale(saleWithLocalTaxFallback)
            originalRegisteredCartItems = cartItems
            registeredSaleHasUnsavedChanges = false
            preview = nil
            isPreviewDirty = false
            orderState = .created
            infoMessage = createdSaleSummaryMessage(
                for: saleWithLocalTaxFallback,
                replayed: response.idempotencyReplayed == true
            )
        } catch let error as APIError {
            orderState = .editing
            if error.isBusinessRevisionConflict,
               await refreshBusinessContextAfterRevisionConflict() {
                preview = nil
                isPreviewDirty = true
                errorMessage = nil
                infoMessage = "Contexto del negocio actualizado. Vuelve a registrar; el total local se actualizó y el servidor validará antes de guardar."
                recalculateLocalCalculation()
                return
            }
            handle(apiError: error)
        } catch {
            orderState = .editing
            errorMessage = error.localizedDescription
        }
    }

    var salesRepositoryForPaymentReadiness: SalesRepository {
        salesRepository
    }

    func makeSaleDetailViewModel(for sale: BusinessSale) -> SaleDetailViewModel {
        SaleDetailViewModel(
            organizationId: organizationId,
            saleId: sale.id,
            revisions: revisions,
            initialSale: sale,
            effectivePermissions: effectivePermissions,
            salesRepository: salesRepository
        )
    }
    
    private func ensureFreshPreviewBeforeCreatingSale() async -> Bool {
        scheduledPreviewTask?.cancel()

        guard validateCart(showErrors: true) else {
            orderState = .editing
            return false
        }

        if preview != nil && !isPreviewDirty {
            return true
        }

        isPreviewing = true
        orderState = .previewing
        errorMessage = nil
        infoMessage = "Recalculando total antes de registrar la venta…"

        defer {
            isPreviewing = false
            if createdSale == nil {
                orderState = .editing
            }
        }

        let success = await loadPreviewAttempt(allowContextRefreshRetry: true, showUserMessages: true)
        if !success {
            infoMessage = nil
        }
        return success
    }

    private func markCalculationDirty(shouldScheduleAutomaticPreview: Bool, showMessage: Bool = false) {
        preview = nil
        isPreviewDirty = true
        if createdSale != nil {
            registeredSaleHasUnsavedChanges = true
        }
        recalculateLocalCalculation()
        if showMessage {
            infoMessage = nil
        }
    }

    private func recalculateLocalCalculation() {
        localCalculation = LocalSaleCalculation.make(
            cartItems: cartItems,
            taxConfiguration: .ecuadorStagingFallback
        )
    }

    private func scheduleAutomaticPreview() {
        recalculateLocalCalculation()
    }

    private func runScheduledPreview() async {
        recalculateLocalCalculation()
    }

    private func createdSaleSummaryMessage(for sale: BusinessSale, replayed: Bool) -> String {
        if replayed {
            return sale.needsCollection
                ? "Venta sin cobrar recuperada de un intento anterior. No se duplicó la operación."
                : "Venta recuperada sin duplicar la operación."
        }

        if sale.needsCollection {
            return "Venta sin cobrar. La venta fue registrada, pero todavía no se ha cobrado ni es cuenta por cobrar."
        }

        if PaymentStatusPresentation.isCollected(sale.paymentStatus) {
            return "Venta cobrada correctamente."
        }

        return "Venta registrada. Revisa el detalle antes de continuar."
    }

    private func ensureOrderIsEditable() -> Bool {
        if createdSale != nil {
            guard canEditRegisteredSaleItems else {
                errorMessage = registeredSaleEditBlockedMessage ?? "Esta venta ya no permite editar productos."
                return false
            }
            return true
        }

        guard !isOrderLocked else {
            errorMessage = "Esta venta ya fue registrada. Toca Nueva venta para continuar."
            return false
        }
        return true
    }
    
    private var serviceTypeForRequest: BusinessSaleServiceType? {
        supportsRestaurantServiceType ? selectedServiceType : nil
    }

    private func previewRequest() -> SalesPreviewRequest {
        SalesPreviewRequest(
            branchId: branchId,
            activityId: activityId,
            customerId: customerIdForRequest,
            customerSnapshot: customerSnapshotForRequest(),
            catalogRevision: revisions.catalogRevision,
            taxConfigurationRevision: revisions.taxConfigurationRevision,
            items: draftItems()
        )
    }

    private func refreshBusinessContextAfterRevisionConflict() async -> Bool {
        guard let contextRepository else {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
            return false
        }

        do {
            let refreshedContext = try await contextRepository.getContext(organizationId: organizationId)

            guard refreshedContext.branches.contains(where: { $0.id == branchId }) else {
                errorMessage = "La sucursal actual ya no está disponible. Cambia el contexto operativo."
                infoMessage = nil
                return false
            }

            guard refreshedContext.activities.contains(where: { $0.id == activityId }) else {
                errorMessage = "La actividad actual ya no está disponible. Cambia el contexto operativo."
                infoMessage = nil
                return false
            }

            revisions = refreshedContext.revisions
            await revisionRegistry.observeRevisions(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                revisions: refreshedContext.revisions
            )
            return true
        } catch let error as APIError {
            errorMessage = "No se pudo actualizar el contexto: \(error.userMessage)"
            infoMessage = nil
            return false
        } catch {
            errorMessage = "No se pudo actualizar el contexto: \(error.localizedDescription)"
            infoMessage = nil
            return false
        }
    }

    private func draftItems() -> [BusinessSaleItemRequest] {
        cartItems.map { saleItemRequest(for: $0) }
    }
    

    private func saleItemRequest(for item: SaleCartItem) -> BusinessSaleItemRequest {
        BusinessSaleItemRequest(
            catalogItemId: item.catalogItem.id,
            quantity: BusinessSaleQuantityRequest(
                value: normalizeQuantity(item.quantity),
                unitCode: resolvedUnitCode(for: item.catalogItem),
                allowsDecimal: resolvedAllowsDecimal(for: item.catalogItem)
            ),
            discount: item.discount,
            priceTaxMode: BusinessSalePriceTaxMode.taxExclusive.rawValue,
            taxProfileCode: item.taxTreatment.taxProfileCode,
            notes: item.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlankForUI
        )
    }

    private func registeredSaleServiceTypeChanged(from sale: BusinessSale?) -> Bool {
        guard supportsRestaurantServiceType else { return false }
        let persisted = sale?.serviceType ?? persistedServiceType
        return persisted != serviceTypeForRequest
    }

    private func registeredSaleCustomerChanged(from sale: BusinessSale) -> Bool {
        let persistedCustomerId = sale.customerId?.nilIfBlank
        let selectedCustomerId = customerIdForRequest?.nilIfBlank

        if persistedCustomerId != selectedCustomerId {
            return true
        }

        return BusinessElectronicInvoiceCustomerPolicy.isFinalConsumer(sale: sale) !=
        BusinessElectronicInvoiceCustomerPolicy.isFinalConsumer(selectedCustomer)
    }

    private func customerSnapshotForRequest() -> BusinessSaleCustomerSnapshot? {
        guard let selectedCustomer else { return nil }
        guard selectedCustomer.identificationType != .finalConsumer else { return nil }
        return BusinessSaleCustomerSnapshot(
            id: selectedCustomer.id,
            displayName: selectedCustomer.displayName,
            identificationType: selectedCustomer.identificationType.rawValue,
            identificationNumber: selectedCustomer.identificationNumber,
            email: selectedCustomer.email
        )
    }

    private func loadExistingSaleForEditing(_ sale: BusinessSale) {
        scheduledPreviewTask?.cancel()
        createdSale = sale
        persistedServiceType = sale.serviceType
        selectedServiceType = sale.serviceType ?? .dineIn
        cartItems = sale.items.map { saleItem in
            SaleCartItem(existingSaleItem: saleItem)
        }
        originalRegisteredCartItems = cartItems
        selectedCustomer = sale.customerForCartEditing
        preview = nil
        isPreviewDirty = false
        registeredSaleHasUnsavedChanges = false
        orderState = .created
        recalculateLocalCalculation()
        infoMessage = "Venta abierta para editar. Puedes ajustar ítems, descuentos, cliente y tipo de servicio mientras no esté cerrada, cancelada o bloqueada por comprobante."
    }

    private func realignCartItemsWithCreatedSale(_ sale: BusinessSale) {
        guard !sale.items.isEmpty, !cartItems.isEmpty else { return }
        let previousCart = cartItems
        var usedCartIds: Set<String> = []

        cartItems = sale.items.enumerated().compactMap { index, saleItem in
            let match = matchingCartItem(for: saleItem, at: index, cartItems: previousCart, usedCartIds: usedCartIds)
            guard let match else { return nil }
            usedCartIds.insert(match.id)
            return SaleCartItem(
                id: saleItem.id,
                catalogItem: match.catalogItem,
                quantity: saleItem.quantity,
                taxTreatment: match.taxTreatment,
                discount: match.discount,
                note: saleItem.note ?? match.note
            )
        }
    }

    private func matchingCartItem(
        for saleItem: BusinessSaleItem,
        at index: Int,
        cartItems: [SaleCartItem],
        usedCartIds: Set<String>
    ) -> SaleCartItem? {
        if let catalogItemId = saleItem.catalogItemId?.nilIfBlank,
           let match = cartItems.first(where: { !usedCartIds.contains($0.id) && $0.catalogItem.id == catalogItemId }) {
            return match
        }

        if index < cartItems.count, !usedCartIds.contains(cartItems[index].id) {
            return cartItems[index]
        }

        let normalizedSaleName = saleItem.name.normalized
        return cartItems.first { !usedCartIds.contains($0.id) && $0.catalogItem.name.normalized == normalizedSaleName }
    }

    private func registeredSaleDocumentBlocksDirectItemEditing(_ sale: BusinessSale) -> Bool {
        guard let status = sale.effectiveDocumentStatus?.nilIfBlank else { return false }
        let normalizedStatus = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")

        switch normalizedStatus {
        case "", "none", "not_required", "no_required", "without_document", "sin_documento":
            return false
        case "not_authorized", "notauthorized", "no_autorizada", "returned", "returned_by_sri", "devuelta", "xsd_invalid", "signature_failed", "reception_transport_failed", "failed", "error":
            return false
        default:
            return true
        }
    }

    private func validateCart(showErrors: Bool = true) -> Bool {
        guard validateOperationalContext(showErrors: showErrors) else { return false }
        
        guard !cartItems.isEmpty else {
            if showErrors { errorMessage = "Agrega al menos un producto o servicio." }
            return false
        }
        
        guard cartItems.allSatisfy({ isValidQuantity($0.quantity) }) else {
            if showErrors { errorMessage = "Revisa las cantidades. Deben ser mayores a cero." }
            return false
        }
        
        return true
    }
    
    private func validateOperationalContext(showErrors: Bool = true) -> Bool {
        if organizationId.isEmpty || branchId.isEmpty || activityId.isEmpty {
            if showErrors { errorMessage = "Falta organización, sucursal o actividad operativa. Actualiza el contexto." }
            return false
        }
        
        if revisions.catalogRevision.isEmpty || revisions.taxConfigurationRevision.isEmpty {
            if showErrors { errorMessage = "Faltan revisiones de catálogo o impuestos. Actualiza el contexto." }
            return false
        }
        
        return true
    }
    
    private func normalizedDiscountValue() -> Decimal? {
        let normalized = discountValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value > .zero else { return nil }
        return value
    }

    private func grossAmount(for item: SaleCartItem) -> Decimal {
        let price = item.catalogItem.price?.amount ?? "0"
        let unitPrice = Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
        let quantity = Decimal(string: normalizeQuantity(item.quantity), locale: Locale(identifier: "en_US_POSIX")) ?? .zero
        return unitPrice * quantity
    }

    private func roundMoney(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    private func formatMoney(_ decimal: Decimal) -> String {
        let rounded = roundMoney(decimal)
        return NSDecimalNumber(decimal: rounded).stringValue.contains(".")
            ? String(format: "%.2f", NSDecimalNumber(decimal: rounded).doubleValue)
            : "\(NSDecimalNumber(decimal: rounded).stringValue).00"
    }

    private func hasPermission(_ permissions: [String]) -> Bool {
        effectivePermissions.contains("*") || permissions.contains { effectivePermissions.contains($0) }
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage

        if apiError.isBusinessRevisionConflict {
            infoMessage = contextRepository == nil
                ? "Actualiza el contexto del negocio antes de continuar."
                : "La información cambió. Intenté actualizar el contexto; vuelve a calcular el total."
            return
        }

        if apiError.isRevisionConflict {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }
    
    private func normalizeQuantity(_ quantity: String) -> String {
        quantity
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
    }
    
    private func isValidQuantity(_ quantity: String) -> Bool {
        let normalized = normalizeQuantity(quantity)
        guard let decimal = Decimal(string: normalized) else { return false }
        return decimal > Decimal.zero
    }
    
    private func incrementQuantity(_ quantity: String) -> String {
        let normalized = normalizeQuantity(quantity)
        let current = Decimal(string: normalized) ?? Decimal.zero
        let next = current + Decimal(1)
        return NSDecimalNumber(decimal: next).stringValue
    }
    
    private func resolvedUnitCode(for item: BusinessCatalogItem) -> String {
        let raw = item.unit?.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ?? item.unit?.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ?? "unit"
        
        switch raw {
        case "unidad", "unidades", "unit", "u", "und":
            return "unit"
        default:
            return raw.isEmpty ? "unit" : raw
        }
    }
    
    private func resolvedAllowsDecimal(for item: BusinessCatalogItem) -> Bool {
        item.allowsDecimalQuantity ?? item.unit?.allowsDecimal ?? false
    }
}


private extension SaleCartItem {
    init(existingSaleItem saleItem: BusinessSaleItem) {
        let catalogItemId = saleItem.catalogItemId?.nilIfBlank ?? saleItem.id
        let price = saleItem.unitPrice ?? saleItem.subtotal ?? saleItem.total ?? MoneyAmount(amount: "0.00")
        let taxTreatment = SaleLineTaxTreatmentOption.fromTaxProfileCode(saleItem.taxProfileCode) ?? .defaultForNewLine()
        self.init(
            id: saleItem.id,
            catalogItem: BusinessCatalogItem(
                id: catalogItemId,
                name: saleItem.name,
                type: "product",
                price: price,
                taxProfileCode: saleItem.taxProfileCode ?? taxTreatment.taxProfileCode,
                taxProfileName: saleItem.taxProfileName
            ),
            quantity: saleItem.quantity,
            taxTreatment: taxTreatment,
            discount: nil,
            note: saleItem.note
        )
    }
}

private extension BusinessSale {
    var customerForCartEditing: BusinessCustomer? {
        if BusinessElectronicInvoiceCustomerPolicy.isFinalConsumer(sale: self) {
            return BusinessCustomerPresentation.finalConsumer
        }

        guard let customerId = customerId?.nilIfBlank ?? customer?.id?.nilIfBlank else { return nil }
        let displayName = customer?.displayName.nilIfBlank ?? customerName?.nilIfBlank ?? "Cliente"
        let identification = customer?.identification?.nilIfBlank ?? ""

        return BusinessCustomer(
            id: customerId,
            displayName: displayName,
            identificationType: .unknown,
            identificationNumber: identification
        )
    }
}

private extension BusinessSale {
    func withLocalCartTaxProfileFallback(from cartItems: [SaleCartItem]) -> BusinessSale {
        guard !cartItems.isEmpty, !items.isEmpty else { return self }

        let enrichedItems = items.enumerated().map { index, item in
            guard item.taxProfileCode?.nilIfBlank == nil else { return item }
            guard let cartItem = matchingCartItem(for: item, at: index, cartItems: cartItems) else { return item }

            return BusinessSaleItem(
                id: item.id,
                catalogItemId: item.catalogItemId,
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                subtotal: item.subtotal,
                total: item.total,
                taxProfileCode: cartItem.taxTreatment.taxProfileCode,
                taxProfileName: item.taxProfileName,
                taxTreatment: item.taxTreatment,
                taxRate: item.taxRate,
                sriTaxCode: item.sriTaxCode,
                sriRateCode: item.sriRateCode,
                taxableBase: item.taxableBase,
                taxAmount: item.taxAmount,
                note: item.note
            )
        }

        return BusinessSale(
            id: id,
            number: number,
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            customerId: customerId,
            customerName: customerName,
            customer: customer,
            status: status,
            paymentStatus: paymentStatus,
            documentStatus: documentStatus,
            electronicDocumentSummary: electronicDocumentSummary,
            totals: totals,
            items: enrichedItems,
            createdAt: createdAt,
            confirmedAt: confirmedAt,
            closedAt: closedAt,
            updatedAt: updatedAt
        )
    }

    private func matchingCartItem(for saleItem: BusinessSaleItem, at index: Int, cartItems: [SaleCartItem]) -> SaleCartItem? {
        if let catalogItemId = saleItem.catalogItemId?.nilIfBlank,
           let match = cartItems.first(where: { $0.catalogItem.id == catalogItemId }) {
            return match
        }

        if index < cartItems.count {
            return cartItems[index]
        }

        let normalizedSaleName = saleItem.name.normalized
        return cartItems.first { $0.catalogItem.name.normalized == normalizedSaleName }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalized: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive], locale: .current)
    }
}
