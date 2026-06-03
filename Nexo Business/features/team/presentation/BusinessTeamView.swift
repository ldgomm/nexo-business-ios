import SwiftUI

struct BusinessTeamView: View {
    @State var viewModel: BusinessTeamViewModel
    @State private var showingCreateUser = false
    @State private var selectedFilter: BusinessTeamFilter = .all

    var body: some View {
        List {
            temporaryPasswordSection
            messageSection
            content
        }
        .navigationTitle("Equipo")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingCreateUser = true
                    } label: {
                        Label("Crear usuario", systemImage: "person.badge.plus")
                    }

                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Label("Actualizar equipo", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.state == .loading || viewModel.isMutating)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .searchable(text: $viewModel.query, prompt: "Buscar usuario")
        .task { await viewModel.load() }
        .onSubmit(of: .search) {
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $showingCreateUser) {
            NavigationStack {
                BusinessTeamCreateUserView(
                    viewModel: viewModel,
                    onDone: { showingCreateUser = false }
                )
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var temporaryPasswordSection: some View {
        if let password = viewModel.lastTemporaryPassword {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contraseña temporal")
                                .font(.headline)

                            Text("Cópiala antes de salir de esta pantalla.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Text(password)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Entrégala únicamente al usuario correspondiente. El sistema no debería mostrarla nuevamente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let message = viewModel.infoMessage, !message.isEmpty {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando equipo…")
                        .foregroundStyle(.secondary)
                }
            }

        case .empty:
            emptyTeamSection

        case .failed(let message):
            Section {
                ContentUnavailableView(
                    "No se pudo cargar",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }

        case .loaded:
            heroSection
            filterSection
            usersSection
            discountRolesSection
            rolesSection
        }
    }

    private var emptyTeamSection: some View {
        Section {
            ContentUnavailableView {
                Label("Sin usuarios", systemImage: "person.2.slash")
            } description: {
                Text("Crea usuarios para operar ventas, caja, clientes, reportes y permisos del negocio.")
            } actions: {
                Button {
                    showingCreateUser = true
                } label: {
                    Label("Crear primer usuario", systemImage: "person.badge.plus")
                }
            }
        }
    }

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Administra tu equipo")
                            .font(.headline)

                        Text("Crea usuarios, asigna roles, controla descuentos y revoca sesiones cuando cambien permisos.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    BusinessTeamMetricCard(
                        title: "Usuarios",
                        value: "\(viewModel.users.count)",
                        systemImage: "person.2.fill",
                        style: .normal
                    )

                    BusinessTeamMetricCard(
                        title: "Activos",
                        value: "\(activeUsersCount)",
                        systemImage: "checkmark.circle.fill",
                        style: .success
                    )

                    BusinessTeamMetricCard(
                        title: "Descuentos",
                        value: "\(discountUsersCount)",
                        systemImage: "percent",
                        style: .warning
                    )
                }

