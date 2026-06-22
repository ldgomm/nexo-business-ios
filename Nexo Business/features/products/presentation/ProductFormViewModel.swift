//
//  ProductFormViewModel.swift
//  Nexo Business
//

import Foundation

@Observable
final class ProductFormViewModel {
    enum Mode: Equatable {
        case create
        case edit(BusinessProduct)
    }

    let mode: Mode
    let organizationId: String
    let branchId: String
    let activityId: String
    let repository: ProductsRepository
    let taxProfiles: [BusinessTaxProfile]

    var name: String
    var description: String
    var code: String
    var price: String
    var selectedTaxProfileCode: String
    var type: String
    var isSaving = false
    var errorMessage: String?

    init(
        mode: Mode,
        organizationId: String,
        branchId: String,
        activityId: String,
        repository: ProductsRepository,
        taxProfiles: [BusinessTaxProfile]
    ) {
        self.mode = mode
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.repository = repository
        self.taxProfiles = taxProfiles.filter { $0.enabled && $0.canUseForProducts && !$0.internalOnly }

        let defaultTaxProfileCode = Self.resolveDefaultTaxProfileCode(
            mode: mode,
            taxProfiles: self.taxProfiles
        )

        switch mode {
        case .create:
            name = ""
            description = ""
            code = ""
            price = ""
            selectedTaxProfileCode = defaultTaxProfileCode
            type = "PRODUCT"
        case .edit(let product):
            name = product.name
            description = product.itemDescription ?? ""
            code = product.productsPrimaryCode ?? ""
            price = product.price?.amount ?? ""
            selectedTaxProfileCode = defaultTaxProfileCode
            type = product.type ?? "PRODUCT"
        }
    }

    var title: String {
        switch mode {
        case .create: "Nuevo producto"
        case .edit: "Editar producto"
        }
    }

    var selectedTaxProfile: BusinessTaxProfile? {
        taxProfiles.first { $0.code == selectedTaxProfileCode }
    }

    var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidPrice = Decimal(string: normalizedPrice) != nil
        return hasName && hasValidPrice && selectedTaxProfile != nil
    }

    var normalizedPrice: String {
        price.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() async -> BusinessProduct? {
        guard canSave else {
            if taxProfiles.isEmpty {
                errorMessage = "No hay perfiles tributarios habilitados para productos. Revisa configuración tributaria."
            } else {
                errorMessage = "Completa nombre, precio válido y perfil tributario."
            }
            return nil
        }
        guard !isSaving else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let money = MoneyAmount(amount: normalizedPrice, currency: "USD")
            let taxProfileCode = selectedTaxProfileCode.trimmingCharacters(in: .whitespacesAndNewlines)
            switch mode {
            case .create:
                let response = try await repository.createProduct(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    request: BusinessProductUpsertRequest(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
                        code: code.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
                        category: nil,
                        type: type,
                        price: money,
                        taxProfileCode: taxProfileCode.nilIfEmptyForProductForm,
                        branchId: branchId,
                        activityId: activityId,
                        reason: "Producto creado desde Business."
                    )
                )
                return response.product
            case .edit(let product):
                let response = try await repository.updateProduct(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    productId: product.id,
                    request: BusinessProductPatchRequest(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
                        code: code.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
                        category: nil,
                        price: money,
                        taxProfileCode: taxProfileCode.nilIfEmptyForProductForm,
                        reason: "Producto editado desde Business."
                    )
                )
                return response.product
            }
        } catch {
            errorMessage = ProductsErrorPresenter.message(for: error)
            return nil
        }
    }

    private static func resolveDefaultTaxProfileCode(
        mode: Mode,
        taxProfiles: [BusinessTaxProfile]
    ) -> String {
        switch mode {
        case .edit(let product):
            let productCode = product.taxProfileCode?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let productCode, taxProfiles.contains(where: { $0.code == productCode }) {
                return productCode
            }
        case .create:
            break
        }

        return taxProfiles.first(where: { $0.defaultForProducts })?.code
        ?? taxProfiles.first?.code
        ?? ""
    }
}

private extension String {
    var nilIfEmptyForProductForm: String? {
        isEmpty ? nil : self
    }
}
