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
                closeSection
                manualAdjustmentsSection
            } else {
                openSection
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Caja")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading || viewModel.isMutating)
            }
        }
        .alert("Registrar ajuste manual", isPresented: $viewModel.showsMovementConfirmation) {
            Button("Registrar ajuste", role: .destructive) {
                NexoKeyboard.dismiss()
                Task { await viewModel.registerMovement() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(viewModel.movementConfirmationMessage)
        }
        .alert("Cerrar caja", isPresented: $viewModel.showsCloseConfirmation) {
            Button("Cerrar caja", role: .destructive) {
                NexoKeyboard.dismiss()
                Task { await viewModel.closeCash() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(viewModel.closeConfirmationMessage)
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

    private var closeSection: some View {
        Section("Cierre guiado") {
            LabeledContent("Efectivo esperado", value: viewModel.currentExpectedDisplay)

            TextField("Monto contado", text: $viewModel.countedAmount)
                .keyboardType(.decimalPad)

            Button {
                viewModel.useExpectedAmountForClosing()
                NexoKeyboard.dismiss()
            } label: {
                Label("Usar efectivo esperado", systemImage: "equal.circle")
            }
            .disabled(viewModel.isMutating)

            LabeledContent("Diferencia estimada", value: viewModel.closingDifferencePreview.displayText)

            TextField("Nota opcional", text: $viewModel.closingNote, axis: .vertical)
                .lineLimit(1...3)

            Text("El monto contado viene prellenado con el efectivo esperado. Cámbialo solo si al contar físicamente el dinero hay una diferencia.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                NexoKeyboard.dismiss()
                viewModel.prepareCloseConfirmation()
            } label: {
                if viewModel.isMutating {
                    ProgressView()
                } else {
                    Label("Cerrar caja", systemImage: "lock")
                }
            }
            .disabled(!viewModel.canPrepareClose)
        }
    }

    private var manualAdjustmentsSection: some View {
        Section {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Usa esto solo para ingresos, egresos o ajustes que no vienen de una venta. Los cobros de ventas se registran desde Cobrar venta y actualizan caja automáticamente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

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
                        viewModel.prepareMovementConfirmation()
                    } label: {
                        Label("Registrar ajuste manual", systemImage: "plus.forwardslash.minus")
                    }
                    .disabled(!viewModel.canPrepareMovement)

                    if let movement = viewModel.lastMovement {
                        Divider()
                        LabeledContent("Último ajuste", value: movement.type.displayName)
                        LabeledContent("Monto", value: moneyText(movement.amount))
                    }
                }
                .padding(.vertical, 8)
            } label: {
                Label("Ajustes manuales de caja", systemImage: "slider.horizontal.3")
            }
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
                        Text(session.isOpen ? "Efectivo esperado" : "Esperado")
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

                if session.isOpen {
                    HStack {
                        Text("Conteo")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Pendiente al cierre")
                            .font(.body.weight(.semibold))
                    }

                    Text("Los cobros en efectivo de ventas aumentan automáticamente el efectivo esperado. No registres esos cobros como ajustes manuales.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if let countedAmount = session.countedAmount {
                        NexoMoneyTotalView(title: "Contado", amount: countedAmount)
                    }

                    if let differenceAmount = session.differenceAmount {
                        NexoMoneyTotalView(title: "Diferencia", amount: differenceAmount, isProminent: true)
                    }
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
