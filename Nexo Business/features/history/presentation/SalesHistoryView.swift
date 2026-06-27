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
    private let customersRepository: CustomersRepository
    private let catalogRepository: CatalogRepository?
    private let contextRepository: BusinessContextRepository?
    private let verticalContext: BusinessVerticalContext
    private let salesHistoryRepository: SalesHistoryRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    @State private var pendingSearchTask: Task<Void, Never>?

    init(
        viewModel: SalesHistoryViewModel,
        salesRepository: SalesRepository,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        catalogRepository: CatalogRepository? = nil,
        contextRepository: BusinessContextRepository? = nil,
        verticalContext: BusinessVerticalContext = .empty,
        salesHistoryRepository: SalesHistoryRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.salesRepository = salesRepository
        self.customersRepository = customersRepository
        self.catalogRepository = catalogRepository
        self.contextRepository = contextRepository
        self.verticalContext = verticalContext
        self.salesHistoryRepository = salesHistoryRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                filtersSection
                    .salesHistoryHeroSurface()

                if hasMessages {
                    messagesSection
                        .salesHistorySurface()
                }

                summarySection
                    .salesHistorySurface()

                resultsSection
                    .salesHistorySurface()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Historial")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshButton
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
    }

    private var refreshButton: some View {
        Button {
            NexoKeyboard.dismiss()
            Task { await viewModel.searchNow() }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(!viewModel.canSearch)
        .accessibilityLabel("Actualizar historial")
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                SalesHistoryIconBadge(systemImage: "clock.arrow.circlepath", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Historial comercial")
                        .font(.headline)

                    Text("Busca ventas, clientes, comprobantes o valores registrados.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if hasActiveFilters {
                    Button {
                        viewModel.clearFilters()
                        NexoKeyboard.dismiss()
                        runSearchNow()
                    } label: {
                        Text("Limpiar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.10), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Limpiar filtros")
                }
            }

            searchField
            statusFilter
            dateFilter
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
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

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
        .padding(.vertical, 11)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var statusFilter: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Estado")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(SalesHistoryStatusFilter.groupedSections) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(group.filters) { status in
                                    statusChip(status)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private func statusChip(_ status: SalesHistoryStatusFilter) -> some View {
        let isSelected = viewModel.selectedStatus == status

        return Button {
            viewModel.selectedStatus = status
        } label: {
            Text(status.displayName)
                .font(.footnote.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                            ? Color.accentColor.opacity(0.13)
                            : Color(uiColor: .secondarySystemBackground).opacity(0.75)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            isSelected
                            ? Color.accentColor.opacity(0.38)
                            : Color.primary.opacity(0.05),
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
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
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
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SalesHistorySectionHeader(
                icon: "chart.bar.doc.horizontal",
                title: "Resumen del historial",
                subtitle: "Vista rápida de la búsqueda actual."
            )

            VStack(spacing: 10) {
                SalesHistoryInfoRow(
                    title: "Filtros activos",
                    value: viewModel.activeFiltersDescription,
                    systemImage: "slider.horizontal.3"
                )

                SalesHistoryInfoRow(
                    title: totalTitle,
                    value: String(totalValue),
                    systemImage: "receipt"
                )
            }

            if viewModel.hasMore == true {
                SalesHistoryNoticeCard(
                    icon: "info.circle",
                    title: "Hay más resultados",
                    message: "Refina la búsqueda por texto, estado o fecha para trabajar con una lista más precisa.",
                    tint: .accentColor
                )
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SalesHistorySectionHeader(
                icon: "list.bullet.rectangle.portrait",
                title: "Ventas",
                subtitle: resultsSubtitle
            )

            if viewModel.isLoading && viewModel.sales.isEmpty {
                SalesHistoryLoadingCard(
                    title: "Buscando ventas…",
                    subtitle: "Estamos aplicando los filtros seleccionados."
                )
            } else if viewModel.sales.isEmpty {
                ContentUnavailableView(
                    "Sin ventas",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Prueba con otro texto, estado o fecha.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.sales) { sale in
                        NavigationLink {
                            SaleDetailView(
                                viewModel: viewModel.makeSaleDetailViewModel(
                                    for: sale,
                                    salesRepository: salesRepository
                                ),
                                customersRepository: customersRepository,
                                catalogRepository: catalogRepository,
                                contextRepository: contextRepository,
                                verticalContext: verticalContext,
                                salesHistoryRepository: salesHistoryRepository,
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message = viewModel.errorMessage, !message.isEmpty {
                SalesHistoryNoticeCard(
                    icon: "exclamationmark.triangle",
                    title: "Atención",
                    message: message,
                    tint: .red
                )
            }

            if let message = viewModel.infoMessage, !message.isEmpty {
                SalesHistoryNoticeCard(
                    icon: "info.circle",
                    title: "Información",
                    message: message,
                    tint: .accentColor
                )
            }
        }
    }

    private var hasMessages: Bool {
        (viewModel.errorMessage?.isEmpty == false) ||
        (viewModel.infoMessage?.isEmpty == false)
    }

    private var totalTitle: String {
        viewModel.total == nil ? "Ventas visibles" : "Ventas encontradas"
    }

    private var totalValue: Int {
        viewModel.total ?? viewModel.sales.count
    }

    private var resultsSubtitle: String {
        if hasActiveFilters {
            return "Resultados según la búsqueda actual."
        }

        return "Últimas ventas registradas en el negocio."
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

private struct SalesHistorySurfaceModifier: ViewModifier {
    var isHero: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(isHero ? 18 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isHero {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.16),
                            Color(uiColor: .secondarySystemGroupedBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: isHero ? 26 : 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(isHero ? 0.07 : 0.035),
                radius: isHero ? 14 : 8,
                x: 0,
                y: isHero ? 8 : 4
            )
    }
}

private extension View {
    func salesHistorySurface() -> some View {
        modifier(SalesHistorySurfaceModifier())
    }

    func salesHistoryHeroSurface() -> some View {
        modifier(SalesHistorySurfaceModifier(isHero: true))
    }
}

private struct SalesHistoryRow: View {
    let sale: BusinessSale
    let document: BusinessDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 12) {
                SalesHistoryIconBadge(systemImage: "receipt", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text(sale.displayNumber)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(sale.displayCustomerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(sale.totals.grandTotal.displayText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()

                    if let createdAt = sale.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
            }

            if !sale.displayItemsSummary.isEmpty {
                Text(sale.displayItemsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let document {
                SalesHistoryDocumentLine(document: document)
            }

            HStack(spacing: 8) {
                SaleStatusLabel(status: sale.status)

                SalesHistoryCollectionStatusBadge(state: sale.collectionState)

                SalesHistoryDocumentStatusBadge(
                    status: document?.effectiveStatus ?? sale.effectiveDocumentStatus,
                    hasDocument: document != nil || sale.hasElectronicDocumentRegistered
                )
            }
            .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct SalesHistoryDocumentLine: View {
    let document: BusinessDocument

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(document.businessDisplayNumber)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                Text("· \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}

private struct SalesHistorySectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SalesHistoryIconBadge(systemImage: icon, tint: .accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SalesHistoryInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SalesHistoryNoticeCard: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct SalesHistoryLoadingCard: View {
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

private struct SalesHistoryIconBadge: View {
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

private struct SalesHistoryCollectionStatusBadge: View {
    let state: SaleCollectionState

    var body: some View {
        Label(state.displayName, systemImage: state.systemImage)
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch state {
        case .paid:
            return .green
        case .realReceivable, .partialWithoutReceivable, .unpaidSavedSale:
            return .orange
        case .receivableNeedsReview, .unknown:
            return .red
        case .cancelled:
            return .secondary
        }
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
