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
        .navigationTitle("Equipo y roles")
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
                        Label("Actualizar", systemImage: "arrow.clockwise")
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
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var temporaryPasswordSection: some View {
        if let password = viewModel.lastTemporaryPassword {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Contraseña temporal", systemImage: "key.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text(password)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Cópiala antes de salir de esta pantalla. Entrégala solo al usuario correspondiente.")
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
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
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
            roleTemplatesSection

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
            roleTemplatesSection
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
                    BusinessTeamMetricCard(title: "Usuarios", value: "\(viewModel.users.count)", systemImage: "person.2.fill")
                    BusinessTeamMetricCard(title: "Activos", value: "\(activeUsersCount)", systemImage: "checkmark.circle.fill")
                    BusinessTeamMetricCard(title: "Descuentos", value: "\(discountUsersCount)", systemImage: "percent")
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
                        BusinessTeamUserDetailView(userId: user.id, viewModel: viewModel)
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
        }
    }

    @ViewBuilder
    private var discountRolesSection: some View {
        if !viewModel.discountRoles.isEmpty {
            Section {
                ForEach(viewModel.discountRoles) { role in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(role.name, systemImage: "percent")
                            .font(.headline)
                        Text("Permite aplicar, quitar y administrar descuentos en ventas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Descuentos")
            } footer: {
                Text("Para retirar descuentos a un usuario, entra a su detalle, toca Editar roles y desmarca el rol de descuentos.")
            }
        }
    }

    private var rolesSection: some View {
        Section("Roles del negocio") {
            ForEach(viewModel.activeRoles) { role in
                BusinessTeamRoleRow(role: role, capabilities: viewModel.readableCapabilities(for: role.permissionKeys), subtitle: viewModel.roleDescription(for: role))
            }
        }
    }

    private var roleTemplatesSection: some View {
        Section {
            if viewModel.availableTemplates.isEmpty {
                Text("No hay plantillas disponibles para este negocio.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.availableTemplates) { template in
                    BusinessRoleTemplateRow(template: template) {
                        Task { await viewModel.createRoleFromTemplate(template, reason: "Crear rol \(template.name) desde plantilla") }
                    }
                    .disabled(viewModel.isMutating || viewModel.roles.contains { $0.code == template.roleCode })
                }
            }
        } header: {
            Text("Plantillas disponibles")
        }  footer: {
            Text("Las plantillas se copian como roles locales del negocio. No se asignan directamente a usuarios.")
        }
    }

    private var filteredUsers: [BusinessTeamUser] {
        viewModel.users.filter { user in
            switch selectedFilter {
            case .all: return true
            case .active: return !user.isBlocked
            case .blocked: return user.isBlocked
            case .discounts: return viewModel.userHasDiscountAccess(user)
            case .superBusiness: return user.isOrganizationSuperAdmin
            }
        }
    }

    private var activeUsersCount: Int {
        viewModel.users.filter { !$0.isBlocked }.count
    }

    private var discountUsersCount: Int {
        viewModel.users.filter { viewModel.userHasDiscountAccess($0) }.count
    }
}

private struct BusinessTeamCreateUserView: View {
    @Bindable var viewModel: BusinessTeamViewModel
    let onDone: () -> Void

    var body: some View {
        Form {
            Section("Datos") {
                TextField("Nombre", text: $viewModel.createDisplayName)
                    .textInputAutocapitalization(.words)
                TextField("Correo", text: $viewModel.createEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Teléfono", text: $viewModel.createPhone)
                    .keyboardType(.phonePad)
            }

            Section {
                if viewModel.activeRoles.isEmpty {
                    Text("Primero crea o provisiona roles para esta organización.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.activeRoles) { role in
                        Toggle(isOn: roleBinding(role.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.name)
                                Text(viewModel.roleDescription(for: role))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Roles")
            } footer: {
                Text("Puedes asignar un rol base y agregar Encargado de descuentos como rol complementario.")
            }

            Section("Motivo") {
                TextField("Motivo", text: $viewModel.createReason, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Button {
                    Task {
                        await viewModel.createUser()
                        if viewModel.errorMessage == nil { onDone() }
                    }
                } label: {
                    if viewModel.isMutating {
                        ProgressView()
                    } else {
                        Text("Crear usuario")
                    }
                }
                .disabled(!viewModel.canCreateUser || viewModel.isMutating)
            }
        }
        .navigationTitle("Crear usuario")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar", action: onDone)
            }
        }
    }

    private func roleBinding(_ roleId: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.selectedRoleIds.contains(roleId) },
            set: { isOn in
                if isOn { viewModel.selectedRoleIds.insert(roleId) }
                else { viewModel.selectedRoleIds.remove(roleId) }
            }
        )
    }
}

private struct BusinessTeamUserDetailView: View {
    let userId: String
    @Bindable var viewModel: BusinessTeamViewModel
    @State private var user: BusinessTeamUser?
    @State private var showingRoleEditor = false
    @State private var actionReason = ""
    @State private var confirmation: Confirmation?

