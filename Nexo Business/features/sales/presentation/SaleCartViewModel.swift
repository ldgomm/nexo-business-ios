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
    
    var isOrderLocked: Bool {
        createdSale != nil || orderState == .created || orderState == .creating
    }
    
    var canCollectCreatedSale: Bool {
        guard let sale = createdSale else { return false }
        return SaleStatusPresentation.canCollect(status: sale.status) &&
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
        return !sale.needsCollection &&
        !sale.hasElectronicDocumentRegistered &&
        BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) &&
        hasPermission(electronicInvoiceIssuePermissions) &&
        !branchId.isEmpty &&
        !activityId.isEmpty
    }

    var createdSaleDocumentActionTitle: String {
        guard let sale = createdSale else { return "Ver comprobantes" }
        if canIssueElectronicInvoiceForCreatedSale {
            return "Emitir factura electrónica"
        }
        if BusinessDocumentStatusPresentation.isMissingElectronicDocument(sale.effectiveDocumentStatus) {
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
        createdSale?.totals.grandTotal ?? preview?.totals.grandTotal
    }

    var createdSaleNeedsCollection: Bool {
        createdSale?.needsCollection == true
    }

    var createdSalePaymentStatusText: String {
        PaymentStatusPresentation.displayName(createdSale?.paymentStatus)
    }

    var createdSaleDocumentStatusText: String {
        BusinessDocumentStatusPresentation.displayName(createdSale?.effectiveDocumentStatus ?? "not_required")
    }

    var createdSaleMessageStyle: NexoMessageStyle {
        createdSaleNeedsCollection ? .warning : .success
    }

    var startNewOrderConfirmationTitle: String {
        "Esta venta quedará pendiente de cobro"
    }

    var startNewOrderConfirmationMessage: String {
        "La venta fue registrada, pero todavía no se ha cobrado. Si continúas, aparecerá como pendiente en el día y tendrás que cobrarla después."
    }

    func updateCreatedSale(_ sale: BusinessSale) {
        guard createdSale?.id == sale.id else { return }
        createdSale = sale
        infoMessage = createdSaleSummaryMessage(for: sale, replayed: false)
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
        preview = nil
        infoMessage = "Calcula nuevamente el total para validar el descuento."
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
        preview = nil
        infoMessage = "Descuento aplicado. Calcula nuevamente el total antes de registrar la venta."
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
        preview = nil
        infoMessage = "Descuentos eliminados."
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
            infoMessage = createdSaleSummaryMessage(
                for: response.sale,
                replayed: response.idempotencyReplayed == true
            )
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
    
    private func createdSaleSummaryMessage(for sale: BusinessSale, replayed: Bool) -> String {
        if replayed {
            return sale.needsCollection
                ? "Venta pendiente recuperada de un intento anterior. No se duplicó la operación."
                : "Venta recuperada sin duplicar la operación."
        }

        if sale.needsCollection {
            return "Venta pendiente de cobro. La venta fue registrada, pero todavía no se ha cobrado."
        }

        if PaymentStatusPresentation.isCollected(sale.paymentStatus) {
            return "Venta cobrada correctamente."
        }

        return "Venta registrada. Revisa el detalle antes de continuar."
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
                discount: item.discount,
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
