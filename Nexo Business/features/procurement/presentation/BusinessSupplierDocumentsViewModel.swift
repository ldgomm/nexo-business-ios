//
//  BusinessSupplierDocumentsViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

struct BusinessSupplierDocumentPresentation: Equatable, Identifiable, Sendable {
    let document: BusinessProcurementSupplierDocumentResponse
    let supplierName: String?

    var id: String { document.id }

    var businessSupplierName: String {
        supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
            ?? "Proveedor no disponible"
    }
}

@MainActor
@Observable
final class BusinessSupplierDocumentsViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case draft
        case confirming
        case confirmed
        case cancelled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .draft: return "Borradores"
            case .confirming: return "Confirmando"
            case .confirmed: return "Confirmados"
            case .cancelled: return "Cancelados"
            }
        }

        var apiValues: [BusinessSupplierDocumentStatus] {
            switch self {
            case .all: return []
            case .draft: return [.draft]
            case .confirming: return [.confirming]
            case .confirmed: return [.confirmed]
            case .cancelled: return [.cancelled]
            }
        }
    }

    enum DocumentTypeFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case invoice
        case expense

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .invoice: return "Facturas"
            case .expense: return "Gastos"
            }
        }

        var apiValues: [String] {
            switch self {
            case .all: return []
            case .invoice: return ["INVOICE"]
            case .expense: return ["EXPENSE"]
            }
        }
    }

    private(set) var supplierDocuments: [BusinessSupplierDocumentPresentation] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var nextCursor: String?
    private(set) var hasLoaded = false
    var query = ""
    var documentDateFrom = ""
    var documentDateTo = ""
    var dueDateFrom = ""
    var dueDateTo = ""
    var statusFilter: StatusFilter = .all
    var documentTypeFilter: DocumentTypeFilter = .all
    var errorMessage: String?
    var infoMessage: String?
    var referenceWarning: String?

    let organizationId: String
    let branchId: String?
    let supplierId: String?
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    init(
        organizationId: String,
        branchId: String? = nil,
        supplierId: String? = nil,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        self.supplierId = supplierId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.supplierDocumentsView)
    }

    var canCreate: Bool {
        accessPolicy.allows(BusinessProcurementPermission.supplierDocumentsCreate) &&
        branchId != nil
    }

    var hasActiveFilters: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !documentDateFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !documentDateTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !dueDateFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !dueDateTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        statusFilter != .all ||
        documentTypeFilter != .all
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
        documentDateFrom = ""
        documentDateTo = ""
        dueDateFrom = ""
        dueDateTo = ""
        statusFilter = .all
        documentTypeFilter = .all
        await load(reset: true)
    }

    func loadNextPageIfNeeded(
        currentDocument: BusinessSupplierDocumentPresentation
    ) async {
        guard currentDocument.id == supplierDocuments.last?.id else { return }
        guard hasLoaded, hasMore, nextCursor != nil else { return }
        await load(reset: false)
    }

    func replace(_ document: BusinessProcurementSupplierDocumentResponse) {
        let existingIndex = supplierDocuments.firstIndex { $0.id == document.id }
        guard matchesCurrentFilters(document) else {
            if let existingIndex {
                supplierDocuments.remove(at: existingIndex)
                infoMessage = supplierDocuments.isEmpty
                    ? "No encontramos documentos de proveedor con estos filtros."
                    : nil
            }
            return
        }

        if let existingIndex {
            let current = supplierDocuments[existingIndex]
            supplierDocuments[existingIndex] = BusinessSupplierDocumentPresentation(
                document: document,
                supplierName: current.supplierName
            )
        } else {
            supplierDocuments.insert(
                BusinessSupplierDocumentPresentation(
                    document: document,
                    supplierName: nil
                ),
                at: 0
            )
        }
        infoMessage = nil
    }

    private func load(reset: Bool) async {
        guard validateAccess() else { return }
        guard !isLoading else { return }
        guard let filters = validatedFilters() else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.listSupplierDocuments(
                organizationId: organizationId,
                filters: BusinessProcurementSupplierDocumentFilters(
                    branchId: branchId,
                    supplierId: supplierId,
                    documentTypes: documentTypeFilter.apiValues,
                    statuses: statusFilter.apiValues,
                    documentDateFrom: filters.documentFrom,
                    documentDateTo: filters.documentTo,
                    dueDateFrom: filters.dueFrom,
                    dueDateTo: filters.dueTo,
                    query: query
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .supplierDocumentNilIfEmpty,
                    limit: 50,
                    cursor: reset ? nil : nextCursor
                )
            )

            let page = await presentations(for: response.supplierDocuments)
            if reset {
                supplierDocuments = page
            } else {
                appendUnique(page)
            }
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            hasLoaded = true
            infoMessage = supplierDocuments.isEmpty
                ? "No encontramos documentos de proveedor con estos filtros."
                : nil
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
            errorMessage = "No tienes permiso para consultar documentos de proveedor."
            infoMessage = nil
            return false
        }
        return true
    }

    private func validatedFilters() -> (
        documentFrom: String?,
        documentTo: String?,
        dueFrom: String?,
        dueTo: String?
    )? {
        guard let documentRange = validatedDateRange(
            from: documentDateFrom,
            to: documentDateTo,
            fieldName: "documento"
        ) else { return nil }
        guard let dueRange = validatedDateRange(
            from: dueDateFrom,
            to: dueDateTo,
            fieldName: "vencimiento"
        ) else { return nil }
        return (
            documentRange.from,
            documentRange.to,
            dueRange.from,
            dueRange.to
        )
    }

    private func validatedDateRange(
        from rawFrom: String,
        to rawTo: String,
        fieldName: String
    ) -> (from: String?, to: String?)? {
        let from = rawFrom
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        let to = rawTo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty

        if let from, !Self.isValidDateOnly(from) {
            errorMessage = "La fecha inicial de \(fieldName) debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let to, !Self.isValidDateOnly(to) {
            errorMessage = "La fecha final de \(fieldName) debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let from, let to, from > to {
            errorMessage = "La fecha inicial de \(fieldName) no puede ser posterior a la final."
            infoMessage = nil
            return nil
        }
        return (from, to)
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

    private func presentations(
        for documents: [BusinessProcurementSupplierDocumentResponse]
    ) async -> [BusinessSupplierDocumentPresentation] {
        var supplierNames: [String: String] = [:]
        for presentation in supplierDocuments {
            if let name = presentation.supplierName {
                supplierNames[presentation.document.supplierId] = name
            }
        }

        var attemptedSupplierIds = Set<String>()
        var unresolvedReferenceCount = 0
        for document in documents where supplierNames[document.supplierId] == nil {
            guard accessPolicy.allows(BusinessProcurementPermission.suppliersView) else {
                continue
            }
            guard attemptedSupplierIds.insert(document.supplierId).inserted else {
                continue
            }
            do {
                let response = try await repository.getSupplier(
                    organizationId: organizationId,
                    supplierId: document.supplierId
                )
                supplierNames[document.supplierId] = response.data.businessSupplierDocumentDisplayName
            } catch {
                unresolvedReferenceCount += 1
            }
        }

        let hasUnavailableSupplier = documents.contains {
            supplierNames[$0.supplierId] == nil
        }
        if unresolvedReferenceCount > 0 || hasUnavailableSupplier {
            referenceWarning = "Algunos nombres de proveedor están protegidos o no disponibles. Los documentos y sus importes siguen siendo consultables."
        }

        return documents.map {
            BusinessSupplierDocumentPresentation(
                document: $0,
                supplierName: supplierNames[$0.supplierId]
            )
        }
    }

    private func appendUnique(_ page: [BusinessSupplierDocumentPresentation]) {
        var knownIds = Set(supplierDocuments.map(\.id))
        for document in page where knownIds.insert(document.id).inserted {
            supplierDocuments.append(document)
        }
    }

    private func matchesCurrentFilters(
        _ document: BusinessProcurementSupplierDocumentResponse
    ) -> Bool {
        if let branchId, document.branchId != branchId { return false }
        if let supplierId, document.supplierId != supplierId { return false }
        if !statusFilter.apiValues.isEmpty,
           !statusFilter.apiValues.contains(document.status) {
            return false
        }
        if !documentTypeFilter.apiValues.isEmpty,
           !documentTypeFilter.apiValues.contains(document.documentType) {
            return false
        }

        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .supplierDocumentNilIfEmpty
        if let normalizedQuery {
            let searchable = [document.documentNumber, document.notes ?? ""]
                .joined(separator: " ")
                .lowercased()
            if !searchable.contains(normalizedQuery) { return false }
        }

        let documentFrom = documentDateFrom
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        let documentTo = documentDateTo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        if let documentFrom, document.documentDate < documentFrom { return false }
        if let documentTo, document.documentDate > documentTo { return false }

        let dueFrom = dueDateFrom
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        let dueTo = dueDateTo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        if dueFrom != nil || dueTo != nil {
            guard let dueDate = document.dueDate else { return false }
            if let dueFrom, dueDate < dueFrom { return false }
            if let dueTo, dueDate > dueTo { return false }
        }
        return true
    }
}

