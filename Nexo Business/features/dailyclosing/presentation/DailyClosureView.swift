//
//  DailyClosureView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct DailyClosureView: View {
    @Bindable private var viewModel: DailyClosureViewModel
    private let salesRepository: SalesRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    init(
        viewModel: DailyClosureViewModel,
        salesRepository: SalesRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.salesRepository = salesRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        Form {
            dateSection
            dailyStatsSection
            cashSection
            pendingSummarySection
            pendingSalesSection
            pendingReceivablesSection
            pendingDocumentsSection
            messagesSection
        }
        .navigationTitle("Hoy")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            if viewModel.reportState == .idle {
                await viewModel.load()
            }
        }
    }

    private var dateSection: some View {
        Section("Día operativo") {
            DatePicker(
                "Fecha",
                selection: $viewModel.businessDate,
                displayedComponents: [.date]
            )
            .onChange(of: viewModel.businessDate) { _, newValue in
                viewModel.updateBusinessDate(newValue)
                Task { await viewModel.load() }
            }

            LabeledContent("Consulta", value: viewModel.selectedBusinessDateString)
        }
    }

    @ViewBuilder
    private var dailyStatsSection: some View {
        Section("Estadísticas de ventas") {
            switch viewModel.reportState {
            case .idle, .loading:
                ProgressView("Cargando estadísticas…")

            case let .failed(message):
                if !viewModel.todaySales.isEmpty {
                    TodayStatsView(report: nil, sales: viewModel.todaySales)
                    Label("Reporte diario no disponible: \(message)", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

            case let .loaded(report):
                if report != nil || !viewModel.todaySales.isEmpty {
                    TodayStatsView(report: report, sales: viewModel.todaySales)
                } else {
                    ContentUnavailableView(
                        "Sin ventas para este día",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Cuando registres ventas, aquí verás el resumen diario.")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var cashSection: some View {
        Section("Caja operativa") {
            if !viewModel.canAccessCash {
                Label("Caja no habilitada para este usuario", systemImage: "lock")
                    .foregroundStyle(.secondary)

                Text("Puedes revisar ventas y pendientes según tus permisos, pero la apertura, consulta y cierre de caja están reservados para cajeros o administradores.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                switch viewModel.cashState {
                case .idle, .loading:
                    ProgressView("Consultando caja…")

                case let .failed(message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)

                case let .loaded(session):
                    if let session {
                        CashTodaySummaryView(session: session)

                        NavigationLink {
                            CashDashboardView(
                                viewModel: CashDashboardViewModel(
                                    organizationId: viewModel.organizationId,
                                    branchId: viewModel.branchId,
                                    permissions: viewModel.effectivePermissions,
                                    cashCapabilities: viewModel.cashCapabilities,
                                    cashRepository: cashRepository
                                )
                            )
                        } label: {
                            Label(
                                viewModel.canCloseCash ? "Ver caja o cerrar caja" : "Ver caja operativa",
                                systemImage: viewModel.canCloseCash ? "lock" : "tray"
                            )
                        }
                    } else {
                        Label("No hay caja abierta", systemImage: "lock.open")
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            CashDashboardView(
                                viewModel: CashDashboardViewModel(
                                    organizationId: viewModel.organizationId,
                                    branchId: viewModel.branchId,
                                    permissions: viewModel.effectivePermissions,
                                    cashCapabilities: viewModel.cashCapabilities,
                                    cashRepository: cashRepository
                                )
                            )
                        } label: {
                            Label(viewModel.canOpenCash ? "Abrir o revisar caja" : "Revisar caja", systemImage: "tray")
                        }
                    }
                }
            }
        }
    }

    private var pendingSummarySection: some View {
        Section("Pendientes del día") {
            LabeledContent("Ventas pendientes", value: String(viewModel.pendingSales.count))
            LabeledContent("Cuentas por cobrar", value: String(viewModel.pendingReceivables.count))
            LabeledContent("Comprobantes por revisar", value: String(viewModel.pendingDocuments.count))

            if viewModel.hasPendingWork {
                Label("Hay pendientes antes de cerrar el día.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Label("No hay pendientes operativos para este día.", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var pendingSalesSection: some View {
        if !viewModel.pendingSales.isEmpty {
            Section("Ventas pendientes") {
                ForEach(viewModel.pendingSales) { sale in
                    NavigationLink {
                        SaleDetailView(
                            viewModel: viewModel.makeSaleDetailViewModel(
                                saleId: sale.id,
                                initialSale: sale,
                                salesRepository: salesRepository
                            ),
                            cashRepository: cashRepository,
                            paymentsRepository: paymentsRepository,
                            receivablesRepository: receivablesRepository,
                            documentsRepository: documentsRepository
                        )
                    } label: {
                        PendingSaleRow(sale: sale)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pendingReceivablesSection: some View {
        if !viewModel.pendingReceivables.isEmpty {
            Section("Cuentas por cobrar") {
                ForEach(viewModel.pendingReceivables) { receivable in
                    NavigationLink {
                        ReceivableCollectionView(
                            viewModel: viewModel.makeReceivableCollectionViewModel(
                                receivable: receivable,
                                cashRepository: cashRepository,
                                receivablesRepository: receivablesRepository
                            )
                        )
                    } label: {
                        PendingReceivableRow(receivable: receivable)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pendingDocumentsSection: some View {
        if !viewModel.pendingDocuments.isEmpty {
            Section("Comprobantes por revisar") {
                ForEach(viewModel.pendingDocuments) { document in
                    NavigationLink {
                        SaleDetailView(
                            viewModel: viewModel.makeSaleDetailViewModel(
                                saleId: document.saleId,
                                salesRepository: salesRepository
                            ),
                            cashRepository: cashRepository,
                            paymentsRepository: paymentsRepository,
                            receivablesRepository: receivablesRepository,
                            documentsRepository: documentsRepository
                        )
                    } label: {
                        PendingDocumentRow(document: document)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.infoMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: viewModel.hasPendingWork ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TodayStatsView: View {
    let report: BusinessDailyReport?
    let sales: [BusinessSale]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TodayMetricCard(
                    title: "Ventas",
                    value: String(salesCount),
                    subtitle: "realizadas",
                    systemImage: "cart.fill"
                )

                TodayMetricCard(
                    title: "Total vendido",
                    value: salesTotal.displayText,
                    subtitle: "ventas brutas",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }

            HStack(spacing: 12) {
                TodayMetricCard(
                    title: "Cobrado",
                    value: paymentsTotal.displayText,
                    subtitle: "pagos recibidos",
                    systemImage: "dollarsign.circle.fill"
                )

                TodayMetricCard(
                    title: "Caja",
                    value: cashExpectedAmount.displayText,
                    subtitle: "efectivo esperado",
                    systemImage: "banknote.fill"
                )
            }

            if cancelledSalesCount > 0 {
                HStack {
                    Label("Canceladas", systemImage: "xmark.circle")
                    Spacer()
                    Text(String(cancelledSalesCount))
                        .font(.headline.monospacedDigit())
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var salesCount: Int {
        report?.salesCount ?? activeSales.count
    }

    private var cancelledSalesCount: Int {
        report?.cancelledSalesCount ?? sales.filter { $0.status.lowercased() == "canceled" || $0.status.lowercased() == "cancelled" }.count
    }

    private var salesTotal: MoneyAmount {
        report?.salesTotal ?? sum(activeSales.map(\.totals.grandTotal))
    }

    private var paymentsTotal: MoneyAmount {
        report?.paymentsTotal ?? sum(activeSales.filter { !PaymentStatusPresentation.canCollect(status: $0.paymentStatus) }.map(\.totals.grandTotal))
    }

    private var cashExpectedAmount: MoneyAmount {
        report?.cashExpectedAmount ?? paymentsTotal
    }

    private var activeSales: [BusinessSale] {
        sales.filter { sale in
            let normalized = sale.status.lowercased()
            return normalized != "canceled" && normalized != "cancelled"
        }
    }

    private func sum(_ amounts: [MoneyAmount]) -> MoneyAmount {
        let total = amounts.reduce(Decimal(0)) { partial, amount in
            partial + (Decimal(string: amount.amount, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(0))
        }
        return MoneyAmount(amount: format(total))
    }

    private func format(_ decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        return String(format: "%.2f", number.doubleValue)
    }
}

private struct TodayMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CashTodaySummaryView: View {
    let session: CashSession

    var body: some View {
        Label(session.isOpen ? "Caja abierta" : "Caja cerrada", systemImage: session.isOpen ? "checkmark.circle.fill" : "lock")
            .foregroundStyle(session.isOpen ? .green : .secondary)

        if let openingAmount = session.openingAmount {
            LabeledContent("Monto inicial", value: money(openingAmount))
        }

        if let expectedAmount = session.expectedAmount {
            LabeledContent(session.isOpen ? "Efectivo esperado" : "Esperado", value: money(expectedAmount))
        }

        if session.isOpen {
            LabeledContent("Conteo", value: "Pendiente al cierre")
        } else {
            if let countedAmount = session.countedAmount {
                LabeledContent("Contado", value: money(countedAmount))
            }

            if let differenceAmount = session.differenceAmount {
                LabeledContent("Diferencia", value: money(differenceAmount))
            }
        }
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct PendingSaleRow: View {
    let sale: BusinessSale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Venta \(sale.displayNumber)")
                .font(.subheadline.weight(.semibold))
            Text(SaleStatusPresentation.title(for: sale.status))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("Pago: \(PaymentStatusPresentation.displayName(sale.paymentStatus))")
                Spacer()
                Text(money(sale.totals.grandTotal))
                    .font(.caption.weight(.semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct PendingReceivableRow: View {
    let receivable: ReceivableRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cuenta \(receivable.id)")
                .font(.subheadline.weight(.semibold))
            Text(ReceivableStatusPresentation.displayName(receivable.status))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("Saldo")
                Spacer()
                Text(money(receivable.balance ?? receivable.amount))
                    .font(.caption.weight(.semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let dueDate = receivable.dueDate {
                Text("Vence: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct PendingDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                BusinessDocumentTypePresentation.displayName(document.type),
                systemImage: BusinessDocumentTypePresentation.systemImage(document.type)
            )
            .font(.subheadline.weight(.semibold))

            Text(BusinessDocumentStatusPresentation.displayName(document.status))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let number = document.number, !number.isEmpty {
                Text(number)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DailyClosureView(
            viewModel: DailyClosureViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                revisions: PreviewData.businessContext.revisions,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                capabilities: PreviewData.businessContext.capabilities,
                pendingRepository: PreviewPendingOperationsRepository(),
                dailyReportRepository: PreviewBusinessDailyReportRepository(),
                cashRepository: PreviewCashRepository()
            ),
            salesRepository: PreviewSalesRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}
