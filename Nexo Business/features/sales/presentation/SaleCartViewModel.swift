//
//  SaleCartViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
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
        .operationalNoTax
    }

    static func defaultForCatalogItem(_ item: BusinessCatalogItem) -> SaleLineTaxTreatmentOption {
        fromTaxProfileCode(item.taxProfileCode) ?? .defaultForNewLine()
    }

    static func fromTaxProfileCode(_ code: String?) -> SaleLineTaxTreatmentOption? {
        switch code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "altos_staging_no_tax_internal", "no_tax_internal", "internal_no_tax":
            return .operationalNoTax
        case "altos_staging_iva_current_full", "iva_current_full", "iva_full":
            return .ivaCurrent
        case "altos_staging_iva_tourism_8", "iva_tourism_8", "iva_reduced_tourism":
            return .ivaTourism8
        case "altos_staging_iva_0", "iva_0", "iva_zero":
            return .ivaZero
        case "altos_staging_not_subject_to_iva", "not_subject_to_iva":
            return .notSubject
        case "altos_staging_exempt_iva", "exempt_iva":
            return .exempt
        default:
            return nil
        }
    }
}

struct SaleCartItem: Equatable, Identifiable, Sendable {
    let id: String
    let catalogItem: BusinessCatalogItem
    var quantity: String
    var taxTreatment: SaleLineTaxTreatmentOption
    var note: String?
    
    init(
        id: String = UUID().uuidString,
        catalogItem: BusinessCatalogItem,
        quantity: String = "1",
        taxTreatment: SaleLineTaxTreatmentOption = .defaultForNewLine(),
        note: String? = nil
    ) {
        self.id = id
        self.catalogItem = catalogItem
        self.quantity = quantity
        self.taxTreatment = taxTreatment
        self.note = note
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
    private(set) var cartItems: [SaleCartItem] = []
    private(set) var preview: SalesPreviewResponse?
    private(set) var createdSale: BusinessSale?
    private(set) var orderState: SaleCartOrderState = .editing
    private(set) var isSearching = false
    private(set) var isPreviewing = false
    private(set) var isCreatingSale = false
    private(set) var selectedCustomer: BusinessCustomer?
    var errorMessage: String?
    var infoMessage: String?
    
    let organizationId: String
    let branchId: String
    let activityId: String
    private(set) var revisions: BusinessRevisions
    let effectivePermissions: Set<String>
    
    private let catalogRepository: CatalogRepository
    private let salesRepository: SalesRepository
    private let contextRepository: BusinessContextRepository?
    private let revisionRegistry: BusinessRevisionRegistry
    
    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String> = [],
        cashSessionId: String? = nil,
        catalogRepository: CatalogRepository,
        salesRepository: SalesRepository,
        contextRepository: BusinessContextRepository? = nil,
        revisionRegistry: BusinessRevisionRegistry = .shared
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.cashSessionId = cashSessionId
        self.catalogRepository = catalogRepository
        self.salesRepository = salesRepository
        self.contextRepository = contextRepository
        self.revisionRegistry = revisionRegistry
    }
    
    var canSearchCatalog: Bool {
        !isSearching && !isOrderLocked
    }
    
    var canEditCart: Bool {
        !isOrderLocked && !isPreviewing && !isCreatingSale
    }
    
    var canPreview: Bool {
        canEditCart && !cartItems.isEmpty
    }
    
    var canCreateSale: Bool {
        canEditCart && !cartItems.isEmpty
    }
    
    var canClearCart: Bool {
        canEditCart && !cartItems.isEmpty
    }
    
    var canStartNewOrder: Bool {
        createdSale != nil || !cartItems.isEmpty || preview != nil || selectedCustomer != nil
    }
    
    var isOrderLocked: Bool {
        createdSale != nil || orderState == .created || orderState == .creating
    }
    
