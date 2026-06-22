//
//  ProductFormView.swift
//  Nexo Business
//

import SwiftUI

struct ProductFormView: View {
    @Bindable private var viewModel: ProductFormViewModel
    private let onSaved: (BusinessProduct) -> Void
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ProductFormViewModel, onSaved: @escaping (BusinessProduct) -> Void) {
        _viewModel = Bindable(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("Información") {
                TextField("Nombre *", text: $viewModel.name)
                TextField("Código interno", text: $viewModel.code)
                TextField("Descripción", text: $viewModel.description, axis: .vertical)
            }

            Section("Venta") {
                TextField("Precio *", text: $viewModel.price)
                    .keyboardType(.decimalPad)
                Picker("Tipo", selection: $viewModel.type) {
                    Text("Producto").tag("PRODUCT")
                    Text("Servicio").tag("SERVICE")
                }

                if viewModel.taxProfiles.isEmpty {
                    ContentUnavailableView(
                        "Sin perfiles tributarios",
                        systemImage: "exclamationmark.triangle",
                        description: Text("No hay perfiles tributarios habilitados para productos en esta organización.")
                    )
                } else {
                    Picker("Perfil tributario", selection: $viewModel.selectedTaxProfileCode) {
                        ForEach(viewModel.taxProfiles) { profile in
                            Text(profile.pickerTitle).tag(profile.code)
                        }
                    }
                    if let helpText = viewModel.selectedTaxProfile?.helpText {
                        Text(helpText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if let product = await viewModel.save() {
                            onSaved(product)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Guardar")
                    }
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
        }
    }
}
