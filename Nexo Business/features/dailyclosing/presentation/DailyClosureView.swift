//
//  DailyClosureView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct DailyClosureView: View {
    @Bindable private var viewModel: DailyClosureViewModel
    private let salesRepository: SalesRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    public init(
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

    public var body: some View {
        Form {
            dateSection
            reportSection
            cashSection
            pendingSalesSection
            pendingReceivablesSection
            pendingDocumentsSection
            messagesSection
        }
        .navigationTitle("Cierre diario")
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

            LabeledContent("Fecha de cierre", value: viewModel.selectedBusinessDateString)
        }
    }

    @ViewBuilder
    private var reportSection: some View {
        Section("Reporte diario") {
            switch viewModel.reportState {
            case .idle, .loading:
                ProgressView("Cargando reporte…")

            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)

            case let .loaded(report):
                if let report {
                    DailyReportSummaryView(report: report)
                } else {
                    ContentUnavailableView(
                        "Sin reporte",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Aún no hay información para este día.")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var cashSection: some View {
        Section("Caja") {
            switch viewModel.cashState {
            case .idle, .loading:
                ProgressView("Consultando caja…")

            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)

            case let .loaded(session):
                if let session {
                    CashDailySummaryView(session: session)

                    NavigationLink {
                        CashDashboardView(
                            viewModel: CashDashboardViewModel(
                                organizationId: viewModel.organizationId,
                                branchId: viewModel.branchId,
                                permissions: viewModel.effectivePermissions,
                                cashRepository: cashRepository
                            )
                        )
                    } label: {
                        Label(
                            viewModel.canCloseCash ? "Ir a cierre de caja" : "Ver caja operativa",
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
                                cashRepository: cashRepository
                            )
                        )
                    } label: {
                        Label("Abrir o revisar caja", systemImage: "tray")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pendingSalesSection: some View {
        Section("Ventas pendientes") {
            if viewModel.pendingSales.isEmpty {
                Label("Sin ventas pendientes", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
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
        Section("Cuentas por cobrar") {
            if viewModel.pendingReceivables.isEmpty {
                Label("Sin cuentas por cobrar pendientes", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
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
        Section("Comprobantes por revisar") {
            if viewModel.pendingDocuments.isEmpty {
                Label("Sin comprobantes pendientes o rechazados", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
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

private struct DailyReportSummaryView: View {
    let report: BusinessDailyReport

    var body: some View {
        LabeledContent("Fecha", value: report.businessDate)

        if let salesCount = report.salesCount {
            LabeledContent("Ventas", value: "\(salesCount)")
        }

        if let salesTotal = report.salesTotal {
            LabeledContent("Total ventas", value: money(salesTotal))
        }

        if let paymentsCount = report.paymentsCount {
            LabeledContent("Cobros", value: "\(paymentsCount)")
        }

        if let paymentsTotal = report.paymentsTotal {
            LabeledContent("Total cobrado", value: money(paymentsTotal))
        }

        if let cashExpectedAmount = report.cashExpectedAmount {
            LabeledContent("Esperado en caja", value: money(cashExpectedAmount))
        }

        if let receivablesPendingCount = report.receivablesPendingCount {
            LabeledContent("Cuentas pendientes", value: "\(receivablesPendingCount)")
        }

        if let receivablesPendingTotal = report.receivablesPendingTotal {
            LabeledContent("Saldo por cobrar", value: money(receivablesPendingTotal))
        }

        if let pendingDocumentsCount = report.pendingDocumentsCount {
            LabeledContent("Comprobantes por revisar", value: "\(pendingDocumentsCount)")
        }
    }

    private func money(_ amount: MoneyAmount) -> String {
        "\(amount.currency) \(amount.amount)"
    }
}

private struct CashDailySummaryView: View {
    let session: CashSession

    var body: some View {
        LabeledContent("Estado", value: session.status)

        if let openingAmount = session.openingAmount {
            LabeledContent("Apertura", value: money(openingAmount))
        }

        if let expectedAmount = session.expectedAmount {
            LabeledContent("Esperado", value: money(expectedAmount))
        }

        if let countedAmount = session.countedAmount {
            LabeledContent("Contado", value: money(countedAmount))
        }

        if let differenceAmount = session.differenceAmount {
            LabeledContent("Diferencia", value: money(differenceAmount))
        }
    }

    private func money(_ amount: MoneyAmount) -> String {
        "\(amount.currency) \(amount.amount)"
    }
}

private struct PendingSaleRow: View {
    let sale: BusinessSale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Venta \(sale.id)")
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
        "\(amount.currency) \(amount.amount)"
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
        "\(amount.currency) \(amount.amount)"
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