    var customerIdForRequest: String? {
        guard let selectedCustomer else { return nil }
        return selectedCustomer.identificationType == .finalConsumer ? nil : selectedCustomer.id
    }
    
    var totalForDisplay: MoneyAmount? {
        createdSale?.totals.grandTotal ?? preview?.totals.grandTotal
    }
    
    func selectCustomer(_ customer: BusinessCustomer) {
        guard ensureOrderIsEditable() else { return }
        selectedCustomer = customer
        preview = nil
        errorMessage = nil
        infoMessage = nil
    }
    
    func clearCustomer() {
        guard ensureOrderIsEditable() else { return }
        selectedCustomer = nil
        preview = nil
        errorMessage = nil
        infoMessage = nil
    }

    func updateLineNote(cartItemId: String, note: String) {
        guard ensureOrderIsEditable() else { return }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }
        cartItems[index].note = note
        preview = nil
        errorMessage = nil
        infoMessage = nil
    }

    func lineNote(for cartItemId: String) -> String {
        cartItems.first(where: { $0.id == cartItemId })?.note ?? ""
    }

    func updateTaxTreatment(cartItemId: String, taxTreatment: SaleLineTaxTreatmentOption) {
        guard ensureOrderIsEditable() else { return }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }
        cartItems[index].taxTreatment = taxTreatment
        preview = nil
        errorMessage = nil
        infoMessage = "Calcula nuevamente el total para validar el tratamiento tributario seleccionado."
    }

    func taxTreatment(for cartItemId: String) -> SaleLineTaxTreatmentOption {
        cartItems.first(where: { $0.id == cartItemId })?.taxTreatment ?? .defaultForNewLine()
    }
    
    func searchCatalog() async {
        guard !isOrderLocked else {
            errorMessage = "Esta venta ya fue registrada. Inicia una nueva venta para continuar."
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
            infoMessage = response.items.isEmpty ? "No encontramos productos o servicios activos." : nil
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
        errorMessage = nil
        infoMessage = nil
    }
    
    func addToCart(_ item: BusinessCatalogItem) {
        guard ensureOrderIsEditable() else { return }
        
        errorMessage = nil
        infoMessage = nil
        preview = nil
        
        if let index = cartItems.firstIndex(where: { $0.catalogItem.id == item.id }) {
            cartItems[index].quantity = incrementQuantity(cartItems[index].quantity)
            return
        }
        
        cartItems.append(
            SaleCartItem(
                catalogItem: item,
                quantity: "1",
                taxTreatment: .defaultForCatalogItem(item)
            )
        )
    }
    
    func updateQuantity(cartItemId: String, quantity: String) {
        guard ensureOrderIsEditable() else { return }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }
        
        let normalized = normalizeQuantity(quantity)
        cartItems[index].quantity = normalized
        preview = nil
    }
    
    func quantity(for cartItemId: String) -> String {
        cartItems.first(where: { $0.id == cartItemId })?.quantity ?? ""
    }
    
    func removeFromCart(cartItemId: String) {
        guard ensureOrderIsEditable() else { return }
        cartItems.removeAll { $0.id == cartItemId }
        preview = nil
    }
    
    func clearCart() {
        guard ensureOrderIsEditable() else { return }
        cartItems = []
        preview = nil
        errorMessage = nil
        infoMessage = nil
        orderState = .editing
    }
    
    func startNewOrder() {
        searchQuery = ""
        searchResults = []
        cartItems = []
        preview = nil
        createdSale = nil
        selectedCustomer = nil
        errorMessage = nil
        infoMessage = nil
        orderState = .editing
    }
    
    func loadPreview() async {
        guard !isOrderLocked else {
            errorMessage = "Esta venta ya fue registrada. Inicia una nueva venta para continuar."
            return
        }

        guard validateCart() else { return }
        guard !isPreviewing, !isCreatingSale else { return }

        isPreviewing = true
        orderState = .previewing
        errorMessage = nil
        infoMessage = nil

        defer {
            isPreviewing = false
            if createdSale == nil {
                orderState = .editing
            }
        }

        await loadPreviewAttempt(allowContextRefreshRetry: true)
    }

    private func loadPreviewAttempt(allowContextRefreshRetry: Bool) async {
        do {
            let response = try await salesRepository.preview(
                organizationId: organizationId,
                revisions: revisions,
                request: previewRequest()
            )

            preview = response
            if !allowContextRefreshRetry {
                infoMessage = "Contexto actualizado y total recalculado."
            }
        } catch let error as APIError {
            if error.isBusinessRevisionConflict,
               allowContextRefreshRetry,
               await refreshBusinessContextAfterRevisionConflict() {
                await loadPreviewAttempt(allowContextRefreshRetry: false)
                return
            }
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createQuickSale() async {
        guard !isCreatingSale else { return }

        guard createdSale == nil else {
            orderState = .created
            errorMessage = "Esta venta ya fue registrada. Inicia una nueva venta para continuar."
            return
        }

        guard validateCart() else { return }

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
                    cashSessionId: cashSessionId,
                    autoConfirm: true,
                    catalogRevision: revisions.catalogRevision,
                    taxConfigurationRevision: revisions.taxConfigurationRevision,
                    items: draftItems()
                )
            )

            createdSale = response.sale
            preview = nil
            orderState = .created
            infoMessage = response.idempotencyReplayed == true
            ? "Venta recuperada sin duplicar la operación."
            : "Venta registrada. Ahora puedes cobrarla o iniciar una nueva venta."
        } catch let error as APIError {
            orderState = .editing
            if error.isBusinessRevisionConflict,
               await refreshBusinessContextAfterRevisionConflict() {
                preview = nil
                errorMessage = nil
                infoMessage = "Contexto del negocio actualizado. Calcula nuevamente el total antes de registrar la venta."
                return
            }
            handle(apiError: error)
        } catch {
            orderState = .editing
            errorMessage = error.localizedDescription
        }
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
    
    private func ensureOrderIsEditable() -> Bool {
        guard !isOrderLocked else {
            errorMessage = "Esta venta ya fue registrada. Toca Nueva venta para continuar."
            return false
        }
        return true
    }
    
    private func previewRequest() -> SalesPreviewRequest {
        SalesPreviewRequest(
            branchId: branchId,
            activityId: activityId,
            customerId: customerIdForRequest,
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
        cartItems.map { item in
            BusinessSaleItemRequest(
                catalogItemId: item.catalogItem.id,
                quantity: BusinessSaleQuantityRequest(
                    value: normalizeQuantity(item.quantity),
                    unitCode: resolvedUnitCode(for: item.catalogItem),
                    allowsDecimal: resolvedAllowsDecimal(for: item.catalogItem)
                ),
                priceTaxMode: BusinessSalePriceTaxMode.taxExclusive.rawValue,
                taxProfileCode: item.taxTreatment.taxProfileCode,
                notes: item.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlankForUI
            )
        }
    }
    
    private func validateCart() -> Bool {
        guard validateOperationalContext() else { return false }
        
        guard !cartItems.isEmpty else {
            errorMessage = "Agrega al menos un producto o servicio."
            return false
        }
        
        guard cartItems.allSatisfy({ isValidQuantity($0.quantity) }) else {
            errorMessage = "Revisa las cantidades. Deben ser mayores a cero."
            return false
        }
        
        return true
    }
    
    private func validateOperationalContext() -> Bool {
        if organizationId.isEmpty || branchId.isEmpty || activityId.isEmpty {
            errorMessage = "Falta organización, sucursal o actividad operativa. Actualiza el contexto."
            return false
        }
        
        if revisions.catalogRevision.isEmpty || revisions.taxConfigurationRevision.isEmpty {
            errorMessage = "Faltan revisiones de catálogo o impuestos. Actualiza el contexto."
            return false
        }
        
        return true
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
