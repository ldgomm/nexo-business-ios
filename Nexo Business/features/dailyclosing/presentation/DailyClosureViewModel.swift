//
//  DailyClosureViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 1/6/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class DailyClosureViewModel {
    private(set) var reportState: AsyncViewState<BusinessDailyReport?> = .idle
    private(set) var cashState: AsyncViewState<CashSession?> = .idle
    private(set) var pendingSales: [BusinessSale] = []
    private(set) var pendingReceivables: [ReceivableRecord] = []
    private(set) var pendingDocuments: [BusinessDocument] = []
    private(set) var todaySales: [BusinessSale] = []

    private(set) var isLoading = false
    var businessDate: Date
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let pendingRepository: PendingOperationsRepository
    private let dailyReportRepository: BusinessDailyReportRepository
    private let cashRepository: CashRepository
    private let historyRepository: SalesHistoryRepository?

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        pendingRepository: PendingOperationsRepository,
        dailyReportRepository: BusinessDailyReportRepository,
        cashRepository: CashRepository,
        historyRepository: SalesHistoryRepository? = nil,
        businessDate: Date = Date()
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.pendingRepository = pendingRepository
        self.dailyReportRepository = dailyReportRepository
        self.cashRepository = cashRepository
        self.historyRepository = historyRepository
        self.businessDate = businessDate
    }

    var selectedBusinessDateString: String {
        BusinessDayFormatter.string(from: businessDate)
    }

    var currentCashSession: CashSession? {
        if case let .loaded(session) = cashState {
            return session
        }
        return nil
    }

    var report: BusinessDailyReport? {
        if case let .loaded(report) = reportState {
            return report
        }
        return nil
    }

    var hasPendingWork: Bool {
        !pendingSales.isEmpty || !pendingReceivables.isEmpty || !pendingDocuments.isEmpty
    }

    var canViewDailyClosure: Bool {
        hasPermission([
            "business.reports.today",
            "reports.today",
            "business.reports.daily",
            "reports.daily",
            "business.sales.view",
            "sales.view",
            "business.receivables.view",
            "receivables.view",
            "business.documents.view",
            "documents.view"
        ])
    }

    var canCloseCash: Bool {
        currentCashSession?.isOpen == true &&
        hasPermission([
            "business.cash.close",
            "cash.close"
        ])
    }

    func load() async {
        guard !branchId.isEmpty else {
            reportState = .failed("Falta una sucursal operativa.")
            cashState = .failed("Falta una sucursal operativa.")
            errorMessage = "Falta una sucursal operativa. Actualiza el contexto."
            return
        }

        guard canViewDailyClosure else {
            reportState = .failed("No tienes permiso para consultar el cierre diario.")
            cashState = .failed("No tienes permiso para consultar caja.")
            errorMessage = "No tienes permiso para consultar pendientes y cierre diario."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        reportState = .loading
        cashState = .loading

        var failures: [String] = []

        do {
            let response = try await dailyReportRepository.dailyReport(
                organizationId: organizationId,
                branchId: branchId,
                businessDate: selectedBusinessDateString
            )
            reportState = .loaded(response.report)
        } catch let error as APIError {
            reportState = .failed(error.userMessage)
            failures.append("Reporte: \(error.userMessage)")
        } catch {
            reportState = .failed(error.localizedDescription)
            failures.append("Reporte: \(error.localizedDescription)")
        }

        do {
            let response = try await cashRepository.current(
                organizationId: organizationId,
                branchId: branchId
            )
            cashState = .loaded(response.session)
        } catch let error as APIError {
            cashState = .failed(error.userMessage)
            failures.append("Caja: \(error.userMessage)")
        } catch {
            cashState = .failed(error.localizedDescription)
            failures.append("Caja: \(error.localizedDescription)")
        }

        if let historyRepository {
            do {
                let response = try await historyRepository.searchSales(
                    organizationId: organizationId,
                    request: SalesHistorySearchRequest(
                        branchId: branchId,
                        query: nil,
                        status: .all,
                        date: businessDate,
                        limit: 100
                    )
                )
                todaySales = response.sales
            } catch let error as APIError {
                todaySales = []
                failures.append("Ventas del día: \(error.userMessage)")
            } catch {
                todaySales = []
                failures.append("Ventas del día: \(error.localizedDescription)")
            }
        }

        do {
            let response = try await pendingRepository.pendingSales(
                organizationId: organizationId,
                branchId: branchId,
                limit: 50
            )
            pendingSales = response.sales
        } catch let error as APIError {
            pendingSales = []
            failures.append("Ventas: \(error.userMessage)")
        } catch {
            pendingSales = []
            failures.append("Ventas: \(error.localizedDescription)")
        }

        do {
            let response = try await pendingRepository.pendingReceivables(
                organizationId: organizationId,
                branchId: branchId,
                limit: 50
            )
            pendingReceivables = response.receivables
        } catch let error as APIError {
            pendingReceivables = []
            failures.append("Cuentas por cobrar: \(error.userMessage)")
        } catch {
            pendingReceivables = []
            failures.append("Cuentas por cobrar: \(error.localizedDescription)")
        }

        do {
            let response = try await pendingRepository.pendingDocuments(
                organizationId: organizationId,
                branchId: branchId,
                limit: 50
            )
            pendingDocuments = response.documents
        } catch let error as APIError {
            pendingDocuments = []
            failures.append("Comprobantes: \(error.userMessage)")
        } catch {
            pendingDocuments = []
            failures.append("Comprobantes: \(error.localizedDescription)")
        }

        isLoading = false

        if failures.isEmpty {
            infoMessage = hasPendingWork
                ? "Tienes pendientes antes de cerrar el día."
                : "No hay pendientes operativos para el día."
        } else {
            errorMessage = failures.joined(separator: "\n")
        }
    }

    func refresh() async {
        await load()
    }

    func updateBusinessDate(_ date: Date) {
        businessDate = date
        reportState = .idle
        pendingSales = []
        pendingReceivables = []
        pendingDocuments = []
        todaySales = []
        infoMessage = nil
        errorMessage = nil
    }

    func makeSaleDetailViewModel(
        saleId: String,
        initialSale: BusinessSale? = nil,
        salesRepository: SalesRepository
    ) -> SaleDetailViewModel {
        SaleDetailViewModel(
            organizationId: organizationId,
            saleId: saleId,
            revisions: revisions,
            initialSale: initialSale,
            effectivePermissions: effectivePermissions,
            salesRepository: salesRepository
        )
    }

    func makeReceivableCollectionViewModel(
        receivable: ReceivableRecord,
        cashRepository: CashRepository,
        receivablesRepository: ReceivablesRepository
    ) -> ReceivableCollectionViewModel {
        ReceivableCollectionViewModel(
            organizationId: organizationId,
            branchId: branchId,
            receivable: receivable,
            effectivePermissions: effectivePermissions,
            cashRepository: cashRepository,
            receivablesRepository: receivablesRepository
        )
    }

    private func hasPermission(_ permissions: [String]) -> Bool {
        permissions.contains { effectivePermissions.contains($0) }
    }
}

enum BusinessDayFormatter {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
