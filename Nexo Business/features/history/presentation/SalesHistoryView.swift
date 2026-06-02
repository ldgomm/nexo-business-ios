//
//  SalesHistoryView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI

struct SalesHistoryView: View {
    @Bindable private var viewModel: SalesHistoryViewModel
    private let salesRepository: SalesRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    @State private var showsFilters = false

    init(
        viewModel: SalesHistoryViewModel,
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
        List {
            summaryHeaderSection
            filtersSection
            resultsSection
            messagesSection
        }
        .listStyle(.insetGrouped)
        .nexoKeyboardDismissable()
        .navigationTitle("Historial")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!viewModel.canSearch)
            }
        }
        .task {
            if viewModel.sales.isEmpty && viewModel.errorMessage == nil {
                await viewModel.load()
            }
        }
    }

    private var summaryHeaderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ventas encontradas")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(String(viewModel.total ?? viewModel.sales.count))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total listado")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(totalSalesAmount.displayText)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                }

                HStack(spacing: 8) {
                    NexoHistoryFilterChip(
                        title: viewModel.useDateFilter
                            ? viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted)
                            : "Todas las fechas",
                        systemImage: "calendar"
                    )

                    if viewModel.selectedStatus != .all {
                        NexoHistoryFilterChip(
                            title: viewModel.selectedStatus.displayName,
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }

                    if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        NexoHistoryFilterChip(title: "Texto", systemImage: "magnifyingglass")
                    }
                }

                if viewModel.hasMore == true {
                    Text("Hay más ventas disponibles. Refina la búsqueda para ver menos resultados.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var filtersSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showsFilters) {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Venta, cliente o referencia", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit {
                            NexoKeyboard.dismiss()
                            Task { await viewModel.load() }
                        }

                    Picker("Estado", selection: $viewModel.selectedStatus) {
                        ForEach(SalesHistoryStatusFilter.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Filtrar por fecha", isOn: $viewModel.useDateFilter)

                    if viewModel.useDateFilter {
                        DatePicker(
                            "Fecha",
                            selection: $viewModel.selectedDate,
                            displayedComponents: [.date]
                        )
                    }

                    HStack(spacing: 12) {
                        Button {
                            NexoKeyboard.dismiss()
                            Task { await viewModel.load() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Label("Buscar", systemImage: "magnifyingglass")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canSearch)

                        Button("Limpiar") {
                            viewModel.clearFilters()
                            NexoKeyboard.dismiss()
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Label("Filtros", systemImage: "slider.horizontal.3")
                    Spacer()
                    Text(viewModel.activeFiltersDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section("Ventas") {
            if viewModel.isLoading && viewModel.sales.isEmpty {
                ProgressView("Buscando ventas…")
            } else if viewModel.sales.isEmpty {
                ContentUnavailableView(
                    "Sin ventas",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Ajusta los filtros o cambia la fecha.")
                )
            } else {
                ForEach(viewModel.sales) { sale in
                    NavigationLink {
                        SaleDetailView(
                            viewModel: viewModel.makeSaleDetailViewModel(
                                for: sale,
                                salesRepository: salesRepository
                            ),
                            cashRepository: cashRepository,
                            paymentsRepository: paymentsRepository,
                            receivablesRepository: receivablesRepository,
                            documentsRepository: documentsRepository
                        )
                    } label: {
                        SalesHistoryCompactRow(sale: sale)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                NexoMessageBanner(message, style: .error)
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                NexoMessageBanner(message, style: .info)
            }
        }
    }

    private var totalSalesAmount: MoneyAmount {
        let total = viewModel.sales.reduce(Decimal(0)) { partial, sale in
            partial + (Decimal(string: sale.totals.grandTotal.amount, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(0))
        }
        return MoneyAmount(amount: format(total))
    }

    private func format(_ decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        return String(format: "%.2f", number.doubleValue)
    }
}

private struct SalesHistoryCompactRow: View {
    let sale: BusinessSale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sale.compactDisplayNumber)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)

                    Text(sale.displayCustomerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(sale.totals.grandTotal.displayText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if !sale.displayItemsSummary.isEmpty {
                Text(sale.displayItemsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                NexoHistoryFilterChip(
                    title: SaleStatusPresentation.title(for: sale.status),
                    systemImage: SaleStatusPresentation.systemImage(for: sale.status)
                )

                NexoHistoryFilterChip(
                    title: PaymentStatusPresentation.displayName(sale.paymentStatus),
                    systemImage: "dollarsign.circle"
                )

                if let documentStatus = sale.documentStatus {
                    NexoHistoryFilterChip(
                        title: BusinessDocumentStatusPresentation.displayName(documentStatus),
                        systemImage: "doc.text"
                    )
                }
            }

            if let createdAt = sale.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct NexoHistoryFilterChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        SalesHistoryView(
            viewModel: SalesHistoryViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                revisions: PreviewData.businessContext.revisions,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                historyRepository: PreviewSalesHistoryRepository()
            ),
            salesRepository: PreviewSalesRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}
