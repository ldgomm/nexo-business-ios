//
//  BusinessSupplierPaymentsView.swift
//  Nexo Business
//
//  27R.M.9A–9C — supplier-payment list, detail and controlled void action.
//

import SwiftUI

struct BusinessSupplierPaymentsView: View {
    @Bindable private var viewModel: BusinessSupplierPaymentsViewModel
    private let activeModules: Set<ModuleCode>
    private let effectivePermissions: Set<String>

    init(
        viewModel: BusinessSupplierPaymentsViewModel,
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
            paymentsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pagos a proveedores")
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
                .accessibilityLabel("Actualizar pagos a proveedores")
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
                Label("Registro operativo de pagos", systemImage: "creditcard.fill")
                    .font(.headline)
                Text("Consulta pagos y aplicaciones registradas por el backend. Esta pantalla no mueve dinero real, no consulta credenciales bancarias y no recalcula saldos localmente.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    BusinessSupplierPaymentMetric(
                        title: "Visibles",
                        value: String(viewModel.supplierPayments.count),
                        systemImage: "list.bullet.rectangle"
                    )
                    BusinessSupplierPaymentMetric(
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

            Picker("Estado", selection: $viewModel.statusFilter) {
                ForEach(BusinessSupplierPaymentsViewModel.StatusFilter.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.statusFilter) { _, _ in
                Task { await viewModel.search() }
            }

            Picker("Método", selection: $viewModel.methodFilter) {
                ForEach(BusinessSupplierPaymentsViewModel.MethodFilter.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.methodFilter) { _, _ in
                Task { await viewModel.search() }
            }

            DisclosureGroup("Fecha del pago") {
                TextField("Desde (AAAA-MM-DD)", text: $viewModel.paymentFrom)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                TextField("Hasta (AAAA-MM-DD)", text: $viewModel.paymentTo)
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
    private var paymentsSection: some View {
        Section("Resultados") {
            if viewModel.isLoading && viewModel.supplierPayments.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando pagos a proveedores…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.supplierPayments.isEmpty {
                ContentUnavailableView(
                    "Sin pagos a proveedores",
                    systemImage: "creditcard.trianglebadge.exclamationmark",
                    description: Text("Prueba otros filtros o confirma que tu usuario tenga acceso al módulo Compras.")
                )
            } else {
                ForEach(viewModel.supplierPayments) { presentation in
                    NavigationLink {
                        BusinessSupplierPaymentDetailView(
                            viewModel: BusinessSupplierPaymentDetailViewModel(
                                organizationId: viewModel.organizationId,
                                activeModules: activeModules,
                                effectivePermissions: effectivePermissions,
                                supplierPayment: presentation.payment,
                                supplierName: presentation.supplierName,
                                repository: viewModel.repository
                            ),
                            onPaymentChanged: viewModel.replace
                        )
                    } label: {
                        BusinessSupplierPaymentRow(presentation: presentation)
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadNextPageIfNeeded(
                                currentPayment: presentation
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

struct BusinessSupplierPaymentDetailView: View {
    @State private var viewModel: BusinessSupplierPaymentDetailViewModel
    @State private var isPresentingVoid = false
    private let onPaymentChanged: (BusinessProcurementSupplierPaymentResponse) -> Void

    init(
        viewModel: BusinessSupplierPaymentDetailViewModel,
        onPaymentChanged: @escaping (BusinessProcurementSupplierPaymentResponse) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onPaymentChanged = onPaymentChanged
    }

    var body: some View {
        List {
            identitySection
            amountSection
            datesSection
            evidenceSection
            allocationsSection
            traceabilitySection
            messagesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.supplierPayment.paymentNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.canVoid {
                    Menu {
                        Button(role: .destructive) {
                            isPresentingVoid = true
                        } label: {
                            Label("Anular pago", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewModel.isBusy)
                    .accessibilityLabel("Acciones del pago a proveedor")
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
                .disabled(viewModel.isBusy || !viewModel.canView)
                .accessibilityLabel("Actualizar pago a proveedor")
            }
        }
        .sheet(isPresented: $isPresentingVoid) {
            NavigationStack {
                BusinessSupplierPaymentVoidView(
                    viewModel: viewModel,
                    onCompleted: handlePaymentChanged
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
            onPaymentChanged(viewModel.supplierPayment)
        }
    }

    private func refreshDetail() async {
        await viewModel.refresh()
        if viewModel.hasLoaded {
            onPaymentChanged(viewModel.supplierPayment)
        }
    }

    private func handlePaymentChanged(
        _ payment: BusinessProcurementSupplierPaymentResponse
    ) {
        viewModel.replace(payment)
        onPaymentChanged(payment)
    }

    private var identitySection: some View {
        Section("Pago") {
            LabeledContent("Proveedor", value: viewModel.businessSupplierName)
            LabeledContent("Número", value: viewModel.supplierPayment.paymentNumber)
            LabeledContent("Estado") {
                BusinessSupplierPaymentStatusBadge(
                    status: viewModel.supplierPayment.status
                )
            }
            Text(viewModel.supplierPayment.status.businessSupplierPaymentExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var amountSection: some View {
        Section("Importe del servidor") {
            BusinessSupplierPaymentMoneyRow(
                title: "Importe registrado",
                money: viewModel.supplierPayment.amount,
                emphasized: true
            )
            LabeledContent(
                "Aplicaciones",
                value: viewModel.supplierPayment.businessAllocationCountText
            )
            Text("El backend entrega el importe y los saldos antes y después de cada aplicación. La app no suma aplicaciones ni recalcula cuentas por pagar.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var datesSection: some View {
        Section("Fechas") {
            LabeledContent("Fecha del pago", value: viewModel.supplierPayment.paymentDate)
            if let recordedAt = viewModel.supplierPayment.recordedAt {
                LabeledContent("Registrado", value: recordedAt)
            }
            LabeledContent("Creado", value: viewModel.supplierPayment.createdAt)
            LabeledContent("Actualizado", value: viewModel.supplierPayment.updatedAt)
            if let voidedAt = viewModel.supplierPayment.voidedAt {
                LabeledContent("Anulado", value: voidedAt)
            }
        }
    }

    private var evidenceSection: some View {
        Section("Método y evidencia") {
            LabeledContent(
                "Método",
                value: viewModel.supplierPayment.businessSupplierPaymentMethodName
            )

            if viewModel.canViewSensitiveEvidence {
                LabeledContent(
                    "Referencia",
                    value: viewModel.visibleReference ?? "No informada"
                )
                if let notes = viewModel.visibleNotes {
                    LabeledContent("Notas", value: notes)
                }
            } else {
                Label(
                    "La referencia y las notas están protegidas por permisos.",
                    systemImage: "lock.fill"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            LabeledContent(
                "Adjuntos",
                value: viewModel.supplierPayment.businessAttachmentCountText
            )

            if let attachmentIds = viewModel.supplierPayment.attachmentIds,
               viewModel.canView,
               viewModel.canViewSensitiveEvidence,
               (!attachmentIds.isEmpty
                || viewModel.accessPolicy.allows(BusinessProcurementPermission.attachmentsUpload)) {
                NavigationLink {
                    BusinessProcurementAttachmentsView(
                        viewModel: BusinessProcurementAttachmentsViewModel(
                            organizationId: viewModel.organizationId,
                            sourceType: .supplierPayment,
                            sourceId: viewModel.supplierPayment.id,
                            sourceVersion: viewModel.supplierPayment.version,
                            sourceDisplayName: "Pago \(viewModel.supplierPayment.paymentNumber)",
                            attachmentIds: attachmentIds,
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
                            Text("Descarga protegida y ligada a este pago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "paperclip.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                }
            }

            Text("Este registro conserva evidencia operativa. No mueve dinero real en el banco y no almacena credenciales bancarias.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var allocationsSection: some View {
        Section("Aplicaciones") {
            if viewModel.supplierPayment.allocations.isEmpty {
                Text("El servidor no informó aplicaciones para este pago.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(viewModel.supplierPayment.allocations.enumerated()),
                    id: \.element.id
                ) { index, allocation in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.allocationTitle(for: allocation, index: index))
                            .font(.headline)
                        LabeledContent(
                            "Estado",
                            value: allocation.businessAllocationStatusName
                        )
                        BusinessSupplierPaymentMoneyRow(
                            title: "Aplicado",
                            money: allocation.amount,
                            emphasized: true
                        )
                        BusinessSupplierPaymentMoneyRow(
                            title: "Saldo anterior",
                            money: allocation.payableBalanceBefore
                        )
                        BusinessSupplierPaymentMoneyRow(
                            title: "Saldo posterior",
                            money: allocation.payableBalanceAfter
                        )
                        LabeledContent("Aplicada", value: allocation.createdAt)

                        if let reversedAt = allocation.reversedAt {
                            LabeledContent("Revertida", value: reversedAt)
                            if viewModel.canViewSensitiveEvidence,
                               let reason = allocation.reversalReason {
                                LabeledContent("Motivo", value: reason)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var traceabilitySection: some View {
        Section("Trazabilidad") {
            LabeledContent("Versión", value: String(viewModel.supplierPayment.version))
            if let voidReason = viewModel.supplierPayment.voidReason,
               viewModel.canViewSensitiveEvidence {
                LabeledContent("Motivo de anulación", value: voidReason)
            }
            Text("La anulación, cuando existe, conserva el pago y la restauración de aplicaciones como historial auditable; no elimina el registro.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                    .disabled(viewModel.isBusy || !viewModel.canView)
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
}

private struct BusinessSupplierPaymentVoidView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BusinessSupplierPaymentDetailViewModel
    let onCompleted: (BusinessProcurementSupplierPaymentResponse) -> Void
    @State private var reason = ""

    var body: some View {
        Form {
            Section {
                Text(
                    "Anularás el pago \(viewModel.supplierPayment.paymentNumber). Esta acción conserva el registro y requiere un motivo auditable."
                )
                .fixedSize(horizontal: false, vertical: true)
            }

            Section("Efecto controlado por el servidor") {
                Label(
                    "El backend vuelve a validar tu permiso, el estado y la versión antes de aceptar la anulación.",
                    systemImage: "checkmark.shield"
                )
                Label(
                    "El servidor restaura las aplicaciones y los saldos; la app no los recalcula localmente.",
                    systemImage: "arrow.uturn.backward.circle"
                )
                Label(
                    "La app no mueve dinero real ni revierte una transferencia bancaria; solicita anular el registro operativo.",
                    systemImage: "building.columns"
                )
                Label(
                    "El pago no se elimina; conserva la anulación y sus reversiones como historial auditable.",
                    systemImage: "clock.arrow.circlepath"
                )
            }
            .font(.footnote)

            Section("Motivo de anulación") {
                TextField(
                    "Explica por qué se anula el pago",
                    text: $reason,
                    axis: .vertical
                )
                .lineLimit(2...5)
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
        .navigationTitle("Anular pago")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.isVoiding)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Volver") { dismiss() }
                    .disabled(viewModel.isVoiding)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(role: .destructive) {
                    Task {
                        if let payment = await viewModel.void(reason: reason) {
                            onCompleted(payment)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isVoiding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Confirmar anulación")
                    }
                }
                .disabled(
                    viewModel.isVoiding || reason
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
            }
        }
    }
}

private struct BusinessSupplierPaymentRow: View {
    let presentation: BusinessSupplierPaymentPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(presentation.payment.paymentNumber)
                    .font(.headline)
                Spacer(minLength: 12)
                BusinessSupplierPaymentStatusBadge(
                    status: presentation.payment.status
                )
            }

            Text(presentation.businessSupplierName)
                .font(.subheadline)

            HStack {
                Text(presentation.payment.paymentDate)
                Spacer()
                Text(presentation.payment.amount.businessDisplayText())
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(
                "\(presentation.payment.businessSupplierPaymentMethodName) · \(presentation.payment.businessAllocationCountText)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct BusinessSupplierPaymentStatusBadge: View {
    let status: BusinessSupplierPaymentStatus

    var body: some View {
        Text(status.businessSupplierPaymentDisplayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(foregroundColor.opacity(0.13), in: Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .processing: return .orange
        case .recorded: return .green
        case .voiding: return .orange
        case .voided: return .secondary
        }
    }
}

private struct BusinessSupplierPaymentMoneyRow: View {
    let title: String
    let money: BusinessProcurementMoneyResponse
    var emphasized = false

    var body: some View {
        LabeledContent(title) {
            Text(money.businessDisplayText())
                .fontWeight(emphasized ? .semibold : .regular)
                .monospacedDigit()
        }
    }
}

private struct BusinessSupplierPaymentMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.indigo)
        }
    }
}
