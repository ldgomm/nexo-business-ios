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
        Form {
            filtersSection
            summarySection
            resultsSection
            messagesSection
        }
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

    private var filtersSection: some View {
        Section("Buscar") {
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

            Toggle("Filtrar por fecha", isOn: $viewModel.useDateFilter)

            if viewModel.useDateFilter {
                DatePicker(
                    "Fecha",
                    selection: $viewModel.selectedDate,
                    displayedComponents: [.date]
                )
            }

            HStack {
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
                .disabled(!viewModel.canSearch)

                Button("Limpiar") {
                    viewModel.clearFilters()
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var summarySection: some View {
        Section("Resumen") {
            LabeledContent("Filtros", value: viewModel.activeFiltersDescription)

            if let total = viewModel.total {
                LabeledContent("Ventas encontradas", value: String(total))
            } else {
                LabeledContent("Ventas", value: String(viewModel.sales.count))
            }

            if viewModel.hasMore == true {
                NexoMessageBanner(
                    "Hay más ventas disponibles. Refina la búsqueda para ver menos resultados.",
                    style: .info
                )
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
                        SalesHistoryRow(sale: sale)
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
}

private struct SalesHistoryRow: View {
    let sale: BusinessSale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(sale.displayNumber)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(sale.displayCustomerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(sale.totals.grandTotal.displayText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }

            if !sale.displayItemsSummary.isEmpty {
                Text(sale.displayItemsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                SaleStatusLabel(status: sale.status)

                Label(PaymentStatusPresentation.displayName(sale.paymentStatus), systemImage: "dollarsign.circle")

                if let documentStatus = sale.documentStatus {
                    Label(BusinessDocumentStatusPresentation.displayName(documentStatus), systemImage: "doc.text")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let createdAt = sale.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
                historyRepository: PreviewSalesHistoryRepository(),
                documentsRepository: PreviewBusinessDocumentsRepository()
            ),
            salesRepository: PreviewSalesRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}
