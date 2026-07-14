//
//  InventoryItemDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct InventoryItemDetailView: View {
    @Bindable private var viewModel: InventoryItemDetailViewModel
    @State private var selectedMovement: InventoryMovement?
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
                advancedOperationsSection
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
        .sheet(item: $selectedMovement) { movement in
            InventoryMovementDetailSheet(
                movement: movement,
                item: viewModel.item
            )
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

                    Text(viewModel.item.displayName)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    if viewModel.item.displayName == "Producto sin nombre",
                       let reference = viewModel.item.technicalReference {
                        Text("Referencia técnica: \(reference)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text("Detalle de stock, umbrales y movimientos operativos.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                InventoryItemDetailPill(
                    title: InventoryStatusPresentation.displayName(viewModel.item),
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
                if let onHand = viewModel.item.onHand {
                    InventoryItemDetailMetricCard(
                        title: "En mano",
                        value: onHand.displayText,
                        systemImage: "shippingbox.fill"
                    )
                }

                InventoryItemDetailMetricCard(
                    title: "Disponible",
                    value: viewModel.item.available.displayText,
                    systemImage: "checkmark.seal"
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

                if let damaged = viewModel.item.damaged {
                    InventoryItemDetailMetricCard(
                        title: "Dañado",
                        value: damaged.displayText,
                        systemImage: "exclamationmark.triangle"
                    )
                }

                if let inTransit = viewModel.item.inTransit {
                    InventoryItemDetailMetricCard(
                        title: "En tránsito",
                        value: inTransit.displayText,
                        systemImage: "truck.box"
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

            InventoryItemDetailFactRow(
                title: "Fuente",
                value: "Stock confirmado por backend",
                systemImage: "server.rack"
            )

            if let updatedAt = viewModel.item.updatedAt {
                InventoryItemDetailFactRow(
                    title: "Actualizado",
                    value: InventoryPresentationFormatter.dateTime(updatedAt),
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
                VStack(alignment: .leading, spacing: 14) {
                    Text("¿Qué ocurrió?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(InventoryAdjustmentType.allCases) { type in
                            InventoryAdjustmentTypeButton(
                                type: type,
                                isSelected: viewModel.adjustmentType == type
                            ) {
                                viewModel.selectAdjustmentType(type)
                            }
                        }
                    }

                    InventoryAdjustmentQuantityControl(
                        quantity: $viewModel.adjustmentQuantity,
                        decrease: viewModel.decrementAdjustmentQuantity,
                        increase: viewModel.incrementAdjustmentQuantity
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Motivo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.adjustmentReasonPresets, id: \.self) { reason in
                                    InventoryAdjustmentReasonButton(
                                        title: reason,
                                        isSelected: viewModel.adjustmentReason == reason
                                    ) {
                                        viewModel.selectAdjustmentReason(reason)
                                    }
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }

                    DisclosureGroup {
                        InventoryItemDetailMultilineInputRow(
                            title: "Nota",
                            placeholder: "Información adicional (opcional)",
                            text: $viewModel.adjustmentNote,
                            systemImage: "note.text"
                        )
                        .padding(.top, 8)
                    } label: {
                        Label("Agregar nota opcional", systemImage: "note.text")
                            .font(.footnote.weight(.semibold))
                    }

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

                            Text(viewModel.isAdjusting ? "Registrando ajuste…" : adjustmentActionTitle)
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

    private var adjustmentActionTitle: String {
        switch viewModel.adjustmentType {
        case .increase:
            return "Registrar entrada"
        case .decrease:
            return "Registrar salida"
        case .set:
            return "Fijar saldo"
        }
    }

    @ViewBuilder
    private var advancedOperationsSection: some View {
        InventoryItemDetailSectionCard(
            title: "Operaciones avanzadas",
            subtitle: "Disponibilidad confirmada sin crear acciones incompletas en Business.",
            systemImage: "shippingbox.and.arrow.backward"
        ) {
            InventoryItemDetailNoticeCard(
                title: "Conteo físico · Admin",
                message: viewModel.physicalCountGuidance,
                systemImage: "checklist",
                tint: .secondary
            )

            InventoryItemDetailNoticeCard(
                title: "Transferencia entre bodegas · Admin",
                message: viewModel.transferGuidance,
                systemImage: "arrow.left.arrow.right.square",
                tint: .secondary
            )

            Text("No hay botones deshabilitados ni navegación pendiente: estas operaciones continúan en la fase Admin 26R.P.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var movementsSection: some View {
        InventoryItemDetailSectionCard(
            title: "Kardex operativo",
            subtitle: "Historial referencial de entradas, salidas y ajustes. No sustituye un Kardex contable o legal.",
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
                        InventoryMovementCard(movement: movement) {
                            selectedMovement = movement
                        }
                    }
                }
            }

            if viewModel.canExportOperationalKardex {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Exporta los últimos 30 días del producto y bodega actuales.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await viewModel.exportOperationalKardex() }
                    } label: {
                        HStack(spacing: 9) {
                            if viewModel.isExportingKardex {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(viewModel.isExportingKardex ? "Preparando CSV…" : "Exportar Kardex operativo CSV")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isExportingKardex)

                    if let file = viewModel.downloadedKardexFile {
                        ShareLink(item: file.localURL) {
                            Label("Compartir \(file.fileName)", systemImage: "square.and.arrow.up.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
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
        let normalized = InventoryStatusPresentation.displayName(viewModel.item).lowercased()
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

private struct InventoryAdjustmentTypeButton: View {
    let type: InventoryAdjustmentType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))

                Text(type.operationTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                (isSelected ? Color.accentColor : Color.secondary).opacity(isSelected ? 0.12 : 0.07),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        (isSelected ? Color.accentColor : Color.primary).opacity(isSelected ? 0.2 : 0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var systemImage: String {
        switch type {
        case .increase:
            return "plus"
        case .decrease:
            return "minus"
        case .set:
            return "equal"
        }
    }
}

private struct InventoryAdjustmentQuantityControl: View {
    @Binding var quantity: String
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cantidad")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                        .font(.body.weight(.bold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Disminuir cantidad")

                TextField("1", text: $quantity)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Color(uiColor: .tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                Button(action: increase) {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Aumentar cantidad")
            }
        }
    }
}

private struct InventoryAdjustmentReasonButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    (isSelected ? Color.accentColor : Color.secondary).opacity(isSelected ? 0.12 : 0.07),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(InventoryStatusPresentation.movementDisplayName(movement.type))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let reason = movement.reasonDisplayText {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let createdAt = movement.createdAt {
                        Text(InventoryPresentationFormatter.dateTime(createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(movement.quantityChangeDisplayText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    if let balance = movement.balanceTransitionDisplayText {
                        Text(balance)
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityHint("Abre el detalle del movimiento")
    }
}

private struct InventoryMovementDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let movement: InventoryMovement
    let item: InventoryItem

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    InventoryItemDetailSectionCard(
                        title: InventoryStatusPresentation.movementDisplayName(movement.type),
                        subtitle: item.displayName,
                        systemImage: "arrow.left.arrow.right.circle"
                    ) {
                        InventoryItemDetailFactRow(
                            title: "Variación",
                            value: movement.quantityChangeDisplayText,
                            systemImage: "plus.forwardslash.minus"
                        )

                        if let balance = movement.balanceTransitionDisplayText {
                            InventoryItemDetailFactRow(
                                title: "Saldo",
                                value: balance,
                                systemImage: "arrow.left.arrow.right"
                            )
                        }

                        if let reason = movement.reasonDisplayText {
                            InventoryItemDetailFactRow(
                                title: "Motivo",
                                value: reason,
                                systemImage: "text.quote"
                            )
                        }

                        if let createdAt = movement.createdAt {
                            InventoryItemDetailFactRow(
                                title: "Fecha",
                                value: InventoryPresentationFormatter.dateTime(createdAt),
                                systemImage: "calendar"
                            )
                        }
                    }
                    .inventoryItemDetailSurface()

                    if let movementDescription {
                        InventoryItemDetailSectionCard(
                            title: "Descripción",
                            subtitle: "Información registrada con el movimiento.",
                            systemImage: "note.text"
                        ) {
                            Text(movementDescription)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .inventoryItemDetailSurface()
                    }

                    InventoryItemDetailSectionCard(
                        title: "Referencia técnica",
                        subtitle: "Datos para soporte y auditoría.",
                        systemImage: "wrench.and.screwdriver"
                    ) {
                        InventoryItemDetailFactRow(
                            title: "Movimiento",
                            value: movement.id,
                            systemImage: "number"
                        )

                        if let productReference = item.technicalReference {
                            InventoryItemDetailFactRow(
                                title: "Producto",
                                value: productReference,
                                systemImage: "shippingbox"
                            )
                        }

                        if let sourceName = InventoryStatusPresentation.sourceDisplayName(movement.sourceType) {
                            InventoryItemDetailFactRow(
                                title: "Origen",
                                value: sourceName,
                                systemImage: "link"
                            )
                        }

                        if let sourceId = movement.sourceId, !sourceId.isEmpty {
                            InventoryItemDetailFactRow(
                                title: "Referencia origen",
                                value: sourceId,
                                systemImage: "link.badge.plus"
                            )
                        }

                        if let warehouseId = movement.warehouseId, !warehouseId.isEmpty {
                            InventoryItemDetailFactRow(
                                title: "Bodega",
                                value: warehouseId,
                                systemImage: "building.2"
                            )
                        }

                        if let createdBy = movement.createdBy, !createdBy.isEmpty {
                            InventoryItemDetailFactRow(
                                title: "Registrado por",
                                value: createdBy,
                                systemImage: "person"
                            )
                        }
                    }
                    .inventoryItemDetailSurface()
                }
                .padding(12)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Detalle del movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var movementDescription: String? {
        if let reasonText = movement.reasonText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reasonText.isEmpty {
            return reasonText
        }
        if let reason = movement.reason?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reason.isEmpty {
            return reason
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        InventoryItemDetailView(
            viewModel: InventoryItemDetailViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                catalogRevision: PreviewData.businessContext.revisions.catalogRevision,
                item: PreviewInventoryData.items[0],
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                inventoryRepository: PreviewInventoryRepository()
            )
        )
    }
}
