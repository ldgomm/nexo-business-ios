//
//  InventoryItemDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct InventoryItemDetailView: View {
    @Bindable private var viewModel: InventoryItemDetailViewModel
    private let onItemUpdated: (InventoryItem) -> Void

    init(
        viewModel: InventoryItemDetailViewModel,
        onItemUpdated: @escaping (InventoryItem) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onItemUpdated = onItemUpdated
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                itemSection

                messagesSection

                adjustmentSection
                    .inventoryItemDetailSurface()

                movementsSection
                    .inventoryItemDetailSurface()
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Stock")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.loadMovements() }
                } label: {
                    if viewModel.isLoadingMovements {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoadingMovements)
                .accessibilityLabel("Actualizar movimientos")
            }
        }
        .task {
            await viewModel.loadMovements()
        }
        .onChange(of: viewModel.item) { _, newItem in
            onItemUpdated(newItem)
        }
    }

    private var itemSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                InventoryItemDetailIconBadge(systemImage: InventoryStatusPresentation.stockSystemImage(viewModel.item), tint: stockTint)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Inventory")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(viewModel.item.name)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text("Detalle de stock, umbrales y movimientos operativos.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                InventoryItemDetailPill(
                    title: InventoryStatusPresentation.displayName(viewModel.item.stockStatus ?? viewModel.item.status),
                    systemImage: InventoryStatusPresentation.stockSystemImage(viewModel.item),
                    tint: stockTint
                )

                InventoryItemDetailPill(
                    title: viewModel.item.trackStock ? "Controla stock" : "Sin control stock",
                    systemImage: viewModel.item.trackStock ? "checkmark.seal" : "info.circle",
                    tint: viewModel.item.trackStock ? .accentColor : .secondary
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                InventoryItemDetailMetricCard(
                    title: "Disponible",
                    value: viewModel.item.available.displayText,
                    systemImage: "shippingbox"
                )

                if let reserved = viewModel.item.reserved {
                    InventoryItemDetailMetricCard(
                        title: "Reservado",
                        value: reserved.displayText,
                        systemImage: "lock"
                    )
                } else {
                    InventoryItemDetailMetricCard(
                        title: "Reservado",
                        value: "—",
                        systemImage: "lock"
                    )
                }

                if let threshold = viewModel.item.lowStockThreshold {
                    InventoryItemDetailMetricCard(
                        title: "Mínimo",
                        value: threshold.displayText,
                        systemImage: "gauge.with.dots.needle.bottom.50percent"
                    )
                }

                if let sku = viewModel.item.sku, !sku.isEmpty {
                    InventoryItemDetailMetricCard(
                        title: "SKU",
                        value: sku,
                        systemImage: "barcode"
                    )
                }
            }

            if let updatedAt = viewModel.item.updatedAt {
                InventoryItemDetailFactRow(
                    title: "Actualizado",
                    value: updatedAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
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
    }

    @ViewBuilder
    private var adjustmentSection: some View {
        InventoryItemDetailSectionCard(
            title: "Ajuste manual",
            subtitle: viewModel.item.trackStock ? "Registra ingresos, salidas o correcciones con motivo claro." : "Este producto no maneja stock.",
            systemImage: "plus.forwardslash.minus"
        ) {
            if viewModel.item.trackStock {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Tipo", selection: $viewModel.adjustmentType) {
                        ForEach(InventoryAdjustmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    InventoryItemDetailInputRow(
                        title: "Cantidad",
                        placeholder: "0",
                        text: $viewModel.adjustmentQuantity,
                        systemImage: "number"
                    )
                    .keyboardType(.decimalPad)

                    InventoryItemDetailMultilineInputRow(
                        title: "Motivo",
                        placeholder: "Ej. compra, merma, corrección de conteo",
                        text: $viewModel.adjustmentReason,
                        systemImage: "text.quote"
                    )

                    InventoryItemDetailMultilineInputRow(
                        title: "Nota",
                        placeholder: "Opcional",
                        text: $viewModel.adjustmentNote,
                        systemImage: "note.text"
                    )

                    Button {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.adjust() }
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.isAdjusting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "plus.forwardslash.minus")
                            }

                            Text(viewModel.isAdjusting ? "Registrando ajuste…" : "Registrar ajuste")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canAdjust)
                }
            } else {
                InventoryItemDetailNoticeCard(
                    title: "Producto sin stock",
                    message: "Este producto no maneja control de inventario. No se pueden registrar ajustes manuales.",
                    systemImage: "info.circle",
                    tint: .secondary
                )
            }
        }
    }

    @ViewBuilder
    private var movementsSection: some View {
        InventoryItemDetailSectionCard(
            title: "Movimientos",
            subtitle: "Historial operativo de entradas, salidas y ajustes.",
            systemImage: "clock.arrow.circlepath"
        ) {
            if viewModel.isLoadingMovements && viewModel.movements.isEmpty {
                InventoryItemDetailLoadingCard(
                    title: "Cargando movimientos…",
                    subtitle: "Estamos revisando el historial de este producto."
                )
            } else if viewModel.movements.isEmpty {
                InventoryItemDetailEmptyState(
                    title: "Sin movimientos",
                    message: "Los ajustes y ventas aparecerán aquí.",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.movements) { movement in
                        InventoryMovementCard(movement: movement)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            InventoryItemDetailNoticeCard(
                title: "Atención",
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
            .inventoryItemDetailSurface()
        }

        if let message = viewModel.infoMessage {
            InventoryItemDetailNoticeCard(
                title: "Información",
                message: message,
                systemImage: "checkmark.circle",
                tint: .secondary
            )
            .inventoryItemDetailSurface()
        }
    }

    private var stockTint: Color {
        let normalized = InventoryStatusPresentation.displayName(viewModel.item.stockStatus ?? viewModel.item.status).lowercased()
        if normalized.contains("sin") || normalized.contains("agot") || normalized.contains("out") {
            return .red
        }
        if normalized.contains("bajo") || normalized.contains("low") || normalized.contains("alert") {
            return .orange
        }
        return .green
    }
}

private struct InventoryItemDetailSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 7, x: 0, y: 3)
    }
}

private extension View {
    func inventoryItemDetailSurface() -> some View {
        modifier(InventoryItemDetailSurfaceModifier())
    }
}

private struct InventoryItemDetailSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                InventoryItemDetailIconBadge(systemImage: systemImage, tint: .accentColor, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.bold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
    }
}

private struct InventoryItemDetailIconBadge: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemImage)
            .font((size > 38 ? Font.headline : Font.subheadline).weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size > 38 ? 15 : 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size > 38 ? 15 : 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct InventoryItemDetailPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct InventoryItemDetailMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InventoryItemDetailFactRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InventoryItemDetailInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InventoryItemDetailMultilineInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InventoryItemDetailNoticeCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InventoryItemDetailLoadingCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

private struct InventoryItemDetailEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct InventoryMovementCard: View {
    let movement: InventoryMovement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(InventoryStatusPresentation.movementDisplayName(movement.type))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let createdAt = movement.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Text(movement.quantity.displayText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }

            if let previous = movement.previousQuantity,
               let new = movement.newQuantity {
                InventoryItemDetailFactRow(
                    title: "Cambio",
                    value: "\(previous.displayText) → \(new.displayText)",
                    systemImage: "arrow.left.arrow.right"
                )
            }

            if let reason = movement.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        InventoryItemDetailView(
            viewModel: InventoryItemDetailViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                catalogRevision: PreviewData.businessContext.revisions.catalogRevision,
                item: PreviewInventoryData.items[0],
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                inventoryRepository: PreviewInventoryRepository()
            )
        )
    }
}
