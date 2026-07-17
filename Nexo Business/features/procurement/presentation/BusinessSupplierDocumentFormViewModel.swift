//
//  BusinessSupplierDocumentFormViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

enum BusinessSupplierDocumentType: String, CaseIterable, Identifiable, Sendable {
    case invoice = "INVOICE"
    case expense = "EXPENSE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .invoice: return "Factura de proveedor"
        case .expense: return "Gasto"
        }
    }
}

enum BusinessSupplierDocumentPriceTaxMode: String, CaseIterable, Identifiable, Sendable {
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

struct BusinessSupplierDocumentSupplierOption: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let currency: String

    init(supplier: BusinessProcurementSupplierResponse) {
        id = supplier.id
        name = supplier.tradeName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentFormNilIfEmpty
            ?? supplier.legalName
        currency = supplier.defaultCurrency
    }

    init(id: String, name: String?, currency: String) {
        self.id = id
        self.name = name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentFormNilIfEmpty
            ?? "Proveedor actual"
        self.currency = currency
    }
}

struct BusinessSupplierDocumentLineDraft: Equatable, Identifiable, Sendable {
    let id: UUID
    let serverId: String?
    var kind: String
    var catalogItemId: String
    var purchaseOrderLineId: String
    var purchaseReceiptLineId: String
    var description: String
    var quantity: String
    var unitCode: String
    var allowsDecimal: Bool
    var unitCost: String
    var discountAmount: String
    var priceTaxMode: BusinessSupplierDocumentPriceTaxMode
    var taxProfileId: String
    var expenseCategoryCode: String
    var notes: String

    init(
        id: UUID = UUID(),
        serverId: String? = nil,
        kind: String = "EXPENSE",
        catalogItemId: String = "",
        purchaseOrderLineId: String = "",
        purchaseReceiptLineId: String = "",
        description: String = "",
        quantity: String = "1",
        unitCode: String = "unit",
        allowsDecimal: Bool = false,
        unitCost: String = "0",
        discountAmount: String = "0",
        priceTaxMode: BusinessSupplierDocumentPriceTaxMode = .taxExclusive,
        taxProfileId: String = "",
        expenseCategoryCode: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.serverId = serverId
        self.kind = kind
        self.catalogItemId = catalogItemId
        self.purchaseOrderLineId = purchaseOrderLineId
        self.purchaseReceiptLineId = purchaseReceiptLineId
        self.description = description
        self.quantity = quantity
        self.unitCode = unitCode
        self.allowsDecimal = allowsDecimal
        self.unitCost = unitCost
        self.discountAmount = discountAmount
        self.priceTaxMode = priceTaxMode
        self.taxProfileId = taxProfileId
        self.expenseCategoryCode = expenseCategoryCode
        self.notes = notes
    }

    init(response: BusinessProcurementSupplierDocumentLineResponse) {
        self.init(
            serverId: response.id,
            kind: response.kind,
            catalogItemId: response.catalogItemId ?? "",
            purchaseOrderLineId: response.purchaseOrderLineId ?? "",
            purchaseReceiptLineId: response.purchaseReceiptLineId ?? "",
            description: response.descriptionSnapshot,
            quantity: response.quantity.value,
            unitCode: response.quantity.unitCode,
            allowsDecimal: response.quantity.allowsDecimal,
            unitCost: response.unitCost.amount,
            discountAmount: response.discountAmount.amount,
            priceTaxMode: BusinessSupplierDocumentPriceTaxMode(rawValue: response.priceTaxMode)
                ?? .taxExclusive,
            taxProfileId: response.taxProfileId,
            expenseCategoryCode: response.expenseCategoryCode ?? "",
            notes: response.notes ?? ""
        )
    }
}

