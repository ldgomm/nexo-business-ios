//
//  BusinessPurchaseReceiptsView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessPurchaseReceiptsView: View {
    @Bindable private var viewModel: BusinessPurchaseReceiptsViewModel
    private let activeModules: Set<ModuleCode>
    private let effectivePermissions: Set<String>

    init(
        viewModel: BusinessPurchaseReceiptsViewModel,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>
    ) {
        self.viewModel = viewModel
        self.activeModules = activeModules
        self.effectivePermissions = effectivePermissions
    }

    var body: some View {
        List {
            summarySection
            filtersSection
            messagesSection
            receiptsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recepciones de compra")
        .navigationBarTitleDisplayMode(.large)
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
                .disabled(viewModel.isLoading || !viewModel.canView)
                .accessibilityLabel("Actualizar recepciones de compra")
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
                Label("Recepción física", systemImage: "shippingbox.and.arrow.backward.fill")
                    .font(.headline)
                Text("Cada recepción representa un evento físico. Un borrador no cambia inventario; una recepción confirmada conserva el efecto autoritativo del servidor para las cantidades aceptadas de artículos con control de stock.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    BusinessPurchaseReceiptMetric(
                        title: "Visibles",
                        value: String(viewModel.purchaseReceipts.count),
                        systemImage: "shippingbox"
                    )
                    BusinessPurchaseReceiptMetric(
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
                ForEach(BusinessPurchaseReceiptsViewModel.StatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.statusFilter) { _, _ in
                Task { await viewModel.search() }
            }

            TextField("Recibida desde (AAAA-MM-DD)", text: $viewModel.receivedFrom)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            TextField("Recibida hasta (AAAA-MM-DD)", text: $viewModel.receivedTo)
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

        if let referenceWarning = viewModel.referenceWarning {
            Section {
                Label {
                    Text(referenceWarning)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.circle")
                }
                .foregroundStyle(.secondary)
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
    private var receiptsSection: some View {
        Section("Resultados") {
            if viewModel.isLoading && viewModel.purchaseReceipts.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando recepciones de compra…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.purchaseReceipts.isEmpty {
                ContentUnavailableView(
                    "Sin recepciones de compra",
                    systemImage: "shippingbox",
                    description: Text("Prueba otras fechas o confirma que tu usuario tenga acceso al módulo Compras.")
                )
            } else {
                ForEach(viewModel.purchaseReceipts) { presentation in
                    NavigationLink {
                        BusinessPurchaseReceiptDetailView(
                            viewModel: BusinessPurchaseReceiptDetailViewModel(
                                organizationId: viewModel.organizationId,
                                activeModules: activeModules,
                                effectivePermissions: effectivePermissions,
                                purchaseReceipt: presentation.receipt,
                                supplierName: presentation.supplierName,
                                purchaseOrderNumber: presentation.purchaseOrderNumber,
                                repository: viewModel.repository
                            ),
                            onReceiptChanged: viewModel.replace
                        )
                    } label: {
                        BusinessPurchaseReceiptRow(presentation: presentation)
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadNextPageIfNeeded(currentReceipt: presentation)
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
}

struct BusinessPurchaseReceiptDetailView: View {
    @State private var viewModel: BusinessPurchaseReceiptDetailViewModel
    @State private var isPresentingEditForm = false
    @State private var actionToConfirm: BusinessPurchaseReceiptAction?
    private let onReceiptChanged: (BusinessProcurementPurchaseReceiptResponse) -> Void

    init(
        viewModel: BusinessPurchaseReceiptDetailViewModel,
        onReceiptChanged: @escaping (BusinessProcurementPurchaseReceiptResponse) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onReceiptChanged = onReceiptChanged
    }

    var body: some View {
        List {
            identitySection
            operationalEffectSection
            quantitiesSection
            datesSection
            evidenceSection
            messagesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.purchaseReceipt.receiptNumber)
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

                        if viewModel.canConfirm {
                            Button {
                                actionToConfirm = .confirm
                            } label: {
                                Label("Confirmar recepción", systemImage: "checkmark.seal")
                            }
                        }

                        if viewModel.canCancel {
                            Button(role: .destructive) {
                                actionToConfirm = .cancel
                            } label: {
                                Label("Cancelar recepción", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewModel.isLoading || viewModel.isPerformingAction)
                    .accessibilityLabel("Acciones de la recepción")
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
                .accessibilityLabel("Actualizar recepción de compra")
            }
        }
        .sheet(isPresented: $isPresentingEditForm) {
            if let purchaseOrder = viewModel.purchaseOrder {
                NavigationStack {
                    BusinessPurchaseReceiptFormView(
                        viewModel: BusinessPurchaseReceiptFormViewModel(
                            organizationId: viewModel.organizationId,
                            branchId: viewModel.purchaseReceipt.branchId,
                            activeModules: viewModel.accessPolicy.activeModules,
                            effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                            purchaseOrder: purchaseOrder,
                            purchaseReceipt: viewModel.purchaseReceipt,
                            repository: viewModel.repository
                        ),
                        onSaved: handleEditedReceipt
                    )
                }
            }
        }
        .sheet(item: $actionToConfirm) { action in
            NavigationStack {
                BusinessPurchaseReceiptActionView(
                    action: action,
                    viewModel: viewModel,
                    onCompleted: handleReceiptChanged
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

    private func loadDetailIfNeeded() async {
        await viewModel.loadIfNeeded()
        if viewModel.hasLoaded {
            onReceiptChanged(viewModel.purchaseReceipt)
        }
    }

    private func refreshDetail() async {
        await viewModel.refresh()
        if viewModel.hasLoaded {
            onReceiptChanged(viewModel.purchaseReceipt)
        }
    }

    private func handleReceiptChanged(_ receipt: BusinessProcurementPurchaseReceiptResponse) {
        viewModel.replace(receipt)
        onReceiptChanged(receipt)
    }

    private func handleEditedReceipt(_ receipt: BusinessProcurementPurchaseReceiptResponse) {
        viewModel.recordEditedReceipt(receipt)
        onReceiptChanged(receipt)
    }

    private var identitySection: some View {
        Section("Recepción") {
            LabeledContent("Número", value: viewModel.purchaseReceipt.receiptNumber)
            LabeledContent("Proveedor", value: viewModel.businessSupplierName)
            LabeledContent("Orden de compra", value: viewModel.businessPurchaseOrderName)
            LabeledContent("Estado") {
                BusinessPurchaseReceiptStatusBadge(status: viewModel.purchaseReceipt.status)
            }
            Label("Bodega validada por el servidor", systemImage: "building.2")
                .foregroundStyle(.secondary)
        }
    }

    private var operationalEffectSection: some View {
        Section("Efecto operativo") {
            Text(viewModel.purchaseReceipt.status.businessInventoryExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent(
                "Evidencia de inventario",
                value: viewModel.purchaseReceipt.businessInventoryMovementCountText
            )

            Text("La recepción física no crea una cuenta por pagar. El documento del proveedor se registra por separado.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var quantitiesSection: some View {
        Section("Cantidades recibidas, aceptadas y rechazadas") {
            if viewModel.purchaseReceipt.lines.isEmpty {
                Text("Esta recepción no contiene líneas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.purchaseReceipt.lines) { line in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(viewModel.itemName(for: line))
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            BusinessPurchaseReceiptQuantity(
                                title: "Recibido",
                                value: line.businessReceivedQuantityText
                            )
                            BusinessPurchaseReceiptQuantity(
                                title: "Aceptado",
                                value: line.businessAcceptedQuantityText
                            )
                            BusinessPurchaseReceiptQuantity(
                                title: "Rechazado",
                                value: line.businessRejectedQuantityText
                            )
                        }

                        if let orderLine = viewModel.linkedOrderLine(for: line) {
                            Divider()
                            HStack(alignment: .firstTextBaseline, spacing: 18) {
                                BusinessPurchaseReceiptQuantity(
                                    title: "Ordenado",
                                    value: orderLine.businessOrderedQuantityText
                                )
                                BusinessPurchaseReceiptQuantity(
                                    title: "Recibido acumulado",
                                    value: orderLine.businessReceivedQuantityText
                                )
                            }
                        }

                        if let unitCost = line.unitCost {
                            LabeledContent("Costo unitario", value: unitCost.businessDisplayText())
                                .font(.footnote)
                        } else {
                            Label("Costo no disponible o protegido por permisos", systemImage: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Label(line.businessTrackedUnitCountText, systemImage: "barcode.viewfinder")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Label(line.businessInventoryEvidenceText, systemImage: "shippingbox.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !line.trackedUnits.isEmpty {
                            DisclosureGroup("Series e identificadores") {
                                ForEach(Array(line.trackedUnits.enumerated()), id: \.offset) { _, trackedUnit in
                                    VStack(alignment: .leading, spacing: 3) {
                                        LabeledContent(
                                            trackedUnit.trackingType,
                                            value: trackedUnit.trackingValue
                                        )
                                        if let notes = trackedUnit.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                                           !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
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

            Text("El pendiente permanece autoritativo en la orden de compra; Nexo no lo recalcula en el dispositivo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var datesSection: some View {
        Section("Fechas") {
            LabeledContent("Recepción física", value: viewModel.purchaseReceipt.receivedAt)
            LabeledContent("Creada", value: viewModel.purchaseReceipt.createdAt)
            LabeledContent("Actualizada", value: viewModel.purchaseReceipt.updatedAt)

            if let confirmedAt = viewModel.purchaseReceipt.confirmedAt {
                LabeledContent("Confirmada", value: confirmedAt)
            }
            if let cancelledAt = viewModel.purchaseReceipt.cancelledAt {
                LabeledContent("Cancelada", value: cancelledAt)
            }
        }
    }

    @ViewBuilder
    private var evidenceSection: some View {
        Section("Notas y evidencia") {
            if let notes = viewModel.purchaseReceipt.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                Text(notes)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Sin notas")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Adjuntos", value: viewModel.purchaseReceipt.businessAttachmentCountText)

            if viewModel.canView,
               (!viewModel.purchaseReceipt.attachmentIds.isEmpty
                || viewModel.accessPolicy.allows(BusinessProcurementPermission.attachmentsUpload)) {
                NavigationLink {
                    BusinessProcurementAttachmentsView(
                        viewModel: BusinessProcurementAttachmentsViewModel(
                            organizationId: viewModel.organizationId,
                            sourceType: .purchaseReceipt,
                            sourceId: viewModel.purchaseReceipt.id,
                            sourceVersion: viewModel.purchaseReceipt.version,
                            sourceDisplayName: "Recepción \(viewModel.purchaseReceipt.receiptNumber)",
                            attachmentIds: viewModel.purchaseReceipt.attachmentIds,
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
                            Text("Descarga protegida y ligada a esta recepción")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "paperclip.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                }
            }

            LabeledContent(
                "Movimientos",
                value: viewModel.purchaseReceipt.businessInventoryMovementCountText
            )

            if let reason = viewModel.purchaseReceipt.cancellationReason?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !reason.isEmpty {
                LabeledContent("Motivo de cancelación", value: reason)
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let infoMessage = viewModel.infoMessage {
            Section {
                Label(
                    infoMessage,
                    systemImage: viewModel.purchaseReceipt.status == .confirming
                        ? "clock.fill"
                        : "checkmark.circle.fill"
                )
                .foregroundStyle(
                    viewModel.purchaseReceipt.status == .confirming
                        ? Color.orange
                        : Color.green
                )
            }
        }

        if let referenceWarning = viewModel.referenceWarning {
            Section {
                Label {
                    Text(referenceWarning)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.circle")
                }
                .foregroundStyle(.secondary)
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
}

private struct BusinessPurchaseReceiptActionView: View {
    @Environment(\.dismiss) private var dismiss
    let action: BusinessPurchaseReceiptAction
    @Bindable var viewModel: BusinessPurchaseReceiptDetailViewModel
    let onCompleted: (BusinessProcurementPurchaseReceiptResponse) -> Void
    @State private var reason = ""

    var body: some View {
        Form {
            Section {
                Text(action.confirmationMessage(receiptNumber: viewModel.purchaseReceipt.receiptNumber))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if action == .confirm {
                Section("Revisión del efecto") {
                    Label("Solo las cantidades aceptadas de artículos con control de stock pueden generar PURCHASE_IN.", systemImage: "shippingbox.fill")
                    Label("Las cantidades rechazadas no entran al stock disponible.", systemImage: "xmark.octagon")
                    Label("El backend aplica el efecto exactamente una vez y la recepción confirmada queda como evidencia inmutable.", systemImage: "checkmark.shield")
                    Label("Confirmar esta recepción no crea una cuenta por pagar.", systemImage: "doc.text")
                }
                .font(.footnote)
            }

            if action == .cancel {
                Section("Motivo de cancelación") {
                    TextField("Explica por qué se cancela el borrador", text: $reason, axis: .vertical)
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
                        if let receipt = await viewModel.perform(action: action, reason: reason) {
                            onCompleted(receipt)
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
                    (action == .cancel && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
            }
        }
    }
}

extension BusinessPurchaseReceiptAction: Identifiable {
    var id: String { rawValue }

    fileprivate var navigationTitle: String {
        switch self {
        case .confirm: return "Confirmar recepción"
        case .cancel: return "Cancelar recepción"
        }
    }

    fileprivate var confirmButtonTitle: String {
        switch self {
        case .confirm: return "Confirmar"
        case .cancel: return "Cancelar borrador"
        }
    }

    fileprivate func confirmationMessage(receiptNumber: String) -> String {
        switch self {
        case .confirm:
            return "Confirmarás \(receiptNumber). Revisa las cantidades antes de continuar; después, la recepción deja de ser editable."
        case .cancel:
            return "Cancelarás el borrador \(receiptNumber). La recepción conservará su historial y no generará una entrada de inventario."
        }
    }
}

private struct BusinessPurchaseReceiptRow: View {
    let presentation: BusinessPurchaseReceiptPresentation

    private var receipt: BusinessProcurementPurchaseReceiptResponse {
        presentation.receipt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(receipt.receiptNumber)
                    .font(.headline)
                Spacer(minLength: 12)
                BusinessPurchaseReceiptStatusBadge(status: receipt.status)
            }

            Text(presentation.businessSupplierName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(presentation.businessPurchaseOrderName, systemImage: "doc.text")
                Label(receipt.businessLineCountText, systemImage: "list.number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Label(receipt.receivedAt, systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessPurchaseReceiptStatusBadge: View {
    let status: BusinessPurchaseReceiptStatus

    var body: some View {
        Text(status.businessDisplayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.businessTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.businessTint.opacity(0.12), in: Capsule())
    }
}

private struct BusinessPurchaseReceiptQuantity: View {
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

private struct BusinessPurchaseReceiptMetric: View {
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

private extension BusinessPurchaseReceiptStatus {
    var businessTint: Color {
        switch self {
        case .draft: return .secondary
        case .confirming: return .orange
        case .confirmed: return .green
        case .cancelled: return .red
        }
    }
}
