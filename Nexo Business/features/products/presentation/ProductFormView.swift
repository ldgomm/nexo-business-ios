//
//  ProductFormView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ProductFormView: View {
    @Bindable private var viewModel: ProductFormViewModel
    private let onSaved: (BusinessProduct) -> Void
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ProductFormViewModel, onSaved: @escaping (BusinessProduct) -> Void) {
        _viewModel = Bindable(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                messagesSection
                heroSection
                localConfigurationSection
                saleConfigurationSection
                saveGuideSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(viewModel.isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    NexoKeyboard.dismiss()
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

    @ViewBuilder
    private var messagesSection: some View {
        if let error = viewModel.errorMessage, !error.isEmpty {
            ProductFormCard {
                NexoMessageBanner(error, style: .error)
            }
        }
    }

    private var heroSection: some View {
        ProductFormHeroCard(
            title: heroTitle,
            subtitle: heroSubtitle,
            systemImage: heroIcon,
            tint: heroTint
        )
    }

    private var localConfigurationSection: some View {
        ProductFormCard(
            title: "Información local",
            subtitle: "Estos campos pertenecen al negocio. El catálogo maestro no se modifica desde Business."
        ) {
            VStack(spacing: 12) {
                ProductFormInputRow(
                    title: nameFieldTitle,
                    placeholder: viewModel.localNamePlaceholder,
                    text: $viewModel.name,
                    systemImage: "tag"
                )

                ProductFormInputRow(
                    title: "Código interno",
                    placeholder: "Opcional",
                    text: $viewModel.code,
                    systemImage: "barcode"
                )

                ProductFormMultilineInputRow(
                    title: "Descripción",
                    placeholder: "Opcional para notas internas o venta futura",
                    text: $viewModel.description,
                    systemImage: "text.alignleft"
                )
            }
        }
    }

    private var saleConfigurationSection: some View {
        ProductFormCard(
            title: "Venta y tributación",
            subtitle: "Precio y perfil tributario habilitado para esta organización. Nada de IVA hardcoded en la app."
        ) {
            VStack(spacing: 12) {
                ProductFormInputRow(
                    title: "Precio",
                    placeholder: "0.00",
                    text: $viewModel.price,
                    keyboardType: .decimalPad,
                    systemImage: "dollarsign.circle"
                )

                ProductReadonlyRow(
                    title: "Tipo",
                    value: typeLabel,
                    systemImage: viewModel.type.uppercased() == "SERVICE" ? "wrench.and.screwdriver" : "shippingbox"
                )

                if viewModel.taxProfiles.isEmpty {
                    ProductFormEmptyTaxCard()
                } else {
                    ProductTaxProfilePicker(
                        selectedCode: $viewModel.selectedTaxProfileCode,
                        profiles: viewModel.taxProfiles,
                        selectedProfile: viewModel.selectedTaxProfile
                    )
                }
            }
        }
    }
    
    private var saveGuideSection: some View {
        ProductFormCard {
            VStack(alignment: .leading, spacing: 12) {
                ProductFormChecklistRow(
                    title: "Copia local segura",
                    subtitle: "Nexo conserva la referencia al producto maestro y evita duplicados sin control.",
                    systemImage: "link.circle.fill",
                    tint: .accentColor
                )

                ProductFormChecklistRow(
                    title: "Editable por negocio",
                    subtitle: "Puedes cambiar precio, código, nombre local y perfil tributario permitido.",
                    systemImage: "slider.horizontal.3",
                    tint: .blue
                )

                Button {
                    NexoKeyboard.dismiss()
                    Task {
                        if let product = await viewModel.save() {
                            onSaved(product)
                            dismiss()
                        }
                    }
                } label: {
                    ProductFormSaveLabel(isSaving: viewModel.isSaving)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
        }
    }

    private var heroTitle: String {
        switch viewModel.mode {
        case .adopt(let master):
            return master.name
        case .edit(let product):
            return product.name
        }
    }

    private var heroSubtitle: String {
        switch viewModel.mode {
        case .adopt:
            return "Configura cómo este negocio venderá el producto seleccionado del catálogo maestro."
        case .edit:
            return "Edita únicamente datos locales del negocio. La referencia maestra se mantiene intacta."
        }
    }

    private var heroIcon: String {
        switch viewModel.mode {
        case .adopt: return "plus.circle.fill"
        case .edit: return "pencil.circle.fill"
        }
    }

    private var heroTint: Color {
        switch viewModel.mode {
        case .adopt: return .accentColor
        case .edit: return .blue
        }
    }

    private var nameFieldTitle: String {
        switch viewModel.mode {
        case .adopt: return "Nombre local"
        case .edit: return "Nombre"
        }
    }


    private var retailServiceCategories: [(String, String)] {
        [
            ("", "Uncategorized"),
            ("retail_products", "Retail products"),
            ("accessories", "Accessories"),
            ("spare_parts", "Spare parts"),
            ("labor", "Labor / service"),
            ("supplies", "Supplies"),
            ("warranty", "Warranty"),
            ("other", "Other")
        ]
    }

    private var restaurantPreparationAreas: [(String, String)] {
        [
            ("", "Sin área"),
            ("kitchen", "Cocina"),
            ("grill", "Parrilla"),
            ("bar", "Bar"),
            ("counter", "Mostrador"),
            ("none", "Ninguna")
        ]
    }

    private var restaurantAvailabilityOptions: [(String, String)] {
        [
            ("AVAILABLE", "Disponible"),
            ("TEMPORARILY_UNAVAILABLE", "No disponible temporalmente"),
            ("HIDDEN", "Oculto del menú")
        ]
    }

    private var typeLabel: String {
        switch viewModel.type.uppercased() {
        case "SERVICE": return "Servicio"
        case "PACKAGE": return "Paquete"
        default: return "Producto"
        }
    }
}

private struct ProductFormHeroCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ProductFormIconBadge(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 5) {
                    Text("CONFIGURACIÓN LOCAL")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(title)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.16),
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

private struct ProductFormCard<Content: View>: View {
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

private struct ProductFormInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.sentences)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProductFormMultilineInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.sentences)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProductReadonlyRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProductTaxProfilePicker: View {
    @Binding var selectedCode: String
    let profiles: [BusinessTaxProfile]
    let selectedProfile: BusinessTaxProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "percent")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Picker("Perfil tributario", selection: $selectedCode) {
                    ForEach(profiles) { profile in
                        Text(profile.pickerTitle).tag(profile.code)
                    }
                }
            }

            if let selectedProfile {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)

                    Text(selectedProfile.helpText?.nilIfEmptyForProductFormUI ?? selectedProfile.pickerTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}


private struct ProductFormPickerRow: View {
    let title: String
    let systemImage: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProductFormToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let systemImage: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProductFormEmptyTaxCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sin perfiles tributarios", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("No hay perfiles habilitados para productos en esta organización. Revisa configuración tributaria antes de agregar al catálogo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProductFormChecklistRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ProductFormSaveLabel: View {
    let isSaving: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
            }
            Text("Guardar producto")
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
    }
}

private struct ProductFormIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension String {
    var nilIfEmptyForProductFormUI: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