                Button {
                    showingCreateUser = true
                } label: {
                    Label("Crear usuario", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isMutating)
            }
            .padding(.vertical, 6)
        }
    }

    private var filterSection: some View {
        Section {
            Picker("Filtro", selection: $selectedFilter) {
                ForEach(BusinessTeamFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(selectedFilter.footer)
        }
    }

    @ViewBuilder
    private var usersSection: some View {
        Section {
            if filteredUsers.isEmpty {
                ContentUnavailableView(
                    "Sin resultados",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("No hay usuarios para este filtro.")
                )
            } else {
                ForEach(filteredUsers) { user in
                    NavigationLink {
                        BusinessTeamUserDetailView(
                            userId: user.id,
                            viewModel: viewModel
                        )
                    } label: {
                        BusinessTeamUserRow(
                            user: user,
                            discountEnabled: viewModel.userHasDiscountAccess(user),
                            branchName: viewModel.branchName(for: user)
                        )
                    }
                }
            }
        } header: {
            Text("Usuarios")
        } footer: {
            Text("Toca un usuario para editar sus roles, quitar permisos sensibles o revocar sesiones.")
        }
    }

    @ViewBuilder
    private var discountRolesSection: some View {
        Section {
            if viewModel.discountRoles.isEmpty {
                Label("No hay un rol asignable con permisos de descuento.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                ForEach(viewModel.discountRoles) { role in
                    RoleCompactRow(
                        role: role,
                        subtitle: "Otorga permisos para aplicar o quitar descuentos en ventas.",
                        isDiscountRole: true
                    )
                }
            }
        } header: {
            Text("Acceso a descuentos")
        } footer: {
            Text("Para quitar descuentos a un operador: entra al usuario, toca Editar permisos, desactiva el rol de descuentos, guarda y revoca sesiones.")
        }
    }

    private var rolesSection: some View {
        Section {
            ForEach(groupedActiveRoles.keys.sorted(), id: \.self) { group in
                DisclosureGroup(group) {
                    ForEach(groupedActiveRoles[group] ?? []) { role in
                        RoleCompactRow(
                            role: role,
                            subtitle: viewModel.roleDescription(for: role),
                            isDiscountRole: viewModel.roleGrantsDiscounts(role)
                        )
                    }
                }
            }
        } header: {
            Text("Roles disponibles")
        } footer: {
            Text("Los permisos se asignan por roles. Evita modificar el rol base si solo quieres dar o quitar una capacidad específica.")
        }
    }

    private var filteredUsers: [BusinessTeamUser] {
        viewModel.users.filter { user in
            switch selectedFilter {
            case .all:
                return true
            case .active:
                return !user.isBlocked
            case .blocked:
                return user.isBlocked
            case .discounts:
                return viewModel.userHasDiscountAccess(user)
            }
        }
    }

    private var activeUsersCount: Int {
        viewModel.users.filter { !$0.isBlocked }.count
    }

    private var discountUsersCount: Int {
        viewModel.users.filter { viewModel.userHasDiscountAccess($0) }.count
    }

    private var groupedActiveRoles: [String: [BusinessTeamRole]] {
        Dictionary(grouping: viewModel.activeRoles) { role in
            roleGroupTitle(for: role)
        }
        .mapValues { roles in
            roles.sorted { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank > rhs.rank
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private func roleGroupTitle(for role: BusinessTeamRole) -> String {
        let code = "\(role.code) \(role.name) \(role.permissionKeys.joined(separator: " "))".lowercased()

        if viewModel.roleGrantsDiscounts(role) { return "Descuentos" }
        if code.contains("super") || code.contains("admin") || code.contains("team") || code.contains("role") || code.contains("credential") { return "Administración" }
        if code.contains("cash") || code.contains("payment") || code.contains("receivable") { return "Caja y cobros" }
        if code.contains("sales") || code.contains("seller") || code.contains("cajero") || code.contains("mesero") { return "Ventas" }
        if code.contains("report") || code.contains("document") { return "Reportes y documentos" }
        return "Otros"
    }
}

private struct BusinessTeamCreateUserView: View {
    @Bindable var viewModel: BusinessTeamViewModel
    let onDone: () -> Void

    @State private var showsRoleHelp = false

    var body: some View {
        Form {
            introSection
            userDataSection
            discountAccessSection
            recommendedRolesSection
            allRolesSection
            auditSection
        }
        .navigationTitle("Crear usuario")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar", action: onDone)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Crear") {
                    Task {
                        await viewModel.createUser()
                        if viewModel.errorMessage == nil {
                            onDone()
                        }
                    }
                }
                .disabled(!viewModel.canCreateUser || viewModel.isMutating)
            }
        }
        .alert("Cómo elegir roles", isPresented: $showsRoleHelp) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Asigna solo lo necesario para el trabajo del usuario. Para descuentos, usa el rol específico de descuentos en vez de editar roles base.")
        }
    }

    private var introSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nuevo integrante")
                        .font(.headline)

                    Text("El usuario se creará con contraseña temporal y roles asignados desde este negocio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(.tint)
            }
        }
    }

    private var userDataSection: some View {
        Section {
            TextField("Correo", text: $viewModel.createEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Nombre", text: $viewModel.createDisplayName)
                .textInputAutocapitalization(.words)

            TextField("Teléfono opcional", text: $viewModel.createPhone)
                .keyboardType(.phonePad)
        } header: {
            Text("Datos del usuario")
        } footer: {
            Text("El usuario deberá cambiar su contraseña temporal al iniciar sesión, si el backend lo exige.")
        }
    }

    @ViewBuilder
    private var discountAccessSection: some View {
        Section {
            if viewModel.discountRoles.isEmpty {
                Label("No hay rol de descuentos disponible.", systemImage: "percent.slash")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.discountRoles) { role in
                    RoleToggleRow(
                        role: role,
                        isSelected: roleSelectionBinding(role.id),
                        subtitle: "Permite aplicar o quitar descuentos en ventas.",
                        isDiscountRole: true
                    )
                }
            }
        } header: {
            Text("Descuentos")
        } footer: {
            Text("Activa esto solo para usuarios autorizados a modificar totales de venta.")
        }
    }

    private var recommendedRolesSection: some View {
        Section {
            ForEach(recommendedRoles) { role in
                RoleToggleRow(
                    role: role,
                    isSelected: roleSelectionBinding(role.id),
                    subtitle: viewModel.roleDescription(for: role),
                    isDiscountRole: viewModel.roleGrantsDiscounts(role)
                )
            }

            Button {
                showsRoleHelp = true
            } label: {
                Label("Ayuda para elegir roles", systemImage: "questionmark.circle")
            }
        } header: {
            Text("Roles recomendados")
        } footer: {
            Text("Puedes combinar un rol operativo con un rol específico como descuentos.")
        }
    }

    private var allRolesSection: some View {
        Section("Todos los roles") {
            ForEach(groupedRoles.keys.sorted(), id: \.self) { group in
                DisclosureGroup(group) {
                    ForEach(groupedRoles[group] ?? []) { role in
                        RoleToggleRow(
                            role: role,
                            isSelected: roleSelectionBinding(role.id),
                            subtitle: viewModel.roleDescription(for: role),
                            isDiscountRole: viewModel.roleGrantsDiscounts(role)
                        )
                    }
                }
            }
        }
    }

    private var auditSection: some View {
        Section("Motivo") {
            TextField("Motivo obligatorio", text: $viewModel.createReason, axis: .vertical)
                .lineLimit(2...4)

            Text("Este motivo ayuda a auditar quién creó el usuario y por qué.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recommendedRoles: [BusinessTeamRole] {
        viewModel.activeRoles
            .filter { role in
                let text = "\(role.code) \(role.name)".lowercased()
                return text.contains("operator") ||
                text.contains("operador") ||
                text.contains("cajero") ||
                text.contains("mesero") ||
                text.contains("contador") ||
                viewModel.roleGrantsDiscounts(role)
            }
            .sorted { lhs, rhs in
                if viewModel.roleGrantsDiscounts(lhs) != viewModel.roleGrantsDiscounts(rhs) {
                    return viewModel.roleGrantsDiscounts(lhs)
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var groupedRoles: [String: [BusinessTeamRole]] {
        Dictionary(grouping: viewModel.activeRoles) { role in
            roleGroupTitle(for: role)
        }
        .mapValues { roles in
            roles.sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private func roleSelectionBinding(_ roleId: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.selectedRoleIds.contains(roleId) },
            set: { selected in
                if selected {
                    viewModel.selectedRoleIds.insert(roleId)
                } else {
                    viewModel.selectedRoleIds.remove(roleId)
                }
            }
        )
    }

    private func roleGroupTitle(for role: BusinessTeamRole) -> String {
        let code = "\(role.code) \(role.name) \(role.permissionKeys.joined(separator: " "))".lowercased()

        if viewModel.roleGrantsDiscounts(role) { return "Descuentos" }
        if code.contains("super") || code.contains("admin") || code.contains("team") || code.contains("role") || code.contains("credential") { return "Administración" }
        if code.contains("cash") || code.contains("payment") || code.contains("receivable") { return "Caja y cobros" }
        if code.contains("sales") || code.contains("seller") || code.contains("cajero") || code.contains("mesero") { return "Ventas" }
        if code.contains("report") || code.contains("document") { return "Reportes y documentos" }
        return "Otros"
    }
}

private struct BusinessTeamUserRow: View {
    let user: BusinessTeamUser
    let discountEnabled: Bool
    let branchName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 8) {
                header
                roles
                badges
            }
        }
        .padding(.vertical, 5)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(user.isBlocked ? Color.red.opacity(0.12) : Color.accentColor.opacity(0.12))
                .frame(width: 42, height: 42)

            Image(systemName: user.isBlocked ? "person.crop.circle.badge.xmark" : "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(user.isBlocked ? .red : .secondary)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusPill(
                title: user.isBlocked ? "Bloqueado" : normalizedStatus,
                systemImage: user.isBlocked ? "lock.fill" : "checkmark.circle.fill",
                style: user.isBlocked ? .blocked : .active
            )
        }
    }

    private var roles: some View {
        Text(user.rolesSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    private var badges: some View {
        FlowLayout(spacing: 6) {
            PermissionPill(
                title: discountEnabled ? "Descuentos" : "Sin descuentos",
                systemImage: discountEnabled ? "percent" : "minus.circle",
                isEnabled: discountEnabled
            )

            if let branchName {
                PermissionPill(
                    title: branchName,
                    systemImage: "building.2",
                    isEnabled: true
                )
            }

            if user.activeSessionCount > 0 {
                PermissionPill(
                    title: "\(user.activeSessionCount) sesión(es)",
                    systemImage: "iphone",
                    isEnabled: true
                )
            }
        }
    }

    private var normalizedStatus: String {
        let status = user.membershipStatus?.trimmed.nilIfBlank ?? user.status
        return status.prefix(1).uppercased() + status.dropFirst()
    }
}

private struct BusinessTeamUserDetailView: View {
    let userId: String
    let viewModel: BusinessTeamViewModel

    @State private var reason = ""
    @State private var showingRoleEditor = false
    @State private var showingSensitiveActionConfirmation = false
    @State private var pendingAction: SensitiveUserAction?

    private var user: BusinessTeamUser? {
        viewModel.user(withId: userId)
    }

    var body: some View {
        Group {
            if let user {
                Form {
                    userHeroSection(user)
                    accessSection(user)
                    assignedRolesSection(user)
                    reasonSection
                    actionsSection(user)
                }
                .navigationTitle(user.displayName)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingRoleEditor = true
                        } label: {
                            Label("Editar permisos", systemImage: "slider.horizontal.3")
                        }
                    }
                }
                .sheet(isPresented: $showingRoleEditor) {
                    NavigationStack {
                        BusinessTeamRoleEditorView(
                            user: user,
                            viewModel: viewModel,
                            onDone: { showingRoleEditor = false }
                        )
                    }
                }
                .confirmationDialog(
                    pendingAction?.title ?? "Confirmar acción",
                    isPresented: $showingSensitiveActionConfirmation,
                    titleVisibility: .visible
                ) {
                    if let pendingAction {
                        Button(pendingAction.confirmationTitle, role: pendingAction.role) {
                            Task { await run(pendingAction, user: user) }
                        }
                    }

                    Button("Cancelar", role: .cancel) {
                        pendingAction = nil
                    }
                } message: {
                    Text(pendingAction?.message ?? "")
                }
            } else {
                ContentUnavailableView(
                    "Usuario no encontrado",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Actualiza el equipo para volver a cargar la información.")
                )
            }
        }
        .task {
            _ = await viewModel.refreshUser(userId)
        }
    }

    private func userHeroSection(_ user: BusinessTeamUser) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(user.isBlocked ? Color.red.opacity(0.12) : Color.accentColor.opacity(0.12))
                            .frame(width: 54, height: 54)

                        Image(systemName: user.isBlocked ? "person.crop.circle.badge.xmark" : "person.crop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(user.isBlocked ? .red : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.headline)

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let phone = user.phone?.trimmed.nilIfBlank {
                            Text(phone)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Estado")
                            .foregroundStyle(.secondary)
                        Text(user.status)
                            .fontWeight(.semibold)
                    }

                    GridRow {
                        Text("Membresía")
                            .foregroundStyle(.secondary)
                        Text(user.membershipStatus ?? "Activa")
                            .fontWeight(.semibold)
                    }

                    GridRow {
                        Text("Sesiones")
                            .foregroundStyle(.secondary)
                        Text("\(user.activeSessionCount)")
                            .fontWeight(.semibold)
                    }

                    if let branchName = viewModel.branchName(for: user) {
                        GridRow {
                            Text("Sucursal")
                                .foregroundStyle(.secondary)
                            Text(branchName)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .font(.footnote)

                if let blockedReason = user.blockedReason?.trimmed.nilIfBlank {
                    Label(blockedReason, systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func accessSection(_ user: BusinessTeamUser) -> some View {
        Section {
            AccessHighlightCard(
                title: viewModel.userHasDiscountAccess(user) ? "Puede aplicar descuentos" : "No puede aplicar descuentos",
                message: viewModel.discountAccessDescription(for: user),
                systemImage: viewModel.userHasDiscountAccess(user) ? "percent" : "percent.slash",
                isEnabled: viewModel.userHasDiscountAccess(user)
            )

            Button {
                showingRoleEditor = true
            } label: {
                Label("Editar roles y permisos", systemImage: "slider.horizontal.3")
            }
        } header: {
            Text("Permisos clave")
        } footer: {
            Text("Los permisos se administran por roles. Para quitar descuentos, desactiva el rol de descuentos y guarda.")
        }
    }

    private func assignedRolesSection(_ user: BusinessTeamUser) -> some View {
        Section("Roles asignados") {
            let assignedRoles = viewModel.roles(for: user)

            if assignedRoles.isEmpty {
                Label("Sin roles asignados", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                ForEach(assignedRoles) { role in
                    RoleCompactRow(
                        role: role,
                        subtitle: viewModel.roleDescription(for: role),
                        isDiscountRole: viewModel.roleGrantsDiscounts(role)
                    )
                }
            }
        }
    }

    private var reasonSection: some View {
        Section {
            TextField("Ej. ajuste solicitado por gerencia", text: $reason, axis: .vertical)
                .lineLimit(2...4)

            Text("Bloquear, desbloquear, resetear contraseña y revocar sesiones requieren motivo de auditoría.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Motivo para acciones sensibles")
        }
    }

    private func actionsSection(_ user: BusinessTeamUser) -> some View {
        Section {
            Button {
                showingRoleEditor = true
            } label: {
                Label("Editar permisos", systemImage: "slider.horizontal.3")
            }

            Button {
                prepare(.resetPassword)
            } label: {
                Label("Resetear contraseña", systemImage: "key")
            }
            .disabled(!hasReason)

            Button {
                prepare(.revokeSessions)
            } label: {
                Label("Revocar sesiones", systemImage: "iphone.slash")
            }
            .disabled(!hasReason)

            if user.isBlocked {
                Button {
                    prepare(.unblock)
                } label: {
                    Label("Desbloquear usuario", systemImage: "lock.open")
                }
                .disabled(!hasReason)
            } else {
                Button(role: .destructive) {
                    prepare(.block)
                } label: {
                    Label("Bloquear usuario", systemImage: "lock")
                }
                .disabled(!hasReason)
            }
        } header: {
            Text("Acciones")
        } footer: {
            Text(hasReason ? "Estas acciones quedarán auditadas." : "Escribe un motivo para habilitar acciones sensibles.")
        }
    }

    private var hasReason: Bool {
        !reason.trimmed.isEmpty
    }

    private func prepare(_ action: SensitiveUserAction) {
        pendingAction = action
        showingSensitiveActionConfirmation = true
    }

    private func run(_ action: SensitiveUserAction, user: BusinessTeamUser) async {
        let normalizedReason = reason.trimmed

        switch action {
        case .block:
            await viewModel.block(user, reason: normalizedReason)
        case .unblock:
            await viewModel.unblock(user, reason: normalizedReason)
        case .resetPassword:
            await viewModel.resetPassword(user, reason: normalizedReason)
        case .revokeSessions:
            await viewModel.revokeSessions(user, reason: normalizedReason)
        }

        pendingAction = nil
    }
}

private struct BusinessTeamRoleEditorView: View {
    let user: BusinessTeamUser
    let viewModel: BusinessTeamViewModel
    let onDone: () -> Void

    @State private var selectedRoleIds: Set<String>
    @State private var reason: String
    @State private var revokeSessions = true
    @State private var showSaveConfirmation = false
    @State private var selectedSection: RoleEditorSection = .important

    init(
        user: BusinessTeamUser,
        viewModel: BusinessTeamViewModel,
        onDone: @escaping () -> Void
    ) {
        self.user = user
        self.viewModel = viewModel
        self.onDone = onDone
        _selectedRoleIds = State(initialValue: user.roleIds)
        _reason = State(initialValue: "Actualizar permisos de \(user.displayName)")
    }

    var body: some View {
        Form {
            userSummarySection
            sectionPicker
            roleContent
            auditSection
            impactSection
        }
        .navigationTitle("Editar permisos")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar", action: onDone)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    showSaveConfirmation = true
                }
                .disabled(!canSave)
            }
        }
        .confirmationDialog(
            "Guardar cambios de permisos",
            isPresented: $showSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Guardar cambios", role: .destructive) {
                Task { await save() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(saveConfirmationMessage)
        }
    }

    private var userSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(user.displayName)
                    .font(.headline)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Selecciona roles. Los cambios quedan auditados y pueden aplicarse de inmediato revocando sesiones.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var sectionPicker: some View {
        Section {
            Picker("Sección", selection: $selectedSection) {
                ForEach(RoleEditorSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var roleContent: some View {
        switch selectedSection {
        case .important:
            importantRolesSection
        case .all:
            allRolesSection
        }
    }

    private var importantRolesSection: some View {
        Section {
            if viewModel.discountRoles.isEmpty {
                Label("No existe un rol de descuentos asignable.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                ForEach(viewModel.discountRoles) { role in
                    RoleToggleRow(
                        role: role,
                        isSelected: roleBinding(role.id),
                        subtitle: "Permite aplicar, quitar o controlar descuentos en ventas.",
                        isDiscountRole: true
                    )
                }
            }

            Divider()

            ForEach(coreAssignedOrSuggestedRoles) { role in
                RoleToggleRow(
                    role: role,
                    isSelected: roleBinding(role.id),
                    subtitle: viewModel.roleDescription(for: role),
                    isDiscountRole: viewModel.roleGrantsDiscounts(role)
                )
            }
        } header: {
            Text("Permisos importantes")
        } footer: {
            Text(discountFooterText)
        }
    }

    private var allRolesSection: some View {
        Section("Todos los roles") {
            ForEach(groupedRoles.keys.sorted(), id: \.self) { group in
                DisclosureGroup(group) {
                    ForEach(groupedRoles[group] ?? []) { role in
                        RoleToggleRow(
                            role: role,
                            isSelected: roleBinding(role.id),
                            subtitle: viewModel.roleDescription(for: role),
                            isDiscountRole: viewModel.roleGrantsDiscounts(role)
                        )
                    }
                }
            }
        }
    }

    private var auditSection: some View {
        Section("Auditoría") {
            TextField("Motivo obligatorio", text: $reason, axis: .vertical)
                .lineLimit(2...4)

            Toggle(isOn: $revokeSessions) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Revocar sesiones al guardar")
                        .font(.subheadline.weight(.semibold))

                    Text("Recomendado para que el usuario vuelva a iniciar sesión y reciba permisos actualizados.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var impactSection: some View {
        Section("Impacto") {
            PermissionChangeRow(
                title: "Descuentos",
                before: viewModel.userHasDiscountAccess(user),
                after: selectedRoles.contains { viewModel.roleGrantsDiscounts($0) }
            )

            LabeledContent("Roles actuales", value: "\(user.roleIds.count)")
            LabeledContent("Roles nuevos", value: "\(selectedRoleIds.count)")

            if selectedRoleIds.isEmpty {
                Label("El usuario debe conservar al menos un rol.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var groupedRoles: [String: [BusinessTeamRole]] {
        Dictionary(grouping: viewModel.activeRoles) { role in
            roleGroupTitle(for: role)
        }
        .mapValues { roles in
            roles.sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var coreAssignedOrSuggestedRoles: [BusinessTeamRole] {
        viewModel.activeRoles
            .filter { role in
                selectedRoleIds.contains(role.id) ||
                !viewModel.roleGrantsDiscounts(role)
            }
            .filter { role in
                let text = "\(role.code) \(role.name)".lowercased()
                return text.contains("operator") ||
                text.contains("operador") ||
                text.contains("cajero") ||
                text.contains("mesero") ||
                text.contains("contador") ||
                selectedRoleIds.contains(role.id)
            }
            .sorted { lhs, rhs in
                if selectedRoleIds.contains(lhs.id) != selectedRoleIds.contains(rhs.id) {
                    return selectedRoleIds.contains(lhs.id)
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var selectedRoles: [BusinessTeamRole] {
        viewModel.activeRoles.filter { selectedRoleIds.contains($0.id) }
    }

    private var canSave: Bool {
        selectedRoleIds != user.roleIds &&
        !selectedRoleIds.isEmpty &&
        !reason.trimmed.isEmpty &&
        !viewModel.isMutating
    }

    private var discountFooterText: String {
        let before = viewModel.userHasDiscountAccess(user)
        let after = selectedRoles.contains { viewModel.roleGrantsDiscounts($0) }

        switch (before, after) {
        case (false, true):
            return "Este usuario podrá aplicar descuentos después de guardar."
        case (true, false):
            return "Este usuario perderá permisos de descuentos después de guardar."
        case (true, true):
            return "Este usuario seguirá teniendo permisos de descuentos."
        case (false, false):
            return "Este usuario seguirá sin permisos de descuentos."
        }
    }

    private var saveConfirmationMessage: String {
        revokeSessions
        ? "Se actualizarán los roles de \(user.displayName) y se revocarán sus sesiones activas para forzar actualización de permisos."
        : "Se actualizarán los roles de \(user.displayName). Si tiene sesión abierta, podría conservar permisos anteriores hasta refrescar contexto o volver a iniciar sesión."
    }

    private func roleBinding(_ roleId: String) -> Binding<Bool> {
        Binding(
            get: { selectedRoleIds.contains(roleId) },
            set: { selected in
                if selected {
                    selectedRoleIds.insert(roleId)
                } else {
                    selectedRoleIds.remove(roleId)
                }
            }
        )
    }

    private func save() async {
        let saved = await viewModel.updateUserRoles(
            user: user,
            roleIds: selectedRoleIds,
            reason: reason,
            revokeSessions: revokeSessions
        )

        if saved {
            onDone()
        }
    }

    private func roleGroupTitle(for role: BusinessTeamRole) -> String {
        let code = "\(role.code) \(role.name) \(role.permissionKeys.joined(separator: " "))".lowercased()

        if viewModel.roleGrantsDiscounts(role) { return "Descuentos" }
        if code.contains("super") || code.contains("admin") || code.contains("team") || code.contains("role") || code.contains("credential") { return "Administración" }
        if code.contains("cash") || code.contains("payment") || code.contains("receivable") { return "Caja y cobros" }
        if code.contains("sales") || code.contains("seller") || code.contains("cajero") || code.contains("mesero") { return "Ventas" }
        if code.contains("report") || code.contains("document") { return "Reportes y documentos" }
        return "Otros"
    }
}

private struct BusinessTeamMetricCard: View {
    enum Style {
        case normal
        case success
        case warning
    }

    let title: String
    let value: String
    let systemImage: String
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var foreground: Color {
        switch style {
        case .normal:
            return .accentColor
        case .success:
            return .green
        case .warning:
            return .orange
        }
    }

    private var background: Color {
        switch style {
        case .normal:
            return Color.accentColor.opacity(0.10)
        case .success:
            return Color.green.opacity(0.10)
        case .warning:
            return Color.orange.opacity(0.10)
        }
    }
}

private struct RoleToggleRow: View {
    let role: BusinessTeamRole
    @Binding var isSelected: Bool
    let subtitle: String
    let isDiscountRole: Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(role.name)
                        .font(.subheadline.weight(.semibold))

                    if isDiscountRole {
                        Image(systemName: "percent")
                            .foregroundStyle(.green)
                    }

                    if role.critical {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Text(role.description.trimmed.nilIfBlank ?? subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 3)
        }
    }
}

private struct RoleCompactRow: View {
    let role: BusinessTeamRole
    let subtitle: String
    let isDiscountRole: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isDiscountRole ? "percent" : role.critical ? "exclamationmark.shield" : "person.badge.key")
                .foregroundStyle(isDiscountRole ? .green : role.critical ? .orange : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(role.name)
                        .font(.subheadline.weight(.semibold))

                    if role.systemRole {
                        Text("Sistema")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }

                if !role.description.trimmed.isEmpty {
                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AccessHighlightCard: View {
    let title: String
    let message: String
    let systemImage: String
    let isEnabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isEnabled ? .green : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PermissionChangeRow: View {
    let title: String
    let before: Bool
    let after: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: before ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(before ? .green : .secondary)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: after ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(after ? .green : .secondary)
            }
        }
    }
}

private struct PermissionPill: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isEnabled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12))
            .foregroundStyle(isEnabled ? .green : .secondary)
            .clipShape(Capsule())
    }
}

private struct StatusPill: View {
    enum Style {
        case active
        case blocked
    }

    let title: String
    let systemImage: String
    let style: Style

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
    }

    private var background: Color {
        switch style {
        case .active:
            return .green.opacity(0.12)
        case .blocked:
            return .red.opacity(0.12)
        }
    }

    private var foreground: Color {
        switch style {
        case .active:
            return .green
        case .blocked:
            return .red
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                content()
            }

            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
        }
    }
}

private enum BusinessTeamFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case blocked
    case discounts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Todos"
        case .active:
            return "Activos"
        case .blocked:
            return "Bloqueados"
        case .discounts:
            return "Desc."
        }
    }

    var footer: String {
        switch self {
        case .all:
            return "Mostrando todos los usuarios del negocio."
        case .active:
            return "Mostrando usuarios que pueden operar si tienen permisos."
        case .blocked:
            return "Mostrando usuarios bloqueados."
        case .discounts:
            return "Mostrando usuarios con permisos para descuentos."
        }
    }
}

private enum RoleEditorSection: String, CaseIterable, Identifiable {
    case important
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .important:
            return "Clave"
        case .all:
            return "Todos"
        }
    }
}

private enum SensitiveUserAction: Identifiable {
    case block
    case unblock
    case resetPassword
    case revokeSessions

    var id: String {
        switch self {
        case .block:
            return "block"
        case .unblock:
            return "unblock"
        case .resetPassword:
            return "resetPassword"
        case .revokeSessions:
            return "revokeSessions"
        }
    }

    var title: String {
        switch self {
        case .block:
            return "Bloquear usuario"
        case .unblock:
            return "Desbloquear usuario"
        case .resetPassword:
            return "Resetear contraseña"
        case .revokeSessions:
            return "Revocar sesiones"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .block:
            return "Bloquear"
        case .unblock:
            return "Desbloquear"
        case .resetPassword:
            return "Resetear"
        case .revokeSessions:
            return "Revocar"
        }
    }

    var message: String {
        switch self {
        case .block:
            return "El usuario no podrá operar hasta ser desbloqueado."
        case .unblock:
            return "El usuario podrá volver a operar si mantiene permisos activos."
        case .resetPassword:
            return "Se generará una contraseña temporal y se revocarán sesiones."
        case .revokeSessions:
            return "El usuario deberá iniciar sesión nuevamente para tomar permisos actualizados."
        }
    }

    var role: ButtonRole? {
        switch self {
        case .block, .resetPassword, .revokeSessions:
            return .destructive
        case .unblock:
            return nil
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        BusinessTeamView(
            viewModel: BusinessTeamViewModel(
                repository: PreviewBusinessTeamRepository()
            )
        )
    }
}
