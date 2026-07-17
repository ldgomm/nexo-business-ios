//
//  BusinessSupplierStatementViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessSupplierStatementViewModel {
    private(set) var lines: [BusinessProcurementSupplierStatementLineResponse] = []
    private(set) var openingBalance: BusinessProcurementMoneyResponse?
    private(set) var closingBalance: BusinessProcurementMoneyResponse?
    private(set) var statementCurrency: String?
    private(set) var statementFrom: String?
    private(set) var statementTo: String?
    private(set) var statementAsOf: String?
    private(set) var isLoading = false
    private(set) var isExportingCSV = false
    private(set) var downloadedCSVFile: BusinessProcurementDownloadedFile?
    private(set) var lastFailureWasExport = false
    private(set) var hasMore = false
    private(set) var nextCursor: String?
    private(set) var hasLoaded = false

    var currency: String {
        didSet { invalidateDownloadedCSVIfChanged(from: oldValue, to: currency) }
    }
    var from = "" {
        didSet { invalidateDownloadedCSVIfChanged(from: oldValue, to: from) }
    }
    var to = "" {
        didSet { invalidateDownloadedCSVIfChanged(from: oldValue, to: to) }
    }
    var asOf = "" {
        didSet { invalidateDownloadedCSVIfChanged(from: oldValue, to: asOf) }
    }
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String?
    let supplierId: String
    let supplierName: String?
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    private let defaultCurrency: String

    init(
        organizationId: String,
        branchId: String? = nil,
        supplierId: String,
        supplierName: String? = nil,
        currency: String = "USD",
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierStatementNilIfEmpty
        self.supplierId = supplierId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.supplierName = supplierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierStatementNilIfEmpty
        let normalisedCurrency = currency
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        self.defaultCurrency = normalisedCurrency.isEmpty ? "USD" : normalisedCurrency
        self.currency = normalisedCurrency.isEmpty ? "USD" : normalisedCurrency
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
    }

    var canView: Bool {
        accessPolicy.allows(BusinessProcurementPermission.supplierStatementsView)
    }

    var canExportCSV: Bool {
        canView && accessPolicy.allows(
            BusinessProcurementPermission.supplierStatementsExport
        )
    }

    var businessSupplierName: String {
        supplierName ?? "Proveedor seleccionado"
    }

    var hasActiveFilters: Bool {
        !from.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !asOf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != defaultCurrency
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load(reset: true)
    }

    func refresh() async {
        invalidateDownloadedCSV()
        await load(reset: true)
    }

    func search() async {
        invalidateDownloadedCSV()
        await load(reset: true)
    }

    func clearFilters() async {
        invalidateDownloadedCSV()
        currency = defaultCurrency
        from = ""
        to = ""
        asOf = ""
        await load(reset: true)
    }

    func loadNextPageIfNeeded(
        currentLine: BusinessProcurementSupplierStatementLineResponse
    ) async {
        guard currentLine.id == lines.last?.id else { return }
        guard hasLoaded, hasMore, nextCursor != nil else { return }
        await load(reset: false)
    }

    func retryLastFailure() async {
        if lastFailureWasExport {
            await exportCSV()
        } else {
            await refresh()
        }
    }

    func exportCSV() async {
        guard !isExportingCSV else { return }
        lastFailureWasExport = true
        guard validateAccess() else { return }
        guard canExportCSV else {
            errorMessage = "No tienes permiso para exportar estados de cuenta de proveedores."
            infoMessage = nil
            return
        }
        guard let filters = validatedFilters(cursor: nil) else { return }

        isExportingCSV = true
        downloadedCSVFile = nil
        errorMessage = nil
        infoMessage = nil
        defer { isExportingCSV = false }

        do {
            let file = try await repository.downloadSupplierStatementCSV(
                organizationId: organizationId,
                supplierId: supplierId,
                filters: filters
            )
            guard file.localURL.isFileURL,
                  file.sizeBytes > 0,
                  file.fileName.lowercased().hasSuffix(".csv") else {
                errorMessage = "El servidor no devolvió un archivo CSV válido."
                return
            }
            downloadedCSVFile = file
            infoMessage = Self.exportReadyMessage
            lastFailureWasExport = false
        } catch let error as APIError {
            errorMessage = supplierStatementExportErrorMessage(error)
        } catch {
            errorMessage = "No se pudo exportar el estado de cuenta. Inténtalo nuevamente."
        }
    }

    private func load(reset: Bool) async {
        lastFailureWasExport = false
        guard validateAccess() else { return }
        guard !isLoading else { return }
        guard let filters = validatedFilters(cursor: reset ? nil : nextCursor) else {
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            let response = try await repository.getSupplierStatement(
                organizationId: organizationId,
                supplierId: supplierId,
                filters: filters
            )
            guard accepts(response, filters: filters) else {
                errorMessage = "El servidor devolvió un estado de cuenta de otro contexto. No se mezclaron saldos ni movimientos."
                return
            }

            if reset {
                lines = response.lines
                openingBalance = response.openingBalance
            } else {
                appendUnique(response.lines)
            }
            closingBalance = response.closingBalance
            statementCurrency = response.currency
            statementFrom = response.from
            statementTo = response.to
            statementAsOf = response.asOf
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            hasLoaded = true
            infoMessage = lines.isEmpty
                ? "No encontramos movimientos para este proveedor y estos filtros."
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
            errorMessage = "No tienes permiso para consultar estados de cuenta de proveedores."
            infoMessage = nil
            return false
        }
        guard !supplierId.isEmpty else {
            errorMessage = "Selecciona un proveedor válido antes de consultar su estado de cuenta."
            infoMessage = nil
            return false
        }
        return true
    }

    private func validatedFilters(
        cursor: String?
    ) -> BusinessProcurementSupplierStatementFilters? {
        let normalisedCurrency = currency
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard normalisedCurrency.range(
            of: "^[A-Z]{3}$",
            options: .regularExpression
        ) != nil else {
            errorMessage = "La moneda debe usar un código de tres letras, por ejemplo USD."
            infoMessage = nil
            return nil
        }

        let normalisedFrom = from
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierStatementNilIfEmpty
        let normalisedTo = to
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierStatementNilIfEmpty
        let normalisedAsOf = asOf
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .supplierStatementNilIfEmpty

        if let normalisedFrom, !Self.isValidDateOnly(normalisedFrom) {
            errorMessage = "La fecha inicial debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let normalisedTo, !Self.isValidDateOnly(normalisedTo) {
            errorMessage = "La fecha final debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let normalisedAsOf, !Self.isValidDateOnly(normalisedAsOf) {
            errorMessage = "La fecha de corte debe usar el formato AAAA-MM-DD."
            infoMessage = nil
            return nil
        }
        if let normalisedFrom, let normalisedTo, normalisedFrom > normalisedTo {
            errorMessage = "La fecha inicial no puede ser posterior a la final."
            infoMessage = nil
            return nil
        }
        if let normalisedTo, let normalisedAsOf, normalisedTo > normalisedAsOf {
            errorMessage = "La fecha final no puede ser posterior a la fecha de corte."
            infoMessage = nil
            return nil
        }

        currency = normalisedCurrency
        return BusinessProcurementSupplierStatementFilters(
            currency: normalisedCurrency,
            branchId: branchId,
            from: normalisedFrom,
            to: normalisedTo,
            asOf: normalisedAsOf,
            limit: 100,
            cursor: cursor
        )
    }

    private func accepts(
        _ response: BusinessProcurementSupplierStatementResponse,
        filters: BusinessProcurementSupplierStatementFilters
    ) -> Bool {
        guard response.supplierId == supplierId else { return false }
        guard response.currency.uppercased() == filters.currency else { return false }
        if let branchId, response.branchId != branchId { return false }
        if let from = filters.from, response.from != from { return false }
        if let to = filters.to, response.to != to { return false }
        if let asOf = filters.asOf, response.asOf != asOf { return false }
        guard response.openingBalance.currency.uppercased() == filters.currency,
              response.closingBalance.currency.uppercased() == filters.currency,
              response.lines.allSatisfy({ line in
                  line.currency.uppercased() == filters.currency &&
                  line.charge.currency.uppercased() == filters.currency &&
                  line.credit.currency.uppercased() == filters.currency &&
                  line.runningBalance.currency.uppercased() == filters.currency
              }) else {
            return false
        }
        return true
    }

    private func appendUnique(
        _ page: [BusinessProcurementSupplierStatementLineResponse]
    ) {
        var knownIds = Set(lines.map(\.id))
        for line in page where knownIds.insert(line.id).inserted {
            lines.append(line)
        }
    }

    private func invalidateDownloadedCSVIfChanged(
        from oldValue: String,
        to newValue: String
    ) {
        guard oldValue != newValue else { return }
        invalidateDownloadedCSV()
    }

    private func invalidateDownloadedCSV() {
        downloadedCSVFile = nil
        if infoMessage == Self.exportReadyMessage {
            infoMessage = nil
        }
    }

    private func supplierStatementExportErrorMessage(_ error: APIError) -> String {
        let code = error.code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch code {
        case "step_up_required", "reauthentication_required", "insufficient_authentication":
            return "La sesión necesita confirmación adicional para exportar este estado de cuenta. Vuelve a autenticarte e inténtalo nuevamente."
        default:
            return error.userMessage
        }
    }

    private static let exportReadyMessage =
        "CSV autoritativo del servidor listo para compartir."

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

extension BusinessProcurementSupplierStatementLineResponse {
    var businessSupplierStatementSourceName: String {
        switch sourceType.uppercased() {
        case "SUPPLIER_DOCUMENT": return "Documento de proveedor"
        case "SUPPLIER_PAYMENT": return "Pago a proveedor"
        case "PAYABLE": return "Cuenta por pagar"
        case "OPENING_BALANCE": return "Saldo inicial"
        case "ADJUSTMENT": return "Ajuste operativo"
        default:
            return sourceType
                .replacingOccurrences(of: "_", with: " ")
                .lowercased()
                .localizedCapitalized
        }
    }

    var businessSupplierStatementOccurredAtText: String {
        let trimmed = occurredAt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return trimmed }
        let date = String(trimmed.prefix(10))
        return date.range(
            of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
            options: .regularExpression
        ) == nil ? trimmed : date
    }

    var businessSupplierStatementAuditName: String {
        switch auditResourceType.lowercased() {
        case "supplier_document": return "Evidencia del documento"
        case "supplier_payment": return "Evidencia del pago"
        case "payable": return "Evidencia de la cuenta por pagar"
        default: return "Evidencia de origen"
        }
    }
}

private extension String {
    var supplierStatementNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
