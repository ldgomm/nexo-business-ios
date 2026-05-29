//
//  CashDashboardView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct CashDashboardView: View {
    @Bindable private var viewModel: CashDashboardViewModel

    public init(viewModel: CashDashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            statusSection
            messagesSection
            openSection
            movementSection
            closeSection
        }
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
    private var statusSection: some View {
        Section("Estado de caja") {
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
                    CashSessionSummaryView(session: session)
                } else {
                    Label("No hay caja abierta", systemImage: "lock.open")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.successMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
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
        Section("Movimientos") {
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
                Task { await viewModel.closeCash() }
            } label: {
                Label("Cerrar caja", systemImage: "lock")
            }
            .disabled(!viewModel.canClose || viewModel.isMutating)
        }
    }

    private func moneyText(_ amount: MoneyAmount?) -> String {
        guard let amount else { return "—" }
        return "\(amount.amount) \(amount.currency)"
    }
}

private struct CashSessionSummaryView: View {
    let session: CashSession

    var body: some View {
        LabeledContent("Estado", value: session.status)
        LabeledContent("Monto inicial", value: moneyText(session.openingAmount))

        if let expectedAmount = session.expectedAmount {
            LabeledContent("Esperado", value: moneyText(expectedAmount))
        }

        if let countedAmount = session.countedAmount {
            LabeledContent("Contado", value: moneyText(countedAmount))
        }

        if let differenceAmount = session.differenceAmount {
            LabeledContent("Diferencia", value: moneyText(differenceAmount))
        }

        if let openedAt = session.openedAt {
            LabeledContent("Apertura", value: openedAt.formatted(date: .abbreviated, time: .shortened))
        }

        if let closedAt = session.closedAt {
            LabeledContent("Cierre", value: closedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    private func moneyText(_ amount: MoneyAmount?) -> String {
        guard let amount else { return "—" }
        return "\(amount.amount) \(amount.currency)"
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
