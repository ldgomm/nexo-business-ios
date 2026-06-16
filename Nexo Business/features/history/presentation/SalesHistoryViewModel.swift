import Foundation
import Observation

@MainActor
@Observable
final class SalesHistoryViewModel {
    private(set) var sales: [BusinessSale] = []
    private(set) var primaryDocumentBySaleId: [String: BusinessDocument] = [:]
    private(set) var total: Int?
    private(set) var hasMore: Bool?
    private(set) var isLoading = false
    private(set) var isRefreshingDocuments = false
    var query = ""
    var selectedStatus: SalesHistoryStatusFilter = .all
    var selectedDate = Date()
    var useDateFilter = true
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let repository: SalesHistoryRepository
    private let documentsRepository: BusinessDocumentsRepository
    private var lastLoadedAt: Date?
    private var lastAppearRefreshAt: Date?

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        historyRepository: SalesHistoryRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.repository = historyRepository
        self.documentsRepository = documentsRepository
    }

    var canSearch: Bool {
        !isLoading && canViewSales && !branchId.isEmpty
    }

    var canViewSales: Bool {
        hasPermission([
            "business.sales.view",
            "sales.view",
            "business.sales.create",
            "sales.create"
        ])
    }

    var hasResults: Bool {
        !sales.isEmpty
    }

    var activeFiltersDescription: String {
        var parts: [String] = []

        if !normalized(query).isEmpty {
            parts.append("Texto: \(normalized(query))")
        }

        if selectedStatus != .all {
            parts.append("Estado: \(selectedStatus.displayName)")
        }

        if useDateFilter {
            parts.append("Fecha: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
        }

        return parts.isEmpty ? "Sin filtros" : parts.joined(separator: " · ")
    }

    func load() async {
        await load(force: true)
    }

    func loadIfNeeded() async {
        guard sales.isEmpty else { return }
        await load(force: true)
    }

    func refreshOnAppear() async {
        let now = Date()
        if let lastAppearRefreshAt, now.timeIntervalSince(lastAppearRefreshAt) < 2 {
            return
        }
        self.lastAppearRefreshAt = now
        await load(force: false)
    }

    func clearFilters() {
        query = ""
        selectedStatus = .all
        selectedDate = Date()
        useDateFilter = true
        errorMessage = nil
        infoMessage = nil
    }

    func makeSaleDetailViewModel(
        for sale: BusinessSale,
        salesRepository: SalesRepository
    ) -> SaleDetailViewModel {
        let initialSale = sale.replacingElectronicDocument(primaryDocumentBySaleId[sale.id])
        return SaleDetailViewModel(
            organizationId: organizationId,
            saleId: sale.id,
            revisions: revisions,
            initialSale: initialSale,
            effectivePermissions: effectivePermissions,
            salesRepository: salesRepository
        )
    }

    func primaryDocument(for sale: BusinessSale) -> BusinessDocument? {
        sale.primaryElectronicDocument ?? primaryDocumentBySaleId[sale.id]
    }

    func applySaleUpdate(_ updatedSale: BusinessSale) {
        let knownDocument = updatedSale.primaryElectronicDocument ?? primaryDocumentBySaleId[updatedSale.id]
        let enrichedSale = updatedSale.replacingElectronicDocument(knownDocument)

        if let index = sales.firstIndex(where: { $0.id == updatedSale.id }) {
            sales[index] = enrichedSale
        }

        if let knownDocument {
            primaryDocumentBySaleId[updatedSale.id] = knownDocument
        }
    }

    private func load(force: Bool) async {
        guard canViewSales else {
            sales = []
            primaryDocumentBySaleId = [:]
            errorMessage = "No tienes permiso para consultar ventas."
            return
        }

        guard !branchId.isEmpty else {
            sales = []
            primaryDocumentBySaleId = [:]
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        guard !isLoading else { return }

        if !force,
           let lastLoadedAt,
           Date().timeIntervalSince(lastLoadedAt) < 8,
           !sales.isEmpty {
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
            let response = try await repository.searchSales(
                organizationId: organizationId,
                request: SalesHistorySearchRequest(
                    branchId: branchId,
                    query: emptyToNil(query),
                    status: selectedStatus,
                    date: useDateFilter ? selectedDate : nil,
                    limit: 50
                )
            )

            let orderedSales = response.sales.sorted(by: sortSales)
            total = response.total
            hasMore = response.hasMore

            let hydration = await hydrateSalesWithDocuments(orderedSales)
            sales = hydration.sales
            primaryDocumentBySaleId = hydration.documentsBySaleId

            if sales.isEmpty {
                infoMessage = "No encontramos ventas con estos filtros."
            } else {
                infoMessage = hydration.warning
            }
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hydrateSalesWithDocuments(_ inputSales: [BusinessSale]) async -> DocumentHydrationResult {
        guard canViewDocuments else {
            let documentsBySaleId = inputSales.reduce(into: [String: BusinessDocument]()) { result, sale in
                if let document = sale.primaryElectronicDocument {
                    result[sale.id] = document
                }
            }
            return DocumentHydrationResult(sales: inputSales, documentsBySaleId: documentsBySaleId, warning: nil)
        }

        isRefreshingDocuments = true
        defer { isRefreshingDocuments = false }

        var documentsBySaleId: [String: BusinessDocument] = [:]
        var enrichedSales: [BusinessSale] = []
        var failedCount = 0
        var bulkDocuments: [BusinessDocument] = []
        var usedDocumentKeys = Set<String>()

        do {
            let response = try await documentsRepository.listElectronicDocuments(
                organizationId: organizationId,
                filters: BusinessElectronicDocumentFilters(limit: 250)
            )
            bulkDocuments = BusinessDocument.mergeUniquePreferBest(response.documents)
        } catch {
            failedCount += 1
        }

        for sale in inputSales {
            var candidates: [BusinessDocument] = []

            if let document = sale.primaryElectronicDocument {
                candidates.append(document)
            }

            if let document = bestDocument(for: sale, from: bulkDocuments, excluding: usedDocumentKeys) {
                candidates.append(document)
            }

            var best = BusinessDocument.bestElectronicInvoice(in: candidates)

            if best.map({ !BusinessDocumentStatusPresentation.isAuthorized($0.effectiveStatus) }) ?? true {
                if let document = await loadElectronicDocumentForSaleId(sale.id, failedCount: &failedCount) {
                    candidates.append(document)
                }
            }

            best = BusinessDocument.bestElectronicInvoice(in: candidates)

            if best.map({ !BusinessDocumentStatusPresentation.isAuthorized($0.effectiveStatus) }) ?? true {
                if let document = await loadElectronicDocumentForAlternateIdentifiers(sale, excluding: usedDocumentKeys, failedCount: &failedCount) {
                    candidates.append(document)
                }
            }

            best = BusinessDocument.bestElectronicInvoice(in: candidates)

            if best == nil, let document = await loadLegacyDocument(for: sale, failedCount: &failedCount) {
                candidates.append(document)
            }

            if let document = BusinessDocument.bestElectronicInvoice(in: candidates) {
                documentsBySaleId[sale.id] = document
                markDocumentUsed(document, in: &usedDocumentKeys)
                enrichedSales.append(sale.replacingElectronicDocument(document))
            } else {
                enrichedSales.append(sale)
            }
        }

        let missingPaidSales = enrichedSales.filter { sale in
            PaymentStatusPresentation.isCollected(sale.paymentStatus) && !sale.hasElectronicDocumentRegistered
        }.count

        let warning: String?
        if failedCount > 0 {
            warning = "Algunos comprobantes no pudieron actualizarse. Vuelve a intentar si ves estados incompletos."
        } else if missingPaidSales > 0 {
            warning = "Hay ventas cobradas que todavía no muestran factura electrónica. Actualiza el historial o revisa el enlace documental de la venta."
        } else {
            warning = nil
        }

        return DocumentHydrationResult(
            sales: enrichedSales,
            documentsBySaleId: documentsBySaleId,
            warning: warning
        )
    }

    private func loadElectronicDocumentForSaleId(_ saleId: String, failedCount: inout Int) async -> BusinessDocument? {
        do {
            let response = try await documentsRepository.listElectronicDocuments(
                organizationId: organizationId,
                filters: BusinessElectronicDocumentFilters(saleId: saleId, limit: 10)
            )
            return BusinessDocument.bestElectronicInvoice(in: response.documents)
        } catch {
            failedCount += 1
            return nil
        }
    }

    private func loadElectronicDocumentForAlternateIdentifiers(
        _ sale: BusinessSale,
        excluding usedDocumentIds: Set<String>,
        failedCount: inout Int
    ) async -> BusinessDocument? {
        let identifiers = saleIdentifierCandidates(for: sale).filter { $0 != sale.id }

        for identifier in identifiers {
            do {
                let response = try await documentsRepository.listElectronicDocuments(
                    organizationId: organizationId,
                    filters: BusinessElectronicDocumentFilters(saleId: identifier, limit: 10)
                )
                let candidates = response.documents.filter { !hasDocumentBeenUsed($0, in: usedDocumentIds) }
                if let document = BusinessDocument.bestElectronicInvoice(in: candidates) {
                    return document
                }
            } catch {
                failedCount += 1
            }
        }

        return nil
    }

    private func loadLegacyDocument(for sale: BusinessSale, failedCount: inout Int) async -> BusinessDocument? {
        do {
            let response = try await documentsRepository.list(
                organizationId: organizationId,
                saleId: sale.id
            )
            return BusinessDocument.bestElectronicInvoice(in: response.documents)
        } catch {
            failedCount += 1
            return nil
        }
    }

    private func bestDocument(
        for sale: BusinessSale,
        from documents: [BusinessDocument],
        excluding usedDocumentIds: Set<String>
    ) -> BusinessDocument? {
        let identifiers = Set(saleIdentifierCandidates(for: sale).map(normalizedIdentifier))

        let candidates = documents.filter { document in
            guard !hasDocumentBeenUsed(document, in: usedDocumentIds) else { return false }
            let documentSaleId = normalizedIdentifier(document.saleId)
            guard !documentSaleId.isEmpty else { return false }
            return identifiers.contains(documentSaleId)
        }

        return BusinessDocument.bestElectronicInvoice(in: candidates)
    }

    private func markDocumentUsed(_ document: BusinessDocument, in usedDocumentKeys: inout Set<String>) {
        for key in document.businessIdentityKeys {
            usedDocumentKeys.insert(key)
        }
    }

    private func hasDocumentBeenUsed(_ document: BusinessDocument, in usedDocumentKeys: Set<String>) -> Bool {
        !Set(document.businessIdentityKeys).isDisjoint(with: usedDocumentKeys)
    }

    private func saleIdentifierCandidates(for sale: BusinessSale) -> [String] {
        var values = [sale.id]

        if let number = sale.number?.trimmedNilIfBlank {
            values.append(number)
        }

        values.append(sale.displayNumber)
        values.append(sale.compactDisplayNumber)

        return Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })).filter { !$0.isEmpty }
    }

    private func normalizedIdentifier(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }

    private var canViewDocuments: Bool {
        hasPermission([
            "business.documents.view",
            "documents.view",
            "business.electronic_documents.view",
            "electronic_documents.view",
            "documents.electronic_invoice.view",
            "business.documents.issue_electronic_invoice",
            "documents.issue_electronic_invoice",
            "documents.electronic_invoice.issue",
            "electronic_documents.issue",
            "business.electronic_documents.issue"
        ])
    }

    private func sortDocuments(_ lhs: BusinessDocument, _ rhs: BusinessDocument) -> Bool {
        BusinessDocument.businessSort(lhs, rhs)
    }

    private func sortSales(_ lhs: BusinessSale, _ rhs: BusinessSale) -> Bool {
        switch (lhs.createdAt, rhs.createdAt) {
        case let (left?, right?):
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.id > rhs.id
        }
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage

        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}

private struct DocumentHydrationResult: Sendable {
    let sales: [BusinessSale]
    let documentsBySaleId: [String: BusinessDocument]
    let warning: String?
}

private extension String {
    var trimmedNilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