@MainActor
@Observable
final class BusinessSupplierDocumentFormViewModel {
    var selectedSupplierId: String {
        didSet {
            guard !isEditing,
                  let option = supplierOptions.first(where: { $0.id == selectedSupplierId }) else {
                return
            }
            currency = option.currency
        }
    }
    var documentType: BusinessSupplierDocumentType
    var documentNumber: String
    var accessKey: String
    var authorizationNumber: String
    var documentDate: String
    var dueDate: String
    var currency: String
    var purchaseOrderIdsText: String
    var purchaseReceiptIdsText: String
    var attachmentIdsText: String
    var sourceTotal: String
    var sourceTaxTotal: String
    var sourcePaymentAmount: String
    var sourcePaymentMethod: String
    var sourcePaymentDate: String
    var sourcePaymentReference: String
    var notes: String
    var lines: [BusinessSupplierDocumentLineDraft]
    private(set) var supplierOptions: [BusinessSupplierDocumentSupplierOption]
    private(set) var isLoadingReferenceData = false
    private(set) var hasLoadedReferenceData = false
    private(set) var isSaving = false
    private(set) var savedSupplierDocument: BusinessProcurementSupplierDocumentResponse?
    var referenceErrorMessage: String?
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    private let supplierDocumentId: String?
    private let supplierDocumentStatus: BusinessSupplierDocumentStatus?
    private let expectedVersion: Int64?
    private let createIdempotencyKey: IdempotencyKey

    init(
        organizationId: String,
        branchId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        initialSupplierId: String? = nil,
        supplierDocument: BusinessProcurementSupplierDocumentResponse? = nil,
        supplierName: String? = nil,
        repository: BusinessProcurementRepository,
        createIdempotencyKey: IdempotencyKey? = nil
    ) {
        self.organizationId = organizationId
        self.branchId = supplierDocument?.branchId ?? branchId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
        self.supplierDocumentId = supplierDocument?.id
        self.supplierDocumentStatus = supplierDocument?.status
        self.expectedVersion = supplierDocument?.version
        self.createIdempotencyKey = createIdempotencyKey
            ?? .generate(prefix: "supplier-document-create")

        selectedSupplierId = supplierDocument?.supplierId
            ?? initialSupplierId?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        documentType = BusinessSupplierDocumentType(
            rawValue: supplierDocument?.documentType.uppercased() ?? ""
        ) ?? .invoice
        documentNumber = supplierDocument?.documentNumber ?? ""
        accessKey = supplierDocument?.accessKey ?? ""
        authorizationNumber = supplierDocument?.authorizationNumber ?? ""
        documentDate = supplierDocument?.documentDate ?? ""
        dueDate = supplierDocument?.dueDate ?? ""
        currency = supplierDocument?.currency ?? "USD"
        purchaseOrderIdsText = Self.joinedIdentifiers(supplierDocument?.purchaseOrderIds ?? [])
        purchaseReceiptIdsText = Self.joinedIdentifiers(supplierDocument?.purchaseReceiptIds ?? [])
        attachmentIdsText = Self.joinedIdentifiers(supplierDocument?.attachmentIds ?? [])
        sourceTotal = supplierDocument?.sourceTotals?.total.amount ?? ""
        sourceTaxTotal = supplierDocument?.sourceTotals?.taxTotal.amount ?? ""
        sourcePaymentAmount = supplierDocument?.sourcePayment?.amount.amount ?? ""
        sourcePaymentMethod = supplierDocument?.sourcePayment?.method ?? ""
        sourcePaymentDate = supplierDocument?.sourcePayment?.paymentDate ?? ""
        sourcePaymentReference = supplierDocument?.sourcePayment?.reference ?? ""
        notes = supplierDocument?.notes ?? ""
        lines = supplierDocument?.lines.map(BusinessSupplierDocumentLineDraft.init(response:)) ?? []
        supplierOptions = supplierDocument.map {
            [
                BusinessSupplierDocumentSupplierOption(
                    id: $0.supplierId,
                    name: supplierName,
                    currency: $0.currency
                ),
            ]
        } ?? []
    }

    var isEditing: Bool {
        supplierDocumentId != nil
    }

    var navigationTitle: String {
        isEditing ? "Editar documento" : "Nuevo documento"
    }

    var saveButtonTitle: String {
        isEditing ? "Guardar cambios" : "Crear documento"
    }

    var canSave: Bool {
        !isSaving && accessValidationMessage == nil && inputValidationMessage == nil
    }

    var hasSourceTotals: Bool {
        optional(sourceTotal) != nil || optional(sourceTaxTotal) != nil
    }

    var hasSourcePayment: Bool {
        [
            sourcePaymentAmount,
            sourcePaymentMethod,
            sourcePaymentDate,
            sourcePaymentReference,
        ].contains { optional($0) != nil }
    }

