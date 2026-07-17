//
//  BusinessSuppliersViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessSuppliersViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case active
        case inactive
        case blocked

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .active: return "Activos"
            case .inactive: return "Inactivos"
            case .blocked: return "Bloqueados"
            }
        }

        var apiValue: BusinessSupplierStatus? {
            switch self {
            case .all: return nil
            case .active: return .active
            case .inactive: return .inactive
            case .blocked: return .blocked
            }
        }
    }

    private(set) var suppliers: [BusinessProcurementSupplierResponse] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var nextCursor: String?
    private(set) var hasLoaded = false
    var query = ""
    var category = ""
    var statusFilter: StatusFilter = .all
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.suppliersView)
    }

    var canCreate: Bool {
        accessPolicy.canCreateSupplier
    }

    var hasActiveFilters: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        statusFilter != .all
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load(reset: true)
    }

    func refresh() async {
        await load(reset: true)
    }

    func search() async {
        await load(reset: true)
    }

    func clearFilters() async {
        query = ""
        category = ""
        statusFilter = .all
        await load(reset: true)
    }

    func loadNextPageIfNeeded(currentSupplier: BusinessProcurementSupplierResponse) async {
        guard currentSupplier.id == suppliers.last?.id else { return }
        guard hasLoaded, hasMore, nextCursor != nil else { return }
        await load(reset: false)
    }

    func replace(_ supplier: BusinessProcurementSupplierResponse) {
        if let index = suppliers.firstIndex(where: { $0.id == supplier.id }) {
            suppliers[index] = supplier
        } else {
            suppliers.insert(supplier, at: 0)
        }
    }

    private func load(reset: Bool) async {
        guard validateAccess() else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            let response = try await repository.listSuppliers(
                organizationId: organizationId,
                filters: BusinessProcurementSupplierFilters(
                    query: query.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    status: statusFilter.apiValue,
                    category: category.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    updatedFrom: nil,
                    updatedTo: nil,
                    limit: 50,
                    cursor: reset ? nil : nextCursor
                )
            )

            if reset {
                suppliers = response.suppliers
            } else {
                appendUnique(response.suppliers)
            }
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            hasLoaded = true
            infoMessage = suppliers.isEmpty ? "No encontramos proveedores con estos filtros." : nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateAccess() -> Bool {
        guard accessPolicy.isModuleActive else {
            errorMessage = "El módulo Compras no está activo para esta organización."
            infoMessage = nil
            return false
        }
        guard canView else {
            errorMessage = "No tienes permiso para consultar proveedores."
            infoMessage = nil
            return false
        }
        return true
    }

    private func appendUnique(_ page: [BusinessProcurementSupplierResponse]) {
        var knownIds = Set(suppliers.map(\.id))
        for supplier in page where knownIds.insert(supplier.id).inserted {
            suppliers.append(supplier)
        }
    }
}

@MainActor
@Observable
final class BusinessSupplierDetailViewModel {
    private(set) var supplier: BusinessProcurementSupplierResponse
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    let organizationId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        supplier: BusinessProcurementSupplierResponse,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.supplier = supplier
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.suppliersView)
    }

    var canEdit: Bool {
        hasLoaded &&
        accessPolicy.allows(BusinessProcurementPermission.suppliersUpdate) &&
        accessPolicy.allows(BusinessProcurementPermission.suppliersSensitiveView) &&
        supplier.contacts != nil
    }

    func replace(_ supplier: BusinessProcurementSupplierResponse) {
        guard supplier.id == self.supplier.id else { return }
        self.supplier = supplier
        hasLoaded = true
        errorMessage = nil
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        guard accessPolicy.isModuleActive else {
            errorMessage = "El módulo Compras no está activo para esta organización."
            return
        }
        guard canView else {
            errorMessage = "No tienes permiso para consultar este proveedor."
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await repository.getSupplier(
                organizationId: organizationId,
                supplierId: supplier.id
            )
            supplier = response.data
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension BusinessProcurementSupplierResponse {
    var businessDisplayName: String {
        tradeName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? legalName
    }

    var businessLegalNameDetail: String? {
        let normalizedTradeName = tradeName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard normalizedTradeName != nil, normalizedTradeName != legalName else { return nil }
        return legalName
    }

    var businessIdentificationText: String? {
        let type = identificationType?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let number = identificationNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        switch (type, number) {
        case let (.some(type), .some(number)): return "\(type) · \(number)"
        case let (.none, .some(number)): return number
        default: return nil
        }
    }

    var businessPrimaryContact: BusinessProcurementSupplierContactResponse? {
        contacts?.first(where: \.isPrimary) ?? contacts?.first
    }
}

extension BusinessProcurementPaymentTermsResponse {
    var businessDisplayText: String {
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            return label
        }
        switch mode.uppercased() {
        case "IMMEDIATE":
            return "Pago inmediato"
        case "NET_DAYS":
            if let netDays { return "Crédito a \(netDays) días" }
            return "Crédito por días"
        default:
            return mode.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
