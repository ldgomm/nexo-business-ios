//
//  SalesHistoryView.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import SwiftUI

struct SalesHistoryView: View {
    @Bindable private var viewModel: SalesHistoryViewModel
    private let salesRepository: SalesRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    @State private var pendingSearchTask: Task<Void, Never>?
    
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
                    Task { await viewModel.searchNow() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!viewModel.canSearch)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            Task { await viewModel.refreshOnAppear() }
        }
        .refreshable {
            await viewModel.searchNow()
        }
        .onChange(of: viewModel.query) { _, _ in
            viewModel.scheduleSearch()
        }
        .onChange(of: viewModel.selectedStatus) { _, _ in
            viewModel.scheduleSearch()
        }
        .onChange(of: viewModel.useDateFilter) { _, _ in
            viewModel.scheduleSearch()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            viewModel.scheduleSearch()
        }
    }

    private var filtersSection: some View {
        Section {
            searchField
            statusFilter
            dateFilter
        } header: {
            HStack {
                Text("Filtros")

                Spacer()

                if hasActiveFilters {
                    Button {
                        viewModel.clearFilters()
                        NexoKeyboard.dismiss()
                        runSearchNow()
                    } label: {
                        Text("Limpiar")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Limpiar filtros")
                }
            }
        }
        .onChange(of: viewModel.query) { _, _ in
            scheduleSearch()
        }
        .onChange(of: viewModel.selectedStatus) { _, _ in
            runSearchNow()
        }
        .onChange(of: viewModel.useDateFilter) { _, _ in
            runSearchNow()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            guard viewModel.useDateFilter else { return }
            runSearchNow()
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Venta, cliente, factura o valor", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    NexoKeyboard.dismiss()
                    runSearchNow()
                }

            if hasQueryFilter {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpiar texto de búsqueda")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var statusFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estado")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SalesHistoryStatusFilter.allCases) { status in
                        statusChip(status)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusChip(_ status: SalesHistoryStatusFilter) -> some View {
        let isSelected = viewModel.selectedStatus == status

        return Button {
            viewModel.selectedStatus = status
        } label: {
            Text(status.displayName)
                .font(.footnote.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                            ? Color.accentColor.opacity(0.12)
                            : Color(.secondarySystemBackground)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            isSelected
                            ? Color.accentColor.opacity(0.45)
                            : Color(.separator),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var dateFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $viewModel.useDateFilter) {
                Label("Filtrar por fecha", systemImage: "calendar")
            }

            if viewModel.useDateFilter {
                DatePicker(
                    "Fecha",
                    selection: $viewModel.selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
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
                    description: Text("Prueba con otro texto, estado o fecha.")
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
                            documentsRepository: documentsRepository,
                            onSaleUpdated: { updatedSale in
                                viewModel.applySaleUpdate(updatedSale)
                            }
                        )
                    } label: {
                        SalesHistoryRow(sale: sale, document: viewModel.primaryDocument(for: sale))
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
    
    private var hasActiveFilters: Bool {
        !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        viewModel.selectedStatus != .all ||
        viewModel.useDateFilter
    }

    private var hasQueryFilter: Bool {
        !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scheduleSearch() {
        pendingSearchTask?.cancel()

        pendingSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)

            guard !Task.isCancelled else { return }

            await viewModel.searchNow()
        }
    }

    private func runSearchNow() {
        pendingSearchTask?.cancel()

        Task {
            await viewModel.searchNow()
        }
    }
}

private struct SalesHistoryRow: View {
    let sale: BusinessSale
    let document: BusinessDocument?

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

            if let document {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text(document.businessDisplayNumber)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                        Text("· \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 10) {
                SaleStatusLabel(status: sale.status)

                Label(PaymentStatusPresentation.displayName(sale.paymentStatus), systemImage: "dollarsign.circle")

                SalesHistoryDocumentStatusBadge(
                    status: document?.effectiveStatus ?? sale.effectiveDocumentStatus,
                    hasDocument: document != nil || sale.hasElectronicDocumentRegistered
                )
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

private struct SalesHistoryDocumentStatusBadge: View {
    let status: String?
    let hasDocument: Bool

    var body: some View {
        Label(title, systemImage: BusinessDocumentStatusPresentation.systemImage(effectiveStatus))
            .foregroundStyle(tint)
    }

    private var effectiveStatus: String {
        status ?? "not_required"
    }

    private var title: String {
        guard hasDocument, !BusinessDocumentStatusPresentation.isMissingElectronicDocument(status) else {
            return "Sin factura"
        }

        if BusinessDocumentStatusPresentation.isAuthorized(effectiveStatus) {
            return "Facturada"
        }

        if BusinessDocumentStatusPresentation.isError(effectiveStatus) {
            return "Fallida"
        }

        return "Pendiente SRI"
    }

    private var tint: Color {
        guard hasDocument, !BusinessDocumentStatusPresentation.isMissingElectronicDocument(status) else {
            return .secondary
        }

        if BusinessDocumentStatusPresentation.isError(effectiveStatus) {
            return .red
        }

        if BusinessDocumentStatusPresentation.isAuthorized(effectiveStatus) {
            return .green
        }

        return .orange
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
