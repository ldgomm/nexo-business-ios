//
//  BusinessSuppliersView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessSuppliersView: View {
    @Bindable private var viewModel: BusinessSuppliersViewModel
    @State private var isPresentingCreate = false
    private let branchId: String?
    private let activeModules: Set<ModuleCode>
    private let effectivePermissions: Set<String>

    init(
        viewModel: BusinessSuppliersViewModel,
        branchId: String? = nil,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>
    ) {
        self.viewModel = viewModel
        self.branchId = branchId
        self.activeModules = activeModules
        self.effectivePermissions = effectivePermissions
    }

    var body: some View {
        List {
            summarySection
            filtersSection
            messagesSection
            suppliersSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Proveedores")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Nombre, identificación o contacto"
        )
        .onSubmit(of: .search) {
            Task { await viewModel.search() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.canCreate {
                    Button {
                        isPresentingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Crear proveedor")
                }

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)
                .accessibilityLabel("Actualizar proveedores")
            }
        }
        .sheet(isPresented: $isPresentingCreate) {
            NavigationStack {
                BusinessSupplierFormView(
                    viewModel: BusinessSupplierFormViewModel(
                        organizationId: viewModel.organizationId,
                        activeModules: activeModules,
                        effectivePermissions: effectivePermissions,
                        repository: viewModel.repository
                    )
                ) { supplier in
                    viewModel.replace(supplier)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Directorio de compras", systemImage: "building.2.crop.circle")
                    .font(.headline)
                Text("Consulta proveedores reales, condiciones de pago y contactos. Los datos protegidos permanecen ocultos cuando el permiso sensible no está disponible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    BusinessSupplierMetric(
                        title: "Visibles",
                        value: String(viewModel.suppliers.count),
                        systemImage: "person.2"
                    )
                    BusinessSupplierMetric(
                        title: "Filtro",
                        value: viewModel.hasActiveFilters ? "Activo" : "Libre",
                        systemImage: viewModel.hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var filtersSection: some View {
        Section("Filtros") {
            Picker("Estado", selection: $viewModel.statusFilter) {
                ForEach(BusinessSuppliersViewModel.StatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.statusFilter) { _, _ in
                Task { await viewModel.search() }
            }

            TextField("Categoría", text: $viewModel.category)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            HStack {
                Button("Aplicar") {
                    Task { await viewModel.search() }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)

                Spacer()

                if viewModel.hasActiveFilters {
                    Button("Limpiar") {
                        Task { await viewModel.clearFilters() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Section {
                Label {
                    Text(errorMessage)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }

        if let infoMessage = viewModel.infoMessage {
            Section {
                Label(infoMessage, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var suppliersSection: some View {
        Section("Resultados") {
            if viewModel.isLoading && viewModel.suppliers.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando proveedores…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.suppliers.isEmpty {
                ContentUnavailableView(
                    "Sin proveedores",
                    systemImage: "building.2.crop.circle",
                    description: Text("Prueba otros filtros o confirma que tu usuario tenga acceso al módulo Compras.")
                )
            } else {
                ForEach(viewModel.suppliers) { supplier in
                    NavigationLink {
                        BusinessSupplierDetailView(
                            viewModel: BusinessSupplierDetailViewModel(
                                organizationId: viewModel.organizationId,
                                activeModules: activeModules,
                                effectivePermissions: effectivePermissions,
                                supplier: supplier,
                                repository: viewModel.repository
                            ),
                            branchId: branchId,
                            onSupplierChanged: { updated in
                                viewModel.replace(updated)
                            }
                        )
                    } label: {
                        BusinessSupplierRow(supplier: supplier)
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadNextPageIfNeeded(currentSupplier: supplier)
                        }
                    }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Cargando más…")
                            .font(.footnote)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct BusinessSupplierDetailView: View {
    @State private var viewModel: BusinessSupplierDetailViewModel
    @State private var isPresentingEdit = false
    private let branchId: String?
    private let onSupplierChanged: (BusinessProcurementSupplierResponse) -> Void

    init(
        viewModel: BusinessSupplierDetailViewModel,
        branchId: String? = nil,
        onSupplierChanged: @escaping (BusinessProcurementSupplierResponse) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.branchId = branchId
        self.onSupplierChanged = onSupplierChanged
    }

    var body: some View {
        List {
            identitySection
            contactSection
            termsSection
            supplierFinanceSection
            categoriesSection
            supplierContactsSection
            notesSection

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label {
                        Text(errorMessage)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.supplier.businessDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.canEdit {
                    Button("Editar") {
                        isPresentingEdit = true
                    }
                    .disabled(viewModel.isLoading)
                }

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)
                .accessibilityLabel("Actualizar proveedor")
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            NavigationStack {
                BusinessSupplierFormView(
                    viewModel: BusinessSupplierFormViewModel(
                        organizationId: viewModel.organizationId,
                        activeModules: viewModel.accessPolicy.activeModules,
                        effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                        supplier: viewModel.supplier,
                        repository: viewModel.repository
                    )
                ) { supplier in
                    viewModel.replace(supplier)
                    onSupplierChanged(supplier)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var identitySection: some View {
        Section("Identidad") {
            LabeledContent("Nombre") {
                Text(viewModel.supplier.businessDisplayName)
                    .multilineTextAlignment(.trailing)
            }

            if let legalName = viewModel.supplier.businessLegalNameDetail {
                LabeledContent("Razón social") {
                    Text(legalName)
                        .multilineTextAlignment(.trailing)
                }
            }

            LabeledContent("Estado") {
                BusinessSupplierStatusBadge(status: viewModel.supplier.status)
            }

            LabeledContent("Identificación") {
                Text(viewModel.supplier.businessIdentificationText ?? "Protegida o no registrada")
                    .foregroundStyle(
                        viewModel.supplier.businessIdentificationText == nil
                            ? Color.secondary
                            : Color.primary
                    )
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var contactSection: some View {
        Section("Contacto general") {
            BusinessSupplierOptionalValueRow(title: "Correo", value: viewModel.supplier.email)
            BusinessSupplierOptionalValueRow(title: "Teléfono", value: viewModel.supplier.phone)
            BusinessSupplierOptionalValueRow(title: "Dirección", value: viewModel.supplier.address)

            if viewModel.supplier.email == nil,
               viewModel.supplier.phone == nil,
               viewModel.supplier.address == nil {
                Text("Protegido por permisos o todavía no registrado.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var termsSection: some View {
        Section("Condiciones comerciales") {
            LabeledContent("Pago", value: viewModel.supplier.paymentTerms.businessDisplayText)
            LabeledContent("Moneda", value: viewModel.supplier.defaultCurrency)
        }
    }

    @ViewBuilder
    private var supplierFinanceSection: some View {
        if viewModel.accessPolicy.allows(
            BusinessProcurementPermission.supplierStatementsView
        ) {
            Section("Finanzas del proveedor") {
                NavigationLink {
                    BusinessSupplierStatementView(
                        viewModel: BusinessSupplierStatementViewModel(
                            organizationId: viewModel.organizationId,
                            branchId: branchId,
                            supplierId: viewModel.supplier.id,
                            supplierName: viewModel.supplier.businessDisplayName,
                            currency: viewModel.supplier.defaultCurrency,
                            activeModules: viewModel.accessPolicy.activeModules,
                            effectivePermissions: viewModel.accessPolicy.effectivePermissions,
                            repository: viewModel.repository
                        )
                    )
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Estado de cuenta")
                                .font(.headline)
                            Text("Cargos, abonos, saldos y evidencia de origen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundStyle(.indigo)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var categoriesSection: some View {
        if !viewModel.supplier.categories.isEmpty {
            Section("Categorías") {
                Text(viewModel.supplier.categories.joined(separator: " · "))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var supplierContactsSection: some View {
        if let contacts = viewModel.supplier.contacts {
            Section("Personas de contacto") {
                if contacts.isEmpty {
                    Text("Sin contactos registrados.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(contacts) { contact in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(contact.name)
                                    .font(.headline)
                                if contact.isPrimary {
                                    Text("Principal")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.blue)
                                }
                            }
                            if let role = contact.role, !role.isEmpty {
                                Text(role)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let email = contact.email, !email.isEmpty {
                                Label(email, systemImage: "envelope")
                                    .font(.footnote)
                            }
                            if let phone = contact.phone, !phone.isEmpty {
                                Label(phone, systemImage: "phone")
                                    .font(.footnote)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        } else {
            Section("Personas de contacto") {
                Text("Protegido por permisos.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = viewModel.supplier.notes, !notes.isEmpty {
            Section("Notas") {
                Text(notes)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BusinessSupplierRow: View {
    let supplier: BusinessProcurementSupplierResponse

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                Text(supplier.businessDisplayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let legalName = supplier.businessLegalNameDetail {
                    Text(legalName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(supplier.businessIdentificationText ?? supplier.paymentTerms.businessDisplayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            BusinessSupplierStatusBadge(status: supplier.status)
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessSupplierStatusBadge: View {
    let status: BusinessSupplierStatus

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var title: String {
        switch status {
        case .active: return "ACTIVO"
        case .inactive: return "INACTIVO"
        case .blocked: return "BLOQUEADO"
        }
    }

    private var tint: Color {
        switch status {
        case .active: return .green
        case .inactive: return .secondary
        case .blocked: return .red
        }
    }
}

private struct BusinessSupplierOptionalValueRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            LabeledContent(title) {
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct BusinessSupplierMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
