//
//  ProductFormViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

@Observable
final class ProductFormViewModel {
    enum Mode: Equatable {
        case adopt(BusinessMasterCatalogItem)
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
    var restaurantMenuCategory: String
    var restaurantPreparationArea: String
    var restaurantIsKitchenItem: Bool
    var restaurantDisplayOrder: String
    var restaurantAvailability: String
    var restaurantVisibleInMenu: Bool
    var restaurantNotes: String
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
        case .adopt(let master):
            name = ""
            description = ""
            code = ""
            price = ""
            selectedTaxProfileCode = defaultTaxProfileCode
            type = master.type
            restaurantMenuCategory = ""
            restaurantPreparationArea = ""
            restaurantIsKitchenItem = false
            restaurantDisplayOrder = ""
            restaurantAvailability = "AVAILABLE"
            restaurantVisibleInMenu = true
            restaurantNotes = ""
        case .edit(let product):
            name = product.name
            description = product.itemDescription ?? ""
            code = product.productsPrimaryCode ?? ""
            price = product.price?.amount ?? ""
            selectedTaxProfileCode = defaultTaxProfileCode
            type = product.type ?? "PRODUCT"
            restaurantMenuCategory = product.restaurantAttributes?.menuCategory ?? ""
            restaurantPreparationArea = product.restaurantAttributes?.preparationArea ?? ""
            restaurantIsKitchenItem = product.restaurantAttributes?.isKitchenItem ?? false
            restaurantDisplayOrder = product.restaurantAttributes?.displayOrder.map(String.init) ?? ""
            restaurantAvailability = product.restaurantAttributes?.availability ?? "AVAILABLE"
            restaurantVisibleInMenu = product.restaurantAttributes?.visibleInMenu ?? true
            restaurantNotes = product.restaurantAttributes?.notes ?? ""
        }
    }

    var title: String {
        switch mode {
        case .adopt: "Agregar desde catálogo"
        case .edit: "Editar producto"
        }
    }

    var masterName: String? {
        switch mode {
        case .adopt(let master): master.name
        case .edit: nil
        }
    }

    var masterSubtitle: String? {
        switch mode {
        case .adopt(let master):
            [master.categoryName, master.type].compactMap { $0?.nilIfEmptyForProductForm }.joined(separator: " · ").nilIfEmptyForProductForm
        case .edit(let product):
            product.productsMasterReferenceLabel
        }
    }

    var localNamePlaceholder: String {
        switch mode {
        case .adopt: "Nombre local opcional"
        case .edit: "Nombre *"
        }
    }

    var selectedTaxProfile: BusinessTaxProfile? {
        taxProfiles.first { $0.code == selectedTaxProfileCode }
    }

    var canSave: Bool {
        let requiresName: Bool
        switch mode {
        case .adopt: requiresName = false
        case .edit: requiresName = true
        }
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidPrice = Decimal(string: normalizedPrice) != nil
        let displayOrderText = restaurantDisplayOrder.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayOrderValue = Int(displayOrderText)
        let hasValidDisplayOrder = displayOrderText.isEmpty || (displayOrderValue != nil && displayOrderValue ?? -1 >= 0)
        return (!requiresName || hasName) && hasValidPrice && selectedTaxProfile != nil && hasValidDisplayOrder
    }

    var normalizedPrice: String {
        price.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var showsRestaurantMenuSection: Bool {
        if case .edit = mode { return true }
        return false
    }

    func save() async -> BusinessProduct? {
        guard canSave else {
            if taxProfiles.isEmpty {
                errorMessage = "No hay perfiles tributarios habilitados para productos. Revisa configuración tributaria."
            } else {
                errorMessage = "Completa precio válido y perfil tributario."
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
            case .adopt(let master):
                let response = try await repository.adoptProduct(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    request: BusinessProductAdoptRequest(
                        masterCatalogItemId: master.id,
                        branchId: branchId,
                        activityId: activityId,
                        price: money,
                        taxProfileCode: taxProfileCode.nilIfEmptyForProductForm,
                        localCode: code.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
                        localName: name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProductForm,
                        reason: "Producto adoptado desde catálogo maestro."
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
                        restaurantAttributes: restaurantAttributesPatch,
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


    private var restaurantAttributesPatch: BusinessRestaurantAttributesPatch? {
        let category = restaurantMenuCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let preparationArea = restaurantPreparationArea.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = restaurantNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayOrderText = restaurantDisplayOrder.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingAttributes: BusinessRestaurantAttributes?
        if case .edit(let product) = mode {
            existingAttributes = product.restaurantAttributes
        } else {
            existingAttributes = nil
        }
        let hasRestaurantConfiguration = existingAttributes != nil
            || !category.isEmpty
            || !preparationArea.isEmpty
            || !notes.isEmpty
            || !displayOrderText.isEmpty
            || restaurantIsKitchenItem
            || restaurantAvailability != "AVAILABLE"
            || !restaurantVisibleInMenu

        guard hasRestaurantConfiguration else { return nil }

        return BusinessRestaurantAttributesPatch(
            menuCategory: category.nilIfEmptyForProductForm ?? existingAttributes.map { _ in "" },
            preparationArea: preparationArea.nilIfEmptyForProductForm ?? existingAttributes.map { _ in "" },
            isKitchenItem: restaurantIsKitchenItem,
            displayOrder: Int(displayOrderText),
            availability: restaurantAvailability,
            visibleInMenu: restaurantVisibleInMenu,
            tags: nil,
            notes: notes.nilIfEmptyForProductForm ?? existingAttributes.map { _ in "" }
        )
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
        case .adopt(let master):
            let masterCode = master.defaultTaxProfileCode?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let masterCode, taxProfiles.contains(where: { $0.code == masterCode }) {
                return masterCode
            }
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
