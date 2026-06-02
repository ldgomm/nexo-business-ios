//
//  ReceivableCollectionView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI

struct ReceivableCollectionView: View {
    @Bindable private var viewModel: ReceivableCollectionViewModel

    init(viewModel: ReceivableCollectionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            Section("Cuenta por cobrar") {
                LabeledContent("ID", value: viewModel.receivable.id)
                LabeledContent("Estado", value: ReceivableStatusPresentation.displayName(viewModel.receivable.status))
                LabeledContent("Monto", value: money(viewModel.receivable.amount))
                if let balance = viewModel.receivable.balance {
                    LabeledContent("Saldo", value: money(balance))
                }
            }

            Section("Abono") {
                Picker("Método", selection: $viewModel.selectedMethod) {
                    ForEach([BusinessPaymentMethod.cash, .transfer, .card], id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }

                TextField("Monto", text: $viewModel.amount)
                    .keyboardType(.decimalPad)

                if viewModel.selectedMethod != .cash {
                    TextField("Referencia", text: $viewModel.reference)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                TextField("Nota opcional", text: $viewModel.note, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
            }

            if viewModel.selectedMethod == .cash {
                Section("Caja") {
                    if viewModel.isLoadingCash {
                        ProgressView("Consultando caja…")
                    } else if let session = viewModel.currentCashSession, session.isOpen {
                        Label("Caja abierta", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        LabeledContent("Sesión", value: session.id)
                    } else {
                        Label("Necesitas una caja abierta para abonos en efectivo.", systemImage: "lock")
                            .foregroundStyle(.red)
                    }
                }
            }

            if let payment = viewModel.paymentResult {
                Section("Abono registrado") {
                    LabeledContent("Pago", value: payment.id)
                    LabeledContent("Monto", value: money(payment.amount))
                    LabeledContent("Método", value: payment.method)
                }
            }

            if let updated = viewModel.updatedReceivable {
                Section("Estado actualizado") {
                    LabeledContent("Estado", value: ReceivableStatusPresentation.displayName(updated.status))
                    if let balance = updated.balance {
                        LabeledContent("Saldo", value: money(balance))
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
                    Label(message, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.collect() }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Label("Registrar abono", systemImage: "checkmark.seal")
                    }
                }
                .disabled(!viewModel.canCollect)
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Registrar abono")
        .task { await viewModel.load() }
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

#Preview {
    NavigationStack {
        ReceivableCollectionView(
            viewModel: ReceivableCollectionViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                receivable: PreviewData.receivableResponse.receivable,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                cashRepository: PreviewCashRepository(),
                receivablesRepository: PreviewReceivablesRepository()
            )
        )
    }
}
