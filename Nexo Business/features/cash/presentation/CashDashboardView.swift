//
//  CashDashboardView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct CashDashboardView: View {
    @Bindable private var viewModel: CashDashboardViewModel

    init(viewModel: CashDashboardViewModel) {
        self.viewModel = viewModel
    }


    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                statusSection
                    .cashDashboardHeroSurface()

                if (viewModel.errorMessage?.isEmpty == false) || (viewModel.successMessage?.isEmpty == false) {
                    messagesSection
                        .cashDashboardSurface()
                }

                if viewModel.shouldShowCloseSection {
                    closingGuideSection
                        .cashDashboardSurface()

                    manualAdjustmentsSection
                        .cashDashboardSurface()
                } else if viewModel.shouldShowOpenSection {
                    openingGuideSection
                        .cashDashboardSurface()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Caja")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshButton
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
            await viewModel.loadIfNeeded()
        }
    }

    private var isBusy: Bool {
        viewModel.isLoading || viewModel.isMutating
    }

    private var refreshButton: some View {
        Button {
            NexoKeyboard.dismiss()
            Task { await viewModel.load() }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(isBusy)
        .accessibilityLabel("Actualizar caja")
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            switch viewModel.state {
            case .idle, .loading:
                CashLoadingCard()

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
                    CashEmptyStateCard()
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
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

    private var openingGuideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                CashSectionHeader(
                    icon: "lock.open",
                    title: "Abrir caja",
                    subtitle: "Registra el efectivo inicial antes de comenzar a cobrar."
                )

                VStack(spacing: 10) {
                    CashInputRow(
                        title: "Monto inicial",
                        placeholder: "0.00",
                        text: $viewModel.openingAmount,
                        keyboardType: .decimalPad,
                        systemImage: "dollarsign.circle"
                    )

                    CashMultilineInputRow(
                        title: "Nota",
                        placeholder: "Opcional",
                        text: $viewModel.openingNote,
                        systemImage: "note.text"
                    )
                }

                CashHintCard(
                    icon: "info.circle",
                    text: "Este monto será la base del efectivo esperado. Los cobros en efectivo aumentarán la caja automáticamente."
                )

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.openCash() }
                } label: {
                    CashActionLabel(
                        title: "Abrir caja",
                        systemImage: "lock.open",
                        isLoading: viewModel.isMutating && !viewModel.isOpen
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(!viewModel.canOpen || viewModel.isMutating)
            }
            .padding(.vertical, 6)
        }
    }

    private var closingGuideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                CashSectionHeader(
                    icon: "checklist",
                    title: "Cierre guiado",
                    subtitle: "Cuenta el efectivo físico y confirma la diferencia antes de cerrar."
                )

                VStack(spacing: 10) {
                    CashMetricRow(
                        title: "Efectivo esperado",
                        value: viewModel.currentExpectedDisplay,
                        systemImage: "banknote",
                        isProminent: true
                    )

                    CashInputRow(
                        title: "Monto contado",
                        placeholder: "0.00",
                        text: $viewModel.countedAmount,
                        keyboardType: .decimalPad,
                        systemImage: "number.circle"
                    )

                    Button {
                        viewModel.useExpectedAmountForClosing()
                        NexoKeyboard.dismiss()
                    } label: {
                        Label("Usar efectivo esperado", systemImage: "equal.circle")
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .disabled(viewModel.isMutating)

                    CashMetricRow(
                        title: "Diferencia estimada",
                        value: viewModel.closingDifferencePreview.displayText,
                        systemImage: "plus.forwardslash.minus",
                        isProminent: false
                    )

                    CashMultilineInputRow(
                        title: "Nota",
                        placeholder: "Opcional",
                        text: $viewModel.closingNote,
                        systemImage: "note.text"
                    )
                }

                CashHintCard(
                    icon: "lightbulb",
                    text: "El monto contado viene prellenado con el efectivo esperado. Cámbialo solo si al contar físicamente el dinero hay diferencia."
                )

                Button(role: .destructive) {
                    NexoKeyboard.dismiss()
                    viewModel.prepareCloseConfirmation()
                } label: {
                    CashActionLabel(
                        title: "Cerrar caja",
                        systemImage: "lock",
                        isLoading: viewModel.isMutating
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(!viewModel.canPrepareClose)
            }
            .padding(.vertical, 6)
        }
    }

    private var manualAdjustmentsSection: some View {
        Section {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    CashHintCard(
                        icon: "exclamationmark.triangle",
                        text: "Usa ajustes manuales solo para ingresos, egresos o correcciones que no vienen de una venta. Los cobros normales se registran desde Cobrar venta."
                    )

                    Picker("Tipo de ajuste", selection: $viewModel.movementType) {
                        ForEach(CashMovementType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    CashInputRow(
                        title: "Monto",
                        placeholder: "0.00",
                        text: $viewModel.movementAmount,
                        keyboardType: .decimalPad,
                        systemImage: "dollarsign.circle"
                    )

                    CashMultilineInputRow(
                        title: "Motivo",
                        placeholder: "Ej. retiro para cambio, ingreso extra, corrección",
                        text: $viewModel.movementNote,
                        systemImage: "text.quote"
                    )

                    Button {
                        NexoKeyboard.dismiss()
                        viewModel.prepareMovementConfirmation()
                    } label: {
                        Label("Registrar ajuste manual", systemImage: "plus.forwardslash.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!viewModel.canPrepareMovement)

                    if let movement = viewModel.lastMovement {
                        Divider()
                            .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Último ajuste")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            CashMetricRow(
                                title: movement.type.displayName,
                                value: moneyText(movement.amount),
                                systemImage: "clock.arrow.circlepath",
                                isProminent: false
                            )
                        }
                    }
                }
                .padding(.vertical, 10)
            } label: {
                Label("Ajustes manuales", systemImage: "slider.horizontal.3")
                    .font(.body.weight(.medium))
            }
        } footer: {
            Text("Los ajustes manuales afectan la caja y deben tener un motivo claro.")
        }
    }

    private func moneyText(_ amount: MoneyAmount?) -> String {
        amount?.displayText ?? "—"
    }
}


