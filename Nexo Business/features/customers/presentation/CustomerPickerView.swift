//
//  CustomerPickerView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct CustomerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: CustomerPickerViewModel
    private let allowsFinalConsumer: Bool
    private let onSelect: (BusinessCustomer) -> Void

    init(
        viewModel: CustomerPickerViewModel,
        allowsFinalConsumer: Bool = true,
        onSelect: @escaping (BusinessCustomer) -> Void
    ) {
        self.viewModel = viewModel
        self.allowsFinalConsumer = allowsFinalConsumer
        self.onSelect = onSelect
    }

    var body: some View {
        List {
            Section("Buscar") {
                TextField("Nombre, cédula, RUC o correo", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                    }

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                } label: {
                    if viewModel.isSearching {
                        ProgressView()
                    } else {
                        Label("Buscar cliente", systemImage: "magnifyingglass")
                    }
                }
                .disabled(viewModel.isSearching || !viewModel.canSearch)
            }

            Section("Rápido") {
                if allowsFinalConsumer {
                    Button {
                        onSelect(BusinessCustomerPresentation.finalConsumer)
                        dismiss()
                    } label: {
                        CustomerRowView(
                            customer: BusinessCustomerPresentation.finalConsumer,
                            showsAccessory: true
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Consumidor final no aplica")
                                .fontWeight(.semibold)
                            Text("Para proformas selecciona o crea un cliente real.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                    }
                    .foregroundStyle(.secondary)
                }
            }

            if viewModel.canCreate {
                Section("Nuevo cliente") {
                    NavigationLink {
                        CustomerCreateView(
                            viewModel: CustomerCreateViewModel(
                                organizationId: viewModel.organizationId,
                                customersRepository: viewModel.customersRepository
                            ),
                            onCreated: { customer in
                                viewModel.addOrReplace(customer)
                                onSelect(customer)
                                dismiss()
                            }
                        )
                    } label: {
                        Label("Crear cliente", systemImage: "person.badge.plus")
                    }
                }
            }

            Section("Resultados") {
                if viewModel.isSearching && viewModel.customers.isEmpty {
                    ProgressView("Buscando clientes…")
                } else if viewModel.customers.isEmpty {
                    ContentUnavailableView(
                        "Sin clientes",
                        systemImage: "person.text.rectangle",
                        description: Text(allowsFinalConsumer ? "Busca o usa Consumidor final para ventas sin datos del cliente." : "Busca por nombre, cédula, RUC o correo. En proformas necesitas un cliente real.")
                    )
                } else {
                    ForEach(viewModel.customers) { customer in
                        Button {
                            onSelect(customer)
                            dismiss()
                        } label: {
                            CustomerRowView(customer: customer, showsAccessory: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

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
        .nexoKeyboardDismissable()
        .navigationTitle("Seleccionar cliente")
        .task {
            await viewModel.loadInitial()
        }
    }
}

#Preview {
    NavigationStack {
        CustomerPickerView(
            viewModel: CustomerPickerViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                customersRepository: PreviewCustomersRepository()
            ),
            onSelect: { _ in }
        )
    }
}
