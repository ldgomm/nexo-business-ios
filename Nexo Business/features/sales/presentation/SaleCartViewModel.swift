//
//  SaleCartViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

public struct SaleCartItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let catalogItem: BusinessCatalogItem
    public var quantity: String
    public var note: String?

    public init(
        id: String = UUID().uuidString,
        catalogItem: BusinessCatalogItem,
        quantity: String = "1",
        note: String? = nil
    ) {
        self.id = id
        self.catalogItem = catalogItem
        self.quantity = quantity
        self.note = note
    }
}

@MainActor
@Observable
public final class SaleCartViewModel {
    public var searchQuery = ""
    public private(set) var searchResults: [BusinessCatalogItem] = []
    public private(set) var cartItems: [SaleCartItem] = []
    public private(set) var preview: SalesPreviewResponse?
    public private(set) var createdSale: BusinessSale?
    public private(set) var isSearching = false
    public private(set) var isPreviewing = false
    public private(set) var isCreatingSale = false
    public private(set) var selectedCustomer: BusinessCustomer?
    public var errorMessage: String?
    public var infoMessage: String?

    public let organizationId: String
    public let branchId: String
    public let activityId: String
    public private(set) var revisions: BusinessRevisions
    public let effectivePermissions: Set<String>

    private let catalogRepository: CatalogRepository
    private let salesRepository: SalesRepository

    public init(
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String> = [],
        catalogRepository: CatalogRepository,
        salesRepository: SalesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.catalogRepository = catalogRepository
        self.salesRepository = salesRepository
    }

    public var canPreview: Bool {
        !cartItems.isEmpty && !isPreviewing && !isCreatingSale
    }

    public var canCreateSale: Bool {
        !cartItems.isEmpty && !isPreviewing && !isCreatingSale
    }

    public var customerIdForRequest: String? {
        guard let selectedCustomer else { return nil }
        return selectedCustomer.identificationType == .finalConsumer ? nil : selectedCustomer.id
    }

    public func selectCustomer(_ customer: BusinessCustomer) {
        selectedCustomer = customer
        preview = nil
        createdSale = nil
        errorMessage = nil
        infoMessage = nil
    }

    public func clearCustomer() {
        selectedCustomer = nil
        preview = nil
        createdSale = nil
    }

    public func searchCatalog() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            searchResults = []
            errorMessage = "Busca por nombre, SKU o código."
            return
        }

        guard validateOperationalContext() else { return }

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

    public func addToCart(_ item: BusinessCatalogItem) {
        errorMessage = nil
        infoMessage = nil
        createdSale = nil
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

    public func updateQuantity(cartItemId: String, quantity: String) {
        guard let index = cartItems.firstIndex(where: { $0.id == cartItemId }) else { return }

        let normalized = normalizeQuantity(quantity)
        cartItems[index].quantity = normalized
        preview = nil
        createdSale = nil
    }

    public func quantity(for cartItemId: String) -> String {
        cartItems.first(where: { $0.id == cartItemId })?.quantity ?? ""
    }

    public func removeFromCart(cartItemId: String) {
        cartItems.removeAll { $0.id == cartItemId }
        preview = nil
        createdSale = nil
    }

    public func clearCart() {
        cartItems = []
        preview = nil
        createdSale = nil
        errorMessage = nil
        infoMessage = nil
    }

    public func loadPreview() async {
        guard validateCart() else { return }

        isPreviewing = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isPreviewing = false
        }

        do {
            let response = try await salesRepository.preview(
                organizationId: organizationId,
                revisions: revisions,
                request: SalesPreviewRequest(
                    branchId: branchId,
                    activityId: activityId,
                    customerId: customerIdForRequest,
                    items: draftItems()
                )
            )

            preview = response

            if let updatedRevisions = response.revisions {
                revisions = updatedRevisions
            }
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createQuickSale() async {
        guard validateCart() else { return }

        isCreatingSale = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isCreatingSale = false
        }

        do {
            let response = try await salesRepository.quickSale(
                organizationId: organizationId,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "quick-sale"),
                request: QuickSaleRequest(
                    branchId: branchId,
                    activityId: activityId,
                    customerId: customerIdForRequest,
                    items: draftItems()
                )
            )

            createdSale = response.sale
            infoMessage = response.idempotencyReplayed == true
                ? "Venta recuperada de un intento anterior."
                : "Venta creada. Revísala y confírmala para continuar."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func makeSaleDetailViewModel(for sale: BusinessSale) -> SaleDetailViewModel {
        SaleDetailViewModel(
            organizationId: organizationId,
            saleId: sale.id,
            revisions: revisions,
            initialSale: sale,
            effectivePermissions: effectivePermissions,
            salesRepository: salesRepository
        )
    }

    private func draftItems() -> [SaleDraftItem] {
        cartItems.map { item in
            SaleDraftItem(
                id: item.id,
                catalogItemId: item.catalogItem.id,
                quantity: normalizeQuantity(item.quantity),
                note: item.note
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
}
