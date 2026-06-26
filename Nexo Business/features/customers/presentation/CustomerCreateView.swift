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
        ScrollView {
            LazyVStack(spacing: 12) {
                heroSection
                identificationSection
                dataSection

                duplicateSection

                messagesSection
                actionSection
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .nexoKeyboardDismissable()
        .navigationTitle("Nuevo cliente")
        .navigationBarTitleDisplayMode(.large)
    }

    private var heroSection: some View {
        CustomerExecutiveCard(
            title: "Crear cliente",
            subtitle: "Registra datos limpios para ventas identificadas, crédito, proformas y comprobantes.",
            systemImage: "person.badge.plus",
            isHero: true,
            usesGradient: true
        ) {
            HStack(spacing: 8) {
                CustomerExecutivePill(
                    title: "Cliente real",
                    systemImage: "checkmark.shield",
                    tint: .accentColor
                )

                CustomerExecutivePill(
                    title: viewModel.identificationType.displayName,
                    systemImage: "number",
                    tint: .secondary
                )
            }
        }
    }

    private var identificationSection: some View {
        CustomerExecutiveCard(
            title: "Identificación",
            subtitle: "Base fiscal y comercial del cliente.",
            systemImage: "number.square"
        ) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tipo de identificación", systemImage: "person.text.rectangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Tipo", selection: $viewModel.identificationType) {
                        ForEach(BusinessCustomerIdentificationType.allCases.filter { $0 != .finalConsumer }) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                CustomerTextInputRow(
                    title: "Número",
                    placeholder: "Cédula, RUC o pasaporte",
                    text: $viewModel.identificationNumber,
                    systemImage: "number",
                    keyboardType: .numbersAndPunctuation,
                    autocapitalization: .characters
                )
            }
        }
    }

    private var dataSection: some View {
        CustomerExecutiveCard(
            title: "Datos del cliente",
            subtitle: "Información visible para búsqueda, cobro y seguimiento.",
            systemImage: "person.crop.rectangle.stack"
        ) {
            VStack(spacing: 10) {
                CustomerTextInputRow(
                    title: "Nombre",
                    placeholder: "Nombre o razón social",
                    text: $viewModel.displayName,
                    systemImage: "person",
                    keyboardType: .default,
                    autocapitalization: .words
                )

                CustomerTextInputRow(
                    title: "Correo",
                    placeholder: "Opcional",
                    text: $viewModel.email,
                    systemImage: "envelope",
                    keyboardType: .emailAddress,
                    autocapitalization: .never,
                    disablesAutocorrection: true
                )

                CustomerTextInputRow(
                    title: "Teléfono",
                    placeholder: "Opcional",
                    text: $viewModel.phone,
                    systemImage: "phone",
                    keyboardType: .phonePad,
                    autocapitalization: .never
                )

                CustomerMultilineInputRow(
                    title: "Dirección",
                    placeholder: "Opcional",
                    text: $viewModel.address,
                    systemImage: "mappin.and.ellipse"
                )
            }
        }
    }

    @ViewBuilder
    private var duplicateSection: some View {
        if let duplicate = viewModel.duplicateCandidate {
            CustomerExecutiveCard(
                title: "Posible duplicado",
                subtitle: "Revisa antes de crear otro registro del mismo cliente.",
                systemImage: "person.crop.circle.badge.exclamationmark"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    CustomerExecutiveNoticeCard(
                        title: duplicate.title,
                        message: duplicate.message,
                        systemImage: "exclamationmark.triangle",
                        tint: .orange
                    )

                    CustomerRowView(customer: duplicate.customer)

                    Button {
                        if let customer = viewModel.useDuplicateCandidate() {
                            onCreated(customer)
                            dismiss()
                        }
                    } label: {
                        CustomerExecutiveActionRow(
                            title: "Usar cliente existente",
                            subtitle: "Evita duplicar ventas, deuda e historial",
                            systemImage: "person.text.rectangle",
                            tint: .accentColor,
                            showsAccessory: false
                        )
                    }
                    .buttonStyle(.plain)
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
                        CustomerExecutiveActionRow(
                            title: "Crear nuevo de todos modos",
                            subtitle: "Mantener registros separados bajo mi responsabilidad",
                            systemImage: "plus.circle",
                            tint: .orange,
                            showsAccessory: false
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            CustomerExecutiveNoticeCard(
                title: "No se pudo guardar",
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
        }

        if let message = viewModel.infoMessage {
            CustomerExecutiveNoticeCard(
                title: "Cliente listo",
                message: message,
                systemImage: "checkmark.circle",
                tint: .green
            )
        }
    }

    private var actionSection: some View {
        CustomerExecutiveCard(
            title: "Guardar registro",
            subtitle: "El cliente quedará disponible para ventas, proformas y cuentas por cobrar.",
            systemImage: "checkmark.seal"
        ) {
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
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Guardar cliente", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSave)
        }
    }
}

private struct CustomerTextInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String
    let keyboardType: UIKeyboardType
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disablesAutocorrection: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disablesAutocorrection)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CustomerMultilineInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(title)
                    .foregroundStyle(.secondary)
            }

            TextField(placeholder, text: $text, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
