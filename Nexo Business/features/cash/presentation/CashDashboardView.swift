//
//  CashDashboardView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct CashDashboardView: View {
    @Bindable private var viewModel: CashDashboardViewModel
    private let refreshOnAppear: Bool

    init(
        viewModel: CashDashboardViewModel,
        refreshOnAppear: Bool = false
    ) {
        self.viewModel = viewModel
        self.refreshOnAppear = refreshOnAppear
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                statusSection

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
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
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
            if refreshOnAppear {
                await viewModel.load()
            } else {
                await viewModel.loadIfNeeded()
            }
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
        Group {
            switch viewModel.state {
            case .idle, .loading:
                CashLoadingCard()

            case let .failed(message):
                CashFailureStateCard(message: message) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                }

            case let .loaded(session):
                if let session {
                    CashSessionHeroView(session: session)
                } else {
                    CashEmptyStateCard()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.16),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message = viewModel.errorMessage, !message.isEmpty {
                NexoMessageBanner(message, style: .error)
            }

            if let message = viewModel.successMessage, !message.isEmpty {
                NexoMessageBanner(message, style: .success)
            }
        }
    }

    private var openingGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CashSectionHeader(
                icon: "lock.open",
                title: "Apertura de caja",
                subtitle: "Registra el efectivo inicial antes de empezar a cobrar."
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
                    title: "Nota de apertura",
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
            .disabled(!viewModel.canOpen || viewModel.isMutating)
        }
    }

    private var closingGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CashSectionHeader(
                icon: "checklist",
                title: "Cierre de caja",
                subtitle: "Cuenta el efectivo físico, revisa la diferencia y confirma el cierre."
            )

            VStack(spacing: 10) {
                CashMetricRow(
                    title: "Efectivo esperado",
                    value: viewModel.currentExpectedDisplay,
                    systemImage: "banknote",
                    isProminent: true,
                    tint: .accentColor
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
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(viewModel.isMutating)

                CashMetricRow(
                    title: "Diferencia estimada",
                    value: viewModel.closingDifferencePreview.displayText,
                    systemImage: "plus.forwardslash.minus",
                    isProminent: false,
                    tint: .orange
                )

                CashMultilineInputRow(
                    title: "Nota de cierre",
                    placeholder: "Opcional",
                    text: $viewModel.closingNote,
                    systemImage: "note.text"
                )
            }

            CashHintCard(
                icon: "lightbulb",
                text: "El monto contado viene prellenado con el efectivo esperado. Cámbialo solo si al contar físicamente hay una diferencia real."
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
            .disabled(!viewModel.canPrepareClose)
        }
    }

    private var manualAdjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                        CashActionLabel(
                            title: "Registrar ajuste manual",
                            systemImage: "plus.forwardslash.minus",
                            isLoading: viewModel.isMutating
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!viewModel.canPrepareMovement)

                    if let movement = viewModel.lastMovement {
                        Divider()
                            .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Último ajuste")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            CashMetricRow(
                                title: movement.type.displayName,
                                value: moneyText(movement.amount),
                                systemImage: "clock.arrow.circlepath",
                                isProminent: false,
                                tint: .secondary
                            )
                        }
                    }
                }
                .padding(.top, 12)
            } label: {
                CashSectionHeader(
                    icon: "slider.horizontal.3",
                    title: "Ajustes manuales",
                    subtitle: "Ingresos, egresos o correcciones fuera de venta."
                )
            }

            CashSectionFooter(
                text: "Los ajustes manuales afectan la caja y deben tener un motivo claro. Para cobros de ventas, usa el flujo normal de venta o historial."
            )
        }
    }

    private func moneyText(_ amount: MoneyAmount?) -> String {
        amount?.displayText ?? "—"
    }
}


private struct CashDashboardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 4)
    }
}

private extension View {
    func cashDashboardSurface() -> some View {
        modifier(CashDashboardSurfaceModifier())
    }
}


