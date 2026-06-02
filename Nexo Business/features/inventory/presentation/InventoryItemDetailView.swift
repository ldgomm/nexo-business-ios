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
        Form {
            itemSection
            adjustmentSection
            movementsSection
            messagesSection
        }
        .navigationTitle("Stock")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.loadMovements() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingMovements)
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
        Section("Producto") {
            Text(viewModel.item.name)
                .font(.headline)

            if let sku = viewModel.item.sku, !sku.isEmpty {
                LabeledContent("SKU", value: sku)
            }

            LabeledContent("Estado", value: InventoryStatusPresentation.displayName(viewModel.item.stockStatus ?? viewModel.item.status))
            LabeledContent("Disponible", value: viewModel.item.available.displayText)

            if let reserved = viewModel.item.reserved {
                LabeledContent("Reservado", value: reserved.displayText)
            }

            if let threshold = viewModel.item.lowStockThreshold {
                LabeledContent("Mínimo", value: threshold.displayText)
            }

            if let updatedAt = viewModel.item.updatedAt {
                LabeledContent("Actualizado", value: updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    @ViewBuilder
    private var adjustmentSection: some View {
        if viewModel.item.trackStock {
            Section("Ajuste manual") {
                Picker("Tipo", selection: $viewModel.adjustmentType) {
                    ForEach(InventoryAdjustmentType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                TextField("Cantidad", text: $viewModel.adjustmentQuantity)
                    .keyboardType(.decimalPad)

                TextField("Motivo", text: $viewModel.adjustmentReason, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...3)

                TextField("Nota opcional", text: $viewModel.adjustmentNote, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...3)

                Button {
                    Task { await viewModel.adjust() }
                } label: {
                    if viewModel.isAdjusting {
                        ProgressView()
                    } else {
                        Label("Registrar ajuste", systemImage: "plus.forwardslash.minus")
                    }
                }
                .disabled(!viewModel.canAdjust)
            }
        } else {
            Section("Ajuste manual") {
                Label("Este producto no maneja stock.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var movementsSection: some View {
        Section("Movimientos") {
            if viewModel.isLoadingMovements && viewModel.movements.isEmpty {
                ProgressView("Cargando movimientos…")
            } else if viewModel.movements.isEmpty {
                ContentUnavailableView(
                    "Sin movimientos",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Los ajustes y ventas aparecerán aquí.")
                )
            } else {
                ForEach(viewModel.movements) { movement in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(InventoryStatusPresentation.movementDisplayName(movement.type))
                            .font(.subheadline.weight(.semibold))

                        LabeledContent("Cantidad", value: movement.quantity.displayText)

                        if let previous = movement.previousQuantity,
                           let new = movement.newQuantity {
                            Text("\(previous.displayText) → \(new.displayText)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        if let reason = movement.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let createdAt = movement.createdAt {
                            Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
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
