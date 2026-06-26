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
        ScrollView {
            LazyVStack(spacing: 12) {
                businessDaySection
                    .dailyClosureHeroSurface()

                if (viewModel.errorMessage?.isEmpty == false) || (viewModel.infoMessage?.isEmpty == false) {
                    messagesSection
                        .dailyClosureSurface()
                }

                dailyStatsSection
                    .dailyClosureSurface()

                cashSection
                    .dailyClosureSurface()

                pendingSummarySection
                    .dailyClosureSurface()

                if !viewModel.pendingSales.isEmpty {
                    pendingSalesSection
                        .dailyClosureSurface()
                }

                if !viewModel.pendingReceivables.isEmpty {
                    pendingReceivablesSection
                        .dailyClosureSurface()
                }

                if !viewModel.pendingDocuments.isEmpty {
                    pendingDocumentsSection
                        .dailyClosureSurface()
                }
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Hoy")
        .navigationBarTitleDisplayMode(.large)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                DailyIconBadge(systemImage: "calendar", tint: .accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Día operativo")
                        .font(.title3.weight(.bold))

                    Text("Resumen ejecutivo de ventas, caja y pendientes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                DailyStatusPill(
                    title: businessDayStatusTitle,
                    systemImage: businessDayStatusIcon,
                    tint: businessDayStatusTint
                )
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fecha")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.selectedBusinessDateString)
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 8)

                DatePicker(
                    "Fecha",
                    selection: $viewModel.businessDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .onChange(of: viewModel.businessDate) { _, newValue in
                    viewModel.updateBusinessDate(newValue)
                    Task { await viewModel.load() }
                }
            }
            .padding(12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 10) {
                DailyCompactFact(
                    title: "Ventas",
                    value: String(viewModel.todaySales.count),
                    systemImage: "cart"
                )

                DailyCompactFact(
                    title: "Pendientes",
                    value: String(totalPendingCount),
                    systemImage: viewModel.hasPendingWork ? "exclamationmark.circle" : "checkmark.circle"
                )
            }
        }
    }

    @ViewBuilder
    private var dailyStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            DailySectionHeader(
                icon: "chart.bar.xaxis",
                title: "Resumen ejecutivo",
                subtitle: "Movimiento, cobros, caja esperada y alertas del día."
            )

            switch viewModel.reportState {
            case .idle, .loading:
                DailyLoadingCard(
                    title: "Cargando resumen…",
                    subtitle: "Preparando los indicadores operativos."
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
                        title: "No pudimos cargar el resumen",
                        message: message,
                        style: .error
                    )
                }

            case let .loaded(report):
                if report != nil || !viewModel.todaySales.isEmpty {
                    TodayStatsView(report: report, sales: viewModel.todaySales)
                } else {
                    DailyEmptyState(
                        title: "Sin movimiento para este día",
                        message: "Cuando registres ventas, aquí aparecerá el resumen de operación.",
                        systemImage: "chart.bar.doc.horizontal"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var cashSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            DailySectionHeader(
                icon: "banknote",
                title: "Caja operativa",
                subtitle: "Estado de caja, efectivo esperado y acceso al cierre."
            )

            if !viewModel.canAccessCash {
                DailyNoticeCard(
                    icon: "lock",
                    title: "Caja no habilitada",
                    message: "Puedes revisar ventas y pendientes según tus permisos, pero apertura, consulta y cierre están reservados para cajeros o administradores.",
                    style: .info
                )
            } else {
                switch viewModel.cashState {
                case .idle, .loading:
                    DailyLoadingCard(
                        title: "Consultando caja…",
                        subtitle: "Revisando el estado actual de caja."
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
                                title: viewModel.canCloseCash ? "Gestionar cierre de caja" : "Ver caja operativa",
                                subtitle: viewModel.canCloseCash ? "Conteo, diferencia y cierre del turno." : "Consultar el estado actual de caja.",
                                systemImage: viewModel.canCloseCash ? "lock" : "tray",
                                tint: .accentColor
                            )
                        }
                        .buttonStyle(.plain)
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
                                title: viewModel.canOpenCash ? "Abrir caja operativa" : "Revisar caja",
                                subtitle: viewModel.canOpenCash ? "Registrar efectivo inicial para operar." : "Consultar información disponible según permisos.",
                                systemImage: "tray",
                                tint: .accentColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var pendingSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            DailySectionHeader(
                icon: viewModel.hasPendingWork ? "exclamationmark.circle" : "checkmark.seal",
                title: "Control de cierre",
                subtitle: "Elementos que conviene resolver antes de cerrar el día."
            )

            DailyPendingSummaryView(
                pendingSalesCount: viewModel.pendingSales.count,
                pendingReceivablesCount: viewModel.pendingReceivables.count,
                pendingDocumentsCount: viewModel.pendingDocuments.count,
                hasPendingWork: viewModel.hasPendingWork
            )

            if viewModel.hasPendingWork {
                DailyInlineFootnote(
                    text: "Primero revisa ventas pendientes, cuentas por cobrar reales y comprobantes. Así el cierre queda limpio y defendible."
                )
            }
        }
    }

    @ViewBuilder
    private var pendingSalesSection: some View {
        if !viewModel.pendingSales.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                DailySectionHeader(
                    icon: "cart.badge.clock",
                    title: "Ventas pendientes",
                    subtitle: "Ventas guardadas o confirmadas que aún requieren cobro final."
                )

                VStack(spacing: 10) {
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pendingReceivablesSection: some View {
        if !viewModel.pendingReceivables.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                DailySectionHeader(
                    icon: "person.crop.circle.badge.clock",
                    title: "Cuentas por cobrar",
                    subtitle: "Deudas reales que siguen abiertas para gestión de cobro."
                )

                VStack(spacing: 10) {
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pendingDocumentsSection: some View {
        if !viewModel.pendingDocuments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                DailySectionHeader(
                    icon: "doc.text.magnifyingglass",
                    title: "Comprobantes pendientes",
                    subtitle: "Documentos que requieren revisión o seguimiento."
                )

                VStack(spacing: 10) {
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = viewModel.errorMessage, !message.isEmpty {
                DailyNoticeCard(
                    icon: "exclamationmark.triangle",
                    title: "Atención",
                    message: message,
                    style: .error
                )
            }

            if let message = viewModel.infoMessage, !message.isEmpty {
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

    private var totalPendingCount: Int {
        viewModel.pendingSales.count + viewModel.pendingReceivables.count + viewModel.pendingDocuments.count
    }

    private var businessDayStatusTitle: String {
        if viewModel.isLoading { return "Actualizando" }
        return viewModel.hasPendingWork ? "Con pendientes" : "Al día"
    }

    private var businessDayStatusIcon: String {
        if viewModel.isLoading { return "arrow.clockwise" }
        return viewModel.hasPendingWork ? "exclamationmark.circle" : "checkmark.circle"
    }

    private var businessDayStatusTint: Color {
        if viewModel.isLoading { return .secondary }
        return viewModel.hasPendingWork ? .orange : .green
    }
}

private struct DailyClosureSurfaceModifier: ViewModifier {
    var isHero: Bool = false

    func body(content: Content) -> some View {
        let cornerRadius: CGFloat = isHero ? 26 : 22

        content
            .padding(isHero ? 18 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isHero {
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.16),
                            Color(uiColor: .secondarySystemGroupedBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(isHero ? 0.055 : 0.03), radius: isHero ? 14 : 8, x: 0, y: isHero ? 8 : 4)
    }
}

private extension View {
    func dailyClosureSurface() -> some View {
        modifier(DailyClosureSurfaceModifier())
    }

    func dailyClosureHeroSurface() -> some View {
        modifier(DailyClosureSurfaceModifier(isHero: true))
    }
}

private struct TodayStatsView: View {
    let report: BusinessDailyReport?
    let sales: [BusinessSale]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TodayMetricCard(
                        title: "Ventas",
                        value: String(salesCount),
                        subtitle: "registradas",
                        systemImage: "cart.fill",
                        prominence: .standard
                    )

                    TodayMetricCard(
                        title: "Total vendido",
                        value: salesTotal.displayText,
                        subtitle: "ventas activas",
                        systemImage: "chart.line.uptrend.xyaxis",
                        prominence: .highlight
                    )
                }

                HStack(spacing: 10) {
                    TodayMetricCard(
                        title: "Cobrado",
                        value: paymentsTotal.displayText,
                        subtitle: "pagos recibidos",
                        systemImage: "dollarsign.circle.fill",
                        prominence: .highlight
                    )

                    TodayMetricCard(
                        title: "Caja",
                        value: cashExpectedAmount.displayText,
                        subtitle: "efectivo esperado",
                        systemImage: "banknote.fill",
                        prominence: .standard
                    )
                }

                HStack(spacing: 10) {
                    TodayMetricCard(
                        title: "Pagos",
                        value: String(paymentsCount),
                        subtitle: "registrados",
                        systemImage: "creditcard.fill",
                        prominence: .quiet
                    )

                    TodayMetricCard(
                        title: "Productos",
                        value: productSummaryText,
                        subtitle: productSummarySubtitle,
                        systemImage: "shippingbox.fill",
                        prominence: .quiet
                    )
                }

                HStack(spacing: 10) {
                    TodayMetricCard(
                        title: "Documentos",
                        value: String(documentsPendingCount),
                        subtitle: "pendientes",
                        systemImage: "doc.text.fill",
                        prominence: documentsPendingCount > 0 ? .warning : .quiet
                    )

                    TodayMetricCard(
                        title: "Alertas",
                        value: String(alertsCount),
                        subtitle: alertsSubtitle,
                        systemImage: "bell.badge.fill",
                        prominence: alertsCount > 0 ? .warning : .quiet
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

    private var paymentsCount: Int {
        report?.paymentsCount ?? report?.paymentSummary?.count ?? 0
    }

    private var productSummaryText: String {
        if let topCount = report?.productSummary?.topProducts.count, topCount > 0 {
            return String(topCount)
        }

        if let lowStockCount = report?.productSummary?.lowStockCount, lowStockCount > 0 {
            return String(lowStockCount)
        }

        if let movementCount = report?.productSummary?.movementCount, movementCount > 0 {
            return String(movementCount)
        }

        return "0"
    }

    private var productSummarySubtitle: String {
        if let topCount = report?.productSummary?.topProducts.count, topCount > 0 {
            return topCount == 1 ? "top producto" : "top productos"
        }

        if let lowStockCount = report?.productSummary?.lowStockCount, lowStockCount > 0 {
            return lowStockCount == 1 ? "bajo stock" : "bajo stock"
        }

        if let movementCount = report?.productSummary?.movementCount, movementCount > 0 {
            return movementCount == 1 ? "movimiento" : "movimientos"
        }

        return "sin movimiento"
    }

    private var documentsPendingCount: Int {
        report?.pendingDocumentsCount ?? report?.documentSummary?.pendingCount ?? 0
    }

    private var alertsCount: Int {
        report?.alerts.count ?? 0
    }

    private var alertsSubtitle: String {
        alertsCount == 1 ? "importante" : "importantes"
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

private enum TodayMetricProminence {
    case highlight
    case standard
    case quiet
    case warning

    var tint: Color {
        switch self {
        case .highlight:
            return .accentColor
        case .standard:
            return .secondary
        case .quiet:
            return .secondary
        case .warning:
            return .orange
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .highlight:
            return 0.10
        case .standard:
            return 0.055
        case .quiet:
            return 0.035
        case .warning:
            return 0.10
        }
    }
}

private struct TodayMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let prominence: TodayMetricProminence

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(prominence.tint)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(prominence.tint.opacity(prominence.backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        )
    }
}

private struct CashTodaySummaryView: View {
    let session: CashSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                DailyIconBadge(systemImage: session.isOpen ? "checkmark.circle.fill" : "lock.fill", tint: session.isOpen ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.isOpen ? "Caja abierta" : "Caja cerrada")
                        .font(.headline)

                    Text(session.isOpen ? "Lista para operar y registrar cobros." : "El turno de caja ya fue cerrado.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                DailyStatusPill(
                    title: session.isOpen ? "Abierta" : "Cerrada",
                    systemImage: session.isOpen ? "checkmark" : "lock",
                    tint: session.isOpen ? .green : .secondary
                )
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
                DailyIconBadge(
                    systemImage: hasPendingWork ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    tint: hasPendingWork ? .orange : .green
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(hasPendingWork ? "Pendientes antes de cerrar" : "Día listo para cierre")
                        .font(.headline)

                    Text(hasPendingWork ? "Hay trabajo operativo que conviene revisar." : "No hay pendientes visibles para este día.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                DailyStatusPill(
                    title: hasPendingWork ? "Revisar" : "Listo",
                    systemImage: hasPendingWork ? "exclamationmark" : "checkmark",
                    tint: hasPendingWork ? .orange : .green
                )
            }

            VStack(spacing: 10) {
                DailyInfoRow(
                    title: "Ventas pendientes",
                    value: String(pendingSalesCount),
                    systemImage: "cart.badge.clock"
                )

                DailyInfoRow(
                    title: "Por cobrar",
                    value: String(pendingReceivablesCount),
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )

                DailyInfoRow(
                    title: "Comprobantes",
                    value: String(pendingDocumentsCount),
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
    }
}

private struct PendingSaleRow: View {
    let sale: BusinessSale

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DailyIconBadge(systemImage: "cart.badge.clock", tint: .accentColor)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Venta \(sale.displayNumber)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Spacer(minLength: 8)

                    Text(money(sale.totals.grandTotal))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(sale.displayCustomerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    DailySmallBadge(
                        text: SaleStatusPresentation.title(for: sale.status),
                        systemImage: "tag"
                    )

                    DailySmallBadge(
                        text: sale.collectionState.shortName,
                        systemImage: sale.collectionState.systemImage
                    )
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct PendingReceivableRow: View {
    let receivable: ReceivableRecord

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DailyIconBadge(systemImage: "person.crop.circle.badge.clock", tint: .orange)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Cuenta \(receivable.id)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 8)

                    Text(money(receivable.balance ?? receivable.amount))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
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

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private func money(_ amount: MoneyAmount) -> String {
        amount.displayText
    }
}

private struct PendingDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DailyIconBadge(systemImage: BusinessDocumentTypePresentation.systemImage(document.type), tint: .green)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(BusinessDocumentTypePresentation.displayName(document.type))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    DailyStatusPill(
                        title: BusinessDocumentStatusPresentation.displayName(document.status),
                        systemImage: "doc.text",
                        tint: .secondary
                    )
                }

                if let number = document.number, !number.isEmpty {
                    Text(number)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Venta \(document.saleId)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct DailySectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DailyIconBadge(systemImage: icon, tint: .accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DailyNavigationActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            DailyIconBadge(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        )
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
            return .accentColor
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .info:
            return 0.08
        case .warning:
            return 0.10
        case .error:
            return 0.09
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
            DailyIconBadge(systemImage: icon, tint: style.color)

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
        .padding(12)
        .background(style.color.opacity(style.backgroundOpacity), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DailySmallBadge: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))
    }
}

private struct DailyStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.11), in: Capsule(style: .continuous))
    }
}

private struct DailyIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct DailyCompactFact: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DailyInlineFootnote: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DailyEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
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
