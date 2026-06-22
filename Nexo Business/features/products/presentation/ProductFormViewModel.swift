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

    var name: String
    var description: String
    var code: String
    var price: String
    var taxProfileCode: String
    var type: String
    var isSaving = false
    var errorMessage: String?

    init(
        mode: Mode,
        organizationId: String,
        branchId: String,
        activityId: String,
        repository: ProductsRepository
    ) {
        self.mode = mode
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.repository = repository

        switch mode {
        case .create:
            name = ""
            description = ""
            code = ""
            price = ""
            taxProfileCode = "IVA_15"
            type = "PRODUCT"
        case .edit(let product):
            name = product.name
            description = product.itemDescription ?? ""
            code = product.productsPrimaryCode ?? ""
            price = product.price?.amount ?? ""
            taxProfileCode = product.taxProfileCode ?? product.taxProfileId ?? "IVA_15"
            type = product.type ?? "PRODUCT"
        }
    }

    var title: String {
        switch mode {
        case .create: "Nuevo producto"
        case .edit: "Editar producto"
        }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Decimal(string: normalizedPrice) != nil
    }

    var normalizedPrice: String {
        price.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() async -> BusinessProduct? {
        guard canSave else {
            errorMessage = "Completa nombre y precio válido."
            return nil
        }
        guard !isSaving else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let money = MoneyAmount(amount: normalizedPrice, currency: "USD")
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
                        taxProfileCode: taxProfileCode.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
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
                        taxProfileCode: taxProfileCode.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
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
}

private extension String {
    var nilIfEmptyForProductForm: String? {
        isEmpty ? nil : self
    }
}