private struct CashLoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            VStack(alignment: .leading, spacing: 4) {
                Text("Consultando caja…")
                    .font(.headline)

                Text("Estamos revisando el estado actual de caja.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct CashFailureStateCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                CashIconBadge(systemImage: "exclamationmark.triangle", tint: .red)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Caja no disponible")
                        .font(.headline)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: retry) {
                Label("Reintentar consulta", systemImage: "arrow.clockwise")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct CashEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                CashIconBadge(systemImage: "lock.fill", tint: .orange)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Caja cerrada")
                        .font(.title3.weight(.bold))

                    Text("Abre caja al iniciar operación para cobrar en efectivo y controlar el cierre del día.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                CashStatusPill(
                    title: "Inactiva",
                    systemImage: "lock",
                    tint: .orange
                )
            }

            CashHintCard(
                icon: "info.circle",
                text: "La apertura debe hacerse al inicio del turno con el efectivo físico disponible."
            )
        }
    }
}

private struct CashSessionHeroView: View {
    let session: CashSession

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            LazyVGrid(columns: columns, spacing: 10) {
                CashHeroMetricCard(
                    title: "Efectivo esperado",
                    value: expectedAmountText,
                    subtitle: session.isOpen ? "actual" : "final",
                    systemImage: "banknote"
                )

                CashHeroMetricCard(
                    title: "Monto inicial",
                    value: openingAmountText,
                    subtitle: "apertura",
                    systemImage: "tray.and.arrow.down"
                )

                if session.isOpen {
                    CashHeroMetricCard(
                        title: "Conteo",
                        value: "Pendiente",
                        subtitle: "al cierre",
                        systemImage: "hourglass"
                    )
                } else {
                    CashHeroMetricCard(
                        title: "Contado",
                        value: countedAmountText,
                        subtitle: "físico",
                        systemImage: "checkmark.circle"
                    )
                }

                CashHeroMetricCard(
                    title: "Diferencia",
                    value: differenceAmountText,
                    subtitle: session.isOpen ? "por calcular" : "cierre",
                    systemImage: "plus.forwardslash.minus"
                )
            }

            if session.isOpen {
                CashHintCard(
                    icon: "checkmark.seal",
                    text: "Los cobros en efectivo de ventas aumentan automáticamente el efectivo esperado. No registres esos cobros como ajustes manuales."
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            CashIconBadge(
                systemImage: session.isOpen ? "checkmark.circle.fill" : "lock.fill",
                tint: session.isOpen ? .green : .secondary
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(session.isOpen ? "Caja operativa" : "Caja cerrada")
                    .font(.title3.weight(.bold))

                Text(openedAtText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            CashStatusPill(
                title: session.isOpen ? "Abierta" : "Cerrada",
                systemImage: session.isOpen ? "checkmark.seal" : "lock",
                tint: session.isOpen ? .green : .secondary
            )
        }
    }

    private var openedAtText: String {
        guard let openedAt = session.openedAt else {
            return session.isOpen ? "Lista para registrar cobros." : "Sin hora de apertura disponible."
        }

        return "Apertura: \(openedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var expectedAmountText: String {
        session.expectedAmount?.displayText ?? "—"
    }

    private var openingAmountText: String {
        (session.openingAmount ?? MoneyAmount(amount: "0.00")).displayText
    }

    private var countedAmountText: String {
        session.countedAmount?.displayText ?? "—"
    }

    private var differenceAmountText: String {
        session.differenceAmount?.displayText ?? (session.isOpen ? "—" : "0.00")
    }
}

private struct CashSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CashIconBadge(systemImage: icon, tint: .accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct CashHeroMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct CashMetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    let isProminent: Bool
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 10)

            Text(value)
                .font(isProminent ? .body.weight(.bold) : .body.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
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
                .lineLimit(1)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
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
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }
}

private struct CashSectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CashActionLabel: View {
    let title: String
    let systemImage: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(title, systemImage: systemImage)
                    .font(.body.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CashIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct CashStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule())
    }
}
