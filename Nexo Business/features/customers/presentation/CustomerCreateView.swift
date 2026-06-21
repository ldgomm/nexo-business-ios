//
//  CustomerCreateView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct CustomerCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: CustomerCreateViewModel
    private let onCreated: (BusinessCustomer) -> Void

    init(
        viewModel: CustomerCreateViewModel,
        onCreated: @escaping (BusinessCustomer) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onCreated = onCreated
    }

    var body: some View {
        Form {
            Section("Identificación") {
                Picker("Tipo", selection: $viewModel.identificationType) {
                    ForEach(BusinessCustomerIdentificationType.allCases.filter { $0 != .finalConsumer }) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                TextField("Número", text: $viewModel.identificationNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
            }

            Section("Datos") {
                TextField("Nombre o razón social", text: $viewModel.displayName)
                    .textInputAutocapitalization(.words)

                TextField("Correo opcional", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)

                TextField("Teléfono opcional", text: $viewModel.phone)
                    .keyboardType(.phonePad)

                TextField("Dirección opcional", text: $viewModel.address, axis: .vertical)
                    .lineLimit(1...3)
            }

            if let duplicate = viewModel.duplicateCandidate {
                Section("Posible duplicado") {
                    Label(duplicate.title, systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))

                    Text(duplicate.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    CustomerRowView(customer: duplicate.customer)

                    Button {
                        if let customer = viewModel.useDuplicateCandidate() {
                            onCreated(customer)
                            dismiss()
                        }
                    } label: {
                        Label("Usar cliente existente", systemImage: "person.text.rectangle")
                    }
                    .disabled(!viewModel.canUseDuplicateCandidate)

                    Button {
                        Task {
                            NexoKeyboard.dismiss()
                            if let customer = await viewModel.saveIgnoringDuplicateWarning() {
                                onCreated(customer)
                                dismiss()
                            }
                        }
                    } label: {
                        Label("Crear nuevo de todos modos", systemImage: "plus.circle")
                    }
                    .disabled(!viewModel.canSave)
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
                    Label(message, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task {
                        NexoKeyboard.dismiss()
                        if let customer = await viewModel.save() {
                            onCreated(customer)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Label("Guardar cliente", systemImage: "checkmark.circle")
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Nuevo cliente")
    }
}

#Preview {
    NavigationStack {
        CustomerCreateView(
            viewModel: CustomerCreateViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                customersRepository: PreviewCustomersRepository()
            )
        )
    }
}
