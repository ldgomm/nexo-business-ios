//
//  BusinessProformasViewModel.swift
//  Nexo Business
//
//  21J.10 — Business iOS Proformas MVP
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessProformasViewModel {
    private(set) var proformas: [BusinessProforma] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var infoMessage: String?
    var searchText = ""
    var selectedStatus: BusinessProformaStatus?

    let organizationId: String
    let branchId: String
    let activityId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let repository: BusinessProformasRepository
    private var lastLoadedAt: Date?

    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        repository: BusinessProformasRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.repository = repository
    }

    var canView: Bool {
        hasPermission([
            "*",
            "business.proformas.view",
            "proformas.view",
            "business.sales.view",
            "sales.view",
            "business.sales.create",
            "sales.create"
        ])
    }

    var canCreate: Bool {
        hasPermission([
            "*",
            "business.proformas.create",
            "proformas.create",
            "business.sales.create",
            "sales.create"
        ])
    }

    func loadIfNeeded() async {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < 8, !proformas.isEmpty {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard canView else {
            proformas = []
            errorMessage = "No tienes permiso para consultar proformas."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
            lastLoadedAt = Date()
        }

        do {
            proformas = try await repository.listProformas(
                organizationId: organizationId,
                branchId: branchId,
                revisions: revisions,
                status: selectedStatus,
                search: searchText,
                limit: 100
            )
            infoMessage = proformas.isEmpty ? "No hay proformas para este filtro." : nil
        } catch is CancellationError {
            // Navigation/sheet transitions can cancel an in-flight list refresh.
            // Do not surface Swift.CancellationError as a business error.
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func apply(_ proforma: BusinessProforma) {
        if let index = proformas.firstIndex(where: { $0.id == proforma.id }) {
            proformas[index] = proforma
        } else {
            proformas.insert(proforma, at: 0)
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains(where: effectivePermissions.contains)
    }
}

@MainActor
@Observable
final class BusinessProformaDetailViewModel {
    private(set) var proforma: BusinessProforma?
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var downloadedDocument: BusinessProformaDownloadedDocument?
    private(set) var lastConvertedSaleId: String?
    var errorMessage: String?
    var infoMessage: String?
    var rejectionReason = ""
    var revisionReason = "Cambio solicitado por cliente"

    let organizationId: String
    let proformaId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let repository: BusinessProformasRepository

    init(
        organizationId: String,
        proformaId: String,
        revisions: BusinessRevisions,
        initialProforma: BusinessProforma? = nil,
        effectivePermissions: Set<String>,
        repository: BusinessProformasRepository
    ) {
        self.organizationId = organizationId
        self.proformaId = proformaId
        self.revisions = revisions
        self.proforma = initialProforma
        self.effectivePermissions = effectivePermissions
        self.repository = repository
    }

    var shouldLoadOnAppear: Bool {
        proforma == nil && !isLoading
    }

    var canEdit: Bool {
        guard let proforma else { return false }
        return proforma.canEditDraft && hasPermission(["*", "business.proformas.update", "proformas.update", "business.sales.create", "sales.create"])
    }

    var canSend: Bool {
        guard let proforma else { return false }
        return proforma.canSend && hasPermission(["*", "business.proformas.send", "proformas.send", "business.sales.create", "sales.create"])
    }

    var canAccept: Bool {
        guard let proforma else { return false }
        return proforma.canAccept && hasPermission(["*", "business.proformas.accept", "proformas.accept", "business.sales.create", "sales.create"])
    }

    var canReject: Bool {
        guard let proforma else { return false }
        return proforma.canReject && hasPermission(["*", "business.proformas.reject", "proformas.reject", "business.sales.create", "sales.create"])
    }

    var canExpire: Bool {
        guard let proforma else { return false }
        return proforma.canExpire && hasPermission(["*", "business.proformas.expire", "proformas.expire", "business.sales.create", "sales.create"])
    }

    var canCreateRevision: Bool {
        guard let proforma else { return false }
        return proforma.canCreateRevision && hasPermission(["*", "business.proformas.revision", "proformas.revision", "business.sales.create", "sales.create"])
    }

    var canConvertToSale: Bool {
        guard let proforma else { return false }
        return proforma.canConvertToSale && hasPermission(["*", "business.proformas.convert_to_sale", "proformas.convert_to_sale", "business.sales.create", "sales.create"])
    }

    var canAcceptAndConvertToSale: Bool {
        guard let proforma else { return false }
        guard proforma.hasRealCustomer else { return false }
        guard proforma.convertedSaleId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else { return false }
        guard [.draft, .sent, .accepted].contains(proforma.status) else { return false }
        return hasPermission(["*", "business.proformas.send", "proformas.send", "business.proformas.accept", "proformas.accept", "business.proformas.convert_to_sale", "proformas.convert_to_sale", "business.sales.create", "sales.create"])
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            proforma = try await repository.getProforma(
                organizationId: organizationId,
                proformaId: proformaId
            )
        } catch is CancellationError {
            // User navigated away while loading; keep the last known state.
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }

    @discardableResult
    func markAsShared() async -> Bool {
        guard !isMutating else { return false }
        await ensureProformaLoadedIfNeeded()

        guard proforma?.hasRealCustomer == true else {
            errorMessage = "Selecciona un cliente real antes de compartir una proforma comercial."
            return false
        }

        return await markAsSharedIfNeeded(
            successMessage: "Proforma compartida. Estado actualizado a Compartida.",
            alreadySharedMessage: "Esta proforma ya estaba compartida. Puedes compartirla de nuevo sin cambiar su estado."
        )
    }

    func send() async {
        await markAsShared()
    }

    func accept() async {
        guard !isMutating else { return }
        guard proforma?.hasRealCustomer == true else {
            errorMessage = "Selecciona un cliente real antes de aceptar una proforma."
            return
        }

        await mutate("Proforma aceptada.") {
            try await repository.accept(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-accept", proformaId)
            )
        }
    }

    @discardableResult
    func acceptAndConvertToSale() async -> String? {
        guard !isMutating else { return nil }
        await ensureProformaLoadedIfNeeded()

        guard proforma?.hasRealCustomer == true else {
            errorMessage = "Selecciona un cliente real antes de aceptar y crear venta."
            return nil
        }

        if let existingSaleId = currentConvertedSaleId() {
            infoMessage = "Esta proforma ya tenía una venta creada. Abriendo venta."
            return existingSaleId
        }

        guard let initialStatus = proforma?.status, [.draft, .sent, .accepted, .converted].contains(initialStatus) else {
            errorMessage = "Esta proforma no está lista para crear venta con su estado actual."
            return nil
        }

        isMutating = true
        errorMessage = nil
        infoMessage = nil
        lastConvertedSaleId = nil
        defer { isMutating = false }

        do {
            if proforma?.status == .draft {
                guard await markAsSharedIfNeeded(
                    successMessage: "Proforma compartida. Continuando con aceptación.",
                    alreadySharedMessage: "La proforma ya estaba compartida. Continuando con aceptación.",
                    managesMutationState: false
                ) else { return nil }
            }

            if proforma?.status == .sent {
                guard await acceptIfNeeded(managesMutationState: false) else { return nil }
            }

            if let existingSaleId = currentConvertedSaleId() {
                infoMessage = "Esta proforma ya tenía una venta creada. Abriendo venta."
                return existingSaleId
            }

            guard proforma?.canConvertToSale == true else {
                await load()
                if let existingSaleId = currentConvertedSaleId() {
                    infoMessage = "Esta proforma ya tenía una venta creada. Abriendo venta."
                    return existingSaleId
                }
                errorMessage = "La proforma no pudo avanzar a venta. Estado actual: \(proforma?.status.displayName ?? "desconocido")."
                return nil
            }

            let response = try await repository.convertToSale(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-convert-sale", proformaId)
            )

            lastConvertedSaleId = response.saleId
            if let converted = response.proforma {
                proforma = converted
            } else {
                await load()
            }

            infoMessage = response.wasAlreadyConverted
                ? "Esta proforma ya tenía una venta creada. Abriendo venta."
                : "Venta creada. Abriendo detalle para confirmar y cobrar."
            return response.saleId
        } catch let error as APIError where error.statusCode == 409 {
            await load()
            if let existingSaleId = currentConvertedSaleId() {
                errorMessage = nil
                infoMessage = "La venta ya estaba creada. Abriendo venta."
                return existingSaleId
            }
            errorMessage = error.userMessage
        } catch is CancellationError {
            // Ignore UI navigation cancellation.
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    private func ensureProformaLoadedIfNeeded() async {
        if proforma == nil {
            await load()
        }
    }

    private func currentConvertedSaleId() -> String? {
        proforma?.convertedSaleId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmptyForProforma
    }

    private func markAsSharedIfNeeded(
        successMessage: String,
        alreadySharedMessage: String,
        managesMutationState: Bool = true
    ) async -> Bool {
        guard let current = proforma else { return false }

        switch current.status {
        case .sent, .accepted, .converted:
            errorMessage = nil
            infoMessage = alreadySharedMessage
            return true
        case .draft:
            break
        default:
            errorMessage = "No se puede compartir esta proforma con estado \(current.status.displayName)."
            return false
        }

        if managesMutationState {
            isMutating = true
            errorMessage = nil
            infoMessage = nil
        }
        defer {
            if managesMutationState { isMutating = false }
        }

        do {
            let updated = try await repository.send(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-send", proformaId)
            )
            proforma = updated
            errorMessage = nil
            infoMessage = successMessage
            return [.sent, .accepted, .converted].contains(updated.status)
        } catch let error as APIError where error.statusCode == 409 {
            await load()
            if let status = proforma?.status, [.sent, .accepted, .converted].contains(status) {
                errorMessage = nil
                infoMessage = alreadySharedMessage
                return true
            }
            errorMessage = error.userMessage
            return false
        } catch is CancellationError {
            return false
        } catch let error as APIError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func acceptIfNeeded(managesMutationState: Bool = true) async -> Bool {
        guard let current = proforma else { return false }

        switch current.status {
        case .accepted, .converted:
            return true
        case .sent:
            break
        default:
            errorMessage = "No se puede aceptar esta proforma con estado \(current.status.displayName)."
            return false
        }

        if managesMutationState {
            isMutating = true
            errorMessage = nil
            infoMessage = nil
        }
        defer {
            if managesMutationState { isMutating = false }
        }

        do {
            proforma = try await repository.accept(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-accept", proformaId)
            )
            return proforma?.status == .accepted || proforma?.status == .converted
        } catch let error as APIError where error.statusCode == 409 {
            await load()
            if let status = proforma?.status, [.accepted, .converted].contains(status) {
                errorMessage = nil
                return true
            }
            errorMessage = error.userMessage
            return false
        } catch is CancellationError {
            return false
        } catch let error as APIError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func reject() async {
        guard !isMutating else { return }
        let reason = rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            errorMessage = "Ingresa una razón para rechazar la proforma."
            return
        }

        await mutate("Proforma rechazada.") {
            try await repository.reject(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-reject", proformaId),
                reason: reason
            )
        }
    }

    func expire() async {
        guard !isMutating else { return }
        await mutate("Proforma expirada.") {
            try await repository.expire(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-expire", proformaId)
            )
        }
    }

    func createRevision() async {
        guard !isMutating else { return }
        let reason = revisionReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            errorMessage = "Ingresa una razón para crear revisión."
            return
        }

        await mutate("Revisión creada como borrador.") {
            try await repository.createRevision(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-revision", proformaId),
                request: CreateBusinessProformaRevisionRequest(
                    validUntil: nil,
                    lines: nil,
                    notes: nil,
                    terms: nil,
                    reason: reason
                )
            )
        }
    }

    @discardableResult
    func convertToSale() async -> String? {
        guard !isMutating else { return nil }
        guard let proforma else { return nil }
        if let existingSaleId = proforma.convertedSaleId?.trimmingCharacters(in: .whitespacesAndNewlines), !existingSaleId.isEmpty {
            infoMessage = "Esta proforma ya tenía una venta creada. Abriendo venta."
            return existingSaleId
        }
        guard proforma.hasRealCustomer else {
            errorMessage = "Selecciona un cliente real antes de convertir. Consumidor final no aplica para proformas comerciales."
            return nil
        }
        guard proforma.canConvertToSale else {
            errorMessage = "Solo una proforma aceptada y no convertida puede crear una venta."
            return nil
        }

        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }

        do {
            let response = try await repository.convertToSale(
                organizationId: organizationId,
                proformaId: proformaId,
                revisions: revisions,
                idempotencyKey: Self.key("proforma-convert-sale", proformaId)
            )

            if let converted = response.proforma {
                self.proforma = converted
            } else {
                await refresh()
            }

            lastConvertedSaleId = response.saleId
            infoMessage = response.wasAlreadyConverted
                ? "Esta proforma ya tenía una venta creada. Abriendo venta."
                : "Venta creada. Confirma la venta y registra el cobro desde el detalle."
            return response.saleId
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    func downloadDocument() async {
        guard !isMutating else { return }
        guard proforma != nil else { return }

        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }

        do {
            downloadedDocument = try await repository.downloadDocumentHtml(
                organizationId: organizationId,
                proformaId: proformaId
            )
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func apply(_ updated: BusinessProforma) {
        proforma = updated
    }

    private func mutate(_ successMessage: String, operation: () async throws -> BusinessProforma) async {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }

        do {
            proforma = try await operation()
            infoMessage = successMessage
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains(where: effectivePermissions.contains)
    }

    private static func key(_ prefix: String, _ id: String) -> IdempotencyKey {
        IdempotencyKey(rawValue: "\(prefix)-\(id)-\(UUID().uuidString.lowercased())")
    }
}

struct BusinessProformaLineDraft: Identifiable, Equatable {
    let id: String
    var productId: String?
    var sku: String?
    var displayName: String
    var quantity: String
    var unitPrice: String
    var discountAmount: String
    var taxAmount: String
    var taxProfileCode: String?
    var taxRatePercent: String?
    var notes: String

    init(
        id: String = UUID().uuidString,
        productId: String? = nil,
        sku: String? = nil,
        displayName: String = "",
        quantity: String = "1",
        unitPrice: String = "0.00",
        discountAmount: String = "0.00",
        taxAmount: String = "0.00",
        taxProfileCode: String? = nil,
        taxRatePercent: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.productId = productId
        self.sku = sku
        self.displayName = displayName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.discountAmount = discountAmount
        self.taxAmount = taxAmount
        self.taxProfileCode = taxProfileCode
        self.taxRatePercent = taxRatePercent
        self.notes = notes
    }

    init(line: BusinessProformaLine) {
        self.init(
            id: line.lineId,
            productId: line.productId,
            sku: line.sku,
            displayName: line.displayName,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            discountAmount: line.discountAmount,
            taxAmount: line.taxAmount,
            taxProfileCode: nil,
            taxRatePercent: nil,
            notes: line.notes ?? ""
        )
    }

    var estimatedRawSubtotal: Decimal {
        Self.decimal(quantity) * Self.decimal(unitPrice)
    }

    var estimatedNetSubtotal: Decimal {
        max(Decimal.zero, estimatedRawSubtotal - Self.decimal(discountAmount))
    }

    var estimatedTaxAmount: Decimal {
        if let taxRatePercent = taxRatePercent?.trimmedNilIfBlankForProforma {
            return Self.taxAmount(
                quantity: quantity,
                unitPrice: unitPrice,
                discountAmount: discountAmount,
                taxRatePercent: taxRatePercent
            )
        }
        return Self.decimal(taxAmount)
    }

    var estimatedTaxAmountText: String {
        Self.money(estimatedTaxAmount)
    }

    var estimatedGrandTotal: Decimal {
        estimatedNetSubtotal + estimatedTaxAmount
    }

    var estimatedGrandTotalText: String {
        Self.money(estimatedGrandTotal)
    }

    func canMerge(with product: BusinessProduct) -> Bool {
        productId == product.id &&
        Self.normalizedMoney(unitPrice) == Self.normalizedMoney(product.price?.amount ?? "0.00") &&
        Self.normalizedMoney(discountAmount) == "0.00" &&
        normalizedTaxProfileCode == Self.normalizedTaxProfileCode(product.taxProfileCode) &&
        notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func incrementQuantity() {
        quantity = Self.quantity(Self.decimal(quantity) + Decimal(1))
        taxAmount = estimatedTaxAmountText
    }

    var input: BusinessProformaLineInput {
        BusinessProformaLineInput(
            productId: productId?.trimmedNilIfBlankForProforma,
            sku: sku?.trimmedNilIfBlankForProforma,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines),
            unitPrice: unitPrice.trimmingCharacters(in: .whitespacesAndNewlines),
            discountAmount: discountAmount.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProforma ?? "0.00",
            taxAmount: estimatedTaxAmountText,
            notes: notes.trimmedNilIfBlankForProforma
        )
    }

    var isValid: Bool {
        productId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Decimal(string: quantity.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 > 0 } == true &&
        Decimal(string: unitPrice.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 >= 0 } == true
    }

    var normalizedTaxProfileCode: String? {
        Self.normalizedTaxProfileCode(taxProfileCode)
    }

    private static func normalizedTaxProfileCode(_ value: String?) -> String? {
        guard let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !normalized.isEmpty
        else {
            return nil
        }
        return normalized
    }

    static func taxRatePercent(for product: BusinessProduct) -> String {
        let treatment = SaleLineTaxTreatmentOption.defaultForCatalogItem(product)
        return percent(treatment.localTaxRate(using: .ecuadorStagingFallback))
    }

    static func taxAmount(
        quantity: String,
        unitPrice: String,
        discountAmount: String,
        taxRatePercent: String
    ) -> Decimal {
        let rawSubtotal = decimal(quantity) * decimal(unitPrice)
        let netSubtotal = max(Decimal.zero, rawSubtotal - decimal(discountAmount))
        return roundMoney(netSubtotal * decimal(taxRatePercent) / Decimal(100))
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(
            string: value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? .zero
    }

    private static func roundMoney(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    private static func percent(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let double = number.doubleValue
        if double.rounded() == double {
            return String(format: "%.0f", double)
        }
        return String(format: "%.2f", double)
    }

    private static func normalizedMoney(_ value: String) -> String {
        money(decimal(value))
    }

    static func money(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: roundMoney(value))
        return String(format: "%.2f", number.doubleValue)
    }

    private static func quantity(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let double = number.doubleValue
        if double.rounded() == double {
            return String(format: "%.0f", double)
        }
        return String(format: "%.2f", double)
    }
}

@MainActor
@Observable
final class BusinessProformaFormViewModel {
    enum Mode: Equatable {
        case create
        case edit(BusinessProforma)
    }

    private(set) var isSaving = false
    private(set) var isSearchingProducts = false
    private(set) var productResults: [BusinessProduct] = []
    var errorMessage: String?
    var infoMessage: String?
    var productSearch = ""
    var selectedCustomer: BusinessCustomer?
    var manualCustomerName = ""
    var validUntil = ""
    var notes = ""
    var terms = "No es factura. Cotización comercial sujeta a confirmación."
    var lines: [BusinessProformaLineDraft] = []

    let mode: Mode
    let organizationId: String
    let branchId: String
    let activityId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let proformasRepository: BusinessProformasRepository
    private let productsRepository: ProductsRepository

    init(
        mode: Mode,
        organizationId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        proformasRepository: BusinessProformasRepository,
        productsRepository: ProductsRepository
    ) {
        self.mode = mode
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.proformasRepository = proformasRepository
        self.productsRepository = productsRepository

        if case let .edit(proforma) = mode {
            selectedCustomer = nil
            manualCustomerName = proforma.customerSnapshot?.displayName ?? ""
            validUntil = proforma.validUntil ?? ""
            notes = proforma.notes ?? ""
            terms = proforma.terms ?? "No es factura. Cotización comercial sujeta a confirmación."
            lines = proforma.lines.map(BusinessProformaLineDraft.init(line:))
        } else {
            lines = []
        }
    }

    var title: String {
        switch mode {
        case .create: return "Nueva proforma"
        case .edit: return "Editar borrador"
        }
    }

    var saveButtonTitle: String {
        switch mode {
        case .create: return "Guardar y continuar"
        case .edit: return "Guardar cambios"
        }
    }

    var canSave: Bool {
        !isSaving && lines.contains(where: { $0.isValid }) && hasConvertibleCustomer
    }

    private var hasConvertibleCustomer: Bool {
        if let selectedCustomer {
            return !Self.isFinalConsumerCandidate(
                customerId: selectedCustomer.id,
                displayName: selectedCustomer.displayName,
                identification: selectedCustomer.identificationNumber
            )
        }
        if case let .edit(proforma) = mode {
            guard let customerId = proforma.customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty else {
                return false
            }
            return !Self.isFinalConsumerIdentifier(customerId)
        }
        return false
    }

    func selectCustomer(_ customer: BusinessCustomer) {
        guard !Self.isFinalConsumerCandidate(
            customerId: customer.id,
            displayName: customer.displayName,
            identification: customer.identificationNumber
        ) else {
            selectedCustomer = nil
            manualCustomerName = ""
            errorMessage = "Consumidor final no aplica para proformas. Selecciona o crea un cliente real."
            return
        }

        selectedCustomer = customer
        manualCustomerName = customer.displayName
        errorMessage = nil
    }

    func searchProducts() async {
        let query = productSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearchingProducts = true
        errorMessage = nil
        defer { isSearchingProducts = false }

        do {
            let response = try await productsRepository.listProducts(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: revisions.catalogRevision,
                query: query,
                status: "active",
                limit: 30
            )
            productResults = response.products
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addProduct(_ product: BusinessProduct) {
        if let index = lines.firstIndex(where: { $0.canMerge(with: product) }) {
            lines[index].incrementQuantity()
            infoMessage = "Cantidad actualizada para \(product.name)."
            return
        }

        let unitPrice = product.price?.amount ?? "0.00"
        let taxRatePercent = BusinessProformaLineDraft.taxRatePercent(for: product)
        let taxAmount = BusinessProformaLineDraft.money(
            BusinessProformaLineDraft.taxAmount(
                quantity: "1",
                unitPrice: unitPrice,
                discountAmount: "0.00",
                taxRatePercent: taxRatePercent
            )
        )

        lines.append(
            BusinessProformaLineDraft(
                productId: product.id,
                sku: product.productsPrimaryCode,
                displayName: product.name,
                quantity: "1",
                unitPrice: unitPrice,
                discountAmount: "0.00",
                taxAmount: taxAmount,
                taxProfileCode: product.taxProfileCode,
                taxRatePercent: taxRatePercent,
                notes: ""
            )
        )
        infoMessage = taxAmount == "0.00"
            ? "Producto agregado sin impuesto referencial según su perfil tributario."
            : "Producto agregado con impuesto referencial de venta."
    }

    func removeLine(_ line: BusinessProformaLineDraft) {
        lines.removeAll { $0.id == line.id }
    }

    func save() async -> BusinessProforma? {
        guard !isSaving else { return nil }
        guard canSave else {
            errorMessage = "Selecciona un cliente real y al menos un producto válido. La conversión a venta valida customerId."
            return nil
        }

        let validLines = lines.filter(\.isValid).map(\.input)
        guard !validLines.isEmpty else {
            errorMessage = "Agrega al menos una línea válida."
            return nil
        }

        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        do {
            switch mode {
            case .create:
                let created = try await proformasRepository.createProforma(
                    organizationId: organizationId,
                    revisions: revisions,
                    idempotencyKey: Self.key("proforma-create"),
                    request: CreateBusinessProformaRequest(
                        branchId: branchId,
                        activityId: activityId,
                        customerId: selectedCustomer?.id,
                        customerSnapshot: selectedCustomer?.proformaCustomerSnapshot,
                        issueDate: Self.todayString(),
                        validUntil: validUntil.trimmedNilIfBlankForProforma,
                        currency: "USD",
                        lines: validLines,
                        notes: notes.trimmedNilIfBlankForProforma,
                        terms: terms.trimmedNilIfBlankForProforma,
                        sourceContext: "business-ios"
                    )
                )
                return created

            case let .edit(proforma):
                let updated = try await proformasRepository.updateDraft(
                    organizationId: organizationId,
                    proformaId: proforma.id,
                    revisions: revisions,
                    idempotencyKey: Self.key("proforma-update-\(proforma.id)"),
                    request: UpdateDraftBusinessProformaRequest(
                        customerId: selectedCustomer?.id ?? proforma.customerId,
                        customerSnapshot: selectedCustomer?.proformaCustomerSnapshot ?? proforma.customerSnapshot,
                        validUntil: validUntil.trimmedNilIfBlankForProforma,
                        currency: proforma.currency,
                        lines: validLines,
                        notes: notes.trimmedNilIfBlankForProforma,
                        terms: terms.trimmedNilIfBlankForProforma,
                        sourceContext: proforma.sourceContext ?? "business-ios"
                    )
                )
                return updated
            }
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    var estimatedSubtotalText: String {
        Self.money(lines.reduce(Decimal.zero) { $0 + $1.estimatedRawSubtotal })
    }

    var estimatedTaxText: String {
        Self.money(lines.reduce(Decimal.zero) { $0 + $1.estimatedTaxAmount })
    }

    var estimatedTotalText: String {
        Self.money(lines.reduce(Decimal.zero) { $0 + $1.estimatedGrandTotal })
    }

    private static func isFinalConsumerCandidate(customerId: String, displayName: String, identification: String) -> Bool {
        isFinalConsumerIdentifier(customerId) ||
        isFinalConsumerIdentifier(displayName) ||
        isFinalConsumerIdentifier(identification)
    }

    private static func isFinalConsumerIdentifier(_ value: String) -> Bool {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return normalized == "cus_final_consumer" ||
            normalized == "final_consumer" ||
            normalized == "consumidor_final" ||
            normalized.contains("final_consumer") ||
            normalized.contains("consumidor_final")
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(
            string: value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? .zero
    }

    private static func roundMoney(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    private static func percent(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let double = number.doubleValue
        if double.rounded() == double {
            return String(format: "%.0f", double)
        }
        return String(format: "%.2f", double)
    }

    private static func money(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: roundMoney(value))
        return String(format: "%.2f", number.doubleValue)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func key(_ prefix: String) -> IdempotencyKey {
        IdempotencyKey(rawValue: "\(prefix)-\(UUID().uuidString.lowercased())")
    }
}

private extension String {
    var nilIfEmptyForProforma: String? {
        isEmpty ? nil : self
    }

    var trimmedNilIfBlankForProforma: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var trimmedNilIfBlankForProforma: String? {
        guard let value = self else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
