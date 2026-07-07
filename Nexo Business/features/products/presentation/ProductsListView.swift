//
//  ProductsListView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct ProductsListView: View {
    @Bindable private var viewModel: ProductsListViewModel
    @State private var selectedProduct: BusinessProduct?
    @State private var productToDeactivate: BusinessProduct?
    
    init(viewModel: ProductsListViewModel) {
        _viewModel = Bindable(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                messagesSection
                heroSection
                metricsSection
                searchSection
                productsContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Productos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.isShowingAdoption = true
                    } label: {
                        Label("Agregar desde catálogo", systemImage: "plus.circle.fill")
                    }
                    
                    Button {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.load() }
                    } label: {
                        Label("Actualizar", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isShowingAdoption) {
            NavigationStack {
                MasterCatalogAdoptionView(
                    viewModel: MasterCatalogAdoptionViewModel(
                        organizationId: viewModel.organizationId,
                        branchId: viewModel.branchId,
                        activityId: viewModel.activityId,
                        repository: viewModel.repository,
                        taxProfiles: viewModel.taxProfiles
                    ),
                    onSaved: { product in
                        viewModel.replace(product)
                        selectedProduct = product
                        viewModel.successMessage = "Producto agregado desde catálogo."
                    }
                )
            }
        }
        .sheet(item: $selectedProduct) { product in
            NavigationStack {
                ProductDetailView(
                    product: product,
                    organizationId: viewModel.organizationId,
                    branchId: viewModel.branchId,
                    activityId: viewModel.activityId,
                    repository: viewModel.repository,
                    taxProfiles: viewModel.taxProfiles,
                    onSaved: { updated in
                        viewModel.replace(updated)
                        selectedProduct = updated
                    }
                )
            }
        }
        .sheet(item: $viewModel.editingProduct) { product in
            NavigationStack {
                ProductFormView(
                    viewModel: ProductFormViewModel(
                        mode: .edit(product),
                        organizationId: viewModel.organizationId,
                        branchId: viewModel.branchId,
                        activityId: viewModel.activityId,
                        repository: viewModel.repository,
                        taxProfiles: viewModel.taxProfiles
                    ),
                    onSaved: { updated in
                        viewModel.replace(updated)
                        viewModel.successMessage = "Producto actualizado."
                    }
                )
            }
        }
        .confirmationDialog(
            "Pausar producto",
            isPresented: deactivationDialogBinding,
            titleVisibility: .visible,
            presenting: productToDeactivate
        ) { product in
            Button("Pausar", role: .destructive) {
                let selectedProduct = product
                productToDeactivate = nil
                
                Task {
                    await viewModel.deactivate(selectedProduct)
                }
            }
            
            Button("Cancelar", role: .cancel) {
                productToDeactivate = nil
            }
        } message: { product in
            Text("\(product.name) dejará de aparecer para la venta, pero conservará su historial.")
        }
    }
    
    private var deactivationDialogBinding: Binding<Bool> {
        Binding(
            get: { productToDeactivate != nil },
            set: { isPresented in
                if !isPresented {
                    productToDeactivate = nil
                }
            }
        )
    }
    
    @ViewBuilder
    private var messagesSection: some View {
        if let error = viewModel.errorMessage, !error.isEmpty {
            ProductsSurfaceCard {
                NexoMessageBanner(error, style: .error)
            }
        }
        
        if let success = viewModel.successMessage, !success.isEmpty {
            ProductsSurfaceCard {
                NexoMessageBanner(success, style: .success)
            }
        }
    }
    
    private var heroSection: some View {
        ProductsHeroCard(
            totalCount: viewModel.products.count,
            availableCount: availableProductsCount,
            blockedCount: blockedProductsCount,
            onAdd: { viewModel.isShowingAdoption = true }
        )
    }
    
    private var metricsSection: some View {
        ProductsMetricsRow(
            totalCount: viewModel.products.count,
            availableCount: availableProductsCount,
            blockedCount: blockedProductsCount
        )
    }
    
    private var searchSection: some View {
        ProductsSurfaceCard {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ProductsSearchField(
                        text: $viewModel.query,
                        placeholder: "Nombre, SKU, código de barras o referencia"
                    ) {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.load() }
                    }
                    
                    Button {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: viewModel.isLoading ? "hourglass" : "slider.horizontal.3")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Aplicar filtros")
                }
                
                Picker("Estado", selection: $viewModel.filter) {
                    ForEach(ProductsListViewModel.Filter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.filter) { _, _ in
                    Task { await viewModel.load() }
                }
            }
        }
    }
    
    @ViewBuilder
    private var productsContent: some View {
        if viewModel.isLoading && viewModel.products.isEmpty {
            ProductsLoadingCard()
        } else if !viewModel.hasProducts {
            ProductsEmptyCatalogCard {
                viewModel.isShowingAdoption = true
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lista de productos")
                        .font(.headline)
                    
                    Text(productsListSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.products) { product in
                        ProductListRowCard(
                            product: product,
                            onOpen: {
                                selectedProduct = product
                            },
                            onEdit: {
                                viewModel.editingProduct = product
                            },
                            onDeactivate: {
                                productToDeactivate = product
                            },
                            onActivate: {
                                Task { await viewModel.activate(product) }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var availableProductsCount: Int {
        viewModel.products.filter(\.productsIsActive).count
    }
    
    private var blockedProductsCount: Int {
        viewModel.products.filter(\.productsIsBlockedForProductsUI).count
    }
    
    private var productsListSubtitle: String {
        let count = viewModel.products.count
        let suffix = count == 1 ? "producto" : "productos"
        return "\(count) \(suffix) en este filtro. Toca una tarjeta para ver el detalle; edita desde dentro del producto."
    }
}

private struct ProductsHeroCard: View {
    let totalCount: Int
    let availableCount: Int
    let blockedCount: Int
    let onAdd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ProductsIconBadge(systemImage: "shippingbox.fill", tint: .accentColor)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("CATÁLOGO DEL NEGOCIO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    
                    Text("Productos listos para vender")
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Adopta desde catálogo maestro y configura lo local: precio, SKU/código, tipo retail/servicio, disponibilidad e impuestos permitidos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 0)
            }
            
            Button(action: onAdd) {
                Label("Agregar desde catálogo maestro", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.teal.opacity(0.16),
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

private struct ProductsMetricsRow: View {
    let totalCount: Int
    let availableCount: Int
    let blockedCount: Int
    
    var body: some View {
        HStack(spacing: 10) {
            ProductsMetricCard(title: "Total", value: "\(totalCount)", systemImage: "shippingbox.fill", tint: .accentColor)
            ProductsMetricCard(title: "Disponibles", value: "\(availableCount)", systemImage: "checkmark.circle.fill", tint: .green)
            ProductsMetricCard(title: "Bloqueados", value: "\(blockedCount)", systemImage: "lock.fill", tint: .orange)
        }
    }
}

private struct ProductsMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.10))
        )
    }
}

private struct ProductsSurfaceCard<Content: View>: View {
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

private struct ProductsSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: $text)
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
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }
}

