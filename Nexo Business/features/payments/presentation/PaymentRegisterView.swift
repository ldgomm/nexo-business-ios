//
//  PaymentRegisterView.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import SwiftUI

struct PaymentRegisterView: View {
    @Bindable private var viewModel: PaymentRegisterViewModel
    private let customersRepository: CustomersRepository
    private let onSaleUpdated: (BusinessSale) -> Void
    private let autoPrepareCashOnAppear: Bool
    @State private var showSubmitConfirmation = false
    @State private var shouldIssueDocumentAfterPayment = false

    init(
        viewModel: PaymentRegisterViewModel,
        autoPrepareCashOnAppear: Bool = false,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.autoPrepareCashOnAppear = autoPrepareCashOnAppear
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
            await viewModel.prepareInitialLoadForPaymentScreen(
                autoPrepareCash: autoPrepareCashOnAppear
            )
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
            Section("Cobro") {
                PaymentOutcomeMessageView(
                    message: "Cobro registrado correctamente.",
                    systemImage: "checkmark.seal.fill",
                    tint: .green
                )

                LabeledContent("Método", value: viewModel.paymentMethodDisplayName(payment.method))
                LabeledContent("Monto cobrado", value: money(payment.amount))

                if viewModel.registeredPaymentWasCash {
                    Divider()
                    PaymentOutcomeMessageView(
                        message: "Caja actualizada automáticamente.",
                        systemImage: "banknote.fill",
                        tint: .green
                    )

                    if let movement = viewModel.cashMovementResult {
                        LabeledContent("Monto en caja", value: movement.amount.displayText)
                    }
                    if let session = viewModel.currentCashSession, let expected = session.expectedAmount {
                        LabeledContent("Efectivo esperado", value: expected.displayText)
                    }

                    Text("El movimiento de caja ya fue creado por el sistema. No registres este cobro como ajuste manual.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let receivable = viewModel.receivableResult {
            Section("Cuenta por cobrar") {
                PaymentOutcomeMessageView(
                    message: "Cuenta por cobrar creada.",
                    systemImage: "person.crop.circle.badge.clock",
                    tint: .orange
                )

                LabeledContent("Monto", value: money(receivable.amount))
                if let balance = receivable.balance {
                    LabeledContent("Saldo", value: money(balance))
                }
            }
        }

        if let document = viewModel.electronicDocumentResult {
            Section("Factura electrónica") {
                PaymentOutcomeMessageView(
                    message: PaymentDocumentOutcomePresentation.title(for: document),
                    systemImage: PaymentDocumentOutcomePresentation.systemImage(for: document),
                    tint: PaymentDocumentOutcomePresentation.tint(for: document)
                )

                if let number = document.number, !number.isEmpty {
                    LabeledContent("Número", value: number)
                }
                if let authorizationNumber = document.authorizationNumber, !authorizationNumber.isEmpty {
                    LabeledContent("Autorización", value: authorizationNumber)
                }
                if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                    PaymentOutcomeMessageView(
                        message: error,
                        systemImage: "exclamationmark.triangle",
                        tint: .red
                    )
                } else if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
                    Text("Disponible en Comprobantes para revisar RIDE, XML o compartir con el cliente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section("Atención") {
                PaymentOutcomeMessageView(
                    message: message,
                    systemImage: "exclamationmark.triangle",
                    tint: .red
                )
            }
        }

        if let message = viewModel.infoMessage, !viewModel.hasCompletedSubmission {
            Section {
                PaymentOutcomeMessageView(
                    message: message,
                    systemImage: "info.circle",
                    tint: .secondary
                )
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if viewModel.hasCompletedSubmission {
            Section("Siguiente acción") {
                NavigationLink {
                    CashDashboardRouteView(
                        viewModel: viewModel.makeCashDashboardViewModel(),
                        refreshOnAppear: true
                    )
                } label: {
                    Label(viewModel.registeredPaymentWasCash ? "Ver caja o cerrar caja" : "Ver caja", systemImage: "banknote")
                }

                if let documentsViewModel = viewModel.makeBusinessDocumentsViewModel() {
                    NavigationLink {
                        BusinessDocumentsRouteView(
                            viewModel: documentsViewModel,
                            onSaleUpdated: { updatedSale in
                                onSaleUpdated(updatedSale)
                            }
                        )
                    } label: {
                        Label("Ver comprobantes", systemImage: "doc.text.magnifyingglass")
                    }
                }

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Label("Actualizar venta y caja", systemImage: "arrow.clockwise")
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
                    if viewModel.shouldShowPaymentAndIssueElectronicDocumentAction {
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
                    }

                    if let reason = viewModel.electronicDocumentAfterPaymentBlockedReason {
                        PaymentOutcomeMessageView(
                            message: reason,
                            systemImage: "info.circle",
                            tint: .secondary
                        )

                        if let detail = viewModel.sale.electronicInvoiceReadiness.detailedMessage {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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

private struct PaymentOutcomeMessageView: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 22)

            Text(message)
                .font(.footnote)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private enum PaymentDocumentOutcomePresentation {
    static func title(for document: BusinessDocument) -> String {
        if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
            return "Factura electrónica autorizada."
        }

        if BusinessDocumentStatusPresentation.isError(document.effectiveStatus) {
            return "Factura electrónica no autorizada."
        }

        return "Factura electrónica: \(BusinessDocumentStatusPresentation.displayName(document.effectiveStatus))."
    }

    static func systemImage(for document: BusinessDocument) -> String {
        if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
            return "checkmark.seal.fill"
        }

        if BusinessDocumentStatusPresentation.isError(document.effectiveStatus) {
            return "exclamationmark.triangle.fill"
        }

        return BusinessDocumentStatusPresentation.systemImage(document.effectiveStatus)
    }

    static func tint(for document: BusinessDocument) -> Color {
        if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
            return .green
        }

        if BusinessDocumentStatusPresentation.isError(document.effectiveStatus) {
            return .red
        }

        return .secondary
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
