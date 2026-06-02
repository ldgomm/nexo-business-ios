//
//  SaleCartViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import Foundation
import Observation

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
    var saleNote = ""
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
    
    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String> = [],
        cashSessionId: String? = nil,
        catalogRepository: CatalogRepository,
        salesRepository: SalesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.cashSessionId = cashSessionId
        self.catalogRepository = catalogRepository
        self.salesRepository = salesRepository
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
        createdSale != nil ||
        !cartItems.isEmpty ||
        preview != nil ||
        selectedCustomer != nil ||
        !saleNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    var allowedPriceTaxModes: [BusinessSalePriceTaxMode] {
        [.taxExclusive]
    }

    var taxModePolicyMessage: String {
        "Esta organización no permite precios con IVA incluido. La venta se enviará como Precio + IVA y el servidor calculará el impuesto."
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
    }

    func lineNote(for cartItemId: String) -> String {
        cartItems.first(where: { $0.id == cartItemId })?.note ?? ""
    }

    func updatePriceTaxMode(cartItemId: String, mode: BusinessSalePriceTaxMode) {
        guard ensureOrderIsEditable() else { return }
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }

        let resolvedMode = resolvedPriceTaxMode(mode)
        cartItems[index].priceTaxMode = resolvedMode
        preview = nil

        if resolvedMode != mode {
            errorMessage = taxModePolicyMessage
            infoMessage = nil
        }
    }

    func priceTaxMode(for cartItemId: String) -> BusinessSalePriceTaxMode {
        cartItems.first(where: { $0.id == cartItemId })?.priceTaxMode ?? .taxExclusive
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
                quantity: "1"
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
        saleNote = ""
        preview = nil
        errorMessage = nil
        infoMessage = nil
        orderState = .editing
    }
    
    func startNewOrder() {
        searchQuery = ""
        searchResults = []
        cartItems = []
        saleNote = ""
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
        
        do {
            let response = try await salesRepository.preview(
                organizationId: organizationId,
                revisions: revisions,
                request: SalesPreviewRequest(
                    branchId: branchId,
                    activityId: activityId,
                    customerId: customerIdForRequest,
                    catalogRevision: revisions.catalogRevision,
                    taxConfigurationRevision: revisions.taxConfigurationRevision,
                    items: draftItems()
                )
            )
            
            preview = response
        } catch let error as APIError {
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
                    items: draftItems(),
                    notes: saleNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlankForUI
                )
            )
            
            createdSale = response.sale
            preview = nil
            orderState = .created
            infoMessage = response.idempotencyReplayed == true
            ? "Venta recuperada sin duplicar la operación."
            : "Venta registrada. Continúa con el cobro en esta misma pantalla."
        } catch let error as APIError {
            orderState = .editing
            handle(apiError: error)
        } catch {
            orderState = .editing
            errorMessage = error.localizedDescription
        }
    }
    
    func applyUpdatedSale(_ sale: BusinessSale) {
        guard createdSale?.id == sale.id else { return }
        createdSale = sale
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
    
    private func draftItems() -> [BusinessSaleItemRequest] {
        cartItems.map { item in
            BusinessSaleItemRequest(
                catalogItemId: item.catalogItem.id,
                quantity: BusinessSaleQuantityRequest(
                    value: normalizeQuantity(item.quantity),
                    unitCode: resolvedUnitCode(for: item.catalogItem),
                    allowsDecimal: resolvedAllowsDecimal(for: item.catalogItem)
                ),
                priceTaxMode: resolvedPriceTaxMode(item.priceTaxMode).rawValue,
                notes: item.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlankForUI
            )
        }
    }
    
    private func resolvedPriceTaxMode(_ mode: BusinessSalePriceTaxMode) -> BusinessSalePriceTaxMode {
        allowedPriceTaxModes.contains(mode) ? mode : .taxExclusive
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
        
        if apiError.statusCode == 409 || apiError.statusCode == 428 {
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