private struct ProductListRowCard: View {
    let product: BusinessProduct
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDeactivate: () -> Void
    let onActivate: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ProductsIconBadge(
                systemImage: iconSystemImage,
                tint: statusTint
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        HStack(spacing: 6) {
                            ProductsCompactPill(title: typeLabel, tint: .secondary)
                            ProductsCompactPill(title: product.productsDisplayStatus, tint: statusTint, leadingDot: true)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    Text(product.productsDisplayPrice)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    if let taxLabel {
                        Text(taxLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if taxLabel != nil {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(product.productsSourceLabelForProductsUI)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            VStack(spacing: 14) {
                Menu {
                    Button(action: onOpen) {
                        Label("Ver detalle", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button(action: onEdit) {
                        Label("Editar producto", systemImage: "pencil")
                    }
                    
                    if product.productsIsActive && product.productsCanDeactivate {
                        Button(role: .destructive, action: onDeactivate) {
                            Label("Pausar", systemImage: "pause.circle")
                        }
                    } else if product.productsCanActivate {
                        Button(action: onActivate) {
                            Label("Activar", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: onOpen)
    }
    
    private var iconSystemImage: String {
        switch product.type?.uppercased() {
        case "SERVICE", "LABOR": "wrench.and.screwdriver.fill"
        case "PART": "gearshape.2.fill"
        case "KIT", "COMBO": "square.stack.3d.up.fill"
        case "PACKAGE": "shippingbox.and.arrow.backward.fill"
        default: product.productsIsActive ? "shippingbox.fill" : "shippingbox"
        }
    }
    
    private var typeLabel: String {
        switch product.type?.uppercased() {
        case "SERVICE": return "Servicio"
        case "PACKAGE": return "Paquete"
        default: return "Producto"
        }
    }
    
    private var taxLabel: String? {
        product.taxProfileName?.nilIfEmptyForProductsUI
        ?? product.taxProfileCode?.nilIfEmptyForProductsUI
    }
    
    private var statusTint: Color {
        if product.productsIsBlockedForProductsUI {
            return .orange
        }
        return product.productsIsActive ? .green : .secondary
    }
}

private struct ProductDetailView: View {
    @State private var product: BusinessProduct
    @State private var isShowingEditForm = false
    @State private var isChangingStatus = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isShowingPauseConfirmation = false
    
    let organizationId: String
    let branchId: String
    let activityId: String
    let repository: ProductsRepository
    let taxProfiles: [BusinessTaxProfile]
    let onSaved: (BusinessProduct) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    init(
        product: BusinessProduct,
        organizationId: String,
        branchId: String,
        activityId: String,
        repository: ProductsRepository,
        taxProfiles: [BusinessTaxProfile],
        onSaved: @escaping (BusinessProduct) -> Void
    ) {
        _product = State(initialValue: product)
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.repository = repository
        self.taxProfiles = taxProfiles
        self.onSaved = onSaved
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                detailMessages
                detailHeader
                ProductDetailSection(title: "Información general", systemImage: "doc.text", tint: .accentColor) {
                    ProductDetailRow(title: "Nombre comercial", value: product.name)
                    ProductDetailRow(title: "Código del producto", value: product.productsPrimaryCode ?? "Sin código")
                    ProductDetailRow(title: "Tipo", value: typeLabel)
                    ProductDetailRow(title: "Catálogo 25R", value: "SKU/código, precio y tributación validados por backend")
                    ProductDetailRow(title: "Origen", value: product.productsSourceLabelForProductsUI)
                }
                
                ProductDetailSection(title: "Venta y precio", systemImage: "dollarsign.circle", tint: .green) {
                    ProductDetailRow(title: "Precio de venta", value: product.productsDisplayPrice)
                    ProductDetailRow(title: "Moneda", value: product.price?.currency ?? "USD")
                    ProductDetailRow(title: "Unidad de medida", value: "Unidad")
                }
                
                ProductDetailSection(title: "Tributación", systemImage: "percent", tint: .purple) {
                    ProductDetailRow(title: "Perfil tributario", value: product.taxProfileName ?? product.taxProfileCode ?? "No configurado")
                    ProductDetailRow(title: "Código tributario", value: product.taxProfileCode ?? "No configurado")
                    ProductDetailRow(title: "Regla", value: "Calculada por servidor")
                    ProductDetailRow(title: "Venta", value: "El backend valida sellability, precio e impuestos antes de cobrar")
                }
                
                ProductDetailSection(title: "Disponibilidad", systemImage: "checkmark.seal", tint: statusTint) {
                    ProductDetailStatusRow(title: "Estado", value: product.productsDisplayStatus, tint: statusTint)
                    ProductDetailRow(title: "Estado local", value: product.localStatus ?? product.status ?? "Sin estado")
                    ProductDetailRow(title: "Estado maestro", value: product.masterStatus ?? "No informado")
                    ProductDetailRow(title: "Estado efectivo", value: product.effectiveStatus ?? "No informado")
                    ProductDetailRow(title: "Costo/margen", value: "Dato sensible: visible solo con permisos de catálogo financiero")
                    if let reason = product.productsAvailabilityReason {
                        ProductDetailRow(title: "Motivo", value: reason)
                    }
                }
                
                detailActions
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Detalle del producto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isShowingEditForm = true
                    } label: {
                        Label("Editar producto", systemImage: "pencil")
                    }
                    
                    if product.productsIsActive && product.productsCanDeactivate {
                        Button(role: .destructive) {
                            isShowingPauseConfirmation = true
                        } label: {
                            Label("Pausar producto", systemImage: "pause.circle")
                        }
                    } else if product.productsCanActivate {
                        Button {
                            Task { await changeStatus(active: true) }
                        } label: {
                            Label("Activar producto", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingEditForm) {
            NavigationStack {
                ProductFormView(
                    viewModel: ProductFormViewModel(
                        mode: .edit(product),
                        organizationId: organizationId,
                        branchId: branchId,
                        activityId: activityId,
                        repository: repository,
                        taxProfiles: taxProfiles
                    ),
                    onSaved: { updated in
                        product = updated
                        onSaved(updated)
                        successMessage = "Producto actualizado."
                    }
                )
            }
        }
        .confirmationDialog(
            "Pausar producto",
            isPresented: $isShowingPauseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Pausar", role: .destructive) {
                Task { await changeStatus(active: false) }
            }
            
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("\(product.name) dejará de aparecer para la venta, pero conservará su historial.")
        }
    }
    
    @ViewBuilder
    private var detailMessages: some View {
        if let errorMessage, !errorMessage.isEmpty {
            ProductsSurfaceCard {
                NexoMessageBanner(errorMessage, style: .error)
            }
        }
        
        if let successMessage, !successMessage.isEmpty {
            ProductsSurfaceCard {
                NexoMessageBanner(successMessage, style: .success)
            }
        }
    }
    
    private var detailHeader: some View {
        HStack(spacing: 14) {
            ProductsIconBadge(systemImage: detailIconSystemImage, tint: statusTint)
                .frame(width: 58, height: 58)
            
            VStack(alignment: .leading, spacing: 7) {
                Text(product.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    ProductsCompactPill(title: typeLabel, tint: .secondary)
                    ProductsCompactPill(title: product.productsDisplayStatus, tint: statusTint, leadingDot: true)
                }
                
                Text(product.productsSourceLabelForProductsUI)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(product.productsDisplayPrice)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                
                Text("Precio de venta")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }
    
    private var detailActions: some View {
        VStack(spacing: 10) {
            Button {
                isShowingEditForm = true
            } label: {
                Label("Editar producto", systemImage: "pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            statusActionButton
        }
    }
    
    @ViewBuilder
    private var statusActionButton: some View {
        if product.productsIsActive && product.productsCanDeactivate {
            Button {
                isShowingPauseConfirmation = true
            } label: {
                ProductsStatusActionLabel(
                    title: "Pausar producto",
                    systemImage: "pause.circle",
                    isLoading: isChangingStatus
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isChangingStatus)
        } else if product.productsCanActivate {
            Button {
                Task { await changeStatus(active: true) }
            } label: {
                ProductsStatusActionLabel(
                    title: "Activar producto",
                    systemImage: "checkmark.circle",
                    isLoading: isChangingStatus
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.green)
            .disabled(isChangingStatus)
        } else {
            Button {} label: {
                Label(product.productsBlockedActionTitleForProductsUI, systemImage: "lock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(true)
        }
    }
    
    @MainActor
    private func changeStatus(active: Bool) async {
        guard !isChangingStatus else { return }
        isChangingStatus = true
        errorMessage = nil
        successMessage = nil
        defer { isChangingStatus = false }
        
        do {
            let response: BusinessProductMutationResponse
            if active {
                response = try await repository.activateProduct(
                    organizationId: organizationId,
                    productId: product.id,
                    reason: "Producto activado desde detalle Business."
                )
            } else {
                response = try await repository.deactivateProduct(
                    organizationId: organizationId,
                    productId: product.id,
                    reason: "Producto pausado desde detalle Business."
                )
            }
            product = response.product
            onSaved(response.product)
            successMessage = active ? "Producto activado." : "Producto pausado."
        } catch {
            errorMessage = ProductsErrorPresenter.message(for: error)
        }
    }
    
    private var detailIconSystemImage: String {
        switch product.type?.uppercased() {
        case "SERVICE": "wrench.and.screwdriver.fill"
        case "PACKAGE": "shippingbox.and.arrow.backward.fill"
        default: product.productsIsActive ? "shippingbox.fill" : "shippingbox"
        }
    }
    
    private var typeLabel: String {
        switch product.type?.uppercased() {
        case "SERVICE": return "Servicio"
        case "PACKAGE": return "Paquete"
        default: return "Producto"
        }
    }
    
    private var statusTint: Color {
        if product.productsIsBlockedForProductsUI {
            return .orange
        }
        return product.productsIsActive ? .green : .secondary
    }
}

private struct ProductDetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let content: Content
    
    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                content
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }
}

private struct ProductDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 16)
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.65)
        }
    }
}

private struct ProductDetailStatusRow: View {
    let title: String
    let value: String
    let tint: Color
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 16)
            
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.65)
        }
    }
}

private struct ProductsStatusActionLabel: View {
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
    }
}

private struct ProductsCompactPill: View {
    let title: String
    let tint: Color
    var leadingDot = false
    
    var body: some View {
        HStack(spacing: 5) {
            if leadingDot {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
            }
            
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct ProductsEmptyCatalogCard: View {
    let onAdd: () -> Void
    
    var body: some View {
        ProductsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                ProductsIconBadge(systemImage: "shippingbox.and.arrow.backward", tint: .accentColor)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Todavía no hay productos")
                        .font(.headline)
                    
                    Text("Agrega productos desde catálogo maestro. Así Nexo mantiene IDs consistentes, reportes sanos y futuras publicaciones públicas sin duplicados raros.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Button(action: onAdd) {
                    Label("Agregar primer producto", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

private struct ProductsLoadingCard: View {
    var body: some View {
        ProductsSurfaceCard {
            HStack(spacing: 12) {
                ProgressView()
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cargando productos…")
                        .font(.headline)
                    
                    Text("Estamos consultando el catálogo operativo del negocio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct ProductsIconBadge: View {
    let systemImage: String
    let tint: Color
    
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 46, height: 46)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private extension BusinessProduct {
    var productsIsBlockedForProductsUI: Bool {
        if let canSell, canSell == false, canActivate == false {
            return true
        }
        let effective = effectiveStatus?.lowercased() ?? ""
        let master = masterStatus?.lowercased() ?? ""
        return effective.contains("master")
        || effective.contains("blocked")
        || effective.contains("removed")
        || effective.contains("legacy")
        || effective.contains("needs_review")
        || master == "draft"
        || master == "paused"
        || master == "archived"
        || master == "disabled"
        || master == "removed"
        || master == "blocked"
        || master == "missing_master"
        || master == "orphan"
    }

    var productsBlockedActionTitleForProductsUI: String {
        switch effectiveStatus?.lowercased() {
        case "draft_by_master":
            return "En preparación por catálogo"
        case "paused_by_master", "blocked_by_master", "disabled_by_master":
            return "Pausado por catálogo maestro"
        case "removed_by_master":
            return "Retirado del catálogo maestro"
        case "legacy_needs_review", "local_needs_review":
            return "Requiere revisión"
        default:
            return "No se puede activar"
        }
    }
    
    var productsSourceLabelForProductsUI: String {
        let sourceValue = source?.lowercased() ?? ""
        if sourceValue.contains("master") || masterCatalogItemId?.nilIfEmptyForProductsUI != nil {
            return "Origen: Catálogo maestro"
        }
        if sourceValue.contains("admin") {
            return "Origen: Semilla admin"
        }
        if sourceValue.contains("legacy") {
            return "Origen: Producto legacy"
        }
        if sourceValue.contains("migrated") {
            return "Origen: Migrado"
        }
        return "Origen: Local"
    }
}

private extension String {
    var nilIfEmptyForProductsUI: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
