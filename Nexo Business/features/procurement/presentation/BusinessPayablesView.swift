//
//  BusinessPayablesView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessPayablesView: View {
    @Bindable private var viewModel: BusinessPayablesViewModel
    private let activeModules: Set<ModuleCode>
    private let effectivePermissions: Set<String>

    init(
        viewModel: BusinessPayablesViewModel,
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
            payablesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cuentas por pagar")
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
                .accessibilityLabel("Actualizar cuentas por pagar")
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
                Label("Obligaciones con proveedores", systemImage: "calendar.badge.exclamationmark")
                    .font(.headline)
                Text("Consulta importes originales, pagos aplicados y saldos pendientes. El estado y todos los importes provienen del servidor; la app no recalcula la cuenta por pagar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    BusinessPayableMetric(
                        title: "Visibles",
                        value: String(viewModel.payables.count),
                        systemImage: "list.bullet.rectangle"
                    )
                    BusinessPayableMetric(
                        title: "Corte",
                        value: viewModel.snapshotAsOf ?? "Servidor",
                        systemImage: "calendar"
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var filtersSection: some View {
        Section("Filtros") {
            Picker("Estado efectivo", selection: $viewModel.statusFilter) {
                ForEach(BusinessPayablesViewModel.StatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.statusFilter) { _, _ in
                Task { await viewModel.search() }
            }

            TextField("Moneda, por ejemplo USD", text: $viewModel.currency)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            DisclosureGroup("Vencimiento") {
                TextField("Desde (AAAA-MM-DD)", text: $viewModel.dueFrom)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                TextField("Hasta (AAAA-MM-DD)", text: $viewModel.dueTo)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
            }

            TextField("Fecha de corte (AAAA-MM-DD)", text: $viewModel.asOf)
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
    private var payablesSection: some View {
        Section("Resultados") {
            if viewModel.isLoading && viewModel.payables.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando cuentas por pagar…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.payables.isEmpty {
                ContentUnavailableView(
                    "Sin cuentas por pagar",
                    systemImage: "checkmark.circle",
                    description: Text("Prueba otros filtros o confirma que tu usuario tenga acceso al módulo Compras.")
                )
            } else {
                ForEach(viewModel.payables) { presentation in
                    NavigationLink {
                        BusinessPayableDetailView(
                            viewModel: BusinessPayableDetailViewModel(
                                organizationId: viewModel.organizationId,
                                asOf: viewModel.snapshotAsOf ?? viewModel.asOf,
                                activeModules: activeModules,
                                effectivePermissions: effectivePermissions,
                                payable: presentation.payable,
                                supplierName: presentation.supplierName,
                                sourceDocumentNumber: presentation.sourceDocumentNumber,
                                repository: viewModel.repository
                            ),
                            onPayableChanged: viewModel.replace
                        )
                    } label: {
                        BusinessPayableRow(presentation: presentation)
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadNextPageIfNeeded(
                                currentPayable: presentation
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

struct BusinessPayableDetailView: View {
    @State private var viewModel: BusinessPayableDetailViewModel
    @State private var isPresentingPaymentForm = false
    private let onPayableChanged: (BusinessProcurementPayableResponse) -> Void

    init(
        viewModel: BusinessPayableDetailViewModel,
        onPayableChanged: @escaping (BusinessProcurementPayableResponse) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onPayableChanged = onPayableChanged
    }

    var body: some View {
        List {
            identitySection
            amountsSection
            datesSection
            settlementSection
            sourceSection
            messagesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cuenta por pagar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
                .disabled(viewModel.isLoading || !viewModel.canView)
                .accessibilityLabel("Actualizar cuenta por pagar")
            }
        }
        .refreshable {
            await refreshDetail()
        }
        .task {
            await loadDetailIfNeeded()
        }
        .sheet(isPresented: $isPresentingPaymentForm) {
            NavigationStack {
                BusinessSupplierPaymentFormView(
                    viewModel: BusinessSupplierPaymentFormViewModel(
                        organizationId: viewModel.organizationId,
                        activeModules: viewModel.accessPolicy.activeModules,
                        effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                        payable: viewModel.payable,
                        supplierName: viewModel.businessSupplierName,
                        repository: viewModel.repository
                    ),
                    onPaymentRecorded: applyPaymentResult
                )
            }
        }
    }

    private func loadDetailIfNeeded() async {
        await viewModel.loadIfNeeded()
        if viewModel.hasLoaded {
            onPayableChanged(viewModel.payable)
        }
    }

    private func refreshDetail() async {
        await viewModel.refresh()
        if viewModel.hasLoaded {
            onPayableChanged(viewModel.payable)
        }
    }

    private var identitySection: some View {
        Section("Obligación") {
            LabeledContent("Proveedor", value: viewModel.businessSupplierName)
            LabeledContent("Origen", value: viewModel.businessSourceDescription)
            LabeledContent("Estado") {
                BusinessPayableStatusBadge(status: viewModel.payable.effectiveStatus)
            }
            Text(viewModel.payable.effectiveStatus.businessPayableExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var amountsSection: some View {
        Section("Importes del servidor") {
            BusinessPayableMoneyRow(
                title: "Importe original",
                money: viewModel.payable.originalAmount
            )
            BusinessPayableMoneyRow(
                title: "Pagado",
                money: viewModel.payable.paidAmount
            )
            BusinessPayableMoneyRow(
                title: "Saldo pendiente",
                money: viewModel.payable.balance,
                emphasized: true
            )
            Text("El servidor entrega cada importe y el saldo. La app no resta pagos ni vuelve a sumar aplicaciones.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var datesSection: some View {
        Section("Fechas") {
            LabeledContent("Vencimiento", value: viewModel.payable.dueDate)
            if let asOf = viewModel.asOf {
                LabeledContent("Corte consultado", value: asOf)
            }
            LabeledContent("Creada", value: viewModel.payable.createdAt)
            LabeledContent("Actualizada", value: viewModel.payable.updatedAt)
        }
    }

    private var settlementSection: some View {
        Section("Liquidación") {
            LabeledContent(
                "Estado de liquidación",
                value: viewModel.payable.businessSettlementStatusName
            )
            LabeledContent(
                "Aplicaciones",
                value: viewModel.payable.businessAllocationCountText
            )
            if viewModel.canRecordPayment {
                Button {
                    isPresentingPaymentForm = true
                } label: {
                    Label("Registrar pago", systemImage: "creditcard")
                }

                Text("El registro aplica el importe a esta cuenta mediante el backend. No mueve dinero en el banco ni recalcula el saldo en la app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func applyPaymentResult(_ result: BusinessSupplierPaymentRecordResult) {
        if let updatedPayable = result.updatedPayable {
            viewModel.replace(updatedPayable)
            onPayableChanged(updatedPayable)
        } else {
            Task { await refreshDetail() }
        }
    }

    private var sourceSection: some View {
        Section("Trazabilidad") {
            LabeledContent(
                "Tipo de origen",
                value: viewModel.payable.sourceType
                    .replacingOccurrences(of: "_", with: " ")
                    .lowercased()
                    .localizedCapitalized
            )
            LabeledContent("Documento", value: viewModel.businessSourceDescription)
            LabeledContent("Versión", value: String(viewModel.payable.version))
            Text("La referencia visible vincula esta obligación con su fuente sin presentar identificadores internos como nombres principales.")
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
    }
}

private struct BusinessSupplierPaymentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BusinessSupplierPaymentFormViewModel
    let onPaymentRecorded: (BusinessSupplierPaymentRecordResult) -> Void

    init(
        viewModel: BusinessSupplierPaymentFormViewModel,
        onPaymentRecorded: @escaping (BusinessSupplierPaymentRecordResult) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onPaymentRecorded = onPaymentRecorded
    }

    var body: some View {
        Form {
            obligationSection
            paymentSection
            evidenceSection
            validationSection
            messagesSection
        }
        .navigationTitle("Registrar pago")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.isRecording)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(viewModel.isRecording)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if let result = await viewModel.recordPayment() {
                            onPaymentRecorded(result)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isRecording {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Registrar")
                    }
                }
                .disabled(!viewModel.canRecord)
            }
        }
    }

    private var obligationSection: some View {
        Section("Cuenta por pagar") {
            LabeledContent("Proveedor", value: viewModel.supplierName)
            BusinessPayableMoneyRow(
                title: "Saldo del servidor",
                money: viewModel.payable.balance,
                emphasized: true
            )
            LabeledContent("Moneda", value: viewModel.payable.currency.uppercased())
        }
    }

    private var paymentSection: some View {
        Section("Pago") {
            TextField("Fecha (AAAA-MM-DD)", text: $viewModel.paymentDate)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)

            TextField("Importe", text: $viewModel.amount)
                .keyboardType(.decimalPad)
                .monospacedDigit()

            Picker("Método", selection: $viewModel.method) {
                ForEach(BusinessSupplierPaymentMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
        }
    }

    private var evidenceSection: some View {
        Section("Evidencia") {
            TextField("Referencia", text: $viewModel.reference)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            TextField("Notas opcionales", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...5)

            Text("El backend registra una aplicación auditada por el mismo importe. La referencia es obligatoria salvo para efectivo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if let validationMessage = viewModel.accessValidationMessage
            ?? viewModel.inputValidationMessage {
            Section {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
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

        if let infoMessage = viewModel.infoMessage {
            Section {
                Label(infoMessage, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BusinessPayableRow: View {
    let presentation: BusinessPayablePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(presentation.businessSupplierName)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                BusinessPayableStatusBadge(
                    status: presentation.payable.effectiveStatus
                )
            }

            Text(presentation.businessSourceDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Label(
                    presentation.payable.dueDate,
                    systemImage: "calendar"
                )
                Spacer()
                Text(presentation.payable.balance.businessDisplayText())
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessPayableStatusBadge: View {
    let status: BusinessPayableEffectiveStatus

    var body: some View {
        Text(status.businessPayableDisplayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .open: return .blue
        case .partiallyPaid: return .orange
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .secondary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.13)
    }
}

private struct BusinessPayableMoneyRow: View {
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

private struct BusinessPayableMetric: View {
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
