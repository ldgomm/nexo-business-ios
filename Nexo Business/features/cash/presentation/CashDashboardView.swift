//
//  CashDashboardView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI

struct CashDashboardView: View {
    @Bindable private var viewModel: CashDashboardViewModel

    init(viewModel: CashDashboardViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            heroSection
            messagesSection

            if viewModel.isOpen {
                movementSection
                closeSection
            } else {
                openSection
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Caja")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading || viewModel.isMutating)
            }
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        Section {
            switch viewModel.state {
            case .idle, .loading:
                HStack {
                    ProgressView()
                    Text("Consultando caja…")
                        .foregroundStyle(.secondary)
                }

            case let .failed(message):
                ContentUnavailableView {
                    Label("No se pudo consultar caja", systemImage: "tray")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") {
                        Task { await viewModel.load() }
                    }
                }

            case let .loaded(session):
                if let session {
                    CashSessionHeroView(session: session)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Caja cerrada", systemImage: "lock")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        Text("Abre caja al iniciar operación para cobrar en efectivo y controlar el cierre del día.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage, !message.isEmpty {
            Section {
                NexoMessageBanner(message, style: .error)
            }
        }

        if let message = viewModel.successMessage, !message.isEmpty {
            Section {
                NexoMessageBanner(message, style: .success)
            }
        }
    }

    private var openSection: some View {
        Section("Abrir caja") {
            TextField("Monto inicial", text: $viewModel.openingAmount)
                .keyboardType(.decimalPad)

            TextField("Nota opcional", text: $viewModel.openingNote, axis: .vertical)
                .lineLimit(1...3)

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.openCash() }
            } label: {
                if viewModel.isMutating && !viewModel.isOpen {
                    ProgressView()
                } else {
                    Label("Abrir caja", systemImage: "lock.open")
                }
            }
            .disabled(!viewModel.canOpen || viewModel.isMutating)
        }
    }

    private var movementSection: some View {
        Section("Movimiento manual") {
            Picker("Tipo", selection: $viewModel.movementType) {
                ForEach(CashMovementType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            TextField("Monto", text: $viewModel.movementAmount)
                .keyboardType(.decimalPad)

            TextField("Motivo", text: $viewModel.movementNote, axis: .vertical)
                .lineLimit(1...3)

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.registerMovement() }
            } label: {
                Label("Registrar movimiento", systemImage: "plus.forwardslash.minus")
            }
            .disabled(!viewModel.canRegisterMovement || viewModel.isMutating)

            if let movement = viewModel.lastMovement {
                LabeledContent("Último movimiento", value: movement.type.displayName)
                LabeledContent("Monto", value: moneyText(movement.amount))
            }
        }
    }

    private var closeSection: some View {
        Section("Cerrar caja") {
            TextField("Monto contado", text: $viewModel.countedAmount)
                .keyboardType(.decimalPad)

            TextField("Nota opcional", text: $viewModel.closingNote, axis: .vertical)
                .lineLimit(1...3)

            Button(role: .destructive) {
                NexoKeyboard.dismiss()
                Task { await viewModel.closeCash() }
            } label: {
                Label("Cerrar caja", systemImage: "lock")
            }
            .disabled(!viewModel.canClose || viewModel.isMutating)
        }
    }

    private func moneyText(_ amount: MoneyAmount?) -> String {
        amount?.displayText ?? "—"
    }
}

private struct CashSessionHeroView: View {
    let session: CashSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(session.isOpen ? "Caja abierta" : "Caja cerrada", systemImage: session.isOpen ? "checkmark.circle.fill" : "lock")
                        .font(.headline)
                        .foregroundStyle(session.isOpen ? .green : .secondary)

                    if let openedAt = session.openedAt {
                        Text("Apertura: \(openedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let expectedAmount = session.expectedAmount {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Esperado")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(expectedAmount.displayText)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                }
            }

            Divider()

            VStack(spacing: 8) {
                NexoMoneyTotalView(title: "Monto inicial", amount: session.openingAmount ?? MoneyAmount(amount: "0.00"))

                if let countedAmount = session.countedAmount {
                    NexoMoneyTotalView(title: "Contado", amount: countedAmount)
                }

                if let differenceAmount = session.differenceAmount {
                    NexoMoneyTotalView(title: "Diferencia", amount: differenceAmount, isProminent: true)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        CashDashboardView(
            viewModel: CashDashboardViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                permissions: PreviewData.businessContext.effectivePermissions,
                cashRepository: PreviewCashRepository()
            )
        )
    }
}
