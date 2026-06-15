//
//  PaymentRegisterView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct PaymentRegisterView: View {
    @Bindable private var viewModel: PaymentRegisterViewModel
    private let customersRepository: CustomersRepository
    private let onSaleUpdated: (BusinessSale) -> Void
    @State private var showSubmitConfirmation = false
    @State private var shouldIssueDocumentAfterPayment = false

    init(
        viewModel: PaymentRegisterViewModel,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.onSaleUpdated = onSaleUpdated
    }

    var body: some View {
        Form {
            saleSection

            if !viewModel.saleNeedsCollection && !viewModel.hasCompletedSubmission {
                collectionClosedSection
                messagesSection
            } else if viewModel.canAccessPaymentScreen {
                if !viewModel.hasCompletedSubmission {
                    methodSection
                    amountSection
                    cashSection
                    creditSection
                }

                resultSection
                messagesSection
                actionsSection
            } else {
                accessDeniedSection
                messagesSection
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle(viewModel.hasCompletedSubmission ? "Cobro registrado" : "Confirmar cobro")
        .alert(
            viewModel.submitConfirmationTitle(issueElectronicDocumentAfterPayment: shouldIssueDocumentAfterPayment),
            isPresented: $showSubmitConfirmation
        ) {
            if viewModel.selectedMode == .credit {
                Button(viewModel.submitButtonTitle(issueElectronicDocumentAfterPayment: false)) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.submit() }
                }
            } else {
                Button(viewModel.submitButtonTitle(issueElectronicDocumentAfterPayment: shouldIssueDocumentAfterPayment), role: .destructive) {
                    let shouldIssue = shouldIssueDocumentAfterPayment
                    NexoKeyboard.dismiss()
                    Task { await viewModel.submit(issueElectronicDocumentAfterPayment: shouldIssue) }
                }
            }
            Button("Cancelar", role: .cancel) {
                shouldIssueDocumentAfterPayment = false
            }
        } message: {
            Text(viewModel.submitConfirmationMessage(issueElectronicDocumentAfterPayment: shouldIssueDocumentAfterPayment))
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.selectedMode) { _, _ in
            viewModel.resetResultMessages()
            Task { await viewModel.refreshForSelectedMode() }
        }
        .onChange(of: viewModel.sale) { _, sale in
            onSaleUpdated(sale)
        }
    }

    private var saleSection: some View {
        Section("Venta") {
            LabeledContent("Venta", value: viewModel.sale.displayNumber)
            SaleStatusLabel(status: viewModel.sale.status)
            LabeledContent("Estado de cobro", value: viewModel.salePaymentStatusText)
            LabeledContent("Comprobante", value: viewModel.saleDocumentStatusText)
            LabeledContent("Total", value: viewModel.sale.totals.grandTotal.displayText)
        }
    }

    private var collectionClosedSection: some View {
        Section("Cobro") {
            Label(viewModel.collectionClosedMessage, systemImage: "checkmark.seal")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.load() }
            } label: {
                Label("Actualizar caja", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoadingCash)
        }
    }

    private var accessDeniedSection: some View {
        Section("Cobro no habilitado") {
            Label(viewModel.accessDeniedMessage, systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var methodSection: some View {
        Section("Método") {
            Picker("Método", selection: $viewModel.selectedMode) {
                ForEach(viewModel.availableModes) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
        }
    }

    private var amountSection: some View {
        Section("Monto") {
            TextField("Monto", text: $viewModel.amount)
                .keyboardType(.decimalPad)

            if viewModel.selectedMode == .transfer || viewModel.selectedMode == .card {
                TextField("Referencia", text: $viewModel.reference)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                if let helpText = viewModel.referenceHelpText {
                    Text(helpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Nota opcional", text: $viewModel.note, axis: .vertical)
                .textInputAutocapitalization(.sentences)
        }
    }

    @ViewBuilder
    private var cashSection: some View {
        if viewModel.selectedMode == .cash {
            Section("Caja") {
                if viewModel.isLoadingCash {
                    ProgressView("Consultando caja…")
                } else if let session = viewModel.currentCashSession, session.isOpen {
                    Label("Caja abierta", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    LabeledContent("Estado", value: session.displayStatus)
                    if let expected = session.expectedAmount {
                        LabeledContent("Efectivo esperado", value: expected.displayText)
                    }
                    if let openedAt = session.openedAt {
                        LabeledContent("Abierta", value: openedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    Text("Al confirmar este cobro, la caja se actualizará automáticamente. No registres este valor como ajuste manual.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Necesitas una caja abierta para cobrar en efectivo.", systemImage: "lock")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var creditSection: some View {
        if viewModel.selectedMode == .credit {
            Section("Cliente para crédito") {
                if let customer = viewModel.selectedCustomer {
                    CustomerRowView(customer: customer)

                    Button(role: .destructive) {
                        viewModel.clearCustomer()
                    } label: {
                        Label("Quitar cliente", systemImage: "xmark.circle")
                    }
                } else if !viewModel.customerId.isEmpty {
                    LabeledContent("Cliente ID", value: viewModel.customerId)
                } else {
                    Label("Selecciona un cliente identificado para dejar una cuenta por cobrar.", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    CustomerPickerView(
                        viewModel: CustomerPickerViewModel(
                            organizationId: viewModel.organizationId,
                            effectivePermissions: viewModel.effectivePermissions,
                            customersRepository: customersRepository
                        ),
                        onSelect: { customer in
                            viewModel.selectCustomer(customer)
                        }
                    )
                } label: {
                    Label("Seleccionar cliente", systemImage: "person.text.rectangle")
                }

                TextField("Cliente ID manual", text: $viewModel.customerId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Agregar fecha de vencimiento", isOn: $viewModel.useDueDate)

                if viewModel.useDueDate {
                    DatePicker(
                        "Vence",
                        selection: $viewModel.dueDate,
                        displayedComponents: [.date]
                    )
                }

                Text("Para dejar fiado o crédito, la venta debe tener un cliente identificado. No lo dejes como consumidor final.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let payment = viewModel.paymentResult {
            Section("Cobro registrado") {
                Label("Cobro registrado correctamente", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                LabeledContent("ID", value: payment.id)
                LabeledContent("Método", value: viewModel.paymentMethodDisplayName(payment.method))
                LabeledContent("Estado", value: PaymentStatusPresentation.displayName(payment.status))
                LabeledContent("Monto", value: money(payment.amount))

                if viewModel.registeredPaymentWasCash {
                    Divider()
                    Label("Caja actualizada automáticamente", systemImage: "banknote.fill")
                        .foregroundStyle(.green)
                    if let movement = viewModel.cashMovementResult {
                        LabeledContent("Movimiento", value: movement.id)
                        LabeledContent("Monto caja", value: movement.amount.displayText)
                    }
                    if let session = viewModel.currentCashSession, let expected = session.expectedAmount {
                        LabeledContent("Efectivo esperado", value: expected.displayText)
                    }
                }
            }
        }

        if let receivable = viewModel.receivableResult {
            Section("Cuenta por cobrar") {
                Label("Cuenta por cobrar creada", systemImage: "person.crop.circle.badge.clock")
                    .foregroundStyle(.orange)
                LabeledContent("ID", value: receivable.id)
                LabeledContent("Estado", value: ReceivableStatusPresentation.displayName(receivable.status))
                LabeledContent("Monto", value: money(receivable.amount))
                if let balance = receivable.balance {
                    LabeledContent("Saldo", value: money(balance))
                }
            }
        }

        if let document = viewModel.electronicDocumentResult {
            Section("Factura electrónica") {
                Label(
                    BusinessDocumentStatusPresentation.displayName(document.status),
                    systemImage: BusinessDocumentStatusPresentation.systemImage(document.status)
                )
                .foregroundStyle(BusinessDocumentStatusPresentation.isError(document.status) ? .red : .secondary)

                if let number = document.number, !number.isEmpty {
                    LabeledContent("Número", value: number)
                }
                if let error = document.lastErrorMessage, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
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
                Label(message, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if viewModel.hasCompletedSubmission {
            Section("Siguiente acción") {
                NavigationLink {
                    CashDashboardView(
                        viewModel: viewModel.makeCashDashboardViewModel()
                    )
                } label: {
                    Label(viewModel.registeredPaymentWasCash ? "Ver caja o cerrar caja" : "Ver caja", systemImage: "banknote")
                }

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Label("Actualizar caja", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingCash)
            }
        } else {
            Section("Confirmación") {
                Button {
                    shouldIssueDocumentAfterPayment = false
                    NexoKeyboard.dismiss()
                    showSubmitConfirmation = true
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else if viewModel.selectedMode == .credit {
                        Label("Crear cuenta por cobrar", systemImage: "person.crop.circle.badge.clock")
                    } else {
                        Label("Confirmar cobro", systemImage: "checkmark.seal")
                    }
                }
                .disabled(viewModel.selectedMode == .credit ? !viewModel.canCreateReceivable : !viewModel.canSubmitPayment)

                if viewModel.selectedMode != .credit {
                    Button {
                        shouldIssueDocumentAfterPayment = true
                        NexoKeyboard.dismiss()
                        showSubmitConfirmation = true
                    } label: {
                        if viewModel.isSubmitting || viewModel.isIssuingElectronicDocument {
                            ProgressView()
                        } else {
                            Label("Confirmar cobro y emitir documento", systemImage: "doc.badge.plus")
                        }
                    }
                    .disabled(!viewModel.canSubmitPaymentAndIssueElectronicDocument)

                    if let reason = viewModel.electronicDocumentAfterPaymentBlockedReason {
                        Label(reason, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Label("Actualizar caja", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingCash)
            }
        }
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

struct PaymentRegisterInlineView: View {
    @Bindable private var viewModel: PaymentRegisterViewModel
    private let customersRepository: CustomersRepository
    private let onSaleUpdated: (BusinessSale) -> Void
    @State private var showSubmitConfirmation = false
    @State private var shouldIssueDocumentAfterPayment = false

    init(
        viewModel: PaymentRegisterViewModel,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.onSaleUpdated = onSaleUpdated
    }

    var body: some View {
        Group {
            if !viewModel.saleNeedsCollection && !viewModel.hasCompletedSubmission {
                paymentCollectionClosedSection
            } else if !viewModel.canAccessPaymentScreen {
                paymentAccessDeniedSection
            } else if !viewModel.hasCompletedSubmission {
                paymentMethodSection
                paymentAmountSection
                paymentCashSection
                paymentCreditSection
                paymentActionSection
            } else {
                paymentResultSection
            }

            paymentMessagesSection
        }
        .alert(
            viewModel.submitConfirmationTitle(issueElectronicDocumentAfterPayment: shouldIssueDocumentAfterPayment),
            isPresented: $showSubmitConfirmation
        ) {
            if viewModel.selectedMode == .credit {
                Button(viewModel.submitButtonTitle(issueElectronicDocumentAfterPayment: false)) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.submit() }
                }
            } else {
                Button(viewModel.submitButtonTitle(issueElectronicDocumentAfterPayment: shouldIssueDocumentAfterPayment), role: .destructive) {
                    let shouldIssue = shouldIssueDocumentAfterPayment
                    NexoKeyboard.dismiss()
                    Task { await viewModel.submit(issueElectronicDocumentAfterPayment: shouldIssue) }
                }
            }
            Button("Cancelar", role: .cancel) {
                shouldIssueDocumentAfterPayment = false
            }
        } message: {
            Text(viewModel.submitConfirmationMessage(issueElectronicDocumentAfterPayment: shouldIssueDocumentAfterPayment))
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.selectedMode) { _, _ in
            viewModel.resetResultMessages()
            Task { await viewModel.refreshForSelectedMode() }
        }
        .onChange(of: viewModel.sale) { _, sale in
            onSaleUpdated(sale)
        }
    }

    private var paymentCollectionClosedSection: some View {
        Section("Cobro") {
            Label(viewModel.collectionClosedMessage, systemImage: "checkmark.seal")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var paymentAccessDeniedSection: some View {
        Section("Cobro no habilitado") {
            Label(viewModel.accessDeniedMessage, systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var paymentMethodSection: some View {
        Section("Registrar cobro") {
            Picker("Método", selection: $viewModel.selectedMode) {
                ForEach(viewModel.availableModes) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)

            Text("Elige el método y confirma el cobro aquí mismo. Si es efectivo, se registrará en caja automáticamente.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var paymentAmountSection: some View {
        Section("Monto y referencia") {
            TextField("Monto", text: $viewModel.amount)
                .keyboardType(.decimalPad)

            if viewModel.selectedMode == .transfer || viewModel.selectedMode == .card {
                TextField("Referencia", text: $viewModel.reference)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                if let helpText = viewModel.referenceHelpText {
                    Text(helpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Nota opcional", text: $viewModel.note, axis: .vertical)
                .textInputAutocapitalization(.sentences)
        }
    }

    @ViewBuilder
    private var paymentCashSection: some View {
        if viewModel.selectedMode == .cash {
            Section("Caja") {
                if viewModel.isLoadingCash {
                    ProgressView("Consultando caja…")
                } else if let session = viewModel.currentCashSession, session.isOpen {
                    Label("Caja abierta", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    if let expected = session.expectedAmount {
                        LabeledContent("Efectivo esperado actual", value: expected.displayText)
                    }

                    Text("Al confirmar el cobro, el backend debe crear el movimiento de caja automáticamente. No uses ajustes manuales para esta venta.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Necesitas caja abierta para cobrar en efectivo.", systemImage: "lock")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var paymentCreditSection: some View {
        if viewModel.selectedMode == .credit {
            Section("Cuenta por cobrar") {
                if let customer = viewModel.selectedCustomer {
                    CustomerRowView(customer: customer)

                    Button(role: .destructive) {
                        viewModel.clearCustomer()
                    } label: {
                        Label("Quitar cliente", systemImage: "xmark.circle")
                    }
                } else if !viewModel.customerId.isEmpty {
                    LabeledContent("Cliente ID", value: viewModel.customerId)
                } else {
                    Label("Selecciona un cliente identificado para dejar la venta por cobrar.", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    CustomerPickerView(
                        viewModel: CustomerPickerViewModel(
                            organizationId: viewModel.organizationId,
                            effectivePermissions: viewModel.effectivePermissions,
                            customersRepository: customersRepository
                        ),
                        onSelect: { customer in
                            viewModel.selectCustomer(customer)
                        }
                    )
                } label: {
                    Label("Seleccionar cliente", systemImage: "person.text.rectangle")
                }

                Toggle("Agregar fecha de vencimiento", isOn: $viewModel.useDueDate)

                if viewModel.useDueDate {
                    DatePicker(
                        "Vence",
                        selection: $viewModel.dueDate,
                        displayedComponents: [.date]
                    )
                }
            }
        }
    }

    private var paymentActionSection: some View {
        Section("Confirmación") {
            Button {
                shouldIssueDocumentAfterPayment = false
                NexoKeyboard.dismiss()
                showSubmitConfirmation = true
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                } else if viewModel.selectedMode == .credit {
                    Label("Crear cuenta por cobrar", systemImage: "person.crop.circle.badge.clock")
                } else {
                    Label("Confirmar cobro", systemImage: "checkmark.seal.fill")
                }
            }
            .disabled(viewModel.selectedMode == .credit ? !viewModel.canCreateReceivable : !viewModel.canSubmitPayment)

            if viewModel.selectedMode != .credit {
                Button {
                    shouldIssueDocumentAfterPayment = true
                    NexoKeyboard.dismiss()
                    showSubmitConfirmation = true
                } label: {
                    if viewModel.isSubmitting || viewModel.isIssuingElectronicDocument {
                        ProgressView()
                    } else {
                        Label("Confirmar cobro y emitir documento", systemImage: "doc.badge.plus")
                    }
                }
                .disabled(!viewModel.canSubmitPaymentAndIssueElectronicDocument)

                if let reason = viewModel.electronicDocumentAfterPaymentBlockedReason {
                    Label(reason, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.load() }
            } label: {
                Label("Actualizar caja", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoadingCash)
        }
    }

    @ViewBuilder
    private var paymentResultSection: some View {
        if let payment = viewModel.paymentResult {
            Section("Cobro registrado") {
                Label("Cobro registrado correctamente", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                LabeledContent("Método", value: viewModel.paymentMethodDisplayName(payment.method))
                LabeledContent("Monto", value: payment.amount.displayText)

                if viewModel.registeredPaymentWasCash {
                    Divider()
                    Label("Caja actualizada automáticamente", systemImage: "banknote.fill")
                        .foregroundStyle(.green)

                    if let movement = viewModel.cashMovementResult {
                        LabeledContent("Movimiento de caja", value: movement.id)
                        LabeledContent("Monto en caja", value: movement.amount.displayText)
                    }

                    if let session = viewModel.currentCashSession, let expected = session.expectedAmount {
                        LabeledContent("Efectivo esperado", value: expected.displayText)
                    }
                }
            }
        }

        if let receivable = viewModel.receivableResult {
            Section("Cuenta por cobrar") {
                Label("Cuenta por cobrar creada", systemImage: "person.crop.circle.badge.clock")
                    .foregroundStyle(.orange)
                LabeledContent("ID", value: receivable.id)
                LabeledContent("Monto", value: receivable.amount.displayText)
                if let balance = receivable.balance {
                    LabeledContent("Saldo", value: balance.displayText)
                }
            }
        }

        if let document = viewModel.electronicDocumentResult {
            Section("Factura electrónica") {
                Label(
                    BusinessDocumentStatusPresentation.displayName(document.status),
                    systemImage: BusinessDocumentStatusPresentation.systemImage(document.status)
                )
                .foregroundStyle(BusinessDocumentStatusPresentation.isError(document.status) ? .red : .secondary)

                if let number = document.number, !number.isEmpty {
                    LabeledContent("Número", value: number)
                }
                if let error = document.lastErrorMessage, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var paymentMessagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                Label(message, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaymentRegisterView(
            viewModel: PaymentRegisterViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                sale: PreviewData.confirmedSaleResponse.sale,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                cashRepository: PreviewCashRepository(),
                paymentsRepository: PreviewPaymentsRepository(),
                receivablesRepository: PreviewReceivablesRepository()
            ),
            customersRepository: PreviewCustomersRepository()
        )
    }
}
