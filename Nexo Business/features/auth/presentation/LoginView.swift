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

    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nexo Business")
                    .font(.largeTitle.bold())

                Text("Opera ventas, caja y comprobantes desde el móvil.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Correo", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()

            SecureField("Contraseña", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if viewModel.isSessionLimitReached {
                sessionLimitCard
            }

            Button {
                Task { await viewModel.login() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Ingresar")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.email.isEmpty ||
                viewModel.password.isEmpty ||
                viewModel.isLoading ||
                viewModel.isRecoveringSessions
            )

            Spacer()
        }
        .padding(24)
        .nexoKeyboardDismissable()
    }

    private var sessionLimitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Máximo de dispositivos alcanzado", systemImage: "iphone.slash")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(viewModel.sessionLimitMessage ?? "Ya alcanzaste el máximo de dispositivos activos.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Para proteger tu negocio, Nexo solo permitirá continuar si tu correo y contraseña son correctos. Se cerrarán las sesiones anteriores y este dispositivo quedará activo.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                Task { await viewModel.recoverSessionsAndLogin() }
            } label: {
                if viewModel.isRecoveringSessions {
                    ProgressView()
                } else {
                    Label("Cerrar sesiones e ingresar", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading || viewModel.isRecoveringSessions)
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    LoginView(
        viewModel: LoginViewModel(
            authRepository: PreviewAuthRepository()
        )
    )
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
        List {
            statusSection
            contentSection
            dangerSection
        }
        .navigationTitle("Mis sesiones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isMutating)
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

    @ViewBuilder
    private var statusSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.state {
        case .idle, .loading:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando sesiones…")
                        .foregroundStyle(.secondary)
                }
            }

        case .empty:
            Section {
                ContentUnavailableView(
                    "Sin sesiones activas",
                    systemImage: "iphone.slash",
                    description: Text("No hay sesiones activas registradas para tu usuario.")
                )
            }

        case .failed(let message):
            Section {
                ContentUnavailableView(
                    "No se pudo cargar",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }

        case .loaded:
            Section {
                ForEach(viewModel.sessions) { session in
                    AuthSessionRow(session: session) {
                        confirmation = .revoke(session)
                    }
                    .disabled(viewModel.isMutating)
                }
            } header: {
                Text("Dispositivos activos")
            } footer: {
                Text("La sesión actual aparece marcada. Si ves un dispositivo desconocido, revócalo y avisa al administrador del negocio.")
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                confirmation = .revokeAll
            } label: {
                Label("Revocar todas las sesiones", systemImage: "iphone.slash")
            }
            .disabled(viewModel.isMutating || viewModel.sessions.isEmpty)
        } footer: {
            Text("Esta acción cerrará también este dispositivo. Volverás a la pantalla de inicio de sesión.")
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: session.current ? "iphone.circle.fill" : "iphone")
                    .font(.title3)
                    .foregroundStyle(session.current ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(session.displayDeviceName)
                            .font(.headline)
                        if session.current {
                            Text("Actual")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.14), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }

                    Text(session.displayVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let deviceId = session.deviceId?.trimmed.nilIfBlank {
                        Text(deviceId)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Creada: \(session.createdAt.nexoSessionDateText)")
                Text("Último uso: \((session.lastSeenAt ?? session.createdAt).nexoSessionDateText)")
                if let ip = session.ipAddress?.trimmed.nilIfBlank {
                    Text("IP: \(ip)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !session.current {
                Button(role: .destructive) {
                    revokeAction()
                } label: {
                    Label("Revocar este dispositivo", systemImage: "xmark.circle")
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }
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
