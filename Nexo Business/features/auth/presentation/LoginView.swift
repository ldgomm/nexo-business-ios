//
//  LoginView.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI
import Observation

struct LoginView: View {
    @Bindable private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                brandSection

                credentialsSection
                    .authSurface()

                if viewModel.isSessionLimitReached {
                    sessionLimitCard
                        .authSurface(tint: .orange)
                }

                securityNoteSection
                    .authSurface()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .nexoKeyboardDismissable()
    }

    private var brandSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                AuthIconBadge(systemImage: "building.2.crop.circle.fill", tint: .accentColor, size: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Business")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Centro operativo")
                        .font(.title.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("Ventas, caja, clientes y comprobantes en una sola superficie móvil.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                AuthPill(title: "Seguro", systemImage: "lock.shield", tint: .accentColor)
                AuthPill(title: "Business", systemImage: "briefcase", tint: .secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthSectionHeader(
                icon: "person.crop.circle.badge.checkmark",
                title: "Ingreso",
                subtitle: "Usa tus credenciales para operar el negocio seleccionado."
            )

            VStack(spacing: 10) {
                AuthInputRow(
                    title: "Correo",
                    placeholder: "usuario@negocio.com",
                    text: $viewModel.email,
                    systemImage: "envelope",
                    isSecure: false,
                    keyboardType: .emailAddress
                )
                .focused($focusedField, equals: .email)
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

                AuthInputRow(
                    title: "Contraseña",
                    placeholder: "Tu contraseña",
                    text: $viewModel.password,
                    systemImage: "lock",
                    isSecure: true,
                    keyboardType: .default
                )
                .focused($focusedField, equals: .password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit { loginIfPossible() }
            }

            if let message = viewModel.errorMessage {
                AuthNoticeCard(
                    title: "No pudimos iniciar sesión",
                    message: message,
                    systemImage: "exclamationmark.triangle",
                    tint: .red
                )
            }

            Button {
                loginIfPossible()
            } label: {
                AuthActionLabel(
                    title: viewModel.isLoading ? "Ingresando…" : "Ingresar",
                    systemImage: "arrow.right.circle.fill",
                    isLoading: viewModel.isLoading
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canLogin)
        }
    }

    private var sessionLimitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthSectionHeader(
                icon: "iphone.slash",
                title: "Límite de dispositivos",
                subtitle: "Ya existe el máximo de sesiones activas para esta cuenta."
            )

            Text(viewModel.sessionLimitMessage ?? "Ya alcanzaste el máximo de dispositivos activos.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            AuthNoticeCard(
                title: "Recuperación segura",
                message: "Si el correo y la contraseña son correctos, Nexo cerrará las sesiones anteriores y dejará activo este dispositivo.",
                systemImage: "lock.rotation",
                tint: .orange
            )

            Button(role: .destructive) {
                NexoKeyboard.dismiss()
                Task { await viewModel.recoverSessionsAndLogin() }
            } label: {
                AuthActionLabel(
                    title: viewModel.isRecoveringSessions ? "Cerrando sesiones…" : "Cerrar sesiones e ingresar",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    isLoading: viewModel.isRecoveringSessions
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading || viewModel.isRecoveringSessions)
        }
    }

    private var securityNoteSection: some View {
        HStack(alignment: .top, spacing: 12) {
            AuthIconBadge(systemImage: "shield.checkered", tint: .secondary, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text("Operación protegida")
                    .font(.subheadline.weight(.semibold))

                Text("Las sesiones activas pueden revisarse y revocarse desde Cuenta → Mis sesiones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var canLogin: Bool {
        !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.password.isEmpty &&
        !viewModel.isLoading &&
        !viewModel.isRecoveringSessions
    }

    private func loginIfPossible() {
        guard canLogin else { return }
        NexoKeyboard.dismiss()
        Task { await viewModel.login() }
    }

    private enum Field {
        case email
        case password
    }
}

@MainActor
@Observable
final class AuthSessionsViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    private let authRepository: AuthRepository

    var state: State = .idle
    var sessions: [AuthUserSession] = []
    var errorMessage: String?
    var infoMessage: String?
    var isMutating = false

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func load() async {
        state = .loading
        errorMessage = nil
        infoMessage = nil

        do {
            sessions = try await authRepository.listSessions().sorted(by: sessionSort)
            state = sessions.isEmpty ? .empty : .loaded
        } catch let error as APIError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func revoke(_ session: AuthUserSession) async {
        guard !session.current else {
            errorMessage = "No puedes revocar esta sesión desde la lista. Usa Cerrar sesión."
            return
        }

        await mutate(successMessage: "Sesión revocada correctamente.") {
            _ = try await authRepository.revokeSession(
                sessionId: session.id,
                reason: "Revocar sesión desde Mis sesiones en Nexo Business"
            )
        }
    }

    func revokeAllSessions() async -> Bool {
        await mutateReturning(successMessage: "Todas las sesiones fueron revocadas.") {
            _ = try await authRepository.revokeAllSessions(
                reason: "Revocar todas las sesiones desde Mis sesiones en Nexo Business"
            )
        }
    }

    private func mutate(successMessage: String, _ operation: () async throws -> Void) async {
        _ = await mutateReturning(successMessage: successMessage, operation)
    }

    @discardableResult
    private func mutateReturning(successMessage: String, _ operation: () async throws -> Void) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }

        do {
            try await operation()
            infoMessage = successMessage
            await load()
            return true
        } catch let error as APIError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func sessionSort(_ lhs: AuthUserSession, _ rhs: AuthUserSession) -> Bool {
        if lhs.current != rhs.current { return lhs.current && !rhs.current }
        return (lhs.lastSeenAt ?? lhs.createdAt) > (rhs.lastSeenAt ?? rhs.createdAt)
    }
}

struct AuthSessionsView: View {
    @State private var viewModel: AuthSessionsViewModel
    @State private var confirmation: Confirmation?

    private let onAllSessionsRevoked: () -> Void

    init(
        viewModel: AuthSessionsViewModel,
        onAllSessionsRevoked: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onAllSessionsRevoked = onAllSessionsRevoked
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                statusSection

                messagesSection

                contentSection

                dangerSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Mis sesiones")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    if viewModel.state == .loading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isMutating || viewModel.state == .loading)
                .accessibilityLabel("Actualizar sesiones")
            }
        }
        .task { await viewModel.load() }
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

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                AuthIconBadge(systemImage: "iphone.and.arrow.forward", tint: .accentColor, size: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Seguridad de cuenta")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Dispositivos activos")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(statusDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                AuthPill(
                    title: sessionsCountText,
                    systemImage: "iphone",
                    tint: .accentColor
                )

                AuthPill(
                    title: currentSessionText,
                    systemImage: "checkmark.shield",
                    tint: currentSessionTint
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            AuthNoticeCard(
                title: "Atención",
                message: message,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
            .authSurface(tint: .red)
        }

        if let message = viewModel.infoMessage {
            AuthNoticeCard(
                title: "Listo",
                message: message,
                systemImage: "checkmark.circle",
                tint: .green
            )
            .authSurface(tint: .green)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.state {
        case .idle, .loading:
            AuthLoadingCard(
                title: "Cargando sesiones…",
                subtitle: "Revisando los dispositivos asociados a tu cuenta."
            )
            .authSurface()

        case .empty:
            AuthEmptyState(
                title: "Sin sesiones activas",
                message: "No hay dispositivos activos registrados para tu usuario.",
                systemImage: "iphone.slash"
            )
            .authSurface()

        case .failed(let message):
            VStack(alignment: .leading, spacing: 14) {
                AuthEmptyState(
                    title: "No se pudo cargar",
                    message: message,
                    systemImage: "exclamationmark.triangle"
                )

                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Reintentar", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .authSurface(tint: .red)

        case .loaded:
            VStack(alignment: .leading, spacing: 14) {
                AuthSectionHeader(
                    icon: "iphone.gen3",
                    title: "Sesiones activas",
                    subtitle: "La sesión actual aparece marcada. Revoca cualquier dispositivo desconocido."
                )

                VStack(spacing: 10) {
                    ForEach(viewModel.sessions) { session in
                        AuthSessionRow(session: session) {
                            confirmation = .revoke(session)
                        }
                        .disabled(viewModel.isMutating)
                    }
                }
            }
            .authSurface()
        }
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthSectionHeader(
                icon: "exclamationmark.shield",
                title: "Acción crítica",
                subtitle: "Úsala si perdiste un dispositivo o sospechas de acceso no autorizado."
            )

            Text("Esta acción cerrará también este dispositivo. Volverás a la pantalla de inicio de sesión.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                confirmation = .revokeAll
            } label: {
                Label("Revocar todas las sesiones", systemImage: "iphone.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isMutating || viewModel.sessions.isEmpty)
        }
        .authSurface(tint: .red)
    }

    private var statusDescription: String {
        switch viewModel.state {
        case .idle, .loading:
            return "Consultando actividad reciente y sesión actual."
        case .empty:
            return "No hay sesiones activas para mostrar."
        case .failed:
            return "No pudimos consultar las sesiones activas."
        case .loaded:
            return "Revisa dónde está abierta tu cuenta y revoca accesos cuando sea necesario."
        }
    }

    private var sessionsCountText: String {
        let count = viewModel.sessions.count
        return count == 1 ? "1 sesión" : "\(count) sesiones"
    }

    private var currentSessionText: String {
        viewModel.sessions.contains(where: \.current) ? "Actual activa" : "Actual no detectada"
    }

    private var currentSessionTint: Color {
        viewModel.sessions.contains(where: \.current) ? .green : .orange
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )
    }

    private func run(_ confirmation: Confirmation) async {
        switch confirmation {
        case .revoke(let session):
            await viewModel.revoke(session)
        case .revokeAll:
            let didRevoke = await viewModel.revokeAllSessions()
            if didRevoke { onAllSessionsRevoked() }
        }
        self.confirmation = nil
    }

    private enum Confirmation: Identifiable {
        case revoke(AuthUserSession)
        case revokeAll

        var id: String { title }

        var title: String {
            switch self {
            case .revoke: return "Revocar sesión"
            case .revokeAll: return "Revocar todas"
            }
        }

        var message: String {
            switch self {
            case .revoke:
                return "Ese dispositivo deberá iniciar sesión otra vez."
            case .revokeAll:
                return "Se cerrarán todas tus sesiones activas, incluida esta. Para entrar de nuevo usa tus credenciales."
            }
        }

        var role: ButtonRole? { .destructive }
    }
}

private struct AuthSessionRow: View {
    let session: AuthUserSession
    let revokeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AuthIconBadge(
                    systemImage: session.current ? "iphone.circle.fill" : "iphone",
                    tint: session.current ? .green : .secondary,
                    size: 38
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(session.displayDeviceName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        if session.current {
                            AuthMiniBadge(title: "Actual", tint: .green)
                        }
                    }

                    Text(session.displayVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let deviceId = session.deviceId?.trimmed.nilIfBlank {
                        Text(deviceId)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 8) {
                AuthFactRow(title: "Creada", value: session.createdAt.nexoSessionDateText, systemImage: "calendar")
                AuthFactRow(title: "Último uso", value: (session.lastSeenAt ?? session.createdAt).nexoSessionDateText, systemImage: "clock")

                if let ip = session.ipAddress?.trimmed.nilIfBlank {
                    AuthFactRow(title: "IP", value: ip, systemImage: "network")
                }
            }

            if !session.current {
                Button(role: .destructive) {
                    revokeAction()
                } label: {
                    Label("Revocar este dispositivo", systemImage: "xmark.circle")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        )
    }
}

private struct AuthSurfaceModifier: ViewModifier {
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder((tint ?? Color.primary).opacity(tint == nil ? 0.055 : 0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 3)
    }
}

private extension View {
    func authSurface(tint: Color? = nil) -> some View {
        modifier(AuthSurfaceModifier(tint: tint))
    }
}

private struct AuthSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AuthIconBadge(systemImage: icon, tint: .accentColor, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct AuthInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                input
                    .font(.body.weight(.medium))
                    .keyboardType(keyboardType)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var input: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}

private struct AuthActionLabel: View {
    let title: String
    let systemImage: String
    let isLoading: Bool

    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AuthNoticeCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct AuthLoadingCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct AuthEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AuthIconBadge(systemImage: systemImage, tint: .secondary, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AuthFactRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AuthIconBadge: View {
    let systemImage: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font((size >= 44 ? Font.title3 : Font.body).weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct AuthPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.11), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct AuthMiniBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule(style: .continuous))
    }
}

#Preview {
    LoginView(
        viewModel: LoginViewModel(
            authRepository: PreviewAuthRepository()
        )
    )
}

private extension Date {
    var nexoSessionDateText: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}