    var body: some View {
        List {
            if let user {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.title3.bold())
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            BusinessTeamStatusBadge(user: user)
                        }

                        Text(viewModel.discountAccessDescription(for: user))
                            .font(.footnote)
                            .foregroundStyle(viewModel.userHasDiscountAccess(user) ? .orange : .secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Roles asignados") {
                    ForEach(viewModel.roles(for: user)) { role in
                        BusinessTeamRoleRow(role: role, capabilities: viewModel.readableCapabilities(for: role.permissionKeys), subtitle: viewModel.roleDescription(for: role))
                    }
                }

                Section("Sesiones") {
                    LabeledContent("Sesiones activas", value: "\(user.activeSessionCount)")
                }

                Section("Acciones") {
                    Button {
                        showingRoleEditor = true
                    } label: {
                        Label("Editar roles", systemImage: "checklist")
                    }

                    Button {
                        confirmation = user.isBlocked ? .unblock(user) : .block(user)
                    } label: {
                        Label(user.isBlocked ? "Desbloquear" : "Bloquear", systemImage: user.isBlocked ? "lock.open" : "lock")
                    }

                    Button {
                        confirmation = .resetPassword(user)
                    } label: {
                        Label("Resetear contraseña", systemImage: "key")
                    }

                    Button(role: .destructive) {
                        confirmation = .revokeSessions(user)
                    } label: {
                        Label("Revocar sesiones", systemImage: "iphone.slash")
                    }
                }
            } else {
                Section {
                    ProgressView("Cargando usuario…")
                }
            }
        }
        .navigationTitle("Detalle")
        .task { user = await viewModel.refreshUser(userId) }
        .sheet(isPresented: $showingRoleEditor) {
            if let user {
                NavigationStack {
                    BusinessTeamRoleEditorView(user: user, viewModel: viewModel) {
                        showingRoleEditor = false
                        Task { self.user = await viewModel.refreshUser(userId) }
                    }
                }
            }
        }
        .confirmationDialog("Confirmar acción", isPresented: confirmationBinding) {
            if let confirmation {
                Button(confirmation.title, role: confirmation.role) {
                    Task { await run(confirmation) }
                }
            }
            Button("Cancelar", role: .cancel) { confirmation = nil }
        } message: {
            Text(confirmation?.message ?? "")
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )
    }

    private func run(_ confirmation: Confirmation) async {
        switch confirmation {
        case .block(let user): await viewModel.block(user, reason: actionReason)
        case .unblock(let user): await viewModel.unblock(user, reason: actionReason)
        case .resetPassword(let user): await viewModel.resetPassword(user, reason: actionReason)
        case .revokeSessions(let user): await viewModel.revokeSessions(user, reason: actionReason)
        }
        self.user = await viewModel.refreshUser(userId)
        self.confirmation = nil
    }

    private enum Confirmation: Identifiable {
        case block(BusinessTeamUser)
        case unblock(BusinessTeamUser)
        case resetPassword(BusinessTeamUser)
        case revokeSessions(BusinessTeamUser)

        var id: String { title }
        var title: String {
            switch self {
            case .block: return "Bloquear usuario"
            case .unblock: return "Desbloquear usuario"
            case .resetPassword: return "Resetear contraseña"
            case .revokeSessions: return "Revocar sesiones"
            }
        }
        var message: String {
            switch self {
            case .block: return "El usuario no podrá operar hasta ser desbloqueado."
            case .unblock: return "El usuario recuperará el acceso según sus roles actuales."
            case .resetPassword: return "Se generará una contraseña temporal y se revocarán sus sesiones."
            case .revokeSessions: return "El usuario deberá iniciar sesión otra vez para recibir permisos actualizados."
            }
        }
        var role: ButtonRole? {
            switch self {
            case .block, .revokeSessions: return .destructive
            default: return nil
            }
        }
    }
}

