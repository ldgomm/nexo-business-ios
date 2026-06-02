//
//  InventoryDashboardView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct InventoryDashboardView: View {
    @Bindable private var viewModel: InventoryDashboardViewModel

    init(viewModel: InventoryDashboardViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            filtersSection
            summarySection
            messagesSection
            itemsSection
        }
        .navigationTitle("Inventario")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.load()
            }
        }
    }

    private var filtersSection: some View {
        Section("Buscar") {
            TextField("Producto, SKU o código", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.load() }
                }

            Picker("Filtro", selection: $viewModel.stockStatus) {
                ForEach(InventoryItemStockStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }

            Button {
                Task { await viewModel.load() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Label("Consultar inventario", systemImage: "magnifyingglass")
                }
            }
            .disabled(viewModel.isLoading)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if viewModel.totalCount != nil || viewModel.lowStockCount != nil || viewModel.outOfStockCount != nil {
            Section("Resumen") {
                if let totalCount = viewModel.totalCount {
                    LabeledContent("Productos", value: String(totalCount))
                }
                if let lowStockCount = viewModel.lowStockCount {
                    LabeledContent("Stock bajo", value: String(lowStockCount))
                }
                if let outOfStockCount = viewModel.outOfStockCount {
                    LabeledContent("Sin stock", value: String(outOfStockCount))
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
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var itemsSection: some View {
        Section("Productos") {
            switch viewModel.state {
            case .idle, .loading:
                HStack {
                    ProgressView()
                    Text("Consultando stock…")
                        .foregroundStyle(.secondary)
                }

            case let .failed(message):
                ContentUnavailableView {
                    Label("No se pudo cargar inventario", systemImage: "shippingbox")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") {
                        Task { await viewModel.load() }
                    }
                }

            case let .loaded(items):
                if items.isEmpty {
                    ContentUnavailableView(
                        "Sin productos",
                        systemImage: "shippingbox",
                        description: Text("No hay productos que coincidan con el filtro actual.")
                    )
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            InventoryItemDetailView(
                                viewModel: viewModel.makeDetailViewModel(for: item),
                                onItemUpdated: { updatedItem in
                                    viewModel.updateItem(updatedItem)
                                }
                            )
                        } label: {
                            InventoryItemRow(item: item)
                        }
                    }
                }
            }
        }
    }
}

private struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: InventoryStatusPresentation.stockSystemImage(item))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let sku = item.sku, !sku.isEmpty {
                    Text("SKU: \(sku)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Disponible: \(item.available.displayText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let lowStockThreshold = item.lowStockThreshold {
                    Text("Mínimo: \(lowStockThreshold.displayText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(InventoryStatusPresentation.displayName(item.stockStatus ?? item.status))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        InventoryDashboardView(
            viewModel: InventoryDashboardViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                activityId: PreviewData.businessContext.activities[0].id,
                catalogRevision: PreviewData.businessContext.revisions.catalogRevision,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                inventoryRepository: PreviewInventoryRepository()
            )
        )
    }
}
