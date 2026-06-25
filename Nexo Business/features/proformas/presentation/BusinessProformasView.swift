//
//  BusinessProformasView.swift
//  Nexo Business
//
//  21J.10 — Business iOS Proformas MVP
//

import SwiftUI
import UIKit

struct BusinessProformasView: View {
    @Bindable private var viewModel: BusinessProformasViewModel
    private let proformasRepository: BusinessProformasRepository
    private let productsRepository: ProductsRepository
    private let customersRepository: CustomersRepository
    private let salesRepository: SalesRepository
    private let salesHistoryRepository: SalesHistoryRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    @State private var isShowingCreateForm = false
    @State private var selectedProformaForDetail: BusinessProforma?
    @State private var pendingProformaToOpen: BusinessProforma?

    init(
        viewModel: BusinessProformasViewModel,
        proformasRepository: BusinessProformasRepository,
        productsRepository: ProductsRepository,
        customersRepository: CustomersRepository,
        salesRepository: SalesRepository,
        salesHistoryRepository: SalesHistoryRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.proformasRepository = proformasRepository
        self.productsRepository = productsRepository
        self.customersRepository = customersRepository
        self.salesRepository = salesRepository
        self.salesHistoryRepository = salesHistoryRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        List {
            Section {
                BusinessProformaBoundaryBanner()
            }

            Section("Filtros") {
                Picker("Estado", selection: $viewModel.selectedStatus) {
                    Text("Todas").tag(BusinessProformaStatus?.none)
                    ForEach(BusinessProformaStatus.allCases.filter { $0 != .unknown }) { status in
                        Text(status.displayName).tag(Optional(status))
                    }
                }

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Label("Aplicar filtros", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                .disabled(viewModel.isLoading)
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

            Section("Proformas") {
                if viewModel.isLoading && viewModel.proformas.isEmpty {
                    ProgressView("Cargando proformas…")
                } else if viewModel.proformas.isEmpty {
                    ContentUnavailableView(
                        "Sin proformas",
                        systemImage: "doc.badge.plus",
                        description: Text("Crea una cotización comercial para enviarla y convertirla a venta cuando el cliente acepte.")
                    )
                } else {
                    ForEach(viewModel.proformas) { proforma in
                        NavigationLink {
                            makeDetailView(proforma)
                        } label: {
                            BusinessProformaRow(proforma: proforma)
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Buscar número o cliente")
        .onSubmit(of: .search) {
            Task { await viewModel.refresh() }
        }
        .navigationTitle("Proformas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canCreate)
            }

            ToolbarItem(placement: .topBarLeading) {
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
        .sheet(isPresented: $isShowingCreateForm) {
            NavigationStack {
                BusinessProformaFormView(
                    viewModel: BusinessProformaFormViewModel(
                        mode: .create,
                        organizationId: viewModel.organizationId,
                        branchId: viewModel.branchId,
                        activityId: viewModel.activityId,
                        revisions: viewModel.revisions,
                        effectivePermissions: viewModel.effectivePermissions,
                        proformasRepository: proformasRepository,
                        productsRepository: productsRepository
                    ),
                    customersRepository: customersRepository,
                    onSaved: { proforma in
                        viewModel.apply(proforma)
                        pendingProformaToOpen = proforma
                        isShowingCreateForm = false
                    }
                )
            }
        }
        .navigationDestination(item: $selectedProformaForDetail) { proforma in
            makeDetailView(proforma)
        }
        .onChange(of: isShowingCreateForm) { _, isPresented in
            guard !isPresented, let pending = pendingProformaToOpen else { return }
            pendingProformaToOpen = nil
            selectedProformaForDetail = pending
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private func makeDetailView(_ proforma: BusinessProforma) -> BusinessProformaDetailView {
        BusinessProformaDetailView(
            viewModel: BusinessProformaDetailViewModel(
                organizationId: viewModel.organizationId,
                proformaId: proforma.id,
                revisions: viewModel.revisions,
                initialProforma: proforma,
                effectivePermissions: viewModel.effectivePermissions,
                repository: proformasRepository
            ),
            proformasRepository: proformasRepository,
            productsRepository: productsRepository,
            customersRepository: customersRepository,
            salesRepository: salesRepository,
            salesHistoryRepository: salesHistoryRepository,
            cashRepository: cashRepository,
            paymentsRepository: paymentsRepository,
            receivablesRepository: receivablesRepository,
            documentsRepository: documentsRepository,
            onUpdated: { updated in
                viewModel.apply(updated)
            }
        )
    }
}

struct BusinessProformaDetailView: View {
    @Bindable private var viewModel: BusinessProformaDetailViewModel
    private let proformasRepository: BusinessProformasRepository
    private let productsRepository: ProductsRepository
    private let customersRepository: CustomersRepository
    private let salesRepository: SalesRepository
    private let salesHistoryRepository: SalesHistoryRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository
    private let onUpdated: (BusinessProforma) -> Void

    @State private var isShowingEditForm = false
    @State private var isShowingRejectSheet = false
    @State private var isShowingRevisionSheet = false
    @State private var previewDocument: BusinessProformaDownloadedDocument?
    @State private var shareDocument: BusinessProformaDownloadedDocument?
    @State private var didCompleteShare = false
    @State private var isShowingMarkSentAfterShare = false
    @State private var isShowingManualSentConfirmation = false

    init(
        viewModel: BusinessProformaDetailViewModel,
        proformasRepository: BusinessProformasRepository,
        productsRepository: ProductsRepository,
        customersRepository: CustomersRepository,
        salesRepository: SalesRepository,
        salesHistoryRepository: SalesHistoryRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository,
        onUpdated: @escaping (BusinessProforma) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.proformasRepository = proformasRepository
        self.productsRepository = productsRepository
        self.customersRepository = customersRepository
        self.salesRepository = salesRepository
        self.salesHistoryRepository = salesHistoryRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
        self.onUpdated = onUpdated
    }

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.proforma == nil {
                Section {
                    ProgressView("Cargando proforma…")
                }
            }

            if let proforma = viewModel.proforma {
                Section {
                    BusinessProformaHero(proforma: proforma)
                    BusinessProformaBoundaryBanner()
                }

                Section("Cliente real") {
                    LabeledContent("Nombre", value: proforma.customerDisplayName)
                    if let identification = proforma.customerSnapshot?.identification, !identification.isEmpty {
                        LabeledContent("Identificación", value: identification)
                    }
                    if let email = proforma.customerSnapshot?.email, !email.isEmpty {
                        LabeledContent("Correo", value: email)
                    }

                    if !proforma.hasRealCustomer {
                        Label("Selecciona un cliente real antes de marcar como enviada, aceptar o crear venta. Consumidor final solo aplica en ventas rápidas.", systemImage: "person.crop.circle.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Líneas agrupadas") {
                    ForEach(proforma.lines) { line in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(line.displayName)
                                .font(.headline)
                            HStack {
                                Text("Cant. \(line.quantity)")
                                Spacer()
                                Text("Total $\(line.grandTotal)")
                                    .fontWeight(.semibold)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Totales") {
                    LabeledContent("Subtotal", value: "$\(proforma.totals.subtotal)")
                    LabeledContent("Descuento", value: "$\(proforma.totals.discountTotal)")
                    LabeledContent("Impuestos", value: "$\(proforma.totals.taxTotal)")
                    LabeledContent("Total", value: "$\(proforma.totals.grandTotal)")
                        .font(.headline)
                }

                if let notes = proforma.notes, !notes.isEmpty {
                    Section("Notas") {
                        Text(notes)
                    }
                }

                if let terms = proforma.terms, !terms.isEmpty {
                    Section("Términos") {
                        Text(terms)
                    }
                }

                Section("Acciones") {
                    if viewModel.canEdit {
                        Button {
                            isShowingEditForm = true
                        } label: {
                            Label("Editar borrador", systemImage: "pencil")
                        }
                    }

                    Button {
                        Task {
                            await viewModel.downloadDocument()
                            previewDocument = viewModel.downloadedDocument
                        }
                    } label: {
                        Label("Ver documento comercial", systemImage: "doc.richtext")
                    }
                    .disabled(viewModel.isMutating)

                    Button {
                        Task {
                            await viewModel.downloadDocument()
                            if viewModel.errorMessage == nil {
                                shareDocument = viewModel.downloadedDocument
                            }
                        }
                    } label: {
                        Label("Compartir proforma", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isMutating)

                    Text("Compartir abre WhatsApp, Mail, AirDrop, Archivos o Imprimir. No cambia el estado ni garantiza entrega por sí solo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if viewModel.canSend {
                        Button {
                            isShowingManualSentConfirmation = true
                        } label: {
                            Label("Marcar como compartida/enviada", systemImage: "paperplane")
                        }
                    }

                    if viewModel.canAccept {
                        Button {
                            Task {
                                await viewModel.accept()
                                notifyUpdated()
                            }
                        } label: {
                            Label("Marcar aceptada", systemImage: "checkmark.seal")
                        }
                    }

                    if viewModel.canReject {
                        Button(role: .destructive) {
                            isShowingRejectSheet = true
                        } label: {
                            Label("Rechazar", systemImage: "xmark.circle")
                        }
                    }

                    if viewModel.canExpire {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.expire()
                                notifyUpdated()
                            }
                        } label: {
                            Label("Expirar", systemImage: "clock.badge.exclamationmark")
                        }
                    }

                    if viewModel.canCreateRevision {
                        Button {
                            isShowingRevisionSheet = true
                        } label: {
                            Label("Crear revisión", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }

                    if viewModel.canConvertToSale {
                        Button {
                            Task {
                                await viewModel.convertToSale()
                                notifyUpdated()
                            }
                        } label: {
                            Label("Crear venta", systemImage: "cart.badge.plus")
                        }
                        .disabled(viewModel.isMutating)
                    }

                    if let saleId = proforma.convertedSaleId, !saleId.isEmpty {
                        NavigationLink {
                            makeSaleDetailView(saleId: saleId)
                        } label: {
                            Label("Ir a venta", systemImage: "cart")
                        }
                    }
                }
            } else if !viewModel.isLoading {
                Section {
                    ContentUnavailableView(
                        "Proforma no encontrada",
                        systemImage: "doc.badge.questionmark",
                        description: Text("Actualiza la pantalla o vuelve a la lista.")
                    )
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
        .navigationTitle(viewModel.proforma?.proformaNumber ?? "Proforma")
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
        .sheet(isPresented: $isShowingEditForm) {
            if let proforma = viewModel.proforma {
                NavigationStack {
                    BusinessProformaFormView(
                        viewModel: BusinessProformaFormViewModel(
                            mode: .edit(proforma),
                            organizationId: viewModel.organizationId,
                            branchId: proforma.branchId,
                            activityId: proforma.activityId,
                            revisions: viewModel.revisions,
                            effectivePermissions: viewModel.effectivePermissions,
                            proformasRepository: proformasRepository,
                            productsRepository: productsRepository
                        ),
                        customersRepository: customersRepository,
                        onSaved: { updated in
                            viewModel.apply(updated)
                            onUpdated(updated)
                            isShowingEditForm = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingRejectSheet) {
            NavigationStack {
                Form {
                    Section("Razón") {
                        TextField("Ej. Cliente no aprobó", text: $viewModel.rejectionReason, axis: .vertical)
                    }
                }
                .navigationTitle("Rechazar")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { isShowingRejectSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Rechazar") {
                            Task {
                                await viewModel.reject()
                                notifyUpdated()
                                if viewModel.errorMessage == nil { isShowingRejectSheet = false }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingRevisionSheet) {
            NavigationStack {
                Form {
                    Section("Razón") {
                        TextField("Ej. Cambio solicitado por cliente", text: $viewModel.revisionReason, axis: .vertical)
                    }
                }
                .navigationTitle("Crear revisión")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { isShowingRevisionSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Crear") {
                            Task {
                                await viewModel.createRevision()
                                notifyUpdated()
                                if viewModel.errorMessage == nil { isShowingRevisionSheet = false }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $previewDocument) { document in
            BusinessDocumentQuickLookPreview(fileURL: document.localURL)
        }
        .sheet(
            item: $shareDocument,
            onDismiss: {
                if didCompleteShare && viewModel.canSend {
                    isShowingMarkSentAfterShare = true
                }
                didCompleteShare = false
            }
        ) { document in
            BusinessProformaShareSheet(activityItems: [document.localURL]) { completed in
                didCompleteShare = completed
            }
        }
        .alert("¿Cambiar estado a compartida/enviada?", isPresented: $isShowingMarkSentAfterShare) {
            Button("No", role: .cancel) {}
            Button("Cambiar estado") {
                Task {
                    await viewModel.send()
                    notifyUpdated()
                }
            }
        } message: {
            Text("Compartir por WhatsApp, Mail, AirDrop, Archivos o Imprimir no confirma entrega real. Esta acción solo marca la proforma como compartida/enviada; no envía correo automático desde Nexo.")
        }
        .alert("Marcar como compartida/enviada", isPresented: $isShowingManualSentConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Cambiar estado") {
                Task {
                    await viewModel.send()
                    notifyUpdated()
                }
            }
        } message: {
            Text("Esto solo cambia el estado de la proforma. No envía correo automáticamente. Para correo manual usa Compartir proforma y elige Mail.")
        }
        .task {
            if viewModel.shouldLoadOnAppear {
                await viewModel.load()
            }
        }
    }

    private func notifyUpdated() {
        if let proforma = viewModel.proforma {
            onUpdated(proforma)
        }
    }

    private func makeSaleDetailView(saleId: String) -> SaleDetailView {
        SaleDetailView(
            viewModel: SaleDetailViewModel(
                organizationId: viewModel.organizationId,
                saleId: saleId,
                revisions: viewModel.revisions,
                effectivePermissions: viewModel.effectivePermissions,
                salesRepository: salesRepository
            ),
            customersRepository: customersRepository,
            salesHistoryRepository: salesHistoryRepository,
            cashRepository: cashRepository,
            paymentsRepository: paymentsRepository,
            receivablesRepository: receivablesRepository,
            documentsRepository: documentsRepository
        )
    }
}

struct BusinessProformaFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: BusinessProformaFormViewModel
    private let customersRepository: CustomersRepository
    private let onSaved: (BusinessProforma) -> Void

    @State private var isShowingCustomerPicker = false

    init(
        viewModel: BusinessProformaFormViewModel,
        customersRepository: CustomersRepository,
        onSaved: @escaping (BusinessProforma) -> Void
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                BusinessProformaBoundaryBanner()
            }

            Section("Cliente real") {
                if let selectedCustomer = viewModel.selectedCustomer {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCustomer.displayName)
                            .font(.headline)
                        Text(selectedCustomer.identificationNumber)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if !viewModel.manualCustomerName.isEmpty {
                    LabeledContent("Cliente guardado", value: viewModel.manualCustomerName)
                } else {
                    Text("Selecciona un cliente real para que la conversión a venta sea válida.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isShowingCustomerPicker = true
                } label: {
                    Label("Seleccionar cliente", systemImage: "person.crop.circle.badge.checkmark")
                }
            }

            Section("Validez y condiciones") {
                TextField("Válida hasta yyyy-mm-dd (opcional)", text: $viewModel.validUntil)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Notas", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Términos", text: $viewModel.terms, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Buscar productos") {
                TextField("Buscar producto", text: $viewModel.productSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.searchProducts() }
                    }

                Button {
                    Task { await viewModel.searchProducts() }
                } label: {
                    if viewModel.isSearchingProducts {
                        ProgressView()
                    } else {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }
                }
                .disabled(viewModel.isSearchingProducts)

                ForEach(viewModel.productResults) { product in
                    Button {
                        viewModel.addProduct(product)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(.headline)
                                Text(product.productsPrimaryCode ?? product.productsDisplayStatus)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(product.price?.displayText ?? "Sin precio")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Líneas agrupadas") {
                if viewModel.lines.isEmpty {
                    ContentUnavailableView(
                        "Sin productos",
                        systemImage: "shippingbox",
                        description: Text("Busca productos y agrégalos a la proforma.")
                    )
                } else {
                    ForEach($viewModel.lines) { $line in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(line.displayName.isEmpty ? "Ítem" : line.displayName)
                                        .font(.headline)
                                    Text("Total estimado $\(line.estimatedGrandTotalText)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.removeLine(line)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }

                            TextField("Nombre del producto", text: $line.displayName)
                            HStack {
                                TextField("Cantidad", text: $line.quantity)
                                    .keyboardType(.decimalPad)
                                TextField("Precio unitario", text: $line.unitPrice)
                                    .keyboardType(.decimalPad)
                            }
                            HStack {
                                TextField("Descuento", text: $line.discountAmount)
                                    .keyboardType(.decimalPad)
                                LabeledContent("Imp. ref.", value: "$\(line.estimatedTaxAmountText)")
                            }
                            if let taxRatePercent = line.taxRatePercent, !taxRatePercent.isEmpty {
                                Text("Calculado con el mismo perfil tributario local usado en ventas: \(taxRatePercent)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Notas de línea", text: $line.notes)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !viewModel.lines.isEmpty {
                Section("Resumen referencial") {
                    LabeledContent("Subtotal", value: "$\(viewModel.estimatedSubtotalText)")
                    LabeledContent("Impuestos", value: "$\(viewModel.estimatedTaxText)")
                    LabeledContent("Total", value: "$\(viewModel.estimatedTotalText)")
                        .font(.headline)
                    Text("El backend conserva la fuente de verdad al guardar. No se genera factura, XML, RIDE ni SRI desde proformas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if let proforma = await viewModel.save() {
                            onSaved(proforma)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text(viewModel.saveButtonTitle)
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .sheet(isPresented: $isShowingCustomerPicker) {
            NavigationStack {
                CustomerPickerView(
                    viewModel: CustomerPickerViewModel(
                        organizationId: viewModel.organizationId,
                        effectivePermissions: viewModel.effectivePermissions,
                        customersRepository: customersRepository
                    ),
                    allowsFinalConsumer: false,
                    onSelect: { customer in
                        viewModel.selectCustomer(customer)
                        isShowingCustomerPicker = false
                    }
                )
            }
        }
    }
}

private struct BusinessProformaRow: View {
    let proforma: BusinessProforma

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proforma.proformaNumber)
                        .font(.headline)
                    Text(proforma.customerDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BusinessProformaStatusBadge(status: proforma.status)
            }

            HStack {
                Label(proforma.issueDate, systemImage: "calendar")
                Spacer()
                Text("$\(proforma.totals.grandTotal)")
                    .fontWeight(.semibold)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessProformaHero: View {
    let proforma: BusinessProforma

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proforma.proformaNumber)
                        .font(.title3.weight(.semibold))
                    Text(proforma.customerDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BusinessProformaStatusBadge(status: proforma.status)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(proforma.totals.grandTotal)")
                        .font(.title3.weight(.bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Fecha")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(proforma.issueDate)
                        .font(.subheadline.weight(.semibold))
                }
            }

            if let saleId = proforma.convertedSaleId, !saleId.isEmpty {
                Label("Venta creada: \(saleId)", systemImage: "cart")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BusinessProformaStatusBadge: View {
    let status: BusinessProformaStatus

    var body: some View {
        Label(status.displayName, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch status {
        case .draft: return .secondary
        case .sent: return .blue
        case .accepted: return .green
        case .rejected: return .red
        case .expired: return .orange
        case .converted: return .purple
        case .unknown: return .secondary
        }
    }
}

private struct BusinessProformaBoundaryBanner: View {
    var body: some View {
        Label {
            Text("Proforma comercial: no es factura, no cobra, no abre caja, no genera XML/RIDE y no llama al SRI. Si el cliente acepta, crea una venta borrador para continuar por el flujo normal.")
                .font(.footnote)
        } icon: {
            Image(systemName: "info.circle")
        }
        .foregroundStyle(.secondary)
    }
}


private struct BusinessProformaShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            DispatchQueue.main.async {
                completion(completed)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
