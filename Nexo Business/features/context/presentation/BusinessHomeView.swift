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
                    Label("Más", systemImage: "building.2")
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
                        historyRepository: container.salesHistoryRepository,
                        documentsRepository: container.documentsRepository
                    ),
                    salesRepository: container.salesRepository,
                    salesHistoryRepository: container.salesHistoryRepository,
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
            ScrollView {
                LazyVStack(spacing: 14) {
                    operationHero
                    dailyOperationCard
                    toolsCard
                    contextCard
                    businessCard
                    diagnosticsCard
                    accountCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Más")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                commonToolbar
            }
        }
    }

    private var operationHero: some View {
        BusinessHomeHeroCard(
            organizationName: context.organization.commercialName,
            subtitle: "\(selectedBranchName) · \(selectedActivityName)",
            readiness: context.readiness.status,
            taxId: context.organization.taxId,
            countryCode: context.organization.countryCode,
            readinessTint: readinessTint
        )
    }

    @ViewBuilder
    private var dailyOperationCard: some View {
        BusinessHomeCard(
            title: "Operación diaria",
            subtitle: "Accesos rápidos para vender, cobrar, revisar caja, historial, comprobantes, inventario, reporte y exportación."
        ) {
            LazyVGrid(columns: toolColumns, spacing: 12) {
                if capabilityGate.canAccessSales {
                    NavigationLink {
                        makeSaleCartView()
                    } label: {
                        BusinessHomeToolTile(
                            title: "Venta rápida",
                            subtitle: "Crear y cobrar",
                            systemImage: "cart.badge.plus",
                            tint: .accentColor
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Venta rápida",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessCash {
                    NavigationLink {
                        makeCashDashboardView(refreshOnAppear: true)
                    } label: {
                        BusinessHomeToolTile(
                            title: "Caja",
                            subtitle: "Abrir, cerrar y revisar",
                            systemImage: "banknote",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Caja",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessHistory {
                    NavigationLink {
                        SalesHistoryView(
                            viewModel: SalesHistoryViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                revisions: revisions,
                                effectivePermissions: permissions,
                                historyRepository: container.salesHistoryRepository,
                                documentsRepository: container.documentsRepository
                            ),
                            salesRepository: container.salesRepository,
                            salesHistoryRepository: container.salesHistoryRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessHomeToolTile(
                            title: "Historial",
                            subtitle: "Ventas y cobros",
                            systemImage: "clock.arrow.circlepath",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Historial",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
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
                        BusinessHomeToolTile(
                            title: "Comprobantes",
                            subtitle: "RIDE y XML",
                            systemImage: "doc.text.magnifyingglass",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Comprobantes",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessInventory {
                    NavigationLink {
                        makeInventoryDashboardView()
                    } label: {
                        BusinessHomeToolTile(
                            title: "Inventario",
                            subtitle: "Stock físico",
                            systemImage: "shippingbox",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Inventario",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessToday {
                    NavigationLink {
                        makeDailyClosureView()
                    } label: {
                        BusinessHomeToolTile(
                            title: "Reporte de hoy",
                            subtitle: "Ventas, caja y alertas",
                            systemImage: "chart.bar.doc.horizontal",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Reporte de hoy",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if canAccessOperationalExports {
                    NavigationLink {
                        makeBusinessExportsView()
                    } label: {
                        BusinessHomeToolTile(
                            title: "Exportar",
                            subtitle: "ZIP operativo diario",
                            systemImage: "square.and.arrow.down",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Exportar",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }
                
                if canAccessOperationalExports {
                    NavigationLink {
                        BusinessAccountantPackSurfaceView(container: container)
                    } label: {
                        BusinessHomeToolTile(
                            title: "Paquete contador",
                            subtitle: "ZIP mensual",
                            systemImage: "doc.zipper",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Paquete contador",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }
            }

            BusinessHomeInlineMessage(
                message: "Proformas cotiza primero y convierte a venta solo cuando el cliente acepta. No cobra, no factura y no toca SRI desde esta superficie.",
                systemImage: "doc.badge.plus",
                tint: .secondary
            )

            BusinessHomeInlineMessage(
                message: "Exportación operativa para revisión diaria. No reemplaza al contador ni a obligaciones tributarias.",
                systemImage: "info.circle",
                tint: .secondary
            )
        }
    }

    @ViewBuilder
    private var toolsCard: some View {
        BusinessHomeCard(
            title: "Herramientas",
            subtitle: "Accesos del negocio según permisos y capacidades activas."
        ) {
            LazyVGrid(columns: toolColumns, spacing: 12) {
                if capabilityGate.canAccessCustomers {
                    NavigationLink {
                        CustomerDirectoryView(
                            viewModel: CustomerDirectoryViewModel(
                                organizationId: organizationId,
                                effectivePermissions: permissions,
                                customersRepository: container.customersRepository
                            ),
                            branchId: branchId,
                            revisions: context.revisions,
                            salesHistoryRepository: container.salesHistoryRepository,
                            salesRepository: container.salesRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessHomeToolTile(
                            title: "Clientes",
                            subtitle: "Directorio",
                            systemImage: "person.2",
                            tint: .accentColor
                        )
                    }
                    .buttonStyle(.plain)
                }

                if capabilityGate.canAccessSales {
                    NavigationLink {
                        ProductsListView(
                            viewModel: ProductsListViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                activityId: activityId,
                                catalogRevision: revisions.catalogRevision,
                                repository: container.productsRepository
                            )
                        )
                    } label: {
                        BusinessHomeToolTile(
                            title: "Productos",
                            subtitle: "Precios y venta",
                            systemImage: "shippingbox.fill",
                            tint: .teal
                        )
                    }
                    .buttonStyle(.plain)
                }

                if capabilityGate.canAccessSales {
                    NavigationLink {
                        makeBusinessProformasView()
                    } label: {
                        BusinessHomeToolTile(
                            title: "Proformas",
                            subtitle: "Cotizar y convertir",
                            systemImage: "doc.badge.plus",
                            tint: .indigo
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessHomeToolTile(
                        title: "Proformas",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessReceivables {
                    NavigationLink {
                        ReceivablesListView(
                            viewModel: ReceivablesListViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                effectivePermissions: permissions,
                                receivablesRepository: container.receivablesRepository,
                                customersRepository: container.customersRepository
                            ),
                            cashRepository: container.cashRepository,
                            receivablesRepository: container.receivablesRepository,
                            revisions: context.revisions,
                            salesHistoryRepository: container.salesHistoryRepository,
                            salesRepository: container.salesRepository,
                            paymentsRepository: container.paymentsRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessHomeToolTile(
                            title: "Por cobrar",
                            subtitle: "Deudas reales",
                            systemImage: "person.crop.circle.badge.clock",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                }

                if capabilityGate.canAccessHistory {
                    NavigationLink {
                        UnpaidSalesListView(
                            viewModel: UnpaidSalesListViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                revisions: revisions,
                                effectivePermissions: permissions,
                                pendingRepository: container.pendingOperationsRepository
                            ),
                            salesRepository: container.salesRepository,
                            salesHistoryRepository: container.salesHistoryRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessHomeToolTile(
                            title: "Ventas sin cobrar",
                            subtitle: "Guardadas",
                            systemImage: "bookmark",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
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
                        BusinessHomeToolTile(
                            title: "Comprobantes",
                            subtitle: "RIDE y XML",
                            systemImage: "doc.text.magnifyingglass",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                }

                if canAccessTeamManagement {
                    NavigationLink {
                        BusinessTeamView(
                            viewModel: BusinessTeamViewModel(
                                repository: container.teamRepository,
                                effectivePermissions: permissions
                            )
                        )
                    } label: {
                        BusinessHomeToolTile(
                            title: "Equipo",
                            subtitle: "Roles y usuarios",
                            systemImage: "person.3.sequence",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
            }        }
    }

    private var contextCard: some View {
        BusinessHomeCard(
            title: "Contexto operativo",
            subtitle: "La venta, caja e historial trabajan con esta sucursal y actividad."
        ) {
            VStack(spacing: 10) {
                BusinessHomeMetaRow(title: "Sucursal", value: selectedBranchName)
                BusinessHomeMetaRow(title: "Actividad", value: selectedActivityName)
                BusinessHomeMetaRow(title: "Catálogo", value: revisions.catalogRevision, isMonospaced: true)
                BusinessHomeMetaRow(title: "Impuestos", value: revisions.taxConfigurationRevision, isMonospaced: true)

                Button {
                    onChangeOperation()
                } label: {
                    BusinessHomeActionLabel(
                        title: "Cambiar sucursal o actividad",
                        subtitle: "Ajusta el punto de operación actual",
                        systemImage: "slider.horizontal.3",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var businessCard: some View {
        BusinessHomeCard(
            title: "Negocio",
            subtitle: "Información visible del negocio seleccionado."
        ) {
            VStack(spacing: 10) {
                BusinessHomeMetaRow(title: "Nombre", value: context.organization.commercialName)
                BusinessHomeMetaRow(title: "RUC", value: context.organization.taxId, isMonospaced: true)
                BusinessHomeMetaRow(title: "País", value: context.organization.countryCode)
            }
        }
    }

    private var diagnosticsCard: some View {
        BusinessHomeCard(
            title: "Diagnóstico",
            subtitle: "Vista técnica ligera para saber qué está activo."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup {
                    VStack(spacing: 8) {
                        capabilityDiagnosticRow("Ventas", enabled: capabilityGate.canAccessSales)
                        capabilityDiagnosticRow("Hoy", enabled: capabilityGate.canAccessToday)
                        capabilityDiagnosticRow("Caja", enabled: capabilityGate.canAccessCash)
                        capabilityDiagnosticRow("Historial", enabled: capabilityGate.canAccessHistory)
                        capabilityDiagnosticRow("Ventas sin cobrar", enabled: capabilityGate.canAccessHistory)
                        capabilityDiagnosticRow("Clientes", enabled: capabilityGate.canAccessCustomers)
                        capabilityDiagnosticRow("Cuentas por cobrar", enabled: capabilityGate.canAccessReceivables)
                        capabilityDiagnosticRow("Inventario", enabled: capabilityGate.canAccessInventory)
                        capabilityDiagnosticRow("Exportaciones", enabled: canAccessOperationalExports)
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Capacidades de negocio", systemImage: "switch.2")
                        .font(.subheadline.weight(.semibold))
                }

                Divider()

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(context.activeModules.map(\.rawValue).sorted(), id: \.self) { module in
                            Text(module)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Módulos activos", systemImage: "square.grid.2x2")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var accountCard: some View {
        BusinessHomeCard(
            title: "Cuenta",
            subtitle: "Acciones de contexto y sesión."
        ) {
            VStack(spacing: 10) {
                Button {
                    onRefresh()
                } label: {
                    BusinessHomeActionLabel(
                        title: "Actualizar contexto",
                        subtitle: "Recarga permisos, módulos y revisiones",
                        systemImage: "arrow.clockwise",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onChangeOrganization()
                } label: {
                    BusinessHomeActionLabel(
                        title: "Cambiar negocio",
                        subtitle: "Selecciona otra organización disponible",
                        systemImage: "building.2",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AuthSessionsView(
                        viewModel: AuthSessionsViewModel(
                            authRepository: container.authRepository
                        ),
                        onAllSessionsRevoked: onLogout
                    )
                } label: {
                    BusinessHomeActionLabel(
                        title: "Mis sesiones",
                        subtitle: "Ver y revocar dispositivos activos",
                        systemImage: "iphone.and.arrow.forward",
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    onLogout()
                } label: {
                    BusinessHomeActionLabel(
                        title: "Cerrar sesión",
                        subtitle: "Salir de Nexo Business",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        tint: .red
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func makeSaleCartView() -> SaleCartView {
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
    }

    private func makeDailyClosureView() -> DailyClosureView {
        DailyClosureView(
            viewModel: DailyClosureViewModel(
                organizationId: organizationId,
                branchId: branchId,
                revisions: revisions,
                effectivePermissions: permissions,
                capabilities: context.capabilities,
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
    }

    private func makeCashDashboardView(refreshOnAppear: Bool = false) -> CashDashboardView {
        CashDashboardView(
            viewModel: CashDashboardViewModel(
                organizationId: organizationId,
                branchId: branchId,
                permissions: permissions,
                cashCapabilities: context.capabilities.cash,
                cashRepository: container.cashRepository
            ),
            refreshOnAppear: refreshOnAppear
        )
    }

    private func makeInventoryDashboardView() -> InventoryDashboardView {
        InventoryDashboardView(
            viewModel: InventoryDashboardViewModel(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: revisions.catalogRevision,
                effectivePermissions: permissions,
                inventoryRepository: container.inventoryRepository
            )
        )
    }

    private func makeBusinessExportsView() -> BusinessExportsView {
        BusinessExportsView(
            viewModel: BusinessExportsViewModel(
                organizationId: organizationId,
                branchId: branchId,
                effectivePermissions: permissions,
                exportsRepository: container.exportsRepository
            )
        )
    }


    private func makeBusinessProformasView() -> BusinessProformasView {
        BusinessProformasView(
            viewModel: BusinessProformasViewModel(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                revisions: revisions,
                effectivePermissions: permissions,
                repository: container.proformasRepository
            ),
            proformasRepository: container.proformasRepository,
            productsRepository: container.productsRepository,
            customersRepository: container.customersRepository,
            salesRepository: container.salesRepository,
            salesHistoryRepository: container.salesHistoryRepository,
            cashRepository: container.cashRepository,
            paymentsRepository: container.paymentsRepository,
            receivablesRepository: container.receivablesRepository,
            documentsRepository: container.documentsRepository
        )
    }

    private func capabilityDiagnosticRow(_ title: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.footnote)

            Spacer(minLength: 12)

            Label(enabled ? "Activo" : "No disponible", systemImage: enabled ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(enabled ? Color.green : Color.secondary)
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var toolColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var readinessTint: Color {
        switch context.readiness.status.lowercased() {
        case "ready", "ok", "active", "enabled":
            return .green
        case "warning", "partial", "pending":
            return .orange
        case "blocked", "error", "failed":
            return .red
        default:
            return .secondary
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


    private var canAccessOperationalExports: Bool {
        guard capabilityGate.canAccessToday || context.effectivePermissions.contains("*") else {
            return false
        }

        return permissionGate.allowsAny(Self.operationalExportPermissions) || context.effectivePermissions.contains("*")
    }

    private static let operationalExportPermissions = [
        "business.exports.view",
        "business.exports.generate",
        "business.exports.download",
        "exports.view",
        "exports.generate",
        "exports.download",
        "reports.export",
        "reports.dashboard.view",
        "reports.sales.view",
        "reports.cash.view",
        "reports.documents.view"
    ]

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
}

@MainActor
@Observable
private final class UnpaidSalesListViewModel {
    private(set) var sales: [BusinessSale] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let revisions: BusinessRevisions
    let effectivePermissions: Set<String>

    private let pendingRepository: PendingOperationsRepository
    private var lastLoadedAt: Date?

    init(
        organizationId: String,
        branchId: String,
        revisions: BusinessRevisions,
        effectivePermissions: Set<String>,
        pendingRepository: PendingOperationsRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.revisions = revisions
        self.effectivePermissions = effectivePermissions
        self.pendingRepository = pendingRepository
    }

    var canView: Bool {
        hasPermission([
            "business.sales.view",
            "sales.view",
            "business.sales.create",
            "sales.create"
        ])
    }

    func loadIfNeeded() async {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < 8, !sales.isEmpty {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard canView else {
            sales = []
            errorMessage = "No tienes permiso para consultar ventas sin cobrar."
            return
        }

        guard !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            sales = []
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
            lastLoadedAt = Date()
        }

        do {
            let response = try await pendingRepository.pendingSales(
                organizationId: organizationId,
                branchId: branchId,
                limit: 100
            )

            sales = response.sales
                .filter { $0.isSavedSaleWithoutReceivable }
                .sorted(by: sortSales)
            infoMessage = sales.isEmpty ? "No hay ventas guardadas o sin cobrar." : nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeSaleDetailViewModel(
        for sale: BusinessSale,
        salesRepository: SalesRepository
    ) -> SaleDetailViewModel {
        SaleDetailViewModel(
            organizationId: organizationId,
            saleId: sale.id,
            revisions: revisions,
            initialSale: sale,
            effectivePermissions: effectivePermissions,
            salesRepository: salesRepository
        )
    }

    private func sortSales(_ lhs: BusinessSale, _ rhs: BusinessSale) -> Bool {
        (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }
}

private struct UnpaidSalesListView: View {
    @Bindable private var viewModel: UnpaidSalesListViewModel
    private let salesRepository: SalesRepository
    private let salesHistoryRepository: SalesHistoryRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    init(
        viewModel: UnpaidSalesListViewModel,
        salesRepository: SalesRepository,
        salesHistoryRepository: SalesHistoryRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.salesRepository = salesRepository
        self.salesHistoryRepository = salesHistoryRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        Form {
            Section("Qué aparece aquí") {
                Label("Ventas guardadas o sin cobrar que todavía no son deuda formal.", systemImage: "bookmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Las cuentas por cobrar reales están separadas en Más → Por cobrar.", systemImage: "person.crop.circle.badge.clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Ventas sin cobrar") {
                if viewModel.isLoading && viewModel.sales.isEmpty {
                    ProgressView("Cargando ventas sin cobrar…")
                } else if viewModel.sales.isEmpty {
                    ContentUnavailableView(
                        "Sin ventas sin cobrar",
                        systemImage: "bookmark",
                        description: Text("Las ventas pausadas, guardadas o parcialmente cobradas sin cuenta por cobrar aparecerán aquí.")
                    )
                } else {
                    ForEach(viewModel.sales) { sale in
                        NavigationLink {
                            SaleDetailView(
                                viewModel: viewModel.makeSaleDetailViewModel(
                                    for: sale,
                                    salesRepository: salesRepository
                                ),
                                salesHistoryRepository: salesHistoryRepository,
                                cashRepository: cashRepository,
                                paymentsRepository: paymentsRepository,
                                receivablesRepository: receivablesRepository,
                                documentsRepository: documentsRepository
                            )
                        } label: {
                            UnpaidSaleRow(sale: sale)
                        }
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
        .navigationTitle("Ventas sin cobrar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }
}

private struct UnpaidSaleRow: View {
    let sale: BusinessSale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sale.displayNumber)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(sale.displayCustomerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(sale.totals.grandTotal.displayText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                BusinessHomePill(
                    title: sale.collectionState.shortName,
                    systemImage: sale.collectionState.systemImage,
                    tint: sale.collectionState == .partialWithoutReceivable ? .orange : .blue
                )

                if BusinessElectronicInvoiceCustomerPolicy.isFinalConsumer(sale: sale) {
                    BusinessHomePill(
                        title: "No es deuda",
                        systemImage: "checkmark.shield",
                        tint: .secondary
                    )
                }
            }

            if let createdAt = sale.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessHomeHeroCard: View {
    let organizationName: String
    let subtitle: String
    let readiness: String
    let taxId: String
    let countryCode: String
    let readinessTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                BusinessHomeIconBadge(systemImage: "building.2.crop.circle.fill", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Business")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(organizationName)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                BusinessHomePill(title: readiness, systemImage: "checkmark.seal", tint: readinessTint)
                BusinessHomePill(title: countryCode, systemImage: "globe.americas", tint: .accentColor)
            }

            HStack(spacing: 10) {
                Image(systemName: "number")
                    .foregroundStyle(Color.accentColor)

                Text("RUC")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(taxId)
                    .font(.caption.monospaced().weight(.semibold))
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color(.secondarySystemGroupedBackground)
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

private struct BusinessHomeCard<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

struct BusinessHomeToolTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessHomeIconBadge(systemImage: systemImage, tint: isDisabled ? .secondary : tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background((isDisabled ? Color.secondary : tint).opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BusinessHomeActionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            BusinessHomeIconBadge(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BusinessHomeMetaRow: View {
    let title: String
    let value: String
    var isMonospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(isMonospaced ? .caption.monospaced() : .footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessHomeInlineMessage: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BusinessHomePill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct BusinessHomeIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct LockedOperationalView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 84, height: 84)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
            .padding(16)
            .padding(.top, 36)
        }
        .background(Color(.systemGroupedBackground))
    }
}
