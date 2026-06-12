//
//  BusinessHomeView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct BusinessHomeView: View {
    private let context: BusinessContextResponse
    private let operationalSelection: BusinessOperationalSelection
    private let container: BusinessAppContainer
    private let onRefresh: () -> Void
    private let onChangeOrganization: () -> Void
    private let onChangeOperation: () -> Void
    private let onLogout: () -> Void
    
    init(
        context: BusinessContextResponse,
        operationalSelection: BusinessOperationalSelection,
        container: BusinessAppContainer,
        onRefresh: @escaping () -> Void = {},
        onChangeOrganization: @escaping () -> Void = {},
        onChangeOperation: @escaping () -> Void = {},
        onLogout: @escaping () -> Void = {}
    ) {
        self.context = context
        self.operationalSelection = operationalSelection
        self.container = container
        self.onRefresh = onRefresh
        self.onChangeOrganization = onChangeOrganization
        self.onChangeOperation = onChangeOperation
        self.onLogout = onLogout
    }
    
    var body: some View {
        TabView {
            sellTab
                .tabItem {
                    Label("Vender", systemImage: "cart.badge.plus")
                }
            
            todayTab
                .tabItem {
                    Label("Hoy", systemImage: "chart.bar.doc.horizontal")
                }
            
            cashTab
                .tabItem {
                    Label("Caja", systemImage: "banknote")
                }
            
            historyTab
                .tabItem {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }
            
            moreTab
                .tabItem {
                    Label("Más", systemImage: "ellipsis.circle")
                }
        }
    }
    
    private var sellTab: some View {
        NavigationStack {
            if capabilityGate.canAccessSales {
                SaleCartView(
                    viewModel: SaleCartViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        activityId: activityId,
                        revisions: revisions,
                        effectivePermissions: permissions,
                        catalogRepository: container.catalogRepository,
                        salesRepository: container.salesRepository,
                        contextRepository: container.contextRepository
                    ),
                    customersRepository: container.customersRepository,
                    cashRepository: container.cashRepository,
                    paymentsRepository: container.paymentsRepository,
                    receivablesRepository: container.receivablesRepository,
                    documentsRepository: container.documentsRepository
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Ventas no habilitadas",
                    message: "Tu usuario no tiene permiso para crear ventas en este contexto.",
                    systemImage: "lock"
                )
                .navigationTitle("Vender")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }
    
    private var todayTab: some View {
        NavigationStack {
            if capabilityGate.canAccessToday {
                DailyClosureView(
                    viewModel: DailyClosureViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        revisions: revisions,
                        effectivePermissions: permissions,
                        pendingRepository: container.pendingOperationsRepository,
                        dailyReportRepository: container.dailyReportRepository,
                        cashRepository: container.cashRepository,
                        historyRepository: container.salesHistoryRepository
                    ),
                    salesRepository: container.salesRepository,
                    cashRepository: container.cashRepository,
                    paymentsRepository: container.paymentsRepository,
                    receivablesRepository: container.receivablesRepository,
                    documentsRepository: container.documentsRepository
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Hoy no habilitado",
                    message: "Tu usuario no tiene permiso para consultar ventas del día, pendientes o cierre diario.",
                    systemImage: "chart.bar.doc.horizontal"
                )
                .navigationTitle("Hoy")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }
    
    private var cashTab: some View {
        NavigationStack {
            if capabilityGate.canAccessCash {
                CashDashboardView(
                    viewModel: CashDashboardViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        permissions: permissions,
                        cashCapabilities: context.capabilities.cash,
                        cashRepository: container.cashRepository
                    )
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Caja no habilitada",
                    message: "Tu usuario no tiene permiso para abrir, consultar o cerrar caja.",
                    systemImage: "banknote"
                )
                .navigationTitle("Caja")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }
    
    private var historyTab: some View {
        NavigationStack {
            if capabilityGate.canAccessHistory {
                SalesHistoryView(
                    viewModel: SalesHistoryViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        revisions: revisions,
                        effectivePermissions: permissions,
                        historyRepository: container.salesHistoryRepository
                    ),
                    salesRepository: container.salesRepository,
                    cashRepository: container.cashRepository,
                    paymentsRepository: container.paymentsRepository,
                    receivablesRepository: container.receivablesRepository,
                    documentsRepository: container.documentsRepository
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Historial no habilitado",
                    message: "Tu usuario no tiene permiso para consultar ventas anteriores.",
                    systemImage: "clock.arrow.circlepath"
                )
                .navigationTitle("Historial")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }
    
    private var moreTab: some View {
        NavigationStack {
            List {
                operationSummarySection
                businessSection
                toolsSection
                contextSection
                modulesSection
                accountSection
            }
            .navigationTitle("Más")
            .toolbar {
                commonToolbar
            }
        }
    }
    
    private var operationSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(context.organization.commercialName)
                    .font(.headline)
                
                Text("\(selectedBranchName) · \(selectedActivityName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    NexoStatusBadge(context.readiness.status, systemImage: "checkmark.seal", style: context.readiness.status.lowercased() == "ready" ? .success : .warning)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var businessSection: some View {
        Section("Negocio") {
            LabeledContent("Nombre", value: context.organization.commercialName)
            LabeledContent("RUC", value: context.organization.taxId)
            LabeledContent("País", value: context.organization.countryCode)
        }
    }
    
    @ViewBuilder
    private var toolsSection: some View {
        Section("Herramientas") {
            if capabilityGate.canAccessCustomers {
                NavigationLink {
                    CustomerDirectoryView(
                        viewModel: CustomerDirectoryViewModel(
                            organizationId: organizationId,
                            effectivePermissions: permissions,
                            customersRepository: container.customersRepository
                        )
                    )
                } label: {
                    Label("Clientes", systemImage: "person.2")
                }
            }
            
            if canAccessElectronicDocumentVault {
                NavigationLink {
                    BusinessElectronicDocumentsListView(
                        viewModel: BusinessElectronicDocumentsViewModel(
                            organizationId: organizationId,
                            effectivePermissions: permissions,
                            documentsRepository: container.documentsRepository
                        ),
                        documentsRepository: container.documentsRepository
                    )
                } label: {
                    Label("Comprobantes electrónicos", systemImage: "doc.text.magnifyingglass")
                }
            }
            
            if canAccessTeamManagement {
                NavigationLink {
                    BusinessTeamView(
                        viewModel: BusinessTeamViewModel(repository: container.teamRepository)
                    )
                } label: {
                    Label("Equipo y roles", systemImage: "person.3.sequence")
                }
            }
            
            if capabilityGate.canAccessInventory {
                Label("Inventario no disponible en staging", systemImage: "shippingbox")
                    .foregroundStyle(.secondary)
                
                Text("El backend responde 404 en /api/v1/business/inventory/items. Lo oculto como acción navegable para evitar una pantalla rota hasta implementar o desplegar ese endpoint.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var contextSection: some View {
        Section("Contexto operativo") {
            LabeledContent("Sucursal", value: selectedBranchName)
            LabeledContent("Actividad", value: selectedActivityName)
            LabeledContent("Catálogo", value: revisions.catalogRevision)
            LabeledContent("Impuestos", value: revisions.taxConfigurationRevision)
            
            Button {
                onChangeOperation()
            } label: {
                Label("Cambiar sucursal o actividad", systemImage: "slider.horizontal.3")
            }
        }
    }
    
    private var modulesSection: some View {
        Section("Diagnóstico técnico") {
            DisclosureGroup("Capacidades de negocio") {
                capabilityDiagnosticRow("Ventas", enabled: capabilityGate.canAccessSales)
                capabilityDiagnosticRow("Hoy", enabled: capabilityGate.canAccessToday)
                capabilityDiagnosticRow("Caja", enabled: capabilityGate.canAccessCash)
                capabilityDiagnosticRow("Historial", enabled: capabilityGate.canAccessHistory)
                capabilityDiagnosticRow("Clientes", enabled: capabilityGate.canAccessCustomers)
                capabilityDiagnosticRow("Inventario", enabled: capabilityGate.canAccessInventory)
            }
            
            DisclosureGroup("Módulos activos") {
                ForEach(context.activeModules.map(\.rawValue).sorted(), id: \.self) { module in
                    Text(module)
                        .font(.footnote.monospaced())
                }
            }
        }
    }
    
    private func capabilityDiagnosticRow(_ title: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(enabled ? Color.green : Color.secondary)
        }
        .font(.footnote)
    }
    
    private var accountSection: some View {
        Section("Cuenta") {
            Button {
                onRefresh()
            } label: {
                Label("Actualizar contexto", systemImage: "arrow.clockwise")
            }
            
            Button {
                onChangeOrganization()
            } label: {
                Label("Cambiar negocio", systemImage: "building.2")
            }
            
            Button(role: .destructive) {
                onLogout()
            } label: {
                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }
    
    @ToolbarContentBuilder
    private var commonToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    onRefresh()
                } label: {
                    Label("Actualizar contexto", systemImage: "arrow.clockwise")
                }
                
                Button {
                    onChangeOperation()
                } label: {
                    Label("Cambiar sucursal/actividad", systemImage: "slider.horizontal.3")
                }
                
                Button {
                    onChangeOrganization()
                } label: {
                    Label("Cambiar negocio", systemImage: "building.2")
                }
                
                Button(role: .destructive) {
                    onLogout()
                } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    private var capabilityGate: BusinessCapabilityGate {
        BusinessCapabilityGate(capabilities: context.capabilities)
    }
    
    private var moduleGate: ModuleGate {
        ModuleGate(activeModules: context.activeModules)
    }
    
    private var permissionGate: PermissionGate {
        PermissionGate(effectivePermissions: context.effectivePermissions)
    }
    
    private var canAccessTeamManagement: Bool {
        permissionGate.allows("credentials.users.view") ||
        permissionGate.allows("credentials.roles.view") ||
        permissionGate.allows("credentials.users.create") ||
        permissionGate.allows("credentials.roles.manage")
    }
    
    private var canAccessElectronicDocumentVault: Bool {
        permissionGate.allows("documents.electronic_invoice.list") ||
        permissionGate.allows("documents.electronic_invoice.view") ||
        permissionGate.allows("documents.electronic_invoice.download_ride") ||
        permissionGate.allows("documents.electronic_invoice.download_xml") ||
        permissionGate.allows("documents.electronic_invoice.email") ||
        permissionGate.allows("documents.view") ||
        permissionGate.allows("business.documents.view")
    }
    
    private var organizationId: String {
        context.organization.id
    }
    
    private var branchId: String {
        operationalSelection.branchId
    }
    
    private var activityId: String {
        operationalSelection.activityId
    }
    
    private var revisions: BusinessRevisions {
        context.revisions
    }
    
    private var permissions: Set<String> {
        context.effectivePermissions
    }
    
    private var selectedBranchName: String {
        context.branches.first(where: { $0.id == operationalSelection.branchId })?.name
        ?? operationalSelection.branchId
    }
    
    private var selectedActivityName: String {
        context.activities.first(where: { $0.id == operationalSelection.activityId })?.name
        ?? operationalSelection.activityId
    }
    
    private func hasSalesAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.sales.create") ||
        permissionGate.allows("sales.create") ||
        permissionGate.allows("business.sales.preview") ||
        permissionGate.allows("sales.preview")
    }
    
    private func hasCashAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("cash.view_current") ||
        permissionGate.allows("business.cash.view_current") ||
        permissionGate.allows("cash.open") ||
        permissionGate.allows("business.cash.open") ||
        permissionGate.allows("cash.close") ||
        permissionGate.allows("business.cash.close")
    }
    
    private func hasCustomerAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.customers.view") ||
        permissionGate.allows("customers.view") ||
        permissionGate.allows("business.customers.create") ||
        permissionGate.allows("customers.create")
    }
    
    private func hasPendingAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.pending.view") ||
        permissionGate.allows("pending.view") ||
        permissionGate.allows("business.reports.today") ||
        permissionGate.allows("reports.today") ||
        permissionGate.allows("business.reports.daily") ||
        permissionGate.allows("reports.daily")
    }
    
    private func hasHistoryAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.sales.view") ||
        permissionGate.allows("sales.view") ||
        permissionGate.allows("business.sales.history") ||
        permissionGate.allows("sales.history")
    }
    
    private func hasInventoryAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.inventory.view") ||
        permissionGate.allows("inventory.view") ||
        permissionGate.allows("business.inventory.adjust") ||
        permissionGate.allows("inventory.adjust")
    }
}

private struct LockedOperationalView: View {
    let title: String
    let message: String
    let systemImage: String
    
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}
