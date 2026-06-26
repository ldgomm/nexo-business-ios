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
        ScrollView {
            LazyVStack(spacing: 12) {
                filtersSection

                summarySection

                messagesSection

                itemsSection
                    .inventoryDashboardSurface()
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Inventario")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Actualizar inventario")
            }
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.load()
            }
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                InventoryDashboardIconBadge(systemImage: "shippingbox.fill", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Inventory")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Inventario operativo")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("Consulta stock, detecta faltantes y abre el detalle para ajustes controlados.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            inventorySearchField

            VStack(alignment: .leading, spacing: 8) {
                Text("Estado de stock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InventoryItemStockStatus.allCases) { status in
                            inventoryStatusChip(status)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.load() }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }

                    Text(viewModel.isLoading ? "Consultando inventario…" : "Consultar inventario")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
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

    private var inventorySearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Producto, SKU o código", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                }

            if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpiar búsqueda")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func inventoryStatusChip(_ status: InventoryItemStockStatus) -> some View {
        let isSelected = viewModel.stockStatus == status

        return Button {
            viewModel.stockStatus = status
            NexoKeyboard.dismiss()
            Task { await viewModel.load() }
        } label: {
            Text(status.displayName)
                .font(.caption.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background((isSelected ? Color.accentColor : Color.secondary).opacity(isSelected ? 0.12 : 0.08), in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder((isSelected ? Color.accentColor : Color.primary).opacity(isSelected ? 0.16 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var summarySection: some View {
        if viewModel.totalCount != nil || viewModel.lowStockCount != nil || viewModel.outOfStockCount != nil {
            InventoryDashboardSectionCard(
                title: "Resumen de stock",
                subtitle: "Lectura rápida del inventario filtrado.",
                systemImage: "chart.bar.doc.horizontal"
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    InventoryDashboardMetricCard(
                        title: "Productos",
                        value: valueText(viewModel.totalCount),
                        systemImage: "shippingbox"
                    )

                    InventoryDashboardMetricCard(
                        title: "Stock bajo",
                        value: valueText(viewModel.lowStockCount),
                        systemImage: "exclamationmark.triangle"
                    )

                    InventoryDashboardMetricCard(
                        title: "Sin stock",
                        value: valueText(viewModel.outOfStockCount),
                        systemImage: "xmark.octagon"
                    )

                    InventoryDashboardMetricCard(
                        title: "Filtro",
                        value: viewModel.stockStatus.displayName,
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
            }
            .inventoryDashboardSurface()
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            InventoryDashboardNoticeCard(
                title: "Atención",
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
            .inventoryDashboardSurface()
        }

        if let message = viewModel.infoMessage {
            InventoryDashboardNoticeCard(
                title: "Información",
                message: message,
                systemImage: "info.circle",
                tint: .secondary
            )
            .inventoryDashboardSurface()
        }
    }

    @ViewBuilder
    private var itemsSection: some View {
        InventoryDashboardSectionCard(
            title: "Productos",
            subtitle: itemsSubtitle,
            systemImage: "list.bullet.rectangle"
        ) {
            switch viewModel.state {
            case .idle, .loading:
                InventoryDashboardLoadingCard(
                    title: "Consultando stock…",
                    subtitle: "Estamos leyendo el inventario disponible."
                )

            case let .failed(message):
                InventoryDashboardFailureCard(
                    title: "No se pudo cargar inventario",
                    message: message
                ) {
                    Task { await viewModel.load() }
                }

            case let .loaded(items):
                if items.isEmpty {
                    InventoryDashboardEmptyState(
                        title: "Sin productos",
                        message: "No hay productos que coincidan con el filtro actual.",
                        systemImage: "shippingbox"
                    )
                } else {
                    VStack(spacing: 10) {
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
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var itemsSubtitle: String {
        if viewModel.isLoading {
            return "Consultando inventario"
        }

        if let total = viewModel.totalCount {
            return total == 1 ? "1 producto encontrado" : "\(total) productos encontrados"
        }

        return "Stock disponible y alertas operativas"
    }

    private func valueText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return String(value)
    }
}

private struct InventoryDashboardSurfaceModifier: ViewModifier {
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
    func inventoryDashboardSurface() -> some View {
        modifier(InventoryDashboardSurfaceModifier())
    }
}

private struct InventoryDashboardSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                InventoryDashboardIconBadge(systemImage: systemImage, tint: .accentColor, size: 34)

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

private struct InventoryDashboardIconBadge: View {
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

private struct InventoryDashboardMetricCard: View {
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
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InventoryDashboardNoticeCard: View {
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

private struct InventoryDashboardLoadingCard: View {
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

private struct InventoryDashboardFailureCard: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InventoryDashboardNoticeCard(
                title: title,
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )

            Button("Reintentar", action: retry)
                .buttonStyle(.bordered)
        }
    }
}

private struct InventoryDashboardEmptyState: View {
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

private struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InventoryDashboardIconBadge(systemImage: InventoryStatusPresentation.stockSystemImage(item), tint: stockTint, size: 38)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if let sku = item.sku, !sku.isEmpty {
                            Text("SKU: \(sku)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(item.available.displayText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    InventoryDashboardStatusPill(
                        title: InventoryStatusPresentation.displayName(item.stockStatus ?? item.status),
                        systemImage: InventoryStatusPresentation.stockSystemImage(item),
                        tint: stockTint
                    )

                    if let lowStockThreshold = item.lowStockThreshold {
                        InventoryDashboardStatusPill(
                            title: "Mín. \(lowStockThreshold.displayText)",
                            systemImage: "gauge.with.dots.needle.bottom.50percent",
                            tint: .secondary
                        )
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var stockTint: Color {
        let normalized = InventoryStatusPresentation.displayName(item.stockStatus ?? item.status).lowercased()
        if normalized.contains("sin") || normalized.contains("agot") || normalized.contains("out") {
            return .red
        }
        if normalized.contains("bajo") || normalized.contains("low") || normalized.contains("alert") {
            return .orange
        }
        return .green
    }
}

private struct InventoryDashboardStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
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
