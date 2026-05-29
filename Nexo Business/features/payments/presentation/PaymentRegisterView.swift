//
//  PaymentRegisterView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct PaymentRegisterView: View {
    @Bindable private var viewModel: PaymentRegisterViewModel

    public init(viewModel: PaymentRegisterViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            saleSection
            methodSection
            amountSection
            cashSection
            creditSection
            resultSection
            messagesSection
            actionsSection
        }
        .navigationTitle("Cobrar venta")
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.selectedMode) { _, _ in
            viewModel.resetResultMessages()
        }
    }

    private var saleSection: some View {
        Section("Venta") {
            LabeledContent("ID", value: viewModel.sale.id)
            LabeledContent("Estado venta", value: viewModel.sale.status)
            LabeledContent("Estado pago", value: PaymentStatusPresentation.displayName(viewModel.sale.paymentStatus))
            LabeledContent("Total", value: money(viewModel.sale.totals.grandTotal))
        }
    }

    private var methodSection: some View {
        Section("Método") {
            Picker("Método", selection: $viewModel.selectedMode) {
                ForEach(PaymentRegisterMode.allCases) { mode in
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
                } else if let session = viewModel.currentCashSession, session.status == "open" {
                    Label("Caja abierta", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    LabeledContent("Sesión", value: session.id)
                    if let openedAt = session.openedAt {
                        LabeledContent("Abierta", value: openedAt.formatted(date: .abbreviated, time: .shortened))
                    }
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
            Section("Cuenta por cobrar") {
                TextField("Cliente ID", text: $viewModel.customerId)
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
                LabeledContent("ID", value: payment.id)
                LabeledContent("Método", value: payment.method)
                LabeledContent("Estado", value: payment.status)
                LabeledContent("Monto", value: money(payment.amount))
            }
        }

        if let receivable = viewModel.receivableResult {
            Section("Cuenta por cobrar") {
                LabeledContent("ID", value: receivable.id)
                LabeledContent("Estado", value: ReceivableStatusPresentation.displayName(receivable.status))
                LabeledContent("Monto", value: money(receivable.amount))
                if let balance = receivable.balance {
                    LabeledContent("Saldo", value: money(balance))
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

    private var actionsSection: some View {
        Section {
            Button {
                Task { await viewModel.submit() }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                } else if viewModel.selectedMode == .credit {
                    Label("Crear cuenta por cobrar", systemImage: "person.crop.circle.badge.clock")
                } else {
                    Label("Registrar cobro", systemImage: "checkmark.seal")
                }
            }
            .disabled(viewModel.selectedMode == .credit ? !viewModel.canCreateReceivable : !viewModel.canSubmitPayment)

            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Actualizar caja", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoadingCash)
        }
    }

    private func money(_ value: MoneyAmount) -> String {
        "\(value.currency) \(value.amount)"
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
            )
        )
    }
}
