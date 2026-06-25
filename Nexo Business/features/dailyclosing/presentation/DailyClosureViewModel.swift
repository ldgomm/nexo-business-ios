//
//  DailyClosureViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation
import Observation

@MainActor
@Observable
class DailyClosureViewModel {
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
    let capabilities: BusinessCapabilities?

    private let pendingRepository: PendingOperationsRepository
    private let dailyReportRepository: BusinessDailyReportRepository
    private let cashRepository: CashRepository
    private let historyRepository: SalesHistoryRepository?

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        capabilities: BusinessCapabilities? = nil,
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
        self.capabilities = capabilities
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
        if let capabilities {
            return capabilities.reports.canViewToday ||
            capabilities.reports.canViewDashboard ||
            capabilities.reports.canViewSales ||
            capabilities.reports.canViewCash ||
            capabilities.reports.canViewDocuments ||
            capabilities.sales.canView ||
            capabilities.receivables.canView ||
            capabilities.documents.canView
        }

        return hasPermission(Self.dailyClosurePermissions)
    }

    var canAccessCash: Bool {
        canViewCash || canOpenCash || canCloseCashByCapability || canRegisterAnyCashMovement
    }

    var canViewCash: Bool {
        capabilities?.cash.canViewCurrent ?? hasPermission(Self.cashViewCurrentPermissions)
    }

    var canOpenCash: Bool {
        capabilities?.cash.canOpen ?? hasPermission(Self.cashOpenPermissions)
    }

    var canCloseCash: Bool {
        currentCashSession?.isOpen == true && canCloseCashByCapability
    }

    var cashCapabilities: CashCapabilities? {
        capabilities?.cash
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
            cashState = canAccessCash ? .failed("No tienes permiso para consultar caja.") : .loaded(nil)
            errorMessage = "No tienes permiso para consultar pendientes y cierre diario."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        reportState = .loading
        cashState = canViewCash ? .loading : .loaded(nil)

        var failures: [String] = []

        do {
            let response = try await dailyReportRepository.dailyReport(
                organizationId: organizationId,
                branchId: branchId,
                businessDate: selectedBusinessDateString
            )
            reportState = .loaded(response.report)
        } catch let error as APIError {
            let message = humanMessage(for: error, area: .report)
            reportState = .failed(message)
            failures.append("Reporte: \(message)")
        } catch {
            reportState = .failed(error.localizedDescription)
            failures.append("Reporte: \(error.localizedDescription)")
        }

        if canViewCash {
            do {
                let response = try await cashRepository.current(
                    organizationId: organizationId,
                    branchId: branchId
                )
                cashState = .loaded(response.session)
            } catch let error as APIError {
                let message = humanMessage(for: error, area: .cash)
                cashState = .failed(message)
                if !isMissingCashPermission(error) {
                    failures.append("Caja: \(message)")
                }
            } catch {
                cashState = .failed(error.localizedDescription)
                failures.append("Caja: \(error.localizedDescription)")
            }
        } else {
            cashState = .loaded(nil)
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
                failures.append("Ventas del día: \(humanMessage(for: error, area: .sales))")
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
            pendingSales = response.sales.filter { !$0.hasRealReceivable }
        } catch let error as APIError {
            pendingSales = []
            failures.append("Ventas: \(humanMessage(for: error, area: .sales))")
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
            failures.append("Cuentas por cobrar: \(humanMessage(for: error, area: .receivables))")
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
            failures.append("Comprobantes: \(humanMessage(for: error, area: .documents))")
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
        cashState = .idle
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

    private var canCloseCashByCapability: Bool {
        capabilities?.cash.canClose ?? hasPermission(Self.cashClosePermissions)
    }

    private var canRegisterAnyCashMovement: Bool {
        if let cash = capabilities?.cash {
            return cash.canRegisterInflow || cash.canRegisterOutflow || cash.canAdjust
        }
        return hasPermission(Self.cashMovementPermissions)
    }

    private func hasPermission(_ permissions: [String]) -> Bool {
        effectivePermissions.contains("*") || permissions.contains { effectivePermissions.contains($0) }
    }

    private enum ErrorArea {
        case report
        case cash
        case sales
        case receivables
        case documents
    }

    private func humanMessage(for error: APIError, area: ErrorArea) -> String {
        if isMissingCashPermission(error) {
            switch area {
            case .cash:
                return "No tienes permiso para consultar caja."
            default:
                return "No tienes permiso para consultar esta información."
            }
        }
        return error.userMessage
    }

    private func isMissingCashPermission(_ error: APIError) -> Bool {
        guard case let .server(_, _, message, _) = error else { return false }
        return message.localizedCaseInsensitiveContains("Missing required permission") ||
        message.localizedCaseInsensitiveContains("cash.session") ||
        message.localizedCaseInsensitiveContains("cash.movements")
    }

    private static let dailyClosurePermissions = [
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
    ]

    private static let cashViewCurrentPermissions = [
        "cash.view",
        "cash.session.view_current",
        "cash.view_current",
        "business.cash.view_current"
    ]

    private static let cashOpenPermissions = [
        "cash.open",
        "cash.session.open",
        "business.cash.open"
    ]

    private static let cashClosePermissions = [
        "cash.close",
        "cash.session.close",
        "business.cash.close"
    ]

    private static let cashMovementPermissions = [
        "cash.movements.register_inflow",
        "cash.movements.register_outflow",
        "cash.movements.adjust",
        "cash.register_inflow",
        "cash.register_outflow",
        "cash.adjust",
        "business.cash.register_inflow",
        "business.cash.register_outflow",
        "business.cash.adjust"
    ]
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
