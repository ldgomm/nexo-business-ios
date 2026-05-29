//
//  CustomerDirectoryView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct CustomerDirectoryView: View {
    @Bindable private var viewModel: CustomerDirectoryViewModel

    public init(viewModel: CustomerDirectoryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section("Buscar") {
                TextField("Nombre, cédula, RUC o correo", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                Button {
                    Task { await viewModel.search() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)
            }

            if viewModel.canCreate {
                Section("Crear") {
                    NavigationLink {
                        CustomerCreateView(
                            viewModel: CustomerCreateViewModel(
                                organizationId: viewModel.organizationId,
                                customersRepository: viewModel.customersRepository
                            ),
                            onCreated: { customer in
                                viewModel.addOrReplace(customer)
                            }
                        )
                    } label: {
                        Label("Nuevo cliente", systemImage: "person.badge.plus")
                    }
                }
            }

            Section("Clientes") {
                if viewModel.isLoading && viewModel.customers.isEmpty {
                    ProgressView("Cargando clientes…")
                } else if viewModel.customers.isEmpty {
                    ContentUnavailableView(
                        "Sin clientes",
                        systemImage: "person.text.rectangle",
                        description: Text("Crea o busca clientes para ventas identificadas, crédito y comprobantes.")
                    )
                } else {
                    ForEach(viewModel.customers) { customer in
                        CustomerRowView(customer: customer)
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
        .navigationTitle("Clientes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.search() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            if viewModel.customers.isEmpty {
                await viewModel.load()
            }
        }
    }
}

#Preview {
    NavigationStack {
        CustomerDirectoryView(
            viewModel: CustomerDirectoryViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                customersRepository: PreviewCustomersRepository()
            )
        )
    }
}
