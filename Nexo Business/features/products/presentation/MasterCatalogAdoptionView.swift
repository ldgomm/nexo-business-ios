//
//  MasterCatalogAdoptionView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

@Observable
final class MasterCatalogAdoptionViewModel {
    let organizationId: String
    let branchId: String
    let activityId: String
    let repository: ProductsRepository
    let taxProfiles: [BusinessTaxProfile]

    var query = ""
    var selectedType: String? = nil
    var items: [BusinessMasterCatalogItem] = []
    var isLoading = false
    var errorMessage: String?
    var hasLoaded = false

    init(
        organizationId: String,
        branchId: String,
        activityId: String,
        repository: ProductsRepository,
        taxProfiles: [BusinessTaxProfile]
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.repository = repository
        self.taxProfiles = taxProfiles
    }

    var hasResults: Bool {
        !items.isEmpty
    }

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var adoptableCount: Int {
        items.filter(\.canAdopt).count
    }

    var alreadyAdoptedCount: Int {
        items.filter(\.alreadyAdopted).count
    }

    var blockedCount: Int {
        items.filter { !$0.canAdopt && !$0.alreadyAdopted }.count
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await search()
    }

    func search() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response = try await repository.searchMasterCatalogItems(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                query: normalizedQuery,
                type: selectedType,
                limit: 25
            )
            items = response.items
        } catch {
            errorMessage = ProductsErrorPresenter.message(for: error)
        }
    }
}

