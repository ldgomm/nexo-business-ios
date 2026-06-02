import Foundation
import Observation

@MainActor
@Observable
final class CashDashboardViewModel {
    private(set) var state: AsyncViewState<CashSession?> = .idle
    private(set) var currentSession: CashSession?
    private(set) var lastMovement: CashMovement?

    var openingAmount = "0.00"
    var openingNote = ""
    var countedAmount = ""
    var closingNote = ""
    var movementType: CashMovementType = .inflow
    var movementAmount = ""
    var movementNote = ""
    var showsMovementConfirmation = false
    var showsCloseConfirmation = false

    var isLoading = false
    var isMutating = false
    var errorMessage: String?
    var successMessage: String?

    private let organizationId: String
    private let branchId: String
    private let permissions: Set<String>
    private let repository: CashRepository

    init(
        organizationId: String,
        branchId: String,
        permissions: Set<String>,
        cashRepository: CashRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.permissions = permissions
        self.repository = cashRepository
    }

    var isOpen: Bool {
        currentSession?.isOpen == true
    }

    var canView: Bool {
        hasAnyPermission([
            "cash.view_current",
            "business.cash.view_current",
            "cash.open",
            "business.cash.open",
            "cash.close",
            "business.cash.close"
        ])
    }

    var canOpen: Bool {
        !isOpen && hasAnyPermission(["cash.open", "business.cash.open"])
    }

    var canClose: Bool {
        isOpen && hasAnyPermission(["cash.close", "business.cash.close"])
    }

    var canPrepareClose: Bool {
        canClose && !isMutating && isValidNonNegativeAmount(countedAmount)
    }

    var canRegisterMovement: Bool {
        guard isOpen else { return false }

        switch movementType {
        case .inflow:
            return hasAnyPermission(["cash.register_inflow", "business.cash.register_inflow"])
        case .outflow:
            return hasAnyPermission(["cash.register_outflow", "business.cash.register_outflow"])
        case .adjustment:
            return hasAnyPermission(["cash.adjust", "business.cash.adjust"])
        }
    }

    var canPrepareMovement: Bool {
        canRegisterMovement && !isMutating && isValidPositiveAmount(movementAmount)
    }

    var currentExpectedAmount: MoneyAmount? {
        currentSession?.expectedAmount ?? currentSession?.openingAmount
    }

    var currentExpectedDisplay: String {
        currentExpectedAmount?.displayText ?? "USD 0.00"
    }

    var closingDifferencePreview: MoneyAmount {
        let counted = decimal(from: countedAmount) ?? Decimal(0)
        let expected = decimal(from: currentExpectedAmount?.amount ?? "0.00") ?? Decimal(0)
        return MoneyAmount(amount: formatDecimal(counted - expected))
    }

    var movementConfirmationMessage: String {
        let typeName = movementType.displayName.lowercased()
        let amount = MoneyAmount(amount: sanitizedAmount(movementAmount)).displayText
        let reason = sanitizedOptional(movementNote) ?? "Sin motivo detallado"

        return "Vas a registrar un \(typeName) manual por \(amount).\n\nEste ajuste modificará la caja y no estará asociado a una venta.\n\nMotivo: \(reason)"
    }

    var closeConfirmationMessage: String {
        "Vas a cerrar la caja con estos valores:\n\nEfectivo esperado: \(currentExpectedDisplay)\nMonto contado: \(MoneyAmount(amount: sanitizedAmount(countedAmount)).displayText)\nDiferencia: \(closingDifferencePreview.displayText)\n\nDespués de cerrar, no podrás registrar cobros en efectivo en esta caja."
    }

