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
        ScrollView {
            LazyVStack(spacing: 12) {
                heroSection
                searchSection
                quickSelectionSection

                if viewModel.canCreate {
                    createSection
                }

                resultsSection
                messagesSection
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .nexoKeyboardDismissable()
        .navigationTitle("Seleccionar cliente")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadInitial()
        }
    }

    private var heroSection: some View {
        CustomerExecutiveCard(
            title: "Cliente de la venta",
            subtitle: allowsFinalConsumer ? "Busca un cliente real o continúa como consumidor final cuando la venta no requiere identificación." : "Para proformas y crédito selecciona un cliente real del directorio.",
            systemImage: "person.text.rectangle",
            isHero: true,
            usesGradient: true
        ) {
            HStack(spacing: 8) {
                CustomerExecutivePill(
                    title: allowsFinalConsumer ? "Consumidor final permitido" : "Cliente real requerido",
                    systemImage: allowsFinalConsumer ? "person.crop.circle" : "checkmark.shield",
                    tint: allowsFinalConsumer ? .orange : .accentColor
                )

                CustomerExecutivePill(
                    title: "Directorio",
                    systemImage: "person.2",
                    tint: .accentColor
                )
            }
        }
    }

    private var searchSection: some View {
        CustomerExecutiveCard(
            title: "Buscar cliente",
            subtitle: "Nombre, cédula, RUC, teléfono o correo.",
            systemImage: "magnifyingglass"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                searchField

                HStack(spacing: 10) {
                    Text("La búsqueda respeta permisos y evita crear duplicados innecesarios.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Button {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.search() }
                    } label: {
                        if viewModel.isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Buscar", systemImage: "magnifyingglass")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(viewModel.isSearching || !viewModel.canSearch)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            TextField("Nombre, cédula, RUC o correo", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.search() }
                }

            if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    viewModel.query = ""
                    NexoKeyboard.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpiar búsqueda")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var quickSelectionSection: some View {
        CustomerExecutiveCard(
            title: "Selección rápida",
            subtitle: allowsFinalConsumer ? "Úsalo solo para ventas simples sin identificación fiscal del cliente." : "Esta operación necesita datos reales del cliente.",
            systemImage: allowsFinalConsumer ? "bolt.fill" : "person.crop.circle.badge.exclamationmark"
        ) {
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
                CustomerExecutiveNoticeCard(
                    title: "Consumidor final no disponible",
                    message: "Para proformas, crédito o seguimiento comercial selecciona o crea un cliente real.",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    tint: .orange
                )
            }
        }
    }

    private var createSection: some View {
        CustomerExecutiveCard(
            title: "Nuevo cliente",
            subtitle: "Crea el registro una sola vez y úsalo en ventas, proformas, crédito y comprobantes.",
            systemImage: "person.badge.plus"
        ) {
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
                CustomerExecutiveActionRow(
                    title: "Crear cliente",
                    subtitle: "Registrar identificación y datos de contacto",
                    systemImage: "person.badge.plus"
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        CustomerExecutiveCard(
            title: "Resultados",
            subtitle: resultSubtitle,
            systemImage: "list.bullet.rectangle"
        ) {
            if viewModel.isSearching && viewModel.customers.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Buscando clientes…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.customers.isEmpty {
                ContentUnavailableView(
                    "Sin clientes",
                    systemImage: "person.text.rectangle",
                    description: Text(allowsFinalConsumer ? "Busca o usa Consumidor final para ventas sin datos del cliente." : "Busca por nombre, cédula, RUC o correo. En proformas necesitas un cliente real.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
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
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            CustomerExecutiveNoticeCard(
                title: "No se pudo completar la búsqueda",
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
        }

        if let message = viewModel.infoMessage {
            CustomerExecutiveNoticeCard(
                title: "Información",
                message: message,
                systemImage: "info.circle",
                tint: .secondary
            )
        }
    }

    private var resultSubtitle: String {
        if viewModel.customers.isEmpty {
            return "Clientes encontrados aparecerán aquí."
        }

        return viewModel.customers.count == 1 ? "1 cliente encontrado" : "\(viewModel.customers.count) clientes encontrados"
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
