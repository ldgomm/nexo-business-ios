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
        List {
            Section("Buscar") {
                TextField("Nombre, cédula, RUC o correo", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.search() }
                    }

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)
            }

            if viewModel.canCreate {
                Section("Crear") {
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
                        Label("Nuevo cliente", systemImage: "person.badge.plus")
                    }
                }
            }

            Section("Clientes") {
                if viewModel.isLoading && viewModel.customers.isEmpty {
                    ProgressView("Cargando clientes…")
                } else if viewModel.customers.isEmpty {
                    ContentUnavailableView(
                        "Sin clientes",
                        systemImage: "person.text.rectangle",
                        description: Text("Crea o busca clientes para ventas identificadas, crédito y comprobantes.")
                    )
                } else {
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
                        } else {
                            CustomerRowView(customer: customer)
                        }
                    }
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let message = viewModel.infoMessage {
                Section {
                    Label(message, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Clientes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            if viewModel.customers.isEmpty {
                await viewModel.load()
            }
        }
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
        Form {
            customerSection
            summarySection
            pilotGuidanceSection
            receivablesSection
            salesSection
            documentsSection
            messagesSection
        }
        .navigationTitle(viewModel.customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }

    private var customerSection: some View {
        Section("Datos del cliente") {
            CustomerRowView(customer: viewModel.customer)

            if let address = viewModel.customer.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LabeledContent("Dirección", value: address)
            }
        }
    }

    private var summarySection: some View {
        Section("Resumen 360") {
            LabeledContent("Saldo pendiente", value: viewModel.pendingBalanceDisplay)
            LabeledContent("Cuentas abiertas", value: String(viewModel.openReceivables.count))
            LabeledContent("Ventas", value: String(viewModel.sales.count))
            LabeledContent("Vendido registrado", value: viewModel.salesTotalDisplay)
            LabeledContent("Última compra", value: viewModel.lastSaleDateText)
            LabeledContent("Comprobantes", value: String(viewModel.documents.count))
        }
    }


    private var pilotGuidanceSection: some View {
        Section("Guía rápida") {
            Label(viewModel.customerPilotStatusText, systemImage: viewModel.customerPilotStatusIcon)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.hasOpenReceivables {
                Text("Este cliente tiene saldo pendiente real. Puedes registrar abonos desde sus cuentas por cobrar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if viewModel.hasSales {
                Text("Este cliente ya tiene ventas registradas y no mantiene deuda abierta en este momento.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Cuando el cliente compre con identificación, aquí se agruparán ventas, deudas y comprobantes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var receivablesSection: some View {
        Section("Cuentas por cobrar") {
            if viewModel.isLoading && viewModel.receivables.isEmpty {
                ProgressView("Cargando cuentas…")
            } else if viewModel.receivables.isEmpty {
                ContentUnavailableView(
                    "Sin cuentas por cobrar",
                    systemImage: "checkmark.circle",
                    description: Text("Este cliente no tiene deuda registrada en Nexo.")
                )
            } else {
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
                    } else {
                        CustomerReceivableRow(receivable: receivable, showsAccessory: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var salesSection: some View {
        Section("Ventas") {
            if viewModel.isLoading && viewModel.sales.isEmpty {
                ProgressView("Cargando ventas…")
            } else if viewModel.sales.isEmpty {
                ContentUnavailableView(
                    "Sin ventas",
                    systemImage: "cart",
                    description: Text("Cuando este cliente compre con identificación aparecerá aquí.")
                )
            } else {
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
                }
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        Section("Comprobantes") {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                ProgressView("Cargando comprobantes…")
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    "Sin comprobantes",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Los RIDE/XML asociados a ventas del cliente aparecerán aquí.")
                )
            } else {
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
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CustomerReceivableRow: View {
    let receivable: ReceivableRecord
    let showsAccessory: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: receivable.isSettled ? "checkmark.circle.fill" : "person.crop.circle.badge.clock")
                .foregroundStyle(receivable.isSettled ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(receivable.displaySaleReference)
                    .font(.subheadline.weight(.semibold))

                Text(ReceivableStatusPresentation.displayName(receivable.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let createdAt = receivable.createdAt {
                    Text(CustomerDetail360Formatters.dateAndTime.string(from: createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(receivable.effectiveBalance.displayText)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()

            if showsAccessory {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CustomerSaleRow: View {
    let sale: BusinessSale
    let document: BusinessDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sale.displayNumber)
                        .font(.subheadline.weight(.semibold))
                    Text(sale.collectionState.displayName)
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
        .padding(.vertical, 4)
    }
}

private struct CustomerDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: BusinessDocumentStatusPresentation.systemImage(document.effectiveStatus))
                .foregroundStyle(statusTint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.businessDisplayNumber)
                    .font(.subheadline.weight(.semibold))

                Text(BusinessDocumentStatusPresentation.displayName(document.effectiveStatus))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let date = document.businessSortDate {
                    Text(CustomerDetail360Formatters.dateAndTime.string(from: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let total = document.total, !total.isEmpty {
                Text("\(document.currency) \(total)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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

        if normalizedId == "final_consumer" || normalizedId == "consumidor_final" { return false }
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
