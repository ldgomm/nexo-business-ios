//
//  ProductsListViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

@Observable
final class ProductsListViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case active
        case disabled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "Todos"
            case .active: "Disponibles"
            case .disabled: "No disponibles"
            }
        }

        var apiValue: String? {
            switch self {
            case .all: "all"
            case .active: "active"
            case .disabled: "disabled"
            }
        }
    }

    let organizationId: String
    let branchId: String
    let activityId: String
    let catalogRevision: String
    let repository: ProductsRepository

    var products: [BusinessProduct] = []
    var taxProfiles: [BusinessTaxProfile] = []
    var defaultProductTaxProfileCode: String?
    var query = ""
    var filter: Filter = .all
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var isShowingAdoption = false
    var editingProduct: BusinessProduct?

    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        repository: ProductsRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.catalogRevision = catalogRevision
        self.repository = repository
    }

    var hasProducts: Bool { !products.isEmpty }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await loadTaxProfilesIfNeeded()
            let response = try await repository.listProducts(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: catalogRevision,
                query: query,
                status: filter.apiValue,
                limit: 100
            )
            products = response.products.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = ProductsErrorPresenter.message(for: error)
        }
    }

    private func loadTaxProfilesIfNeeded() async throws {
        guard taxProfiles.isEmpty else { return }
        let response = try await repository.listTaxProfiles(organizationId: organizationId)
        taxProfiles = response.profiles.filter { $0.enabled && $0.canUseForProducts && !$0.internalOnly }
        defaultProductTaxProfileCode = response.defaultProductTaxProfileCode
    }

    func deactivate(_ product: BusinessProduct) async {
        await setStatus(product, active: false)
    }

    func activate(_ product: BusinessProduct) async {
        await setStatus(product, active: true)
    }

    private func setStatus(_ product: BusinessProduct, active: Bool) async {
        errorMessage = nil
        successMessage = nil
        do {
            let response: BusinessProductMutationResponse
            if active {
                response = try await repository.activateProduct(
                    organizationId: organizationId,
                    productId: product.id,
                    reason: "Producto activado desde Business."
                )
            } else {
                response = try await repository.deactivateProduct(
                    organizationId: organizationId,
                    productId: product.id,
                    reason: "Producto desactivado desde Business."
                )
            }
            replace(response.product)
            successMessage = active ? "Producto activado." : "Producto desactivado."
        } catch {
            errorMessage = ProductsErrorPresenter.message(for: error)
        }
    }

    func replace(_ product: BusinessProduct) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        } else {
            products.insert(product, at: 0)
        }
    }
}

enum ProductsErrorPresenter {
    static func message(for error: Error) -> String {
        let raw = String(describing: error)
        if raw.contains("404") {
            return "Productos todavía no está disponible en el servidor. Actualiza backend 20O.2C y vuelve a intentar."
        }
        if raw.contains("403") {
            return "Tu usuario no tiene permiso para administrar productos."
        }
        if raw.lowercased().contains("already") || raw.lowercased().contains("duplic") || raw.lowercased().contains("ya fue") {
            return "Ese producto ya fue agregado desde el catálogo maestro."
        }
        if raw.lowercased().contains("master catalog") || raw.lowercased().contains("catálogo maestro") {
            return "Los productos deben agregarse desde el catálogo maestro."
        }
        if raw.lowercased().contains("tax profile") || raw.lowercased().contains("perfil tributario") {
            return "No se pudo usar el perfil tributario seleccionado. Recarga Productos y elige un perfil habilitado."
        }
        return "No se pudo completar la operación. Revisa conexión o permisos."
    }
}
