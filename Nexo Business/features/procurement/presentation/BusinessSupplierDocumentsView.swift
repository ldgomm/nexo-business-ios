//
//  BusinessSupplierDocumentsView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import SwiftUI

struct BusinessSupplierDocumentsView: View {
    @Bindable private var viewModel: BusinessSupplierDocumentsViewModel
    @State private var isPresentingCreateForm = false
    private let activeModules: Set<ModuleCode>
    private let effectivePermissions: Set<String>

    init(
        viewModel: BusinessSupplierDocumentsViewModel,
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
            documentsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Documentos de proveedor")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.canCreate {
                    Button {
                        isPresentingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Crear documento de proveedor")
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
                .accessibilityLabel("Actualizar documentos de proveedor")
            }
        }
        .sheet(isPresented: $isPresentingCreateForm) {
            if let branchId = viewModel.branchId {
                NavigationStack {
                    BusinessSupplierDocumentFormView(
                        viewModel: BusinessSupplierDocumentFormViewModel(
                            organizationId: viewModel.organizationId,
                            branchId: branchId,
                            activeModules: activeModules,
                            effectivePermissions: effectivePermissions,
                            initialSupplierId: viewModel.supplierId,
                            repository: viewModel.repository
                        ),
                        onSaved: viewModel.replace
                    )
                }
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
                Label("Cargo del proveedor", systemImage: "doc.text.fill")
                    .font(.headline)
                Text("El documento registra lo que el proveedor cobra. No representa una recepción física y no cambia inventario; sus totales, estado y saldo provienen del servidor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    BusinessSupplierDocumentMetric(
                        title: "Visibles",
                        value: String(viewModel.supplierDocuments.count),
                        systemImage: "doc.text"
                    )
                    BusinessSupplierDocumentMetric(
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
            TextField("Número o referencia", text: $viewModel.query)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            Picker("Tipo", selection: $viewModel.documentTypeFilter) {
                ForEach(BusinessSupplierDocumentsViewModel.DocumentTypeFilter.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.documentTypeFilter) { _, _ in
                Task { await viewModel.search() }
            }

            Picker("Estado", selection: $viewModel.statusFilter) {
                ForEach(BusinessSupplierDocumentsViewModel.StatusFilter.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.statusFilter) { _, _ in
                Task { await viewModel.search() }
            }

            DisclosureGroup("Fechas del documento") {
                TextField("Desde (AAAA-MM-DD)", text: $viewModel.documentDateFrom)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                TextField("Hasta (AAAA-MM-DD)", text: $viewModel.documentDateTo)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
            }

            DisclosureGroup("Fechas de vencimiento") {
                TextField("Desde (AAAA-MM-DD)", text: $viewModel.dueDateFrom)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                TextField("Hasta (AAAA-MM-DD)", text: $viewModel.dueDateTo)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
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
    private var documentsSection: some View {
        Section("Resultados") {
            if viewModel.isLoading && viewModel.supplierDocuments.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando documentos de proveedor…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.supplierDocuments.isEmpty {
                ContentUnavailableView(
                    "Sin documentos de proveedor",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Prueba otros filtros o confirma que tu usuario tenga acceso al módulo Compras.")
                )
            } else {
                ForEach(viewModel.supplierDocuments) { presentation in
                    NavigationLink {
                        BusinessSupplierDocumentDetailView(
                            viewModel: BusinessSupplierDocumentDetailViewModel(
                                organizationId: viewModel.organizationId,
                                activeModules: activeModules,
                                effectivePermissions: effectivePermissions,
                                supplierDocument: presentation.document,
                                supplierName: presentation.supplierName,
                                repository: viewModel.repository
                            ),
                            onDocumentChanged: viewModel.replace
                        )
                    } label: {
                        BusinessSupplierDocumentRow(presentation: presentation)
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadNextPageIfNeeded(
                                currentDocument: presentation
                            )
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

struct BusinessSupplierDocumentDetailView: View {
    @State private var viewModel: BusinessSupplierDocumentDetailViewModel
    @State private var isPresentingEditForm = false
    @State private var actionToConfirm: BusinessSupplierDocumentAction?
    private let onDocumentChanged: (BusinessProcurementSupplierDocumentResponse) -> Void

    init(
        viewModel: BusinessSupplierDocumentDetailViewModel,
        onDocumentChanged: @escaping (BusinessProcurementSupplierDocumentResponse) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onDocumentChanged = onDocumentChanged
    }

    var body: some View {
        List {
            identitySection
            datesSection
            totalsSection
            linesSection
            linksSection
            sourceEvidenceSection
            payableSection
            messagesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.supplierDocument.documentNumber)
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
                                Label("Confirmar documento", systemImage: "checkmark.seal")
                            }
                        }

                        if viewModel.canCancel {
                            Button(role: .destructive) {
                                actionToConfirm = .cancel
                            } label: {
                                Label("Cancelar documento", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewModel.isLoading || viewModel.isPerformingAction)
                    .accessibilityLabel("Acciones del documento de proveedor")
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
                .disabled(
                    viewModel.isLoading ||
                    viewModel.isPerformingAction ||
                    !viewModel.canView
                )
                .accessibilityLabel("Actualizar documento de proveedor")
            }
        }
        .sheet(isPresented: $isPresentingEditForm) {
            NavigationStack {
                BusinessSupplierDocumentFormView(
                    viewModel: BusinessSupplierDocumentFormViewModel(
                        organizationId: viewModel.organizationId,
                        branchId: viewModel.supplierDocument.branchId,
                        activeModules: viewModel.accessPolicy.activeModules,
                        effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                        supplierDocument: viewModel.supplierDocument,
                        supplierName: viewModel.businessSupplierName,
                        repository: viewModel.repository
                    ),
                    onSaved: handleEditedDocument
                )
            }
        }
        .sheet(item: $actionToConfirm) { action in
            NavigationStack {
                BusinessSupplierDocumentActionView(
                    action: action,
                    viewModel: viewModel,
                    onCompleted: handleDocumentChanged
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
            onDocumentChanged(viewModel.supplierDocument)
        }
    }

    private func refreshDetail() async {
        await viewModel.refresh()
        if viewModel.hasLoaded {
            onDocumentChanged(viewModel.supplierDocument)
        }
    }

    private func handleDocumentChanged(
        _ document: BusinessProcurementSupplierDocumentResponse
    ) {
        viewModel.replace(document)
        onDocumentChanged(document)
    }

    private func handleEditedDocument(
        _ document: BusinessProcurementSupplierDocumentResponse
    ) {
        viewModel.recordEditedDocument(document)
        onDocumentChanged(document)
    }

    private var identitySection: some View {
        Section("Documento") {
            LabeledContent("Proveedor", value: viewModel.businessSupplierName)
            LabeledContent("Número", value: viewModel.supplierDocument.documentNumber)
            LabeledContent("Tipo", value: viewModel.supplierDocument.businessDocumentTypeName)
            LabeledContent("Estado") {
                BusinessSupplierDocumentStatusBadge(
                    status: viewModel.supplierDocument.status
                )
            }
            LabeledContent(
                "Estado contable operativo",
                value: businessReadableCode(viewModel.supplierDocument.accountingStatus)
            )
            Text(viewModel.supplierDocument.status.businessPayableExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var datesSection: some View {
        Section("Fechas") {
            LabeledContent("Documento", value: viewModel.supplierDocument.documentDate)
            LabeledContent(
                "Vencimiento",
                value: viewModel.supplierDocument.dueDate ?? "Sin vencimiento informado"
            )
            LabeledContent("Creado", value: viewModel.supplierDocument.createdAt)
            LabeledContent("Actualizado", value: viewModel.supplierDocument.updatedAt)
            if let confirmedAt = viewModel.supplierDocument.confirmedAt {
                LabeledContent("Confirmado", value: confirmedAt)
            }
            if let cancelledAt = viewModel.supplierDocument.cancelledAt {
                LabeledContent("Cancelado", value: cancelledAt)
            }
        }
    }

    private var totalsSection: some View {
        Section("Totales del servidor") {
            supplierDocumentMoneyRow(
                "Subtotal",
                money: viewModel.supplierDocument.subtotal
            )
            supplierDocumentMoneyRow(
                "Descuento",
                money: viewModel.supplierDocument.discountTotal
            )
            supplierDocumentMoneyRow(
                "Impuestos",
                money: viewModel.supplierDocument.taxTotal
            )
            supplierDocumentMoneyRow(
                "Total",
                money: viewModel.supplierDocument.total,
                emphasized: true
            )
            supplierDocumentMoneyRow(
                "Saldo financiado",
                money: viewModel.supplierDocument.payableAmount,
                emphasized: true
            )
            Text("El total y saldo provienen del servidor; la app no los recalcula sumando líneas.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var linesSection: some View {
        Section("Líneas · \(viewModel.supplierDocument.businessLineCountText)") {
            if viewModel.supplierDocument.lines.isEmpty {
                Text("El servidor no informó líneas para este documento.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.supplierDocument.lines) { line in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(line.descriptionSnapshot)
                            .font(.headline)
                        Text(line.businessKindName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LabeledContent("Cantidad", value: line.businessQuantityText)
                        supplierDocumentMoneyRow("Costo unitario", money: line.unitCost)
                        supplierDocumentMoneyRow("Descuento", money: line.discountAmount)
                        supplierDocumentMoneyRow("Base neta", money: line.netAmount)
                        supplierDocumentMoneyRow("Impuestos", money: line.taxAmount)
                        supplierDocumentMoneyRow(
                            "Total de línea",
                            money: line.lineTotal,
                            emphasized: true
                        )

                        if let category = line.expenseCategoryCode,
                           !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            LabeledContent(
                                "Categoría operativa",
                                value: businessReadableCode(category)
                            )
                        }
                        if let notes = line.notes,
                           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var linksSection: some View {
        Section("Contexto operativo") {
            Label(
                viewModel.supplierDocument.businessPurchaseOrderLinkCountText,
                systemImage: "doc.plaintext"
            )
            Label(
                viewModel.supplierDocument.businessPurchaseReceiptLinkCountText,
                systemImage: "shippingbox"
            )
            Label(
                viewModel.supplierDocument.businessAttachmentCountText,
                systemImage: "paperclip"
            )

            if viewModel.canView,
               (!viewModel.supplierDocument.attachmentIds.isEmpty
                || viewModel.accessPolicy.allows(BusinessProcurementPermission.attachmentsUpload)) {
                NavigationLink {
                    BusinessProcurementAttachmentsView(
                        viewModel: BusinessProcurementAttachmentsViewModel(
                            organizationId: viewModel.organizationId,
                            sourceType: .supplierDocument,
                            sourceId: viewModel.supplierDocument.id,
                            sourceVersion: viewModel.supplierDocument.version,
                            sourceDisplayName: "Documento \(viewModel.supplierDocument.documentNumber)",
                            attachmentIds: viewModel.supplierDocument.attachmentIds,
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
                            Text("Descarga protegida y ligada a este documento")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "paperclip.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                }
            }

            Text("El documento de proveedor permanece separado de la recepción física. Vincularlos conserva contexto, pero nunca duplica ni reemplaza la verdad de inventario.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var sourceEvidenceSection: some View {
        if viewModel.supplierDocument.sourceTotals != nil ||
            viewModel.supplierDocument.sourcePayment != nil ||
            viewModel.supplierDocument.accessKey != nil ||
            viewModel.supplierDocument.authorizationNumber != nil ||
            viewModel.supplierDocument.notes != nil {
            Section("Evidencia de origen") {
                if let sourceTotals = viewModel.supplierDocument.sourceTotals {
                    supplierDocumentMoneyRow(
                        "Total informado por origen",
                        money: sourceTotals.total
                    )
                    supplierDocumentMoneyRow(
                        "Impuesto informado por origen",
                        money: sourceTotals.taxTotal
                    )
                }

                if let sourcePayment = viewModel.supplierDocument.sourcePayment {
                    supplierDocumentMoneyRow(
                        "Pago inmediato informado",
                        money: sourcePayment.amount
                    )
                    LabeledContent(
                        "Método",
                        value: businessReadableCode(sourcePayment.method)
                    )
                    LabeledContent("Fecha de pago", value: sourcePayment.paymentDate)
                    if let reference = sourcePayment.reference,
                       !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        LabeledContent("Referencia", value: reference)
                    }
                }

                if let accessKey = viewModel.supplierDocument.accessKey,
                   !accessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Clave de acceso") {
                        Text(accessKey)
                            .font(.caption.monospaced())
                            .multilineTextAlignment(.trailing)
                    }
                }
                if let authorization = viewModel.supplierDocument.authorizationNumber,
                   !authorization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Autorización", value: authorization)
                }
                if let notes = viewModel.supplierDocument.notes,
                   !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var payableSection: some View {
        Section("Cuenta por pagar") {
            if let payable = viewModel.payable, viewModel.canViewPayable {
                supplierDocumentMoneyRow("Importe original", money: payable.originalAmount)
                supplierDocumentMoneyRow("Pagado", money: payable.paidAmount)
                supplierDocumentMoneyRow("Pendiente", money: payable.balance, emphasized: true)
                LabeledContent("Vencimiento", value: payable.dueDate)
                LabeledContent(
                    "Estado",
                    value: payable.effectiveStatus.businessSupplierDocumentDisplayName
                )
            } else if viewModel.supplierDocument.payableId != nil {
                Label(
                    "Existe una cuenta por pagar vinculada, pero su detalle está protegido por permisos o no fue incluido por el servidor.",
                    systemImage: "lock.circle"
                )
                .foregroundStyle(.secondary)
            } else {
                Text("El servidor no informó una cuenta por pagar vinculada.")
                    .foregroundStyle(.secondary)
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
                        Task { await refreshDetail() }
                    }
                    .disabled(
                        viewModel.isLoading ||
                        viewModel.isPerformingAction ||
                        !viewModel.canView
                    )
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

    private func supplierDocumentMoneyRow(
        _ title: String,
        money: BusinessProcurementMoneyResponse,
        emphasized: Bool = false
    ) -> some View {
        LabeledContent(title) {
            Text(supplierDocumentMoneyText(money))
                .fontWeight(emphasized ? .semibold : .regular)
                .monospacedDigit()
        }
    }
}

private struct BusinessSupplierDocumentActionView: View {
    @Environment(\.dismiss) private var dismiss
    let action: BusinessSupplierDocumentAction
    @Bindable var viewModel: BusinessSupplierDocumentDetailViewModel
    let onCompleted: (BusinessProcurementSupplierDocumentResponse) -> Void
    @State private var reason = ""

    var body: some View {
        Form {
            Section {
                Text(
                    action.confirmationMessage(
                        documentNumber: viewModel.supplierDocument.documentNumber
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            }

            if action == .confirm {
                Section("Revisión del efecto") {
                    Label(
                        "El backend valida las líneas, impuestos y totales antes de confirmar.",
                        systemImage: "checkmark.shield"
                    )
                    Label(
                        "Si queda saldo pendiente, el backend crea la cuenta por pagar exactamente una vez.",
                        systemImage: "creditcard"
                    )
                    Label(
                        "La confirmación no recibe mercancía y no modifica inventario.",
                        systemImage: "shippingbox"
                    )
                    Label(
                        "Si el servidor responde Confirmando, actualiza el detalle antes de asumir el efecto final.",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .font(.footnote)
            }

            if action == .cancel {
                Section("Motivo de cancelación") {
                    TextField(
                        "Explica por qué se cancela el borrador",
                        text: $reason,
                        axis: .vertical
                    )
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
                        if let document = await viewModel.perform(
                            action: action,
                            reason: reason
                        ) {
                            onCompleted(document)
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
                    (action == .cancel && reason
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty)
                )
            }
        }
    }
}

extension BusinessSupplierDocumentAction: Identifiable {
    var id: String { rawValue }

    fileprivate var navigationTitle: String {
        switch self {
        case .confirm: return "Confirmar documento"
        case .cancel: return "Cancelar documento"
        }
    }

    fileprivate var confirmButtonTitle: String {
        switch self {
        case .confirm: return "Confirmar"
        case .cancel: return "Cancelar borrador"
        }
    }

    fileprivate func confirmationMessage(documentNumber: String) -> String {
        switch self {
        case .confirm:
            return "Confirmarás \(documentNumber). Revisa la evidencia y los importes antes de continuar; después, el documento deja de ser editable."
        case .cancel:
            return "Cancelarás el borrador \(documentNumber). El documento conservará su historial y no creará una nueva cuenta por pagar."
        }
    }
}

private struct BusinessSupplierDocumentRow: View {
    let presentation: BusinessSupplierDocumentPresentation

    var body: some View {
        let document = presentation.document
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(document.documentNumber)
                    .font(.headline)
                Spacer(minLength: 8)
                BusinessSupplierDocumentStatusBadge(status: document.status)
            }

            Text(presentation.businessSupplierName)
                .font(.subheadline)
            Text(document.businessDocumentTypeName)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label(document.documentDate, systemImage: "calendar")
                if let dueDate = document.dueDate {
                    Label(dueDate, systemImage: "calendar.badge.clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text(supplierDocumentMoneyText(document.total))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Spacer()
                Text("Saldo \(supplierDocumentMoneyText(document.payableAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessSupplierDocumentStatusBadge: View {
    let status: BusinessSupplierDocumentStatus

    var body: some View {
        Text(status.businessDisplayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .draft: return .secondary
        case .confirming: return .orange
        case .confirmed: return .green
        case .cancelled: return .red
        }
    }
}

private struct BusinessSupplierDocumentMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func supplierDocumentMoneyText(
    _ money: BusinessProcurementMoneyResponse,
    locale: Locale = .current
) -> String {
    guard let decimal = Decimal(
        string: money.amount,
        locale: Locale(identifier: "en_US_POSIX")
    ) else {
        return "\(money.currency) \(supplierDocumentTrimmedMoney(money.amount))"
    }

    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .currency
    formatter.currencyCode = money.currency
    return formatter.string(from: decimal as NSDecimalNumber)
        ?? "\(money.currency) \(supplierDocumentTrimmedMoney(money.amount))"
}

private func supplierDocumentTrimmedMoney(_ rawValue: String) -> String {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let separator = value.firstIndex(of: ".") else { return value }
    let integer = String(value[..<separator])
    let fractionStart = value.index(after: separator)
    let fraction = String(value[fractionStart...]).replacingOccurrences(
        of: "0+$",
        with: "",
        options: .regularExpression
    )
    return fraction.isEmpty ? integer : "\(integer).\(fraction)"
}

private func businessReadableCode(_ value: String) -> String {
    value
        .replacingOccurrences(of: "_", with: " ")
        .localizedCapitalized
}
