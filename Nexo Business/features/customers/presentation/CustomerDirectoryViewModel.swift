//
//  CustomerDirectoryViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
class CustomerDirectoryViewModel {
    private(set) var customers: [BusinessCustomer] = []
    private(set) var isLoading = false
    var query = ""
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let effectivePermissions: Set<String>
    let customersRepository: CustomersRepository

    init(
        organizationId: String,
        effectivePermissions: Set<String>,
        customersRepository: CustomersRepository
    ) {
        self.organizationId = organizationId
        self.effectivePermissions = effectivePermissions
        self.customersRepository = customersRepository
    }

    var canView: Bool {
        hasPermission([
            "business.customers.view",
            "customers.view",
            "business.customers.create",
            "customers.create"
        ])
    }

    var canCreate: Bool {
        hasPermission([
            "business.customers.create",
            "customers.create"
        ])
    }

    func load() async {
        await search()
    }

    func search() async {
        guard canView else {
            errorMessage = "No tienes permiso para consultar clientes."
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
        }

        do {
            let response = try await customersRepository.search(
                organizationId: organizationId,
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                limit: 50
            )

            customers = response.customers
            infoMessage = response.customers.isEmpty ? "No encontramos clientes." : nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addOrReplace(_ customer: BusinessCustomer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[index] = customer
        } else {
            customers.insert(customer, at: 0)
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        candidates.contains { effectivePermissions.contains($0) }
    }
}

@MainActor
@Observable
class CustomerDetail360ViewModel {
    private(set) var receivables: [ReceivableRecord] = []
    private(set) var sales: [BusinessSale] = []
    private(set) var documents: [BusinessDocument] = []
    private(set) var primaryDocumentBySaleId: [String: BusinessDocument] = [:]
    private(set) var isLoading = false
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let revisions: BusinessRevisions
    let customer: BusinessCustomer
    let effectivePermissions: Set<String>

    let salesHistoryRepository: SalesHistoryRepository
    let receivablesRepository: ReceivablesRepository
    let documentsRepository: BusinessDocumentsRepository
    private var lastLoadedAt: Date?

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        customer: BusinessCustomer,
        effectivePermissions: Set<String>,
        salesHistoryRepository: SalesHistoryRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.revisions = revisions
        self.customer = customer
        self.effectivePermissions = effectivePermissions
        self.salesHistoryRepository = salesHistoryRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var canViewSales: Bool {
        hasPermission([
            "business.sales.view",
            "sales.view",
            "business.sales.create",
            "sales.create"
        ])
    }

    var canViewReceivables: Bool {
        hasPermission([
            "business.receivables.view",
            "receivables.view",
            "business.receivables.collect",
            "receivables.collect",
            "business.receivables.create",
            "receivables.create"
        ])
    }

    var canViewDocuments: Bool {
        hasPermission([
            "documents.electronic_invoice.list",
            "documents.electronic_invoice.view",
            "business.documents.view",
            "documents.view"
        ])
    }

    var canCollectReceivables: Bool {
        hasPermission([
            "business.receivables.collect",
            "receivables.collect",
            "business.payments.collect",
            "payments.collect"
        ])
    }

    var openReceivables: [ReceivableRecord] {
        receivables.filter { !$0.isSettled }
    }

    var settledReceivables: [ReceivableRecord] {
        receivables.filter(\.isSettled)
    }

    var hasOpenReceivables: Bool {
        !openReceivables.isEmpty
    }

    var hasSales: Bool {
        !sales.isEmpty
    }

    var customerPilotStatusText: String {
        if hasOpenReceivables {
            return "Cliente con deuda real: saldo pendiente y abonos deben revisarse desde Por cobrar."
        }

        if hasSales || !documents.isEmpty {
            return "Cliente registrado: ventas, cuentas por cobrar y comprobantes agrupados para seguimiento del negocio."
        }

        return "Cliente real: todavía sin movimiento histórico en esta sucursal."
    }

    var customerPilotStatusIcon: String {
        if hasOpenReceivables { return "person.crop.circle.badge.clock" }
        if hasSales || !documents.isEmpty { return "person.text.rectangle" }
        return "person.crop.circle.badge.questionmark"
    }

    var pendingBalanceDisplay: String {
        moneyDisplay(decimal: openReceivables.reduce(Decimal.zero) { partial, receivable in
            partial + decimal(from: receivable.effectiveBalance.amount)
        })
    }

    var salesTotalDisplay: String {
        moneyDisplay(decimal: sales.reduce(Decimal.zero) { partial, sale in
            partial + decimal(from: sale.totals.grandTotal.amount)
        })
    }

    var lastSaleDateText: String {
        guard let date = sales.compactMap(\.createdAt).max() else { return "Sin ventas" }
        return CustomerDetail360Formatters.dateAndTime.string(from: date)
    }

    var hasAnyData: Bool {
        !receivables.isEmpty || !sales.isEmpty || !documents.isEmpty
    }

    func loadIfNeeded() async {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < 8, hasAnyData {
            return
        }
        await load(force: false)
    }

    func refresh() async {
        await load(force: true)
    }

    func applyReceivableUpdate(_ updated: ReceivableRecord) {
        if let index = receivables.firstIndex(where: { $0.id == updated.id }) {
            receivables[index] = updated
        } else {
            receivables.insert(updated, at: 0)
        }
        receivables.sort(by: sortReceivables)
    }

    func makeSaleDetailViewModel(
        for sale: BusinessSale,
        salesRepository: SalesRepository
    ) -> SaleDetailViewModel {
        SaleDetailViewModel(
            organizationId: organizationId,
            saleId: sale.id,
            revisions: revisions,
            initialSale: sale.replacingElectronicDocument(primaryDocumentBySaleId[sale.id]),
            effectivePermissions: effectivePermissions,
            salesRepository: salesRepository
        )
    }

    private func load(force: Bool) async {
        guard !isLoading else { return }

        guard !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
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
            let loadedReceivables = try await loadReceivables()
            let loadedSales = try await loadSales()
            let hydration = await hydrateDocuments(for: loadedSales)

            receivables = loadedReceivables.sorted(by: sortReceivables)
            sales = hydration.sales.sorted(by: sortSales)
            documents = hydration.documents
            primaryDocumentBySaleId = hydration.documentsBySaleId

            if !hasAnyData {
                infoMessage = "Este cliente todavía no tiene ventas, cuentas por cobrar ni comprobantes en Nexo."
            }
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadReceivables() async throws -> [ReceivableRecord] {
        guard canViewReceivables else { return [] }

        let response = try await receivablesRepository.list(
            organizationId: organizationId,
            customerId: customer.id,
            status: "open,partially_paid,partially_collected,overdue,paid,collected,closed,settled",
            limit: 100
        )

        return response.receivables
    }

    private func loadSales() async throws -> [BusinessSale] {
        guard canViewSales else { return [] }

        var seen: [String: BusinessSale] = [:]
        let candidates = saleSearchCandidates()

        for query in candidates {
            let response = try await salesHistoryRepository.searchSales(
                organizationId: organizationId,
                request: SalesHistorySearchRequest(
                    branchId: branchId,
                    query: query,
                    status: .all,
                    date: nil,
                    limit: 50
                )
            )

            for sale in response.sales where saleMatchesCustomer(sale) {
                seen[sale.id] = sale
            }
        }

        return Array(seen.values)
    }

    private func hydrateDocuments(for inputSales: [BusinessSale]) async -> CustomerDocumentHydrationResult {
        guard canViewDocuments else {
            return CustomerDocumentHydrationResult(sales: inputSales, documents: [], documentsBySaleId: [:])
        }

        var documentsBySaleId: [String: BusinessDocument] = [:]
        var allDocuments: [BusinessDocument] = []

        for sale in inputSales {
            var candidates = [sale.primaryElectronicDocument].compactMap { $0 }

            do {
                let response = try await documentsRepository.list(
                    organizationId: organizationId,
                    saleId: sale.id
                )
                candidates.append(contentsOf: response.documents)
            } catch {
                // Customer 360 must remain useful even if one sale document lookup fails.
            }

            let merged = BusinessDocument.mergeUniquePreferBest(candidates)
            allDocuments.append(contentsOf: merged)

            if let primary = BusinessDocument.bestElectronicInvoice(in: merged) {
                documentsBySaleId[sale.id] = primary
            }
        }

        let enrichedSales = inputSales.map { sale in
            sale.replacingElectronicDocument(documentsBySaleId[sale.id])
        }

        return CustomerDocumentHydrationResult(
            sales: enrichedSales,
            documents: BusinessDocument.mergeUniquePreferBest(allDocuments),
            documentsBySaleId: documentsBySaleId
        )
    }

    private func saleSearchCandidates() -> [String] {
        [
            customer.id,
            customer.identificationNumber,
            customer.displayName,
            customer.email ?? "",
            customer.phone ?? ""
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in
                if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                    result.append(value)
                }
            }
    }

    private func saleMatchesCustomer(_ sale: BusinessSale) -> Bool {
        let expectedId = normalized(customer.id)
        let expectedIdentification = normalized(customer.identificationNumber)
        let expectedName = normalized(customer.displayName)

        let saleCustomerIds = [
            sale.customerId,
            sale.customer?.id,
            sale.receivableCustomerId
        ]
            .compactMap { normalized($0) }

        if !expectedId.isEmpty, saleCustomerIds.contains(expectedId) {
            return true
        }

        let saleIdentifications = [sale.customer?.identification]
            .compactMap { normalized($0) }
        if !expectedIdentification.isEmpty, saleIdentifications.contains(expectedIdentification) {
            return true
        }

        let saleNames = [sale.customerName, sale.customer?.displayName]
            .compactMap { normalized($0) }
        if !expectedName.isEmpty, saleNames.contains(expectedName) {
            return true
        }

        return false
    }

    private func sortSales(_ lhs: BusinessSale, _ rhs: BusinessSale) -> Bool {
        switch (lhs.createdAt, rhs.createdAt) {
        case let (lhs?, rhs?):
            return lhs > rhs
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.displayNumber.localizedCaseInsensitiveCompare(rhs.displayNumber) == .orderedAscending
        }
    }

    private func sortReceivables(_ lhs: ReceivableRecord, _ rhs: ReceivableRecord) -> Bool {
        if lhs.isSettled != rhs.isSettled { return !lhs.isSettled }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (lhs?, rhs?):
            return lhs < rhs
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func decimal(from amount: String) -> Decimal {
        Decimal(
            string: amount.replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? .zero
    }

    private func moneyDisplay(decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)

        let formatted = CustomerDetail360Formatters.money.string(from: number)
            ?? number.stringValue

        let cleanAmount = formatted
            .replacingOccurrences(of: "US$", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "USD", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return "USD \(cleanAmount)"
    }
}

private struct CustomerDocumentHydrationResult {
    let sales: [BusinessSale]
    let documents: [BusinessDocument]
    let documentsBySaleId: [String: BusinessDocument]
}

enum CustomerDetail360Formatters {
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()

    static let money: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