struct BusinessSupplierDocumentActionIdempotencyKeys: Equatable, Sendable {
    let confirm: IdempotencyKey
    let cancel: IdempotencyKey

    static func generate() -> BusinessSupplierDocumentActionIdempotencyKeys {
        BusinessSupplierDocumentActionIdempotencyKeys(
            confirm: .generate(prefix: "supplier-document-confirm"),
            cancel: .generate(prefix: "supplier-document-cancel")
        )
    }
}

@MainActor
@Observable
final class BusinessSupplierDocumentDetailViewModel {
    private(set) var supplierDocument: BusinessProcurementSupplierDocumentResponse
    private(set) var supplierName: String?
    private(set) var payable: BusinessProcurementPayableResponse?
    private(set) var isLoading = false
    private(set) var isPerformingAction = false
    private(set) var activeAction: BusinessSupplierDocumentAction?
    private(set) var hasLoaded = false
    var errorMessage: String?
    var infoMessage: String?
    var referenceWarning: String?

    let organizationId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository
    private let actionIdempotencyKeys: BusinessSupplierDocumentActionIdempotencyKeys

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        supplierDocument: BusinessProcurementSupplierDocumentResponse,
        supplierName: String? = nil,
        repository: BusinessProcurementRepository,
        actionIdempotencyKeys: BusinessSupplierDocumentActionIdempotencyKeys = .generate()
    ) {
        self.organizationId = organizationId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.supplierDocument = supplierDocument
        self.supplierName = supplierName
        self.repository = repository
        self.actionIdempotencyKeys = actionIdempotencyKeys
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.supplierDocumentsView)
    }

    var canViewPayable: Bool {
        accessPolicy.allows(BusinessProcurementPermission.payablesView)
    }

    var canEdit: Bool {
        accessPolicy.canEditSupplierDocument(status: supplierDocument.status)
    }

    var canConfirm: Bool {
        accessPolicy.canConfirmSupplierDocument(status: supplierDocument.status)
    }

    var canCancel: Bool {
        accessPolicy.canCancelSupplierDocument(status: supplierDocument.status)
    }

    var hasAvailableActions: Bool {
        canEdit || canConfirm || canCancel
    }

    var businessSupplierName: String {
        supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
            ?? "Proveedor no disponible"
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
            errorMessage = "No tienes permiso para consultar este documento de proveedor."
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer { isLoading = false }

        do {
            let response = try await repository.getSupplierDocument(
                organizationId: organizationId,
                documentId: supplierDocument.id
            )
            supplierDocument = response.data
            payable = canViewPayable ? response.payable : nil
            await hydrateSupplier()
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replace(_ document: BusinessProcurementSupplierDocumentResponse) {
        guard document.id == supplierDocument.id else { return }
        supplierDocument = document
        hasLoaded = true
        errorMessage = nil
    }

    func recordEditedDocument(
        _ document: BusinessProcurementSupplierDocumentResponse
    ) {
        guard document.id == supplierDocument.id else { return }
        replace(document)
        infoMessage = "Documento actualizado correctamente."
    }

    func perform(
        action: BusinessSupplierDocumentAction,
        reason: String? = nil
    ) async -> BusinessProcurementSupplierDocumentResponse? {
        guard !isPerformingAction else { return nil }
        guard isActionAllowed(action) else {
            errorMessage = "La acción ya no está disponible para el estado actual o tus permisos."
            return nil
        }
        guard supplierDocument.version > 0 else {
            errorMessage = "No se encontró una versión válida del documento."
            return nil
        }

        let normalizedReason = reason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
        if action == .cancel, normalizedReason == nil {
            errorMessage = "Ingresa el motivo de cancelación."
            return nil
        }

        isPerformingAction = true
        activeAction = action
        errorMessage = nil
        infoMessage = nil
        referenceWarning = nil
        defer {
            activeAction = nil
            isPerformingAction = false
        }

        do {
            let response = try await repository.performSupplierDocumentAction(
                organizationId: organizationId,
                documentId: supplierDocument.id,
                action: action,
                idempotencyKey: idempotencyKey(for: action),
                request: BusinessProcurementSupplierDocumentActionRequest(
                    expectedVersion: supplierDocument.version,
                    reason: action == .cancel ? normalizedReason : nil
                )
            )
            supplierDocument = response.data
            payable = canViewPayable ? response.payable : nil
            await hydrateSupplier()
            hasLoaded = true
            infoMessage = actionSuccessMessage(
                action,
                status: response.data.status,
                replayed: response.meta.idempotencyReplayed == true
            )
            return response.data
        } catch let error as APIError {
            errorMessage = supplierDocumentActionErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func isActionAllowed(_ action: BusinessSupplierDocumentAction) -> Bool {
        switch action {
        case .confirm: return canConfirm
        case .cancel: return canCancel
        }
    }

    private func idempotencyKey(
        for action: BusinessSupplierDocumentAction
    ) -> IdempotencyKey {
        switch action {
        case .confirm: return actionIdempotencyKeys.confirm
        case .cancel: return actionIdempotencyKeys.cancel
        }
    }

    private func actionSuccessMessage(
        _ action: BusinessSupplierDocumentAction,
        status: BusinessSupplierDocumentStatus,
        replayed: Bool
    ) -> String {
        if action == .confirm, status == .confirming {
            return "La confirmación está en proceso. Actualiza el detalle antes de asumir la creación de una cuenta por pagar."
        }
        if replayed {
            return "El documento se recuperó de un intento anterior."
        }
        switch action {
        case .confirm:
            return status == .confirmed
                ? "Documento confirmado correctamente."
                : "El servidor actualizó el documento. Revisa su estado antes de continuar."
        case .cancel:
            return status == .cancelled
                ? "Documento cancelado correctamente."
                : "El servidor actualizó el documento. Revisa su estado antes de continuar."
        }
    }

    private func supplierDocumentActionErrorMessage(_ error: APIError) -> String {
        let code = error.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "El documento cambió en el servidor. Actualiza el detalle antes de reintentar."
        case "procurement_state_conflict":
            return "El estado del documento cambió. Actualiza el detalle antes de continuar."
        default:
            return error.userMessage
        }
    }

    private func hydrateSupplier() async {
        guard accessPolicy.allows(BusinessProcurementPermission.suppliersView) else {
            if supplierName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .supplierDocumentNilIfEmpty == nil {
                referenceWarning = "El nombre del proveedor está protegido por permisos. El documento sigue mostrando la verdad recibida del servidor."
            }
            return
        }

        do {
            let response = try await repository.getSupplier(
                organizationId: organizationId,
                supplierId: supplierDocument.supplierId
            )
            supplierName = response.data.businessSupplierDocumentDisplayName
        } catch {
            referenceWarning = "No pudimos resolver el nombre del proveedor. El documento y sus importes siguen disponibles."
        }
    }
}

extension BusinessSupplierDocumentStatus {
    var businessDisplayName: String {
        switch self {
        case .draft: return "Borrador"
        case .confirming: return "Confirmando"
        case .confirmed: return "Confirmado"
        case .cancelled: return "Cancelado"
        }
    }

    var businessPayableExplanation: String {
        switch self {
        case .draft:
            return "El borrador todavía no crea una cuenta por pagar ni cambia inventario."
        case .confirming:
            return "La confirmación está en proceso; actualiza antes de asumir la creación de una cuenta por pagar."
        case .confirmed:
            return "El servidor confirmó el cargo. Si existe saldo a crédito, el backend conserva la cuenta por pagar autoritativa e idempotente."
        case .cancelled:
            return "El documento está cancelado y no crea nuevas obligaciones."
        }
    }
}

extension BusinessPayableEffectiveStatus {
    var businessSupplierDocumentDisplayName: String {
        switch self {
        case .open: return "Pendiente"
        case .partiallyPaid: return "Pago parcial"
        case .paid: return "Pagada"
        case .overdue: return "Vencida"
        case .cancelled: return "Cancelada"
        }
    }
}

extension BusinessProcurementSupplierDocumentResponse {
    var businessDocumentTypeName: String {
        switch documentType.uppercased() {
        case "INVOICE", "SUPPLIER_INVOICE": return "Factura de proveedor"
        case "EXPENSE": return "Gasto"
        default:
            return documentType
                .replacingOccurrences(of: "_", with: " ")
                .localizedCapitalized
        }
    }

    var businessLineCountText: String {
        lines.count == 1 ? "1 línea" : "\(lines.count) líneas"
    }

    var businessAttachmentCountText: String {
        attachmentIds.count == 1 ? "1 archivo" : "\(attachmentIds.count) archivos"
    }

    var businessPurchaseOrderLinkCountText: String {
        purchaseOrderIds.count == 1
            ? "1 orden vinculada"
            : "\(purchaseOrderIds.count) órdenes vinculadas"
    }

    var businessPurchaseReceiptLinkCountText: String {
        purchaseReceiptIds.count == 1
            ? "1 recepción vinculada"
            : "\(purchaseReceiptIds.count) recepciones vinculadas"
    }
}

private extension BusinessProcurementSupplierResponse {
    var businessSupplierDocumentDisplayName: String {
        tradeName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierDocumentNilIfEmpty
            ?? legalName
    }
}

extension BusinessProcurementSupplierDocumentLineResponse {
    var businessKindName: String {
        switch kind.uppercased() {
        case "STOCK_ITEM": return "Artículo con inventario"
        case "NON_STOCK_ITEM": return "Artículo sin inventario"
        case "SERVICE": return "Servicio"
        case "EXPENSE": return "Gasto"
        default:
            return kind
                .replacingOccurrences(of: "_", with: " ")
                .localizedCapitalized
        }
    }

    var businessQuantityText: String {
        "\(supplierDocumentTrimmedDecimal(quantity.value)) \(quantity.unitCode)"
    }
}

private func supplierDocumentTrimmedDecimal(_ rawValue: String) -> String {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let separator = value.firstIndex(of: ".") else { return value }
    let integer = String(value[..<separator])
    let fractionStart = value.index(after: separator)
    let fraction = String(value[fractionStart...]).replacingOccurrences(
        of: "0+$",
        with: "",
        options: .regularExpression
    )
    return fraction.isEmpty ? integer : "\(integer).\(fraction)"
}

private extension String {
    var supplierDocumentNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
