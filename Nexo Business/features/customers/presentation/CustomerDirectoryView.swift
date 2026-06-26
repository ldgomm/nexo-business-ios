//
//  CustomerDirectoryView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct CustomerDirectoryView: View {
    @Bindable private var viewModel: CustomerDirectoryViewModel
    private let branchId: String?
    private let revisions: BusinessRevisions?
    private let salesHistoryRepository: SalesHistoryRepository?
    private let salesRepository: SalesRepository?
    private let cashRepository: CashRepository?
    private let paymentsRepository: PaymentsRepository?
    private let receivablesRepository: ReceivablesRepository?
    private let documentsRepository: BusinessDocumentsRepository?

    init(
        viewModel: CustomerDirectoryViewModel,
        branchId: String? = nil,
        revisions: BusinessRevisions? = nil,
        salesHistoryRepository: SalesHistoryRepository? = nil,
        salesRepository: SalesRepository? = nil,
        cashRepository: CashRepository? = nil,
        paymentsRepository: PaymentsRepository? = nil,
        receivablesRepository: ReceivablesRepository? = nil,
        documentsRepository: BusinessDocumentsRepository? = nil
    ) {
        self.viewModel = viewModel
        self.branchId = branchId
        self.revisions = revisions
        self.salesHistoryRepository = salesHistoryRepository
        self.salesRepository = salesRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                directoryHeroSection
                messagesSection
                searchSection

                if viewModel.canCreate {
                    createSection
                }

                customersSection
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .nexoKeyboardDismissable()
        .navigationTitle("Clientes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Actualizar clientes")
            }
        }
        .refreshable {
            await viewModel.search()
        }
        .task {
            if viewModel.customers.isEmpty {
                await viewModel.load()
            }
        }
    }

    private var directoryHeroSection: some View {
        CustomerExecutiveCard(
            title: "Directorio comercial",
            subtitle: "Clientes reales para ventas identificadas, proformas, crédito, historial y comprobantes.",
            systemImage: "person.2.fill",
            isHero: true,
            usesGradient: true
        ) {
            LazyVGrid(columns: metricColumns, spacing: 10) {
                CustomerExecutiveMetricCard(
                    title: "Clientes",
                    value: String(viewModel.customers.count),
                    subtitle: "visibles",
                    systemImage: "person.2"
                )

                CustomerExecutiveMetricCard(
                    title: "Filtro",
                    value: hasActiveQuery ? "Activo" : "Libre",
                    subtitle: hasActiveQuery ? "búsqueda aplicada" : "sin búsqueda",
                    systemImage: hasActiveQuery ? "line.3.horizontal.decrease.circle" : "sparkles"
                )
            }
        }
    }

    private var searchSection: some View {
        CustomerExecutiveCard(
            title: "Buscar",
            subtitle: "Encuentra clientes por nombre, cédula, RUC, teléfono o correo.",
            systemImage: "magnifyingglass"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    TextField("Nombre, cédula, RUC o correo", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit {
                            NexoKeyboard.dismiss()
                            Task { await viewModel.search() }
                        }

                    if hasActiveQuery {
                        Button {
                            viewModel.query = ""
                            NexoKeyboard.dismiss()
                            Task { await viewModel.search() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Limpiar búsqueda")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 10) {
                    Text("Usa búsqueda antes de crear: reduce duplicados y mantiene limpio el historial 360.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Button {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.search() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Buscar", systemImage: "magnifyingglass")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(viewModel.isLoading || !viewModel.canView)
                }
            }
        }
    }

    private var createSection: some View {
        CustomerExecutiveCard(
            title: "Alta de cliente",
            subtitle: "Registra cliente real para ventas, proformas, crédito y comprobantes.",
            systemImage: "person.badge.plus"
        ) {
            NavigationLink {
                CustomerCreateView(
                    viewModel: CustomerCreateViewModel(
                        organizationId: viewModel.organizationId,
                        customersRepository: viewModel.customersRepository
                    ),
                    onCreated: { customer in
                        viewModel.addOrReplace(customer)
                    }
                )
            } label: {
                CustomerExecutiveActionRow(
                    title: "Nuevo cliente",
                    subtitle: "Crear ficha comercial y fiscal",
                    systemImage: "person.badge.plus"
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var customersSection: some View {
        CustomerExecutiveCard(
            title: "Clientes",
            subtitle: customersSubtitle,
            systemImage: "person.text.rectangle"
        ) {
            if viewModel.isLoading && viewModel.customers.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando clientes…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.customers.isEmpty {
                ContentUnavailableView(
                    "Sin clientes",
                    systemImage: "person.text.rectangle",
                    description: Text("Crea o busca clientes para ventas identificadas, crédito y comprobantes.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.customers) { customer in
                        if let detailViewModel = makeCustomerDetailViewModel(for: customer),
                           let salesRepository,
                           let cashRepository,
                           let paymentsRepository,
                           let receivablesRepository,
                           let documentsRepository {
                            NavigationLink {
                                CustomerDetail360View(
                                    viewModel: detailViewModel,
                                    salesRepository: salesRepository,
                                    cashRepository: cashRepository,
                                    paymentsRepository: paymentsRepository,
                                    receivablesRepository: receivablesRepository,
                                    documentsRepository: documentsRepository
                                )
                            } label: {
                                CustomerRowView(customer: customer, showsAccessory: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            CustomerRowView(customer: customer)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            CustomerExecutiveNoticeCard(
                title: "No se pudo cargar clientes",
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
        }

        if let message = viewModel.infoMessage {
            CustomerExecutiveNoticeCard(
                title: "Información",
                message: message,
                systemImage: "info.circle",
                tint: .secondary
            )
        }
    }

    private var customersSubtitle: String {
        if viewModel.customers.isEmpty {
            return "Resultados del directorio."
        }

        return viewModel.customers.count == 1 ? "1 cliente visible" : "\(viewModel.customers.count) clientes visibles"
    }

    private var hasActiveQuery: Bool {
        !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private func makeCustomerDetailViewModel(for customer: BusinessCustomer) -> CustomerDetail360ViewModel? {
        guard customer.identificationType != .finalConsumer else { return nil }
        guard let branchId,
              let revisions,
              let salesHistoryRepository,
              let receivablesRepository,
              let documentsRepository else {
            return nil
        }

        return CustomerDetail360ViewModel(
            organizationId: viewModel.organizationId,
            branchId: branchId,
            revisions: revisions,
            customer: customer,
            effectivePermissions: viewModel.effectivePermissions,
            salesHistoryRepository: salesHistoryRepository,
            receivablesRepository: receivablesRepository,
            documentsRepository: documentsRepository
        )
    }
}

struct CustomerDetail360View: View {
    @Bindable private var viewModel: CustomerDetail360ViewModel
    private let salesRepository: SalesRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    init(
        viewModel: CustomerDetail360ViewModel,
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
                customerHeroSection
                messagesSection
                summarySection
                pilotGuidanceSection
                receivablesSection
                salesSection
                documentsSection
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
                .accessibilityLabel("Actualizar cliente")
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }

    private var customerHeroSection: some View {
        CustomerExecutiveCard(
            title: viewModel.customer.displayName,
            subtitle: BusinessCustomerPresentation.subtitle(for: viewModel.customer),
            systemImage: "person.text.rectangle",
            isHero: true,
            usesGradient: true
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    CustomerExecutivePill(
                        title: viewModel.hasOpenReceivables ? "Saldo pendiente" : "Sin deuda abierta",
                        systemImage: viewModel.hasOpenReceivables ? "person.crop.circle.badge.clock" : "checkmark.circle",
                        tint: viewModel.hasOpenReceivables ? .orange : .green
                    )

                    CustomerExecutivePill(
                        title: "360",
                        systemImage: "scope",
                        tint: .accentColor
                    )
                }

                if let address = viewModel.customer.address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
                    CustomerExecutiveInfoRow(
                        title: "Dirección",
                        value: address,
                        systemImage: "mappin.and.ellipse"
                    )
                }
            }
        }
    }

    private var summarySection: some View {
        CustomerExecutiveCard(
            title: "Resumen 360",
            subtitle: "Ventas, deuda, última compra y comprobantes asociados.",
            systemImage: "chart.bar.doc.horizontal"
        ) {
            LazyVGrid(columns: metricColumns, spacing: 10) {
                CustomerExecutiveMetricCard(
                    title: "Saldo",
                    value: viewModel.pendingBalanceDisplay,
                    subtitle: "pendiente",
                    systemImage: "person.crop.circle.badge.clock",
                    tint: viewModel.hasOpenReceivables ? .orange : .green
                )

                CustomerExecutiveMetricCard(
                    title: "Cuentas",
                    value: String(viewModel.openReceivables.count),
                    subtitle: "abiertas",
                    systemImage: "creditcard"
                )

                CustomerExecutiveMetricCard(
                    title: "Ventas",
                    value: String(viewModel.sales.count),
                    subtitle: "registradas",
                    systemImage: "cart"
                )

                CustomerExecutiveMetricCard(
                    title: "Vendido",
                    value: viewModel.salesTotalDisplay,
                    subtitle: "histórico",
                    systemImage: "chart.line.uptrend.xyaxis"
                )

                CustomerExecutiveMetricCard(
                    title: "Última compra",
                    value: viewModel.lastSaleDateText,
                    subtitle: "actividad",
                    systemImage: "clock.arrow.circlepath"
                )

                CustomerExecutiveMetricCard(
                    title: "Comprobantes",
                    value: String(viewModel.documents.count),
                    subtitle: "emitidos/revisados",
                    systemImage: "doc.text"
                )
            }
        }
    }

    private var pilotGuidanceSection: some View {
        CustomerExecutiveCard(
            title: "Guía operativa",
            subtitle: "Lectura rápida del estado comercial del cliente.",
            systemImage: viewModel.customerPilotStatusIcon
        ) {
            VStack(alignment: .leading, spacing: 12) {
                CustomerExecutiveNoticeCard(
                    title: viewModel.customerPilotStatusText,
                    message: pilotGuidanceMessage,
                    systemImage: viewModel.customerPilotStatusIcon,
                    tint: viewModel.hasOpenReceivables ? .orange : .secondary
                )
            }
        }
    }

    @ViewBuilder
    private var receivablesSection: some View {
        CustomerExecutiveCard(
            title: "Cuentas por cobrar",
            subtitle: "Deuda real registrada y abonos disponibles.",
            systemImage: "person.crop.circle.badge.clock"
        ) {
            if viewModel.isLoading && viewModel.receivables.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando cuentas…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.receivables.isEmpty {
                ContentUnavailableView(
                    "Sin cuentas por cobrar",
                    systemImage: "checkmark.circle",
                    description: Text("Este cliente no tiene deuda registrada en Nexo.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.receivables) { receivable in
                        if viewModel.canCollectReceivables && !receivable.isSettled && !receivable.isMissingCustomer {
                            NavigationLink {
                                ReceivableCollectionView(
                                    viewModel: ReceivableCollectionViewModel(
                                        organizationId: viewModel.organizationId,
                                        branchId: viewModel.branchId,
                                        receivable: receivable,
                                        effectivePermissions: viewModel.effectivePermissions,
                                        cashRepository: cashRepository,
                                        receivablesRepository: receivablesRepository
                                    ),
                                    onCollected: { updated in
                                        viewModel.applyReceivableUpdate(updated)
                                    }
                                )
                            } label: {
                                CustomerReceivableRow(receivable: receivable, showsAccessory: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            CustomerReceivableRow(receivable: receivable, showsAccessory: false)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var salesSection: some View {
        CustomerExecutiveCard(
            title: "Ventas",
            subtitle: "Historial comercial identificado del cliente.",
            systemImage: "cart"
        ) {
            if viewModel.isLoading && viewModel.sales.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando ventas…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.sales.isEmpty {
                ContentUnavailableView(
                    "Sin ventas",
                    systemImage: "cart",
                    description: Text("Cuando este cliente compre con identificación aparecerá aquí.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.sales) { sale in
                        NavigationLink {
                            SaleDetailView(
                                viewModel: viewModel.makeSaleDetailViewModel(
                                    for: sale,
                                    salesRepository: salesRepository
                                ),
                                salesHistoryRepository: viewModel.salesHistoryRepository,
                                cashRepository: cashRepository,
                                paymentsRepository: paymentsRepository,
                                receivablesRepository: receivablesRepository,
                                documentsRepository: documentsRepository
                            )
                        } label: {
                            CustomerSaleRow(sale: sale, document: viewModel.primaryDocumentBySaleId[sale.id])
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        CustomerExecutiveCard(
            title: "Comprobantes",
            subtitle: "RIDE/XML asociados a las ventas del cliente.",
            systemImage: "doc.text.magnifyingglass"
        ) {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando comprobantes…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    "Sin comprobantes",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Los RIDE/XML asociados a ventas del cliente aparecerán aquí.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.documents) { document in
                        NavigationLink {
                            BusinessElectronicDocumentDetailView(
                                viewModel: BusinessElectronicDocumentDetailViewModel(
                                    organizationId: viewModel.organizationId,
                                    documentId: document.documentId,
                                    effectivePermissions: viewModel.effectivePermissions,
                                    documentsRepository: documentsRepository
                                ),
                                customer360Dependencies: Customer360Dependencies(
                                    organizationId: viewModel.organizationId,
                                    branchId: viewModel.branchId,
                                    revisions: viewModel.revisions,
                                    effectivePermissions: viewModel.effectivePermissions,
                                    salesHistoryRepository: viewModel.salesHistoryRepository,
                                    salesRepository: salesRepository,
                                    cashRepository: cashRepository,
                                    paymentsRepository: paymentsRepository,
                                    receivablesRepository: receivablesRepository,
                                    documentsRepository: documentsRepository
                                )
                            )
                        } label: {
                            CustomerDocumentRow(document: document)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            CustomerExecutiveNoticeCard(
                title: "No se pudo actualizar el cliente",
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
        }

        if let message = viewModel.infoMessage {
            CustomerExecutiveNoticeCard(
                title: "Información",
                message: message,
                systemImage: "info.circle",
                tint: .secondary
            )
        }
    }

    private var pilotGuidanceMessage: String {
        if viewModel.hasOpenReceivables {
            return "Este cliente tiene saldo pendiente real. Puedes registrar abonos desde sus cuentas por cobrar."
        }

        if viewModel.hasSales {
            return "Este cliente ya tiene ventas registradas y no mantiene deuda abierta en este momento."
        }

        return "Cuando el cliente compre con identificación, aquí se agruparán ventas, deudas y comprobantes."
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }
}

private struct CustomerReceivableRow: View {
    let receivable: ReceivableRecord
    let showsAccessory: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CustomerExecutiveIconBadge(
                systemImage: receivable.isSettled ? "checkmark.circle.fill" : "person.crop.circle.badge.clock",
                tint: receivable.isSettled ? .green : .orange,
                size: 38
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(receivable.displaySaleReference)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    CustomerExecutivePill(
                        title: ReceivableStatusPresentation.displayName(receivable.status),
                        systemImage: "tag",
                        tint: receivable.isSettled ? .green : .orange
                    )
                }

                if let createdAt = receivable.createdAt {
                    Text(CustomerDetail360Formatters.dateAndTime.string(from: createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(receivable.effectiveBalance.displayText)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()

            if showsAccessory {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CustomerSaleRow: View {
    let sale: BusinessSale
    let document: BusinessDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sale.displayNumber)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(sale.collectionState.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(sale.totals.grandTotal.displayText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            if !sale.displayItemsSummary.isEmpty {
                Text(sale.displayItemsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                SaleStatusLabel(status: sale.status)

                if let document {
                    Label(document.businessDisplayNumber, systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Sin factura", systemImage: "doc")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            if let createdAt = sale.createdAt {
                Text(CustomerDetail360Formatters.dateAndTime.string(from: createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CustomerDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CustomerExecutiveIconBadge(
                systemImage: BusinessDocumentStatusPresentation.systemImage(document.effectiveStatus),
                tint: statusTint,
                size: 38
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(document.businessDisplayNumber)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(BusinessDocumentStatusPresentation.displayName(document.effectiveStatus))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let date = document.businessSortDate {
                    Text(CustomerDetail360Formatters.dateAndTime.string(from: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let total = document.total, !total.isEmpty {
                Text("\(document.currency) \(total)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusTint: Color {
        if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) { return .green }
        if BusinessDocumentStatusPresentation.isError(document.effectiveStatus) { return .red }
        return .orange
    }
}

struct Customer360Dependencies {
    let organizationId: String
    let branchId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>
    let salesHistoryRepository: SalesHistoryRepository
    let salesRepository: SalesRepository
    let cashRepository: CashRepository
    let paymentsRepository: PaymentsRepository
    let receivablesRepository: ReceivablesRepository
    let documentsRepository: BusinessDocumentsRepository

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        salesHistoryRepository: SalesHistoryRepository,
        salesRepository: SalesRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.salesHistoryRepository = salesHistoryRepository
        self.salesRepository = salesRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }
}

struct Customer360RouteView: View {
    let customer: BusinessCustomer
    let dependencies: Customer360Dependencies

    var body: some View {
        CustomerDetail360View(
            viewModel: CustomerDetail360ViewModel(
                organizationId: dependencies.organizationId,
                branchId: dependencies.branchId,
                revisions: dependencies.revisions,
                customer: customer,
                effectivePermissions: dependencies.effectivePermissions,
                salesHistoryRepository: dependencies.salesHistoryRepository,
                receivablesRepository: dependencies.receivablesRepository,
                documentsRepository: dependencies.documentsRepository
            ),
            salesRepository: dependencies.salesRepository,
            cashRepository: dependencies.cashRepository,
            paymentsRepository: dependencies.paymentsRepository,
            receivablesRepository: dependencies.receivablesRepository,
            documentsRepository: dependencies.documentsRepository
        )
    }
}

struct Customer360NavigationLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    init(
        title: String = "Ver cliente",
        subtitle: String = "Historial, deudas y comprobantes del cliente",
        systemImage: String = "person.text.rectangle"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        CustomerExecutiveActionRow(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        )
    }
}

enum Customer360SeedFactory {
    static func customer(from sale: BusinessSale) -> BusinessCustomer? {
        let id = firstNonBlank([
            sale.customerId,
            sale.customer?.id,
            sale.receivableCustomerId
        ])

        let displayName = firstNonBlank([
            sale.customer?.displayName,
            sale.customerName,
            sale.displayCustomerName
        ]) ?? "Cliente"

        let identification = firstNonBlank([
            sale.customer?.identification
        ]) ?? ""

        guard let id, isRealCustomer(id: id, displayName: displayName, identification: identification) else {
            return nil
        }

        return BusinessCustomer(
            id: id,
            displayName: displayName,
            identificationType: identificationType(from: nil, identificationNumber: identification),
            identificationNumber: identification
        )
    }

    static func customer(from receivable: ReceivableRecord) -> BusinessCustomer? {
        let id = firstNonBlank([receivable.customerId, receivable.customerSnapshot?.id])
        let displayName = firstNonBlank([
            receivable.customerName,
            receivable.customerSnapshot?.displayName,
            receivable.displayCustomerName
        ]) ?? "Cliente por revisar"

        guard let id, isRealCustomer(id: id, displayName: displayName, identification: "") else {
            return nil
        }

        return BusinessCustomer(
            id: id,
            displayName: displayName,
            identificationType: .unknown,
            identificationNumber: ""
        )
    }

    static func customer(from document: BusinessElectronicDocumentDetail, resolvedCustomer: BusinessCustomer?) -> BusinessCustomer? {
        if let resolvedCustomer,
           resolvedCustomer.identificationType != .finalConsumer,
           firstNonBlank([resolvedCustomer.id]) != nil {
            return resolvedCustomer
        }

        let displayName = firstNonBlank([document.customerName, document.summary.customerName])
        let identification = firstNonBlank([document.customerIdentification, document.summary.customerIdentification]) ?? ""

        guard isRealCustomer(id: nil, displayName: displayName, identification: identification) else {
            return nil
        }

        // A customer id is required to query real receivables. Without a resolved directory record,
        // document detail should not open a 360 that could hide debt data.
        return nil
    }

    static func isRealCustomer(id: String?, displayName: String?, identification: String?) -> Bool {
        let normalizedId = normalized(id)
        let normalizedName = normalized(displayName)
        let normalizedIdentification = normalized(identification)

        if BusinessElectronicInvoiceCustomerPolicy.isFinalConsumerCustomerId(normalizedId) { return false }
        if normalizedName == "consumidor final" || normalizedName == "final consumer" { return false }
        if normalizedIdentification == "9999999999999" { return false }

        return normalizedId != nil || normalizedName != nil || normalizedIdentification != nil
    }

    static func firstNonBlank(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func identificationType(from rawValue: String?, identificationNumber: String) -> BusinessCustomerIdentificationType {
        if let rawValue,
           let type = BusinessCustomerIdentificationType(rawValue: rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            return type
        }

        let compact = identificationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if compact == "9999999999999" { return .finalConsumer }
        if compact.count == 13 { return .ruc }
        if compact.count == 10 { return .cedula }
        return .unknown
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension BusinessSale {
    var customer360Seed: BusinessCustomer? {
        Customer360SeedFactory.customer(from: self)
    }

    var hasCustomer360EntryPoint: Bool {
        customer360Seed != nil
    }
}

extension ReceivableRecord {
    var customer360Seed: BusinessCustomer? {
        Customer360SeedFactory.customer(from: self)
    }
}

#Preview {
    NavigationStack {
        CustomerDirectoryView(
            viewModel: CustomerDirectoryViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                customersRepository: PreviewCustomersRepository()
            ),
            branchId: PreviewData.businessContext.branches[0].id,
            revisions: PreviewData.businessContext.revisions,
            salesHistoryRepository: PreviewSalesHistoryRepository(),
            salesRepository: PreviewSalesRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}
