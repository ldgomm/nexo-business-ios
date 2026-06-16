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
            businessDaySection
            messagesSection
            dailyStatsSection
            cashSection
            pendingSummarySection
            pendingSalesSection
            pendingReceivablesSection
            pendingDocumentsSection
        }
        .navigationTitle("Hoy")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshButton
            }
        }
        .task {
            if viewModel.reportState == .idle {
                await viewModel.load()
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(viewModel.isLoading)
        .accessibilityLabel("Actualizar día operativo")
    }

    private var businessDaySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                DailySectionHeader(
                    icon: "calendar",
                    title: "Día operativo",
                    subtitle: "Revisa ventas, caja y pendientes del día seleccionado."
                )

                DatePicker(
                    "Fecha",
                    selection: $viewModel.businessDate,
                    displayedComponents: [.date]
                )
                .onChange(of: viewModel.businessDate) { _, newValue in
                    viewModel.updateBusinessDate(newValue)
                    Task { await viewModel.load() }
                }

                DailyInfoRow(
                    title: "Consulta",
                    value: viewModel.selectedBusinessDateString,
                    systemImage: "clock"
                )
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var dailyStatsSection: some View {
        Section {
            switch viewModel.reportState {
            case .idle, .loading:
                DailyLoadingCard(
                    title: "Cargando estadísticas…",
                    subtitle: "Estamos preparando el resumen del día."
                )

            case let .failed(message):
                if !viewModel.todaySales.isEmpty {
                    TodayStatsView(report: nil, sales: viewModel.todaySales)

                    DailyNoticeCard(
                        icon: "info.circle",
                        title: "Reporte diario no disponible",
                        message: message,
                        style: .info
                    )
                } else {
                    DailyNoticeCard(
                        icon: "exclamationmark.triangle",
                        title: "No se pudieron cargar las estadísticas",
                        message: message,
                        style: .error
                    )
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
        } header: {
            Text("Resumen")
        }
    }

    @ViewBuilder
    private var cashSection: some View {
        Section {
            if !viewModel.canAccessCash {
                DailyNoticeCard(
                    icon: "lock",
                    title: "Caja no habilitada",
                    message: "Puedes revisar ventas y pendientes según tus permisos, pero la apertura, consulta y cierre de caja están reservados para cajeros o administradores.",
                    style: .info
                )
            } else {
                switch viewModel.cashState {
                case .idle, .loading:
                    DailyLoadingCard(
                        title: "Consultando caja…",
                        subtitle: "Estamos revisando el estado actual de caja."
                    )

                case let .failed(message):
                    DailyNoticeCard(
                        icon: "exclamationmark.triangle",
                        title: "No se pudo consultar caja",
                        message: message,
                        style: .error
                    )

                case let .loaded(session):
                    if let session {
                        CashTodaySummaryView(session: session)

                        NavigationLink {
                            makeCashDashboardView()
                        } label: {
                            DailyNavigationActionRow(
                                title: viewModel.canCloseCash ? "Ver caja o cerrar caja" : "Ver caja operativa",
                                subtitle: viewModel.canCloseCash ? "Revisar efectivo esperado, contado y cierre." : "Consultar el estado actual de caja.",
                                systemImage: viewModel.canCloseCash ? "lock" : "tray"
                            )
                        }
                    } else {
                        DailyNoticeCard(
                            icon: "lock.open",
                            title: "No hay caja abierta",
                            message: viewModel.canOpenCash ? "Abre caja antes de iniciar cobros en efectivo." : "No tienes permisos para abrir caja.",
                            style: .info
                        )

                        NavigationLink {
                            makeCashDashboardView()
                        } label: {
                            DailyNavigationActionRow(
                                title: viewModel.canOpenCash ? "Abrir caja" : "Revisar caja",
                                subtitle: viewModel.canOpenCash ? "Registrar efectivo inicial para operar." : "Consultar información disponible según permisos.",
                                systemImage: "tray"
                            )
                        }
                    }
                }
            }
        } header: {
            Text("Caja operativa")
        }
    }

    private var pendingSummarySection: some View {
        Section {
            DailyPendingSummaryView(
                pendingSalesCount: viewModel.pendingSales.count,
                pendingReceivablesCount: viewModel.pendingReceivables.count,
                pendingDocumentsCount: viewModel.pendingDocuments.count,
                hasPendingWork: viewModel.hasPendingWork
            )
        } header: {
            Text("Pendientes")
        } footer: {
            if viewModel.hasPendingWork {
                Text("Resuelve estos pendientes antes de considerar cerrado el día operativo.")
            }
        }
    }

    @ViewBuilder
    private var pendingSalesSection: some View {
        if !viewModel.pendingSales.isEmpty {
            Section {
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
            } header: {
                Text("Ventas pendientes")
            }
        }
    }

    @ViewBuilder
    private var pendingReceivablesSection: some View {
        if !viewModel.pendingReceivables.isEmpty {
            Section {
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
            } header: {
                Text("Cuentas por cobrar")
            }
        }
    }

    @ViewBuilder
    private var pendingDocumentsSection: some View {
        if !viewModel.pendingDocuments.isEmpty {
            Section {
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
            } header: {
                Text("Comprobantes por revisar")
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage, !message.isEmpty {
            Section {
                DailyNoticeCard(
                    icon: "exclamationmark.triangle",
                    title: "Atención",
                    message: message,
                    style: .error
                )
            }
        }

        if let message = viewModel.infoMessage, !message.isEmpty {
            Section {
                DailyNoticeCard(
                    icon: viewModel.hasPendingWork ? "exclamationmark.circle" : "checkmark.circle",
                    title: viewModel.hasPendingWork ? "Pendientes detectados" : "Todo en orden",
                    message: message,
                    style: viewModel.hasPendingWork ? .warning : .info
                )
            }
        }
    }

    private func makeCashDashboardView() -> some View {
        CashDashboardView(
            viewModel: CashDashboardViewModel(
                organizationId: viewModel.organizationId,
                branchId: viewModel.branchId,
                permissions: viewModel.effectivePermissions,
                cashCapabilities: viewModel.cashCapabilities,
                cashRepository: cashRepository
            )
        )
    }
}

private struct TodayStatsView: View {
    let report: BusinessDailyReport?
    let sales: [BusinessSale]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DailySectionHeader(
                icon: "chart.bar.fill",
                title: "Movimiento del día",
                subtitle: "Ventas, cobros y efectivo esperado."
            )

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TodayMetricCard(
                        title: "Ventas",
                        value: String(salesCount),
                        subtitle: "registradas",
                        systemImage: "cart.fill"
                    )

                    TodayMetricCard(
                        title: "Total vendido",
                        value: salesTotal.displayText,
                        subtitle: "ventas activas",
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
            }

            if cancelledSalesCount > 0 {
                DailyInfoRow(
                    title: "Ventas canceladas",
                    value: String(cancelledSalesCount),
                    systemImage: "xmark.circle"
                )
            }
        }
        .padding(.vertical, 6)
    }

    private var salesCount: Int {
        report?.salesCount ?? activeSales.count
    }

    private var cancelledSalesCount: Int {
        report?.cancelledSalesCount ?? sales.filter {
            let status = $0.status.lowercased()
            return status == "canceled" || status == "cancelled"
        }.count
    }

    private var salesTotal: MoneyAmount {
        report?.salesTotal ?? sum(activeSales.map(\.totals.grandTotal))
    }

    private var paymentsTotal: MoneyAmount {
        report?.paymentsTotal ?? sum(
            activeSales
                .filter { !PaymentStatusPresentation.canCollect(status: $0.paymentStatus) }
                .map(\.totals.grandTotal)
        )
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct CashTodaySummaryView: View {
    let session: CashSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: session.isOpen ? "checkmark.circle.fill" : "lock.fill")
                    .font(.title3)
                    .foregroundStyle(session.isOpen ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.isOpen ? "Caja abierta" : "Caja cerrada")
                        .font(.headline)

                    Text(session.isOpen ? "La caja está lista para operar." : "La caja ya fue cerrada.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                if let openingAmount = session.openingAmount {
                    DailyInfoRow(
                        title: "Monto inicial",
                        value: money(openingAmount),
                        systemImage: "tray.and.arrow.down"
                    )
                }

                if let expectedAmount = session.expectedAmount {
                    DailyInfoRow(
                        title: session.isOpen ? "Efectivo esperado" : "Esperado",
                        value: money(expectedAmount),
                        systemImage: "banknote"
                    )
                }

                if session.isOpen {
                    DailyInfoRow(
                        title: "Conteo",
                        value: "Pendiente al cierre",
                        systemImage: "hourglass"
                    )
                } else {
                    if let countedAmount = session.countedAmount {
                        DailyInfoRow(
                            title: "Contado",
                            value: money(countedAmount),
                            systemImage: "checkmark.circle"
                        )
                    }

                    if let differenceAmount = session.differenceAmount {
                        DailyInfoRow(
                            title: "Diferencia",
                            value: money(differenceAmount),
                            systemImage: "plus.forwardslash.minus"
                        )
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct DailyPendingSummaryView: View {
    let pendingSalesCount: Int
    let pendingReceivablesCount: Int
    let pendingDocumentsCount: Int
    let hasPendingWork: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: hasPendingWork ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(hasPendingWork ? .orange : .green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(hasPendingWork ? "Hay pendientes antes de cerrar" : "Sin pendientes operativos")
                        .font(.headline)

                    Text(hasPendingWork ? "Revisa ventas, cuentas por cobrar y comprobantes." : "El día no tiene pendientes visibles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                DailyInfoRow(
                    title: "Ventas pendientes",
                    value: String(pendingSalesCount),
                    systemImage: "cart.badge.clock"
                )

                DailyInfoRow(
                    title: "Cuentas por cobrar",
                    value: String(pendingReceivablesCount),
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )

                DailyInfoRow(
                    title: "Comprobantes por revisar",
                    value: String(pendingDocumentsCount),
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
        .padding(.vertical, 6)
    }
}

private struct PendingSaleRow: View {
    let sale: BusinessSale

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("Venta \(sale.displayNumber)")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(money(sale.totals.grandTotal))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                DailySmallBadge(
                    text: SaleStatusPresentation.title(for: sale.status),
                    systemImage: "tag"
                )

                DailySmallBadge(
                    text: PaymentStatusPresentation.displayName(sale.paymentStatus),
                    systemImage: "creditcard"
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct PendingReceivableRow: View {
    let receivable: ReceivableRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cuenta \(receivable.id)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text(money(receivable.balance ?? receivable.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                DailySmallBadge(
                    text: ReceivableStatusPresentation.displayName(receivable.status),
                    systemImage: "tag"
                )

                if let dueDate = receivable.dueDate {
                    DailySmallBadge(
                        text: "Vence \(dueDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "calendar"
                    )
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct PendingDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: BusinessDocumentTypePresentation.systemImage(document.type))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(BusinessDocumentTypePresentation.displayName(document.type))
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

                Spacer()
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DailySectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DailyInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct DailyNavigationActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DailyLoadingCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private enum DailyNoticeStyle {
    case info
    case warning
    case error

    var color: Color {
        switch self {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct DailyNoticeCard: View {
    let icon: String
    let title: String
    let message: String
    let style: DailyNoticeStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(style.color)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

private struct DailySmallBadge: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
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