private struct BusinessTeamRoleEditorView: View {
    let user: BusinessTeamUser
    @Bindable var viewModel: BusinessTeamViewModel
    let onDone: () -> Void

    @State private var selectedRoleIds: Set<String>
    @State private var reason = "Actualizar roles desde Business"
    @State private var revokeSessions = true

    init(user: BusinessTeamUser, viewModel: BusinessTeamViewModel, onDone: @escaping () -> Void) {
        self.user = user
        self.viewModel = viewModel
        self.onDone = onDone
        self._selectedRoleIds = State(initialValue: user.roleIds)
    }

    var body: some View {
        Form {
            Section("Usuario") {
                LabeledContent("Nombre", value: user.displayName)
                LabeledContent("Correo", value: user.email)
            }

            Section {
                ForEach(viewModel.activeRoles) { role in
                    Toggle(isOn: roleBinding(role.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(role.name)
                                if viewModel.roleGrantsDiscounts(role) {
                                    Image(systemName: "percent")
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text(viewModel.roleDescription(for: role))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Roles del negocio")
            } footer: {
                Text("Desmarca Encargado de descuentos para retirar permisos de descuento. Mantén activada la revocación de sesiones para aplicar el cambio inmediatamente.")
            }

            Section("Aplicación del cambio") {
                Toggle("Revocar sesiones al guardar", isOn: $revokeSessions)
                TextField("Motivo", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Button {
                    Task {
                        let ok = await viewModel.updateUserRoles(
                            user: user,
                            roleIds: selectedRoleIds,
                            reason: reason,
                            revokeSessions: revokeSessions
                        )
                        if ok { onDone() }
                    }
                } label: {
                    if viewModel.isMutating { ProgressView() }
                    else { Text("Guardar roles") }
                }
                .disabled(selectedRoleIds.isEmpty || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isMutating)
            }
        }
        .navigationTitle("Editar roles")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar", action: onDone)
            }
        }
    }

    private func roleBinding(_ roleId: String) -> Binding<Bool> {
        Binding(
            get: { selectedRoleIds.contains(roleId) },
            set: { isOn in
                if isOn { selectedRoleIds.insert(roleId) }
                else { selectedRoleIds.remove(roleId) }
            }
        )
    }
}

private struct BusinessTeamMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessTeamUserRow: View {
    let user: BusinessTeamUser
    let discountEnabled: Bool
    let branchName: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: user.isOrganizationSuperAdmin ? "crown.fill" : "person.crop.circle")
                .font(.title3)
                .foregroundStyle(user.isOrganizationSuperAdmin ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text([user.rolesSummary, branchName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                BusinessTeamStatusBadge(user: user)
                if discountEnabled {
                    Label("Descuentos", systemImage: "percent")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessTeamStatusBadge: View {
    let user: BusinessTeamUser

    var body: some View {
        Text(user.isBlocked ? "Bloqueado" : "Activo")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(user.isBlocked ? .red.opacity(0.15) : .green.opacity(0.15))
            .foregroundStyle(user.isBlocked ? .red : .green)
            .clipShape(Capsule())
    }
}

private struct BusinessTeamRoleRow: View {
    let role: BusinessTeamRole
    let capabilities: [String]
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(role.name)
                    .font(.headline)
                if role.critical {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("Rango \(role.rank)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(role.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(capabilities, id: \.self) { capability in
                        Text(capability)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.45))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessRoleTemplateRow: View {
    let template: BusinessRoleTemplate
    let create: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.readableVertical)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Crear", action: create)
                    .buttonStyle(.bordered)
            }
            Text(template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private enum BusinessTeamFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case blocked
    case discounts
    case superBusiness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todos"
        case .active: return "Activos"
        case .blocked: return "Bloqueados"
        case .discounts: return "Descuentos"
        case .superBusiness: return "Super"
        }
    }

    var footer: String {
        switch self {
        case .all: return "Muestra todo el equipo del negocio."
        case .active: return "Usuarios que pueden operar actualmente."
        case .blocked: return "Usuarios sin acceso operativo."
        case .discounts: return "Usuarios con roles que permiten aplicar descuentos."
        case .superBusiness: return "Usuarios con control crítico del negocio."
        }
    }
}
