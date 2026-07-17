//
//  BusinessPurchaseOrdersView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessPurchaseOrdersView: View {
    @Bindable private var viewModel: BusinessPurchaseOrdersViewModel
    @State private var isPresentingCreateForm = false
    private let activeModules: Set<ModuleCode>
    private let effectivePermissions: Set<String>
    private let activityId: String
    private let catalogRevision: String
    private let catalogRepository: CatalogRepository

    init(
        viewModel: BusinessPurchaseOrdersViewModel,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        activityId: String,
        catalogRevision: String,
        catalogRepository: CatalogRepository
    ) {
        self.viewModel = viewModel
        self.activeModules = activeModules
        self.effectivePermissions = effectivePermissions
        self.activityId = activityId
        self.catalogRevision = catalogRevision
        self.catalogRepository = catalogRepository
    }

    var body: some View {
        List {
            summarySection
            filtersSection
            messagesSection
            ordersSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Órdenes de compra")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Número de orden o proveedor"
        )
        .onSubmit(of: .search) {
            Task { await viewModel.search() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.canCreate {
                    Button {
                        isPresentingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Crear orden de compra")
                }

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
                .disabled(viewModel.isLoading || !viewModel.canView)
                .accessibilityLabel("Actualizar órdenes de compra")
            }
        }
        .sheet(isPresented: $isPresentingCreateForm) {
            NavigationStack {
                BusinessPurchaseOrderFormView(
                    viewModel: makeFormViewModel(purchaseOrder: nil),
                    onSaved: viewModel.replace
                )
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Seguimiento de compras", systemImage: "shippingbox.and.arrow.backward")
                    .font(.headline)
                Text("Consulta el estado real de cada orden y compara cantidades ordenadas y recibidas. Los importes se muestran únicamente cuando el backend y tus permisos los entregan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    BusinessPurchaseOrderMetric(
                        title: "Visibles",
                        value: String(viewModel.purchaseOrders.count),
                        systemImage: "doc.text.magnifyingglass"
                    )
                    BusinessPurchaseOrderMetric(
                        title: "Filtro",
                        value: viewModel.hasActiveFilters ? "Activo" : "Libre",
                        systemImage: viewModel.hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var filtersSection: some View {
        Section("Filtros") {
            Picker("Estado", selection: $viewModel.statusFilter) {
                ForEach(BusinessPurchaseOrdersViewModel.StatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.statusFilter) { _, _ in
                Task { await viewModel.search() }
            }

            TextField("Fecha esperada desde (AAAA-MM-DD)", text: $viewModel.expectedFrom)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            TextField("Fecha esperada hasta (AAAA-MM-DD)", text: $viewModel.expectedTo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            HStack {
                Button("Aplicar") {
                    Task { await viewModel.search() }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)

                Spacer()

                if viewModel.hasActiveFilters {
                    Button("Limpiar") {
                        Task { await viewModel.clearFilters() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text(errorMessage)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }

                    Button("Reintentar") {
                        Task { await viewModel.refresh() }
                    }
                    .disabled(viewModel.isLoading || !viewModel.canView)
                }
            }
        }

        if let infoMessage = viewModel.infoMessage {
            Section {
                Label(infoMessage, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var ordersSection: some View {
        Section("Resultados") {
            if viewModel.isLoading && viewModel.purchaseOrders.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando órdenes de compra…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.purchaseOrders.isEmpty {
                ContentUnavailableView(
                    "Sin órdenes de compra",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Prueba otros filtros o confirma que tu usuario tenga acceso al módulo Compras.")
                )
            } else {
                ForEach(viewModel.purchaseOrders) { order in
                    NavigationLink {
                        BusinessPurchaseOrderDetailView(
                            viewModel: BusinessPurchaseOrderDetailViewModel(
                                organizationId: viewModel.organizationId,
                                activeModules: activeModules,
                                effectivePermissions: effectivePermissions,
                                purchaseOrder: order,
                                repository: viewModel.repository
                            ),
                            activityId: activityId,
                            catalogRevision: catalogRevision,
                            catalogRepository: catalogRepository,
                            onOrderChanged: viewModel.replace
                        )
                    } label: {
                        BusinessPurchaseOrderRow(order: order)
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadNextPageIfNeeded(currentOrder: order)
                        }
                    }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Cargando más…")
                            .font(.footnote)
                        Spacer()
                    }
                }
            }
        }
    }

    private func makeFormViewModel(
        purchaseOrder: BusinessProcurementPurchaseOrderResponse?
    ) -> BusinessPurchaseOrderFormViewModel {
        BusinessPurchaseOrderFormViewModel(
            organizationId: viewModel.organizationId,
            branchId: viewModel.branchId ?? "",
            activityId: activityId,
            catalogRevision: catalogRevision,
            activeModules: activeModules,
            effectivePermissions: effectivePermissions,
            purchaseOrder: purchaseOrder,
            repository: viewModel.repository,
            catalogRepository: catalogRepository
        )
    }
}

struct BusinessPurchaseOrderDetailView: View {
    @State private var viewModel: BusinessPurchaseOrderDetailViewModel
    @State private var isPresentingEditForm = false
    @State private var isPresentingReceiptForm = false
    @State private var actionToConfirm: BusinessPurchaseOrderAction?
    private let activityId: String
    private let catalogRevision: String
    private let catalogRepository: CatalogRepository
    private let onOrderChanged: (BusinessProcurementPurchaseOrderResponse) -> Void

    init(
        viewModel: BusinessPurchaseOrderDetailViewModel,
        activityId: String,
        catalogRevision: String,
        catalogRepository: CatalogRepository,
        onOrderChanged: @escaping (BusinessProcurementPurchaseOrderResponse) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.activityId = activityId
        self.catalogRevision = catalogRevision
        self.catalogRepository = catalogRepository
        self.onOrderChanged = onOrderChanged
    }

    var body: some View {
        List {
            identitySection
            fulfillmentSection
            totalsSection
            datesSection
            evidenceSection

            if let infoMessage = viewModel.infoMessage {
                Section {
                    Label(infoMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text(errorMessage)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }

                        Button("Reintentar") {
                            Task { await refreshDetail() }
                        }
                        .disabled(viewModel.isLoading || viewModel.isPerformingAction || !viewModel.canView)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.purchaseOrder.orderNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.hasAvailableActions {
                    Menu {
                        if viewModel.canEdit {
                            Button {
                                isPresentingEditForm = true
                            } label: {
                                Label("Editar borrador", systemImage: "pencil")
                            }
                        }

                        if viewModel.canSend {
                            Button {
                                actionToConfirm = .send
                            } label: {
                                Label("Enviar orden", systemImage: "paperplane")
                            }
                        }

                        if viewModel.canCancel {
                            Button(role: .destructive) {
                                actionToConfirm = .cancel
                            } label: {
                                Label("Cancelar orden", systemImage: "xmark.circle")
                            }
                        }

                        if viewModel.canClose {
                            Button {
                                actionToConfirm = .close
                            } label: {
                                Label("Cerrar orden", systemImage: "checkmark.seal")
                            }
                        }

                        if viewModel.canReceive {
                            Button {
                                isPresentingReceiptForm = true
                            } label: {
                                Label("Registrar recepción", systemImage: "shippingbox.and.arrow.backward")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewModel.isLoading || viewModel.isPerformingAction)
                    .accessibilityLabel("Acciones de la orden")
                }

                Button {
                    Task { await refreshDetail() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isPerformingAction || !viewModel.canView)
                .accessibilityLabel("Actualizar orden de compra")
            }
        }
        .sheet(isPresented: $isPresentingEditForm) {
            NavigationStack {
                BusinessPurchaseOrderFormView(
                    viewModel: makeEditFormViewModel(),
                    onSaved: handleOrderChanged
                )
            }
        }
        .sheet(isPresented: $isPresentingReceiptForm) {
            NavigationStack {
                BusinessPurchaseReceiptFormView(
                    viewModel: BusinessPurchaseReceiptFormViewModel(
                        organizationId: viewModel.organizationId,
                        branchId: viewModel.purchaseOrder.branchId,
                        activeModules: viewModel.accessPolicy.activeModules,
                        effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                        purchaseOrder: viewModel.purchaseOrder,
                        repository: viewModel.repository
                    ),
                    onSaved: viewModel.recordCreatedReceipt
                )
            }
        }
        .sheet(item: $actionToConfirm) { action in
            NavigationStack {
                BusinessPurchaseOrderActionView(
                    action: action,
                    viewModel: viewModel,
                    onCompleted: handleOrderChanged
                )
            }
        }
        .refreshable {
            await refreshDetail()
        }
        .task {
            await loadDetailIfNeeded()
        }
    }

    private func makeEditFormViewModel() -> BusinessPurchaseOrderFormViewModel {
        BusinessPurchaseOrderFormViewModel(
            organizationId: viewModel.organizationId,
            branchId: viewModel.purchaseOrder.branchId,
            activityId: activityId,
            catalogRevision: catalogRevision,
            activeModules: viewModel.accessPolicy.activeModules,
            effectivePermissions: viewModel.accessPolicy.effectivePermissions,
            purchaseOrder: viewModel.purchaseOrder,
            repository: viewModel.repository,
            catalogRepository: catalogRepository
        )
    }

    private func handleOrderChanged(_ order: BusinessProcurementPurchaseOrderResponse) {
        viewModel.replace(order)
        onOrderChanged(order)
    }

    private func loadDetailIfNeeded() async {
        await viewModel.loadIfNeeded()
        if viewModel.hasLoaded {
            onOrderChanged(viewModel.purchaseOrder)
        }
    }

    private func refreshDetail() async {
        await viewModel.refresh()
        if viewModel.hasLoaded {
            onOrderChanged(viewModel.purchaseOrder)
        }
    }

    private var identitySection: some View {
        Section("Orden") {
            LabeledContent("Número", value: viewModel.purchaseOrder.orderNumber)
            LabeledContent("Proveedor", value: viewModel.purchaseOrder.businessSupplierName)

            if let legalName = viewModel.purchaseOrder.supplierSnapshot.businessLegalNameDetail {
                LabeledContent("Razón social", value: legalName)
            }

            LabeledContent("Estado") {
                BusinessPurchaseOrderStatusBadge(status: viewModel.purchaseOrder.status)
            }
            LabeledContent("Moneda", value: viewModel.purchaseOrder.currency)
            LabeledContent(
                "Condición de pago",
                value: viewModel.purchaseOrder.paymentTermsSnapshot.businessDisplayText
            )
        }
    }

    private var fulfillmentSection: some View {
        Section("Cantidades ordenadas y recibidas") {
            if viewModel.purchaseOrder.lines.isEmpty {
                Text("Esta orden no contiene líneas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.purchaseOrder.lines) { line in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(line.descriptionSnapshot)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .firstTextBaseline, spacing: 18) {
                            BusinessPurchaseOrderQuantity(
                                title: "Ordenado",
                                value: line.businessOrderedQuantityText
                            )
                            BusinessPurchaseOrderQuantity(
                                title: "Recibido",
                                value: line.businessReceivedQuantityText
                            )
                        }

                        if let unitCost = line.unitCost {
                            LabeledContent("Costo unitario", value: unitCost.businessDisplayText())
                                .font(.footnote)
                        } else {
                            Label("Costo protegido por permisos", systemImage: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let lineTotal = line.lineTotal {
                            LabeledContent("Total de línea", value: lineTotal.businessDisplayText())
                                .font(.footnote)
                        }

                        if let notes = line.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !notes.isEmpty {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if viewModel.canViewLinkedReceipts {
                NavigationLink {
                    BusinessPurchaseReceiptsView(
                        viewModel: BusinessPurchaseReceiptsViewModel(
                            organizationId: viewModel.organizationId,
                            branchId: viewModel.purchaseOrder.branchId,
                            supplierId: viewModel.purchaseOrder.supplierId,
                            purchaseOrderId: viewModel.purchaseOrder.id,
                            activeModules: viewModel.accessPolicy.activeModules,
                            effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                            repository: viewModel.repository
                        ),
                        activeModules: viewModel.accessPolicy.activeModules,
                        effectivePermissions: viewModel.accessPolicy.effectivePermissions
                    )
                } label: {
                    Label("Ver recepciones de esta orden", systemImage: "shippingbox")
                }
            }
        }
    }

    @ViewBuilder
    private var totalsSection: some View {
        Section("Totales del backend") {
            if let subtotal = viewModel.purchaseOrder.subtotal,
               let discount = viewModel.purchaseOrder.discountTotal,
               let tax = viewModel.purchaseOrder.taxTotal,
               let total = viewModel.purchaseOrder.total {
                LabeledContent("Subtotal", value: subtotal.businessDisplayText())
                LabeledContent("Descuento", value: discount.businessDisplayText())
                LabeledContent("Impuestos", value: tax.businessDisplayText())
                LabeledContent("Total", value: total.businessDisplayText())
                    .font(.headline)
            } else {
                Label {
                    Text("Costos protegidos por permisos o no disponibles.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .foregroundStyle(.secondary)
            }

            Text("Nexo muestra los importes autoritativos recibidos del servidor; no recalcula el total en el dispositivo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var datesSection: some View {
        Section("Fechas y ciclo") {
            if let expectedDate = viewModel.purchaseOrder.expectedDate {
                LabeledContent("Entrega esperada", value: expectedDate)
            } else {
                LabeledContent("Entrega esperada", value: "No definida")
            }

            LabeledContent("Creada", value: viewModel.purchaseOrder.createdAt)
            LabeledContent("Actualizada", value: viewModel.purchaseOrder.updatedAt)

            if let sentAt = viewModel.purchaseOrder.sentAt {
                LabeledContent("Enviada", value: sentAt)
            }
            if let closedAt = viewModel.purchaseOrder.closedAt {
                LabeledContent("Cerrada", value: closedAt)
            }
            if let cancelledAt = viewModel.purchaseOrder.cancelledAt {
                LabeledContent("Cancelada", value: cancelledAt)
            }
        }
    }

    @ViewBuilder
    private var evidenceSection: some View {
        Section("Notas y evidencia") {
            if let notes = viewModel.purchaseOrder.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                Text(notes)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Sin notas")
                    .foregroundStyle(.secondary)
            }

            LabeledContent(
                "Adjuntos",
                value: viewModel.purchaseOrder.attachmentIds.count == 1
                    ? "1 archivo"
                    : "\(viewModel.purchaseOrder.attachmentIds.count) archivos"
            )

            if viewModel.canView,
               viewModel.canViewCosts,
               (!viewModel.purchaseOrder.attachmentIds.isEmpty
                || viewModel.accessPolicy.allows(BusinessProcurementPermission.attachmentsUpload)) {
                NavigationLink {
                    BusinessProcurementAttachmentsView(
                        viewModel: BusinessProcurementAttachmentsViewModel(
                            organizationId: viewModel.organizationId,
                            sourceType: .purchaseOrder,
                            sourceId: viewModel.purchaseOrder.id,
                            sourceVersion: viewModel.purchaseOrder.version,
                            sourceDisplayName: "Orden \(viewModel.purchaseOrder.orderNumber)",
                            attachmentIds: viewModel.purchaseOrder.attachmentIds,
                            activeModules: viewModel.accessPolicy.activeModules,
                            effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                            repository: viewModel.repository
                        )
                    )
                    .onDisappear {
                        Task { await refreshDetail() }
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ver evidencia adjunta")
                                .font(.headline)
                            Text("Descarga protegida y ligada a esta orden")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "paperclip.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                }
            }

            if let reason = viewModel.purchaseOrder.cancellationReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reason.isEmpty {
                LabeledContent("Motivo de cancelación", value: reason)
            }
            if let reason = viewModel.purchaseOrder.closeReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reason.isEmpty {
                LabeledContent("Motivo de cierre", value: reason)
            }
        }
    }
}

private struct BusinessPurchaseOrderActionView: View {
    @Environment(\.dismiss) private var dismiss
    let action: BusinessPurchaseOrderAction
    @Bindable var viewModel: BusinessPurchaseOrderDetailViewModel
    let onCompleted: (BusinessProcurementPurchaseOrderResponse) -> Void
    @State private var reason = ""

    var body: some View {
        Form {
            Section {
                Text(action.confirmationMessage(orderNumber: viewModel.purchaseOrder.orderNumber))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if action.requiresReason {
                Section(action.reasonTitle) {
                    TextField(action.reasonPrompt, text: $reason, axis: .vertical)
                        .lineLimit(2...5)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label {
                        Text(errorMessage)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(action.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.isPerformingAction)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Volver") { dismiss() }
                    .disabled(viewModel.isPerformingAction)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(role: action == .cancel ? .destructive : nil) {
                    Task {
                        if let order = await viewModel.perform(action: action, reason: reason) {
                            onCompleted(order)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isPerformingAction {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(action.confirmButtonTitle)
                    }
                }
                .disabled(
                    viewModel.isPerformingAction ||
                    (action.requiresReason && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
            }
        }
    }
}

extension BusinessPurchaseOrderAction: Identifiable {
    var id: String { rawValue }

    fileprivate var requiresReason: Bool {
        self != .send
    }

    fileprivate var navigationTitle: String {
        switch self {
        case .send: return "Enviar orden"
        case .cancel: return "Cancelar orden"
        case .close: return "Cerrar orden"
        }
    }

    fileprivate var confirmButtonTitle: String {
        switch self {
        case .send: return "Enviar"
        case .cancel: return "Cancelar orden"
        case .close: return "Cerrar"
        }
    }

    fileprivate var reasonTitle: String {
        self == .cancel ? "Motivo de cancelación" : "Motivo de cierre"
    }

    fileprivate var reasonPrompt: String {
        self == .cancel
            ? "Explica por qué se cancela la orden"
            : "Explica por qué se cierra la orden"
    }

    fileprivate func confirmationMessage(orderNumber: String) -> String {
        switch self {
        case .send:
            return "Enviarás \(orderNumber) al siguiente estado. La orden dejará de ser editable y todavía no cambiará inventario ni cuentas por pagar."
        case .cancel:
            return "Cancelarás \(orderNumber). Esta acción requiere un motivo y solo procede si no existen cantidades recibidas."
        case .close:
            return "Cerrarás \(orderNumber) con sus cantidades recibidas actuales. Registra un motivo claro antes de continuar."
        }
    }
}

private struct BusinessPurchaseOrderRow: View {
    let order: BusinessProcurementPurchaseOrderResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(order.orderNumber)
                    .font(.headline)
                Spacer(minLength: 12)
                BusinessPurchaseOrderStatusBadge(status: order.status)
            }

            Text(order.businessSupplierName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(order.businessLineCountText, systemImage: "list.number")
                if let expectedDate = order.expectedDate {
                    Label(expectedDate, systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let total = order.total {
                Text(total.businessDisplayText())
                    .font(.subheadline.weight(.semibold))
            } else {
                Label("Costos protegidos", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessPurchaseOrderStatusBadge: View {
    let status: BusinessPurchaseOrderStatus

    var body: some View {
        Text(status.businessDisplayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.businessTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.businessTint.opacity(0.12), in: Capsule())
    }
}

private struct BusinessPurchaseOrderQuantity: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct BusinessPurchaseOrderMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }
}

private extension BusinessPurchaseOrderStatus {
    var businessTint: Color {
        switch self {
        case .draft: return .secondary
        case .sent: return .blue
        case .partiallyReceived: return .orange
        case .received: return .green
        case .cancelled: return .red
        case .closed: return .indigo
        }
    }
}
