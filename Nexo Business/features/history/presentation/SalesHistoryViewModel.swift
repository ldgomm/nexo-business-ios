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
        var usedDocumentIds = Set<String>()

        do {
            let response = try await documentsRepository.listElectronicDocuments(
                organizationId: organizationId,
                filters: BusinessElectronicDocumentFilters(limit: 250)
            )
            bulkDocuments = response.documents.sorted(by: sortDocuments)
        } catch {
            failedCount += 1
        }

        for sale in inputSales {
            if let document = sale.primaryElectronicDocument {
                documentsBySaleId[sale.id] = document
                usedDocumentIds.insert(document.id)
                enrichedSales.append(sale.replacingElectronicDocument(document))
                continue
            }

            if let document = bestDocument(for: sale, from: bulkDocuments, excluding: usedDocumentIds) {
                documentsBySaleId[sale.id] = document
                usedDocumentIds.insert(document.id)
                enrichedSales.append(sale.replacingElectronicDocument(document))
                continue
            }

            if let document = await loadElectronicDocumentForSaleId(sale.id, failedCount: &failedCount) {
                documentsBySaleId[sale.id] = document
                usedDocumentIds.insert(document.id)
                enrichedSales.append(sale.replacingElectronicDocument(document))
                continue
            }

            if let document = await loadElectronicDocumentForAlternateIdentifiers(sale, excluding: usedDocumentIds, failedCount: &failedCount) {
                documentsBySaleId[sale.id] = document
                usedDocumentIds.insert(document.id)
                enrichedSales.append(sale.replacingElectronicDocument(document))
                continue
            }

            if let document = await loadLegacyDocument(for: sale, failedCount: &failedCount) {
                documentsBySaleId[sale.id] = document
                usedDocumentIds.insert(document.id)
                enrichedSales.append(sale.replacingElectronicDocument(document))
                continue
            }

            enrichedSales.append(sale)
        }

        let missingPaidSales = enrichedSales.filter { sale in
            PaymentStatusPresentation.isCollected(sale.paymentStatus) && !sale.hasElectronicDocumentRegistered
        }.count

        let warning: String?
        if failedCount > 0 {
            warning = "Algunos comprobantes no pudieron actualizarse. Vuelve a intentar si ves estados incompletos."
        } else if missingPaidSales > 0 {
            warning = "Hay ventas cobradas sin comprobante enlazado por saleId. Si Admin sí muestra el comprobante, el enlace quedó inconsistente en servidor."
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
            return response.documents.sorted(by: sortDocuments).first
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
                if let document = response.documents.sorted(by: sortDocuments).first(where: { !usedDocumentIds.contains($0.id) }) {
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
            return response.documents.sorted(by: sortDocuments).first
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

        return documents.first { document in
            guard !usedDocumentIds.contains(document.id) else { return false }
            let documentSaleId = normalizedIdentifier(document.saleId)
            guard !documentSaleId.isEmpty else { return false }
            return identifiers.contains(documentSaleId)
        }
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
        switch (lhs.createdAt ?? lhs.issuedAt ?? lhs.authorizedAt, rhs.createdAt ?? rhs.issuedAt ?? rhs.authorizedAt) {
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
