//
//  BusinessOrganizationSelectionView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct BusinessOrganizationSelectionView: View {
    private let organizations: [BusinessOrganizationAccess]
    private let selectAction: (BusinessOrganizationAccess) -> Void
    private let logoutAction: () -> Void

    init(
        organizations: [BusinessOrganizationAccess],
        selectAction: @escaping (BusinessOrganizationAccess) -> Void,
        logoutAction: @escaping () -> Void
    ) {
        self.organizations = organizations
        self.selectAction = selectAction
        self.logoutAction = logoutAction
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Elige el negocio con el que vas a operar hoy. Esta selección define permisos, sucursales, módulos y revisiones tributarias/catálogo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Negocios disponibles") {
                    ForEach(organizations) { organization in
                        Button {
                            selectAction(organization)
                        } label: {
                            OrganizationAccessRow(organization: organization)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Seleccionar negocio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        logoutAction()
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
}

private struct OrganizationAccessRow: View {
    let organization: BusinessOrganizationAccess

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "building.2")
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(organization.commercialName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let taxId = organization.taxId, !taxId.isEmpty {
                    Text("RUC: \(taxId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let roleName = organization.roleName, !roleName.isEmpty {
                    Text(roleName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    BusinessOrganizationSelectionView(
        organizations: PreviewData.organizations,
        selectAction: { _ in },
        logoutAction: {}
    )
}