    var accessValidationMessage: String? {
        guard accessPolicy.isModuleActive else {
            return "El módulo Compras no está activo para esta organización."
        }
        if isEditing {
            guard let supplierDocumentStatus,
                  accessPolicy.canEditSupplierDocument(status: supplierDocumentStatus) else {
                return "Solo puedes editar documentos en borrador cuando tienes el permiso correspondiente."
            }
            guard let expectedVersion, expectedVersion > 0 else {
                return "No se encontró una versión válida del documento."
            }
        } else {
            guard accessPolicy.allows(BusinessProcurementPermission.supplierDocumentsCreate) else {
                return "No tienes permiso para crear documentos de proveedor."
            }
            guard !normalized(branchId).isEmpty else {
                return "Selecciona una sucursal operativa antes de crear el documento."
            }
        }
        return nil
    }

    var inputValidationMessage: String? {
        guard !normalized(selectedSupplierId).isEmpty else {
            return "Selecciona un proveedor activo."
        }
        guard !normalized(documentNumber).isEmpty else {
            return "Ingresa el número del documento."
        }
        guard Self.isValidDateOnly(normalized(documentDate)) else {
            return "La fecha del documento debe usar el formato AAAA-MM-DD."
        }
        if let dueDate = optional(dueDate) {
            guard Self.isValidDateOnly(dueDate) else {
                return "La fecha de vencimiento debe usar el formato AAAA-MM-DD."
            }
            guard dueDate >= normalized(documentDate) else {
                return "La fecha de vencimiento no puede ser anterior a la fecha del documento."
            }
        }
        let normalizedCurrency = normalized(currency).uppercased()
        guard normalizedCurrency.count == 3,
              normalizedCurrency.unicodeScalars.allSatisfy({
                  CharacterSet.letters.contains($0)
              }) else {
            return "La moneda debe usar un código de tres letras, por ejemplo USD."
        }
        guard !lines.isEmpty else {
            return "Agrega al menos una línea al documento."
        }

        for (index, line) in lines.enumerated() {
            let number = index + 1
            if normalized(line.description).isEmpty {
                return "La línea \(number) necesita una descripción."
            }
            if normalized(line.unitCode).isEmpty {
                return "La línea \(number) no tiene una unidad válida."
            }
            guard let quantity = decimal(line.quantity), quantity > .zero else {
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
            if normalized(line.kind).uppercased() == "STOCK_ITEM",
               optional(line.catalogItemId) == nil {
                return "La línea \(number) de inventario necesita un producto vinculado."
            }
        }

        if hasSourceTotals {
            guard let total = decimal(sourceTotal), total >= .zero else {
                return "El total informado por el origen debe ser cero o mayor."
            }
            guard let tax = decimal(sourceTaxTotal), tax >= .zero else {
                return "El impuesto informado por el origen debe ser cero o mayor."
            }
        }

        if hasSourcePayment {
            guard let amount = decimal(sourcePaymentAmount), amount > .zero else {
                return "El pago inmediato informado debe ser mayor que cero."
            }
            guard optional(sourcePaymentMethod) != nil else {
                return "Selecciona o escribe el método del pago inmediato informado."
            }
            guard let paymentDate = optional(sourcePaymentDate),
                  Self.isValidDateOnly(paymentDate) else {
                return "La fecha del pago inmediato debe usar el formato AAAA-MM-DD."
            }
        }
        return nil
    }

    func loadReferenceDataIfNeeded() async {
        guard !hasLoadedReferenceData, !isLoadingReferenceData else { return }
        hasLoadedReferenceData = true

        guard accessPolicy.allows(BusinessProcurementPermission.suppliersView) else {
            if !isEditing {
                referenceErrorMessage = "Necesitas permiso para consultar proveedores antes de crear el documento."
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
            mergeSupplierOptions(
                response.suppliers.map(BusinessSupplierDocumentSupplierOption.init(supplier:))
            )
            if supplierOptions.isEmpty {
                referenceErrorMessage = "No hay proveedores activos disponibles para este documento."
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

    func addLine(kind: String = "EXPENSE") {
        lines.append(BusinessSupplierDocumentLineDraft(kind: kind))
    }

    func removeLines(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            lines.remove(at: index)
        }
    }

    func save() async -> BusinessProcurementSupplierDocumentResponse? {
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

        do {
            let response: BusinessProcurementSupplierDocumentEnvelopeResponse
            if let supplierDocumentId {
                response = try await repository.updateSupplierDocument(
                    organizationId: organizationId,
                    documentId: supplierDocumentId,
                    request: makeRequest()
                )
            } else {
                response = try await repository.createSupplierDocument(
                    organizationId: organizationId,
                    idempotencyKey: createIdempotencyKey,
                    request: makeRequest()
                )
            }

            savedSupplierDocument = response.data
            if response.meta.idempotencyReplayed == true {
                infoMessage = "Documento recuperado de un intento anterior."
            } else {
                infoMessage = isEditing
                    ? "Documento actualizado correctamente."
                    : "Documento creado correctamente."
            }
            return response.data
        } catch let error as APIError {
            errorMessage = supplierDocumentErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func makeRequest() -> BusinessProcurementSupplierDocumentWriteRequest {
        BusinessProcurementSupplierDocumentWriteRequest(
            branchId: optional(branchId),
            supplierId: normalized(selectedSupplierId),
            documentType: documentType.rawValue,
            documentNumber: normalized(documentNumber),
            accessKey: optional(accessKey),
            authorizationNumber: optional(authorizationNumber),
            documentDate: normalized(documentDate),
            dueDate: optional(dueDate),
            currency: normalized(currency).uppercased(),
            purchaseOrderIds: Self.identifiers(from: purchaseOrderIdsText),
            purchaseReceiptIds: Self.identifiers(from: purchaseReceiptIdsText),
            lines: lines.map { line in
                BusinessProcurementSupplierDocumentLineRequest(
                    id: line.serverId,
                    kind: normalized(line.kind).uppercased(),
                    catalogItemId: optional(line.catalogItemId),
                    purchaseOrderLineId: optional(line.purchaseOrderLineId),
                    purchaseReceiptLineId: optional(line.purchaseReceiptLineId),
                    description: optional(line.description),
                    quantity: normalizedDecimal(line.quantity),
                    unitCode: normalized(line.unitCode),
                    allowsDecimal: line.allowsDecimal,
                    unitCost: normalizedDecimal(line.unitCost),
                    discountAmount: normalizedDecimal(line.discountAmount),
                    priceTaxMode: line.priceTaxMode.rawValue,
                    taxProfileId: optional(line.taxProfileId),
                    expenseCategoryCode: optional(line.expenseCategoryCode),
                    notes: optional(line.notes)
                )
            },
            sourceTotals: hasSourceTotals
                ? BusinessProcurementSupplierSourceTotalsRequest(
                    total: normalizedDecimal(sourceTotal),
                    taxTotal: normalizedDecimal(sourceTaxTotal)
                )
                : nil,
            sourcePayment: hasSourcePayment
                ? BusinessProcurementSourcePaymentEvidenceRequest(
                    amount: normalizedDecimal(sourcePaymentAmount),
                    method: normalized(sourcePaymentMethod).uppercased(),
                    paymentDate: normalized(sourcePaymentDate),
                    reference: optional(sourcePaymentReference)
                )
                : nil,
            attachmentIds: Self.identifiers(from: attachmentIdsText),
            notes: optional(notes),
            expectedVersion: expectedVersion
        )
    }

    private func mergeSupplierOptions(
        _ incoming: [BusinessSupplierDocumentSupplierOption]
    ) {
        var byId = Dictionary(uniqueKeysWithValues: supplierOptions.map { ($0.id, $0) })
        for option in incoming {
            byId[option.id] = option
        }
        supplierOptions = byId.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        if selectedSupplierId.isEmpty, let first = supplierOptions.first {
            selectedSupplierId = first.id
        } else if !isEditing,
                  let selected = supplierOptions.first(where: { $0.id == selectedSupplierId }) {
            currency = selected.currency
        }
    }

    private func supplierDocumentErrorMessage(_ error: APIError) -> String {
        let code = error.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "El documento cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        case "procurement_state_conflict":
            return "El estado del documento cambió. Actualiza el detalle antes de continuar."
        case "procurement_supplier_unavailable":
            return "El proveedor ya no está activo para este documento."
        case "procurement_supplier_document_duplicate", "procurement_duplicate_supplier_document":
            return "Ya existe un documento de este proveedor con el mismo número."
        case "procurement_currency_mismatch":
            return "La moneda del documento no coincide con el contexto aceptado por el servidor."
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
        normalized(value).supplierDocumentFormNilIfEmpty
    }

    private static func identifiers(from rawValue: String) -> [String] {
        var seen = Set<String>()
        return rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func joinedIdentifiers(_ identifiers: [String]) -> String {
        identifiers.joined(separator: ", ")
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
    var supplierDocumentFormNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