struct MasterCatalogAdoptionView: View {
    @Bindable private var viewModel: MasterCatalogAdoptionViewModel
    private let onSaved: (BusinessProduct) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: MasterCatalogAdoptionViewModel,
        onSaved: @escaping (BusinessProduct) -> Void
    ) {
        _viewModel = Bindable(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                messagesSection
                heroSection
                searchSection
                adoptionGuideSection
                resultsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Catálogo maestro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Actualizar catálogo maestro")
            }
        }
        .refreshable {
            await viewModel.search()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let error = viewModel.errorMessage, !error.isEmpty {
            MasterCatalogSurfaceCard {
                NexoMessageBanner(error, style: .error)
            }
        }
    }

    private var heroSection: some View {
        MasterCatalogHeroCard(
            adoptableCount: viewModel.adoptableCount,
            alreadyAdoptedCount: viewModel.alreadyAdoptedCount,
            blockedCount: viewModel.blockedCount
        )
    }

    private var searchSection: some View {
        MasterCatalogSurfaceCard(
            title: "Encuentra el producto maestro",
            subtitle: "Busca por nombre o código. Luego Nexo creará una copia local para que configures precio, código interno y perfil tributario."
        ) {
            VStack(spacing: 12) {
                MasterCatalogSearchField(text: $viewModel.query) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                }

                Picker("Tipo", selection: $viewModel.selectedType) {
                    Text("Todos").tag(String?.none)
                    Text("Productos").tag(String?.some("PRODUCT"))
                    Text("Servicios").tag(String?.some("SERVICE"))
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedType) { _, _ in
                    Task { await viewModel.search() }
                }

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                } label: {
                    MasterCatalogActionLabel(
                        title: "Buscar en catálogo maestro",
                        systemImage: "magnifyingglass",
                        isLoading: viewModel.isLoading
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var adoptionGuideSection: some View {
        MasterCatalogSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                MasterCatalogGuideRow(
                    title: "El catálogo maestro dice qué existe",
                    subtitle: "Nombres canónicos, familia, tipo y estado global viven en la plataforma.",
                    systemImage: "building.columns.fill",
                    tint: .accentColor
                )

                MasterCatalogGuideRow(
                    title: "Tu negocio decide cómo lo vende",
                    subtitle: "Precio, disponibilidad local, código interno y perfil tributario permitido se editan en Business.",
                    systemImage: "storefront.fill",
                    tint: .blue
                )

                MasterCatalogGuideRow(
                    title: "Si el maestro se bloquea, no se vende",
                    subtitle: "Esto protege ventas, reportes, marketplace futuro y consistencia tributaria.",
                    systemImage: "lock.shield.fill",
                    tint: .orange
                )
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            MasterCatalogLoadingCard()
        } else if !viewModel.hasResults {
            MasterCatalogEmptyStateCard(hasLoaded: viewModel.hasLoaded)
        } else {
            MasterCatalogSurfaceCard(
                title: "Resultados",
                subtitle: resultsSubtitle
            ) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items) { item in
                        masterItemRow(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func masterItemRow(_ item: BusinessMasterCatalogItem) -> some View {
        if item.canAdopt {
            NavigationLink {
                ProductFormView(
                    viewModel: ProductFormViewModel(
                        mode: .adopt(item),
                        organizationId: viewModel.organizationId,
                        branchId: viewModel.branchId,
                        activityId: viewModel.activityId,
                        repository: viewModel.repository,
                        taxProfiles: viewModel.taxProfiles
                    ),
                    onSaved: { product in
                        onSaved(product)
                        dismiss()
                    }
                )
            } label: {
                MasterCatalogResultCard(item: item)
            }
            .buttonStyle(.plain)
        } else {
            MasterCatalogResultCard(item: item)
        }
    }

    private var resultsSubtitle: String {
        let total = viewModel.items.count
        let suffix = total == 1 ? "resultado" : "resultados"
        return "\(total) \(suffix). Los disponibles se pueden configurar y agregar al negocio."
    }
}

private struct MasterCatalogHeroCard: View {
    let adoptableCount: Int
    let alreadyAdoptedCount: Int
    let blockedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                MasterCatalogIconBadge(systemImage: "square.stack.3d.up.fill", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("ADOPCIÓN SEGURA")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Agregar desde catálogo")
                        .font(.title2.weight(.bold))

                    Text("Copia productos maestros al negocio sin crear duplicados huérfanos. Nexo conserva el origen y tú configuras lo local.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                MasterCatalogMetricPill(title: "Disponibles", value: "\(adoptableCount)", systemImage: "plus.circle.fill", tint: .green)
                MasterCatalogMetricPill(title: "Ya agregados", value: "\(alreadyAdoptedCount)", systemImage: "checkmark.circle.fill", tint: .blue)
                MasterCatalogMetricPill(title: "Bloqueados", value: "\(blockedCount)", systemImage: "lock.fill", tint: .orange)
            }
        }
        .padding(18)
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
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct MasterCatalogSurfaceCard<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct MasterCatalogSearchField: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Buscar producto maestro", text: $text)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit(onSubmit)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    text = ""
                    onSubmit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
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
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }
}

private struct MasterCatalogResultCard: View {
    let item: BusinessMasterCatalogItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MasterCatalogIconBadge(systemImage: iconName, tint: tint)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if item.canAdopt {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    MasterCatalogPill(title: typeLabel, systemImage: typeIcon, tint: .accentColor)
                    MasterCatalogPill(title: item.masterStatus, systemImage: "server.rack", tint: tint)
                }

                if let category = item.categoryName?.nilIfEmptyForMasterCatalogUI {
                    MasterCatalogStatusStrip(title: "Familia", value: category, systemImage: "folder")
                }

                if let helperText {
                    Text(helperText)
                        .font(.footnote)
                        .foregroundStyle(helperTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
        .opacity(item.canAdopt ? 1 : 0.74)
    }

    private var typeLabel: String {
        switch item.type.uppercased() {
        case "SERVICE": return "Servicio"
        case "PACKAGE": return "Paquete"
        default: return "Producto"
        }
    }

    private var typeIcon: String {
        item.type.uppercased() == "SERVICE" ? "wrench.and.screwdriver" : "shippingbox"
    }

    private var iconName: String {
        if item.canAdopt { return "plus.circle.fill" }
        if item.alreadyAdopted { return "checkmark.circle.fill" }
        return "lock.fill"
    }

    private var tint: Color {
        if item.canAdopt { return .green }
        if item.alreadyAdopted { return .blue }
        return .orange
    }

    private var helperText: String? {
        if item.alreadyAdopted {
            return "Ya fue agregado a este negocio. Edita su copia local desde Productos."
        }
        if let blockedReason = item.blockedReason?.nilIfEmptyForMasterCatalogUI {
            return blockedReason
        }
        if item.canAdopt {
            return "Toca para configurar precio, código interno y perfil tributario."
        }
        return "No disponible para adopción."
    }

    private var helperTint: Color {
        item.canAdopt ? .secondary : tint
    }
}

private struct MasterCatalogGuideRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct MasterCatalogLoadingCard: View {
    var body: some View {
        MasterCatalogSurfaceCard {
            HStack(spacing: 12) {
                ProgressView()

                VStack(alignment: .leading, spacing: 3) {
                    Text("Buscando catálogo…")
                        .font(.headline)

                    Text("Estamos consultando los productos maestros disponibles para el negocio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct MasterCatalogEmptyStateCard: View {
    let hasLoaded: Bool

    var body: some View {
        MasterCatalogSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                MasterCatalogIconBadge(systemImage: hasLoaded ? "magnifyingglass" : "square.stack.3d.up", tint: .accentColor)

                VStack(alignment: .leading, spacing: 6) {
                    Text(hasLoaded ? "Sin resultados" : "Catálogo maestro")
                        .font(.headline)

                    Text(hasLoaded ? "Prueba con otro nombre, revisa el tipo seleccionado o confirma que existan productos maestros adoptables." : "Busca productos del catálogo maestro para agregarlos al negocio sin crear productos huérfanos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct MasterCatalogMetricPill: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MasterCatalogIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MasterCatalogPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .lineLimit(1)
    }
}

private struct MasterCatalogStatusStrip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MasterCatalogActionLabel: View {
    let title: String
    let systemImage: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
    }
}

private extension String {
    var nilIfEmptyForMasterCatalogUI: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