    func load() async {
        guard !branchId.isEmpty else {
            currentSession = nil
            state = .failed("Falta una sucursal operativa.")
            return
        }

        guard canView else {
            currentSession = nil
            state = .failed("No tienes permiso para consultar caja.")
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        state = .loading

        defer {
            isLoading = false
        }

        do {
            let response = try await repository.current(
                organizationId: organizationId,
                branchId: branchId
            )
            apply(session: response.session)
        } catch let error as APIError {
            currentSession = nil
            state = .failed(error.userMessage)
        } catch {
            currentSession = nil
            state = .failed(error.localizedDescription)
        }
    }

    func openCash() async {
        guard !isMutating else { return }
        guard canOpen else {
            errorMessage = isOpen
                ? "La caja ya está abierta."
                : "No tienes permiso para abrir caja."
            return
        }
        guard validateAmount(openingAmount, fieldName: "monto inicial", allowsZero: true) else { return }

        isMutating = true
        errorMessage = nil
        successMessage = nil

        defer {
            isMutating = false
        }

        do {
            let identity = BusinessMutationIdentity.generate(prefix: "cash-open")
            let response = try await repository.open(
                organizationId: organizationId,
                idempotencyKey: identity.idempotencyKey,
                request: OpenCashSessionRequest(
                    branchId: branchId,
                    openingAmount: sanitizedAmount(openingAmount),
                    note: sanitizedOptional(openingNote),
                    requestId: identity.requestId
                )
            )

            apply(session: response.session)
            successMessage = response.idempotencyReplayed == true
                ? "Caja recuperada sin duplicar la operación."
                : "Caja abierta correctamente."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareMovementConfirmation() {
        guard !isMutating else { return }
        guard let session = currentSession, session.isOpen else {
            errorMessage = "Debes tener una caja abierta para registrar ajustes."
            return
        }
        guard canRegisterMovement else {
            errorMessage = "No tienes permiso para registrar este ajuste."
            return
        }
        guard validateAmount(movementAmount, fieldName: "monto del ajuste", allowsZero: false) else { return }

        errorMessage = nil
        successMessage = nil
        showsMovementConfirmation = true
    }

    func registerMovement() async {
        showsMovementConfirmation = false

        guard !isMutating else { return }
        guard let session = currentSession, session.isOpen else {
            errorMessage = "Debes tener una caja abierta para registrar ajustes."
            return
        }
        guard canRegisterMovement else {
            errorMessage = "No tienes permiso para registrar este ajuste."
            return
        }
        guard validateAmount(movementAmount, fieldName: "monto del ajuste", allowsZero: false) else { return }

        isMutating = true
        errorMessage = nil
        successMessage = nil

        defer {
            isMutating = false
        }

        do {
            let identity = BusinessMutationIdentity.generate(prefix: "cash-movement")
            let response = try await repository.registerMovement(
                organizationId: organizationId,
                cashSessionId: session.id,
                idempotencyKey: identity.idempotencyKey,
                request: RegisterCashMovementRequest(
                    type: movementType,
                    amount: sanitizedAmount(movementAmount),
                    note: sanitizedOptional(movementNote),
                    requestId: identity.requestId
                )
            )

            lastMovement = response.movement
            if let updatedSession = response.session {
                apply(session: updatedSession, preserveCountedAmount: false)
            }

            movementAmount = ""
            movementNote = ""
            successMessage = response.idempotencyReplayed == true
                ? "Ajuste recuperado sin duplicar la operación."
                : "Ajuste manual registrado correctamente."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareCloseConfirmation() {
        guard !isMutating else { return }
        guard let session = currentSession, session.isOpen else {
            errorMessage = "No hay una caja abierta para cerrar."
            return
        }
        guard canClose else {
            errorMessage = "No tienes permiso para cerrar caja."
            return
        }

        prefillClosingFields(from: session, forceIfBlank: true)
        guard validateAmount(countedAmount, fieldName: "monto contado", allowsZero: true) else { return }

        errorMessage = nil
        successMessage = nil
        showsCloseConfirmation = true
    }

    func closeCash() async {
        showsCloseConfirmation = false

        guard !isMutating else { return }
        guard let session = currentSession, session.isOpen else {
            errorMessage = "No hay una caja abierta para cerrar."
            return
        }
        guard canClose else {
            errorMessage = "No tienes permiso para cerrar caja."
            return
        }
        guard validateAmount(countedAmount, fieldName: "monto contado", allowsZero: true) else { return }

        isMutating = true
        errorMessage = nil
        successMessage = nil

        defer {
            isMutating = false
        }

        do {
            let identity = BusinessMutationIdentity.generate(prefix: "cash-close")
            let response = try await repository.close(
                organizationId: organizationId,
                cashSessionId: session.id,
                idempotencyKey: identity.idempotencyKey,
                request: CloseCashSessionRequest(
                    countedAmount: sanitizedAmount(countedAmount),
                    note: sanitizedOptional(closingNote),
                    requestId: identity.requestId
                )
            )

            apply(session: response.session, preserveCountedAmount: true)
            successMessage = response.idempotencyReplayed == true
                ? "Cierre recuperado sin duplicar la operación."
                : "Caja cerrada correctamente."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func useExpectedAmountForClosing() {
        countedAmount = currentExpectedAmount?.amount ?? "0.00"
        if closingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            closingNote = "Cierre de caja"
        }
    }

    private func apply(session: CashSession?, preserveCountedAmount: Bool = false) {
        currentSession = session
        state = .loaded(session)

        guard let session, session.isOpen else { return }
        prefillClosingFields(from: session, forceIfBlank: !preserveCountedAmount)
    }

    private func prefillClosingFields(from session: CashSession, forceIfBlank: Bool) {
        let shouldFillAmount = forceIfBlank || sanitizedAmount(countedAmount).isEmpty
        if shouldFillAmount {
            countedAmount = session.expectedAmount?.amount ?? session.openingAmount?.amount ?? "0.00"
        }

        if closingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            closingNote = "Cierre de caja"
        }
    }

    private func hasAnyPermission(_ candidates: [String]) -> Bool {
        candidates.contains { permissions.contains($0) }
    }

    private func validateAmount(_ value: String, fieldName: String, allowsZero: Bool) -> Bool {
        let sanitized = sanitizedAmount(value)

        guard !sanitized.isEmpty else {
            errorMessage = "Ingresa el \(fieldName)."
            return false
        }

        guard let decimal = decimal(from: sanitized) else {
            errorMessage = "El \(fieldName) no es válido."
            return false
        }

        if allowsZero {
            guard decimal >= 0 else {
                errorMessage = "El \(fieldName) no es válido."
                return false
            }
        } else {
            guard decimal > 0 else {
                errorMessage = "El \(fieldName) debe ser mayor a cero."
                return false
            }
        }

        return true
    }

    private func isValidNonNegativeAmount(_ value: String) -> Bool {
        guard let decimal = decimal(from: sanitizedAmount(value)) else { return false }
        return decimal >= 0
    }

    private func isValidPositiveAmount(_ value: String) -> Bool {
        guard let decimal = decimal(from: sanitizedAmount(value)) else { return false }
        return decimal > 0
    }

    private func decimal(from value: String) -> Decimal? {
        Decimal(
            string: sanitizedAmount(value),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func sanitizedAmount(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
    }

    private func sanitizedOptional(_ value: String) -> String? {
        let sanitized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? nil : sanitized
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return String(format: "%.2f", number.doubleValue)
    }
}
