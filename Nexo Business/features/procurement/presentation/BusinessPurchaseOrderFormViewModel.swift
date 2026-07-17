//
//  BusinessPurchaseOrderFormViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

enum BusinessPurchaseOrderPriceTaxMode: String, CaseIterable, Identifiable, Sendable {
    case taxExclusive = "TAX_EXCLUSIVE"
    case taxInclusive = "TAX_INCLUSIVE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .taxExclusive: return "Impuestos adicionales"
        case .taxInclusive: return "Impuestos incluidos"
        }
    }
}

struct BusinessPurchaseOrderSupplierOption: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let currency: String

    init(supplier: BusinessProcurementSupplierResponse) {
        id = supplier.id
        name = supplier.tradeName?.trimmingCharacters(in: .whitespacesAndNewlines).businessPOFormNilIfEmpty
            ?? supplier.legalName
        currency = supplier.defaultCurrency
    }

    init(purchaseOrder: BusinessProcurementPurchaseOrderResponse) {
        id = purchaseOrder.supplierId
        name = purchaseOrder.businessSupplierName
        currency = purchaseOrder.supplierSnapshot.defaultCurrency
    }
}

struct BusinessPurchaseOrderLineDraft: Equatable, Identifiable, Sendable {
    let id: UUID
    let serverId: String?
    let catalogItemId: String?
    let taxProfileId: String?
    let targetWarehouseId: String?
    var kind: String
    var displayName: String
    var sku: String?
    var description: String
    var orderedQuantity: String
    var unitCode: String
    var allowsDecimal: Bool
    var unitCost: String
    var discountAmount: String
    var priceTaxMode: BusinessPurchaseOrderPriceTaxMode
    var notes: String

    init(
        id: UUID = UUID(),
        serverId: String? = nil,
        catalogItemId: String?,
        taxProfileId: String?,
        targetWarehouseId: String? = nil,
        kind: String,
        displayName: String,
        sku: String? = nil,
        description: String,
        orderedQuantity: String = "1",
        unitCode: String,
        allowsDecimal: Bool,
        unitCost: String,
        discountAmount: String = "0",
        priceTaxMode: BusinessPurchaseOrderPriceTaxMode = .taxExclusive,
        notes: String = ""
    ) {
        self.id = id
        self.serverId = serverId
        self.catalogItemId = catalogItemId
        self.taxProfileId = taxProfileId
        self.targetWarehouseId = targetWarehouseId
        self.kind = kind
        self.displayName = displayName
        self.sku = sku
        self.description = description
        self.orderedQuantity = orderedQuantity
        self.unitCode = unitCode
        self.allowsDecimal = allowsDecimal
        self.unitCost = unitCost
        self.discountAmount = discountAmount
        self.priceTaxMode = priceTaxMode
        self.notes = notes
    }

    init(response: BusinessProcurementPurchaseOrderLineResponse) {
        self.init(
            serverId: response.id,
            catalogItemId: response.catalogItemId,
            taxProfileId: response.taxProfileId,
            targetWarehouseId: response.targetWarehouseId,
            kind: response.kind,
            displayName: response.descriptionSnapshot,
            sku: response.catalogItemSnapshot?.sku,
            description: response.descriptionSnapshot,
            orderedQuantity: response.orderedQuantity.value,
            unitCode: response.orderedQuantity.unitCode,
            allowsDecimal: response.orderedQuantity.allowsDecimal,
            unitCost: response.unitCost?.amount ?? "",
            discountAmount: response.discountAmount?.amount ?? "",
            priceTaxMode: BusinessPurchaseOrderPriceTaxMode(rawValue: response.priceTaxMode) ?? .taxExclusive,
            notes: response.notes ?? ""
        )
    }
}

@MainActor
@Observable
final class BusinessPurchaseOrderFormViewModel {
    var selectedSupplierId: String {
        didSet {
            guard let option = supplierOptions.first(where: { $0.id == selectedSupplierId }) else { return }
            currency = option.currency
        }
    }
    private(set) var currency: String
    var expectedDate: String
    var notes: String
    var lines: [BusinessPurchaseOrderLineDraft]
    var supplierOptions: [BusinessPurchaseOrderSupplierOption]
    var catalogQuery = ""
    private(set) var catalogResults: [BusinessCatalogItem] = []
    private(set) var isLoadingReferenceData = false
    private(set) var isSearchingCatalog = false
    private(set) var hasLoadedReferenceData = false
    private(set) var isSaving = false
    private(set) var savedPurchaseOrder: BusinessProcurementPurchaseOrderResponse?
    var referenceErrorMessage: String?
    var catalogInfoMessage: String?
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let activityId: String
    let catalogRevision: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository
    let catalogRepository: CatalogRepository

