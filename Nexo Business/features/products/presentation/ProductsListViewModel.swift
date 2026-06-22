//
//  ProductsListViewModel.swift
//  Nexo Business
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
    var query = ""
    var filter: Filter = .all
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var isShowingCreate = false
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
        return "No se pudo completar la operación. Revisa conexión o permisos."
    }
}
