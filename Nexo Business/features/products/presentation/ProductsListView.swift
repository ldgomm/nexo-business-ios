//
//  ProductsListView.swift
//  Nexo Business
//

import SwiftUI

struct ProductsListView: View {
    @Bindable private var viewModel: ProductsListViewModel
    @State private var productToDeactivate: BusinessProduct?

    init(viewModel: ProductsListViewModel) {
        _viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Productos")
                        .font(.title2.bold())
                    Text("Lo que vendes en este negocio: platos, bebidas, productos, servicios y precios.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField("Buscar por nombre o código", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        Task { await viewModel.load() }
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

            if viewModel.isLoading && viewModel.products.isEmpty {
                Section {
                    ProgressView("Cargando productos…")
                }
            } else if !viewModel.hasProducts {
                Section {
                    ContentUnavailableView(
                        "Sin productos",
                        systemImage: "shippingbox",
                        description: Text("Crea o activa productos para vender desde Nexo Business.")
                    )

                    Button("Crear producto") {
                        viewModel.isShowingCreate = true
                    }
                }
            } else {
                Section("Lista") {
                    ForEach(viewModel.products) { product in
                        productRowButton(product)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if let success = viewModel.successMessage {
                Section {
                    Text(success)
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Productos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isShowingCreate = true
                } label: {
                    Label("Nuevo producto", systemImage: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isShowingCreate) {
            NavigationStack {
                ProductFormView(
                    viewModel: ProductFormViewModel(
                        mode: .create,
                        organizationId: viewModel.organizationId,
                        branchId: viewModel.branchId,
                        activityId: viewModel.activityId,
                        repository: viewModel.repository,
                        taxProfiles: viewModel.taxProfiles
                    ),
                    onSaved: { product in
                        viewModel.replace(product)
                        viewModel.successMessage = "Producto creado."
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
            "Desactivar producto",
            isPresented: deactivationDialogBinding,
            titleVisibility: .visible,
            presenting: productToDeactivate
        ) { product in
            Button("Desactivar", role: .destructive) {
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
            Text("\(product.name) dejará de aparecer para la venta, pero se conservará su historial.")
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
    private func productRowButton(_ product: BusinessProduct) -> some View {
        Button {
            viewModel.editingProduct = product
        } label: {
            ProductRow(product: product)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            productSwipeActions(product)
        }
    }

    @ViewBuilder
    private func productSwipeActions(_ product: BusinessProduct) -> some View {
        if product.productsIsActive {
            Button(role: .destructive) {
                productToDeactivate = product
            } label: {
                Label("Desactivar", systemImage: "pause.circle")
            }
        } else {
            Button {
                Task {
                    await viewModel.activate(product)
                }
            } label: {
                Label("Activar", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
    }
}

private struct ProductRow: View {
    let product: BusinessProduct

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: product.productsIsActive ? "shippingbox.fill" : "shippingbox")
                .foregroundStyle(product.productsIsActive ? Color.accentColor : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(product.productsDisplayPrice)

                    if let code = product.productsPrimaryCode {
                        Text(code)
                            .monospaced()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(product.productsDisplayStatus)
                .font(.caption.weight(.semibold))
                .foregroundStyle(product.productsIsActive ? Color.green : Color.secondary)
        }
        .padding(.vertical, 4)
    }
}
