//
//  BusinessSupplierFormView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessSupplierFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: BusinessSupplierFormViewModel
    private let onSaved: (BusinessProcurementSupplierResponse) -> Void

    init(
        viewModel: BusinessSupplierFormViewModel,
        onSaved: @escaping (BusinessProcurementSupplierResponse) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            accessSection
            identitySection
            generalContactSection
            categoriesSection
            paymentTermsSection
            supplierContactsSection
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
                        if let supplier = await viewModel.save() {
                            onSaved(supplier)
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

    private var identitySection: some View {
        Section("Identidad") {
            TextField("Razón social", text: $viewModel.legalName)
                .textInputAutocapitalization(.words)

            TextField("Nombre comercial (opcional)", text: $viewModel.tradeName)
                .textInputAutocapitalization(.words)

            Picker("Tipo de identificación", selection: $viewModel.identificationKind) {
                ForEach(BusinessSupplierIdentificationKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }

            if viewModel.identificationKind != .none {
                TextField("Número de identificación", text: $viewModel.identificationNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
        }
    }

    private var generalContactSection: some View {
        Section("Contacto general") {
            TextField("Correo (opcional)", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Teléfono (opcional)", text: $viewModel.phone)
                .keyboardType(.phonePad)

            TextField("Dirección (opcional)", text: $viewModel.address, axis: .vertical)
                .lineLimit(1...3)
        }
    }

    private var categoriesSection: some View {
        Section {
            TextField("Ej. ferretería, transporte", text: $viewModel.categoriesText, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(1...3)
        } header: {
            Text("Categorías")
        } footer: {
            Text("Separa cada categoría con coma o salto de línea.")
        }
    }

    private var paymentTermsSection: some View {
        Section("Condiciones de pago") {
            Picker("Modalidad", selection: $viewModel.paymentTermsKind) {
                ForEach(BusinessSupplierPaymentTermsKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }

            if viewModel.paymentTermsKind == .netDays {
                TextField("Días de crédito", text: $viewModel.netDaysText)
                    .keyboardType(.numberPad)
            }

            if viewModel.paymentTermsKind == .custom || viewModel.paymentTermsKind == .netDays {
                TextField(
                    viewModel.paymentTermsKind == .custom
                        ? "Descripción obligatoria"
                        : "Etiqueta (opcional)",
                    text: $viewModel.paymentTermsLabel
                )
            }

            TextField("Notas de pago (opcional)", text: $viewModel.paymentTermsNotes, axis: .vertical)
                .lineLimit(1...3)

            LabeledContent("Moneda", value: "USD")
        }
    }

    private var supplierContactsSection: some View {
        Section {
            ForEach($viewModel.contacts) { $contact in
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Nombre", text: $contact.name)
                        .font(.headline)
                    TextField("Cargo (opcional)", text: $contact.role)
                    TextField("Correo (opcional)", text: $contact.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Teléfono (opcional)", text: $contact.phone)
                        .keyboardType(.phonePad)
                    TextField("Notas (opcional)", text: $contact.notes, axis: .vertical)
                        .lineLimit(1...3)
                    Toggle(
                        "Contacto principal",
                        isOn: Binding(
                            get: { contact.isPrimary },
                            set: { isPrimary in
                                viewModel.setPrimaryContact(contact.id, isPrimary: isPrimary)
                            }
                        )
                    )
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: viewModel.removeContacts)

            Button {
                viewModel.addContact()
            } label: {
                Label("Agregar persona de contacto", systemImage: "person.badge.plus")
            }
            .disabled(viewModel.isSaving)
        } header: {
            Text("Personas de contacto")
        } footer: {
            Text("Puedes marcar una sola persona como contacto principal.")
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