private struct CashDashboardSurfaceModifier: ViewModifier {
    var isHero: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(isHero ? 18 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: isHero ? 24 : 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: isHero ? 24 : 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(isHero ? 0.07 : 0.035), radius: isHero ? 14 : 8, x: 0, y: isHero ? 8 : 4)
    }
}

private extension View {
    func cashDashboardSurface() -> some View {
        modifier(CashDashboardSurfaceModifier())
    }

    func cashDashboardHeroSurface() -> some View {
        modifier(CashDashboardSurfaceModifier(isHero: true))
    }
}



private struct CashLoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            VStack(alignment: .leading, spacing: 3) {
                Text("Consultando caja…")
                    .font(.headline)

                Text("Estamos revisando el estado actual de caja.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CashEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Caja cerrada")
                        .font(.headline)

                    Text("Abre caja al iniciar operación para cobrar en efectivo y controlar el cierre del día.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CashSessionHeroView: View {
    let session: CashSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            metrics

            if session.isOpen {
                CashHintCard(
                    icon: "checkmark.seal",
                    text: "Los cobros en efectivo de ventas aumentan automáticamente el efectivo esperado. No registres esos cobros como ajustes manuales."
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.isOpen ? "checkmark.circle.fill" : "lock.fill")
                .font(.title2)
                .foregroundStyle(session.isOpen ? .green : .secondary)

            VStack(alignment: .leading, spacing: 5) {
                Text(session.isOpen ? "Caja abierta" : "Caja cerrada")
                    .font(.headline)

                if let openedAt = session.openedAt {
                    Text("Apertura: \(openedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let expectedAmount = session.expectedAmount {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(session.isOpen ? "Esperado" : "Esperado final")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(expectedAmount.displayText)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            }
        }
    }

    private var metrics: some View {
        VStack(spacing: 10) {
            CashMetricRow(
                title: "Monto inicial",
                value: (session.openingAmount ?? MoneyAmount(amount: "0.00")).displayText,
                systemImage: "tray.and.arrow.down",
                isProminent: false
            )

            if session.isOpen {
                CashMetricRow(
                    title: "Conteo",
                    value: "Pendiente al cierre",
                    systemImage: "hourglass",
                    isProminent: false
                )
            } else {
                if let countedAmount = session.countedAmount {
                    CashMetricRow(
                        title: "Contado",
                        value: countedAmount.displayText,
                        systemImage: "checkmark.circle",
                        isProminent: false
                    )
                }

                if let differenceAmount = session.differenceAmount {
                    CashMetricRow(
                        title: "Diferencia",
                        value: differenceAmount.displayText,
                        systemImage: "plus.forwardslash.minus",
                        isProminent: true
                    )
                }
            }
        }
    }
}

private struct CashSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CashMetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    let isProminent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(isProminent ? .body.weight(.bold) : .body.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct CashInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct CashMultilineInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                Text(title)
                    .foregroundStyle(.secondary)
            }

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct CashHintCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

private struct CashActionLabel: View {
    let title: String
    let systemImage: String
    let isLoading: Bool

    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        CashDashboardView(
            viewModel: CashDashboardViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                permissions: PreviewData.businessContext.effectivePermissions,
                cashCapabilities: PreviewData.businessContext.capabilities.cash,
                cashRepository: PreviewCashRepository()
            )
        )
    }
}
