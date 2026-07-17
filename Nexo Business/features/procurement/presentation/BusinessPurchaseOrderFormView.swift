//
//  BusinessPurchaseOrderFormView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessPurchaseOrderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: BusinessPurchaseOrderFormViewModel
    private let onSaved: (BusinessProcurementPurchaseOrderResponse) -> Void

    init(
        viewModel: BusinessPurchaseOrderFormViewModel,
        onSaved: @escaping (BusinessProcurementPurchaseOrderResponse) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            accessSection
            supplierSection
            orderSection
            catalogSection
            linesSection
            notesSection
            messagesSection
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(viewModel.isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if let order = await viewModel.save() {
                            onSaved(order)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(viewModel.saveButtonTitle)
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .task {
            await viewModel.loadReferenceDataIfNeeded()
        }
    }

    @ViewBuilder
    private var accessSection: some View {
        if let message = viewModel.accessValidationMessage {
            Section {
                Label {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.trianglebadge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var supplierSection: some View {
        Section("Proveedor") {
            if viewModel.isLoadingReferenceData {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando proveedores activos…")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Proveedor", selection: $viewModel.selectedSupplierId) {
                if viewModel.selectedSupplierId.isEmpty {
                    Text("Selecciona un proveedor").tag("")
                }
                ForEach(viewModel.supplierOptions) { supplier in
                    Text(supplier.name).tag(supplier.id)
                }
            }
            .disabled(viewModel.isLoadingReferenceData || viewModel.isSaving)

            LabeledContent("Moneda", value: viewModel.currency)

            if let message = viewModel.referenceErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Reintentar proveedores") {
                    Task { await viewModel.retryReferenceData() }
                }
                .disabled(viewModel.isLoadingReferenceData || viewModel.isSaving)
            }
        }
    }

    private var orderSection: some View {
        Section {
            TextField("Fecha esperada (AAAA-MM-DD)", text: $viewModel.expectedDate)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Entrega")
        } footer: {
            Text("La fecha es opcional y se envía como fecha local, sin convertirla a zona horaria.")
        }
    }

    private var catalogSection: some View {
        Section {
            TextField("Nombre, SKU o código", text: $viewModel.catalogQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.searchCatalog() }
                }

            Button {
                Task { await viewModel.searchCatalog() }
            } label: {
                if viewModel.isSearchingCatalog {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Buscando…")
                    }
                } else {
                    Label("Buscar en catálogo", systemImage: "magnifyingglass")
                }
            }
            .disabled(viewModel.isSearchingCatalog || viewModel.isSaving)

            ForEach(viewModel.catalogResults) { item in
                Button {
                    viewModel.addCatalogItem(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName ?? item.name)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        if let sku = item.sku?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !sku.isEmpty {
                            Text("SKU: \(sku)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(viewModel.isSaving)
            }

            if let message = viewModel.catalogInfoMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Agregar productos o servicios")
        } footer: {
            Text("La orden conserva la identidad tributaria del catálogo; nunca solicita identificadores internos.")
        }
    }

    private var linesSection: some View {
        Section {
            if viewModel.lines.isEmpty {
                ContentUnavailableView(
                    "Orden sin líneas",
                    systemImage: "cart.badge.plus",
                    description: Text("Busca arriba el primer producto o servicio.")
                )
            } else {
                ForEach($viewModel.lines) { $line in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(line.displayName)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 10)
                            if let sku = line.sku?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !sku.isEmpty {
                                Text(sku)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TextField("Descripción", text: $line.description, axis: .vertical)
                            .lineLimit(1...3)

                        LabeledContent("Unidad", value: line.unitCode)

                        TextField("Cantidad", text: $line.orderedQuantity)
                            .keyboardType(.decimalPad)

                        TextField("Costo unitario", text: $line.unitCost)
                            .keyboardType(.decimalPad)

                        TextField("Descuento de línea", text: $line.discountAmount)
                            .keyboardType(.decimalPad)

                        Picker("Impuestos", selection: $line.priceTaxMode) {
                            ForEach(BusinessPurchaseOrderPriceTaxMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        TextField("Notas de línea (opcional)", text: $line.notes, axis: .vertical)
                            .lineLimit(1...3)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: viewModel.removeLines)
            }
        } header: {
            Text("Líneas de la orden")
        } footer: {
            Text("Desliza una línea para eliminarla. Los totales finales los calcula el backend con su configuración tributaria vigente.")
        }
    }

    private var notesSection: some View {
        Section("Notas internas") {
            TextField("Notas (opcional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