    private let purchaseOrderId: String?
    private let purchaseOrderStatus: BusinessPurchaseOrderStatus?
    private let expectedVersion: Int64?
    private let attachmentIds: [String]
    private let hasCompleteCostSnapshot: Bool
    private let createIdempotencyKey: IdempotencyKey

    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        purchaseOrder: BusinessProcurementPurchaseOrderResponse? = nil,
        repository: BusinessProcurementRepository,
        catalogRepository: CatalogRepository,
        createIdempotencyKey: IdempotencyKey? = nil
    ) {
        self.organizationId = organizationId
        self.branchId = purchaseOrder?.branchId ?? branchId
        self.activityId = activityId
        self.catalogRevision = catalogRevision
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
        self.catalogRepository = catalogRepository
        self.purchaseOrderId = purchaseOrder?.id
        self.purchaseOrderStatus = purchaseOrder?.status
        self.expectedVersion = purchaseOrder?.version
        self.attachmentIds = purchaseOrder?.attachmentIds ?? []
        self.hasCompleteCostSnapshot = purchaseOrder == nil || purchaseOrder?.lines.allSatisfy {
            $0.unitCost != nil && $0.discountAmount != nil
        } == true
        self.createIdempotencyKey = createIdempotencyKey ?? .generate(prefix: "purchase-order-create")

        selectedSupplierId = purchaseOrder?.supplierId ?? ""
        currency = purchaseOrder?.currency ?? "USD"
        expectedDate = purchaseOrder?.expectedDate ?? ""
        notes = purchaseOrder?.notes ?? ""
        lines = purchaseOrder?.lines.map(BusinessPurchaseOrderLineDraft.init(response:)) ?? []
        supplierOptions = purchaseOrder.map { [BusinessPurchaseOrderSupplierOption(purchaseOrder: $0)] } ?? []
    }

    var isEditing: Bool {
        purchaseOrderId != nil
    }

    var navigationTitle: String {
        isEditing ? "Editar orden" : "Nueva orden"
    }

    var saveButtonTitle: String {
        isEditing ? "Guardar cambios" : "Crear orden"
    }

    var canSave: Bool {
        !isSaving && accessValidationMessage == nil && inputValidationMessage == nil
    }

    var accessValidationMessage: String? {
        guard accessPolicy.isModuleActive else {
            return "El módulo Compras no está activo para esta organización."
        }
        if isEditing {
            guard let purchaseOrderStatus,
                  accessPolicy.canEditPurchaseOrder(status: purchaseOrderStatus) else {
                return "Solo puedes editar órdenes en borrador cuando tienes el permiso correspondiente."
            }
            guard accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersCostView) else {
                return "La edición requiere permiso para consultar los costos de la orden."
            }
            guard hasCompleteCostSnapshot else {
                return "Actualiza el detalle con acceso a costos antes de editar para no sobrescribir valores protegidos."
            }
            guard let expectedVersion, expectedVersion > 0 else {
                return "No se encontró una versión válida de la orden."
            }
        } else {
            guard accessPolicy.canCreatePurchaseOrder else {
                return "No tienes permiso para crear órdenes de compra."
            }
            guard accessPolicy.allows(BusinessProcurementPermission.purchaseOrdersCostView) else {
                return "La creación requiere permiso para consultar y registrar costos de compra."
            }
            guard !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "Selecciona una sucursal operativa antes de crear la orden."
            }
        }
        return nil
    }

    var inputValidationMessage: String? {
        guard !selectedSupplierId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Selecciona un proveedor activo."
        }
        guard !currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No se encontró una moneda válida para el proveedor."
        }
        guard !lines.isEmpty else {
            return "Agrega al menos un producto o servicio a la orden."
        }
        if let expectedDate = optional(expectedDate), !Self.isValidDateOnly(expectedDate) {
            return "La fecha esperada debe usar el formato AAAA-MM-DD."
        }

        for (index, line) in lines.enumerated() {
            let number = index + 1
            if normalized(line.description).isEmpty {
                return "La línea \(number) necesita una descripción."
            }
            if normalized(line.unitCode).isEmpty {
                return "La línea \(number) no tiene una unidad válida."
            }
            guard let quantity = decimal(line.orderedQuantity), quantity > .zero else {
                return "La cantidad de la línea \(number) debe ser mayor que cero."
            }
            if !line.allowsDecimal, !Self.isWhole(quantity) {
                return "La cantidad de la línea \(number) debe ser un número entero."
            }
            guard let unitCost = decimal(line.unitCost), unitCost >= .zero else {
                return "El costo unitario de la línea \(number) debe ser cero o mayor."
            }
            guard let discount = decimal(line.discountAmount), discount >= .zero else {
                return "El descuento de la línea \(number) debe ser cero o mayor."
            }
            if normalized(line.kind) == "STOCK_ITEM",
               line.catalogItemId?.trimmingCharacters(in: .whitespacesAndNewlines).businessPOFormNilIfEmpty == nil {
                return "La línea \(number) necesita un producto válido del catálogo."
            }
            if line.catalogItemId?.trimmingCharacters(in: .whitespacesAndNewlines).businessPOFormNilIfEmpty == nil,
               line.taxProfileId?.trimmingCharacters(in: .whitespacesAndNewlines).businessPOFormNilIfEmpty == nil {
                return "La línea \(number) no tiene una configuración tributaria válida."
            }
        }
        return nil
    }

    func loadReferenceDataIfNeeded() async {
        guard !hasLoadedReferenceData, !isLoadingReferenceData else { return }
        hasLoadedReferenceData = true

        guard accessPolicy.allows(BusinessProcurementPermission.suppliersView) else {
            if !isEditing {
                referenceErrorMessage = "Necesitas permiso para consultar proveedores antes de crear una orden."
            }
            return
        }

        isLoadingReferenceData = true
        referenceErrorMessage = nil
        defer { isLoadingReferenceData = false }

        do {
            let response = try await repository.listSuppliers(
                organizationId: organizationId,
                filters: BusinessProcurementSupplierFilters(
                    query: nil,
                    status: .active,
                    category: nil,
                    updatedFrom: nil,
                    updatedTo: nil,
                    limit: 50,
                    cursor: nil
                )
            )
            mergeSupplierOptions(response.suppliers.map(BusinessPurchaseOrderSupplierOption.init(supplier:)))
            if supplierOptions.isEmpty {
                referenceErrorMessage = "No hay proveedores activos disponibles para esta orden."
            }
        } catch let error as APIError {
            referenceErrorMessage = error.userMessage
        } catch {
            referenceErrorMessage = error.localizedDescription
        }
    }

    func retryReferenceData() async {
        hasLoadedReferenceData = false
        await loadReferenceDataIfNeeded()
    }

    func searchCatalog() async {
        let query = normalized(catalogQuery)
        guard !query.isEmpty else {
            catalogResults = []
            catalogInfoMessage = "Escribe un nombre, SKU o código para buscar."
            return
        }
        guard !isSearchingCatalog else { return }

        isSearchingCatalog = true
        referenceErrorMessage = nil
        catalogInfoMessage = nil
        defer { isSearchingCatalog = false }

        do {
            let response = try await catalogRepository.search(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: catalogRevision,
                query: query,
                limit: 20
            )
            catalogResults = response.items
            catalogInfoMessage = response.items.isEmpty
                ? "No encontramos productos o servicios activos con esa búsqueda."
                : nil
        } catch let error as APIError {
            referenceErrorMessage = error.userMessage
        } catch {
            referenceErrorMessage = error.localizedDescription
        }
    }

    func addCatalogItem(_ item: BusinessCatalogItem) {
        guard let unitCode = item.unit?.code?.trimmingCharacters(in: .whitespacesAndNewlines).businessPOFormNilIfEmpty else {
            referenceErrorMessage = "Este elemento del catálogo no tiene una unidad válida para comprar."
            return
        }

        let description = item.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).businessPOFormNilIfEmpty
            ?? item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemType = item.type?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let kind: String
        if item.tracksInventory == true {
            kind = "STOCK_ITEM"
        } else if itemType.map({ ["SERVICE", "LABOR"].contains($0) }) == true {
            kind = "SERVICE"
        } else {
            kind = "OTHER"
        }

        lines.append(
            BusinessPurchaseOrderLineDraft(
                catalogItemId: item.id,
                taxProfileId: item.taxProfileId,
                kind: kind,
                displayName: description,
                sku: item.sku,
                description: description,
                unitCode: unitCode,
                allowsDecimal: item.unit?.allowsDecimal ?? item.allowsDecimalQuantity ?? false,
                unitCost: item.cost?.amount ?? "0"
            )
        )
        catalogResults = []
        catalogQuery = ""
        catalogInfoMessage = "Elemento agregado. Revisa cantidad, costo e impuestos antes de guardar."
    }

    func removeLines(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            lines.remove(at: index)
        }
    }

    func save() async -> BusinessProcurementPurchaseOrderResponse? {
        guard !isSaving else { return nil }
        if let accessValidationMessage {
            errorMessage = accessValidationMessage
            return nil
        }
        if let inputValidationMessage {
            errorMessage = inputValidationMessage
            return nil
        }

        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        let request = makeRequest()
        do {
            let response: BusinessProcurementPurchaseOrderEnvelopeResponse
            if let purchaseOrderId {
                response = try await repository.updatePurchaseOrder(
                    organizationId: organizationId,
                    orderId: purchaseOrderId,
                    request: request
                )
            } else {
                response = try await repository.createPurchaseOrder(
                    organizationId: organizationId,
                    idempotencyKey: createIdempotencyKey,
                    request: request
                )
            }

            savedPurchaseOrder = response.data
            if response.meta.idempotencyReplayed == true {
                infoMessage = "Orden recuperada de un intento anterior."
            } else {
                infoMessage = isEditing
                    ? "Orden actualizada correctamente."
                    : "Orden creada correctamente."
            }
            return response.data
        } catch let error as APIError {
            errorMessage = purchaseOrderErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func makeRequest() -> BusinessProcurementPurchaseOrderWriteRequest {
        BusinessProcurementPurchaseOrderWriteRequest(
            branchId: normalized(branchId),
            supplierId: normalized(selectedSupplierId),
            currency: normalized(currency).uppercased(),
            lines: lines.map { line in
                BusinessProcurementPurchaseOrderLineRequest(
                    id: line.serverId,
                    kind: normalized(line.kind).uppercased(),
                    catalogItemId: line.catalogItemId,
                    description: normalized(line.description),
                    orderedQuantity: normalizedDecimal(line.orderedQuantity),
                    unitCode: normalized(line.unitCode),
                    allowsDecimal: line.allowsDecimal,
                    unitCost: normalizedDecimal(line.unitCost),
                    discountAmount: normalizedDecimal(line.discountAmount),
                    priceTaxMode: line.priceTaxMode.rawValue,
                    taxProfileId: line.taxProfileId,
                    targetWarehouseId: line.targetWarehouseId,
                    notes: optional(line.notes)
                )
            },
            expectedDate: optional(expectedDate),
            notes: optional(notes),
            attachmentIds: attachmentIds,
            expectedVersion: expectedVersion
        )
    }

    private func mergeSupplierOptions(_ incoming: [BusinessPurchaseOrderSupplierOption]) {
        var byId = Dictionary(uniqueKeysWithValues: supplierOptions.map { ($0.id, $0) })
        for option in incoming {
            byId[option.id] = option
        }
        supplierOptions = byId.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        if selectedSupplierId.isEmpty, let first = supplierOptions.first {
            selectedSupplierId = first.id
        }
    }

    private func purchaseOrderErrorMessage(_ error: APIError) -> String {
        let code = error.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "La orden cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        case "procurement_state_conflict":
            return "El estado de la orden cambió. Actualiza el detalle antes de continuar."
        case "procurement_supplier_unavailable":
            return "El proveedor ya no está activo para esta orden."
        case "procurement_catalog_item_unavailable":
            return "Uno de los elementos del catálogo ya no está disponible para comprar."
        case "procurement_currency_mismatch":
            return "La moneda de la orden no coincide con la moneda del proveedor."
        default:
            return error.userMessage
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedDecimal(_ value: String) -> String {
        normalized(value).replacingOccurrences(of: ",", with: ".")
    }

    private func decimal(_ value: String) -> Decimal? {
        Decimal(
            string: normalizedDecimal(value),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func optional(_ value: String) -> String? {
        normalized(value).businessPOFormNilIfEmpty
    }

    private static func isWhole(_ value: Decimal) -> Bool {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return rounded == value
    }

    private static func isValidDateOnly(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }
}

private extension String {
    var businessPOFormNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
