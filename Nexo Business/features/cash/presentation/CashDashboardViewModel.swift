//
//  CashDashboardViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class CashDashboardViewModel {
    public private(set) var state: AsyncViewState<CashSession?> = .idle
    public private(set) var currentSession: CashSession?
    public private(set) var lastMovement: CashMovement?

    public var openingAmount = "0.00"
    public var openingNote = ""
    public var countedAmount = ""
    public var closingNote = ""
    public var movementType: CashMovementType = .inflow
    public var movementAmount = ""
    public var movementNote = ""

    public var isLoading = false
    public var isMutating = false
    public var errorMessage: String?
    public var successMessage: String?

    private let organizationId: String
    private let branchId: String
    private let permissions: Set<String>
    private let repository: CashRepository

    public init(
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

    public var isOpen: Bool {
        currentSession?.status == "open"
    }

    public var canView: Bool {
        hasAnyPermission([
            "cash.view_current",
            "business.cash.view_current",
            "cash.open",
            "business.cash.open",
            "cash.close",
            "business.cash.close"
        ])
    }

    public var canOpen: Bool {
        !isOpen && hasAnyPermission(["cash.open", "business.cash.open"])
    }

    public var canClose: Bool {
        isOpen && hasAnyPermission(["cash.close", "business.cash.close"])
    }

    public var canRegisterMovement: Bool {
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

    public func load() async {
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
            currentSession = response.session
            state = .loaded(response.session)
        } catch let error as APIError {
            currentSession = nil
            state = .failed(error.userMessage)
        } catch {
            currentSession = nil
            state = .failed(error.localizedDescription)
        }
    }

    public func openCash() async {
        guard !isMutating else { return }
        guard canOpen else {
            errorMessage = isOpen
                ? "La caja ya está abierta."
                : "No tienes permiso para abrir caja."
            return
        }
        guard validateAmount(openingAmount, fieldName: "monto inicial") else { return }

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

            currentSession = response.session
            state = .loaded(response.session)
            successMessage = response.idempotencyReplayed == true
                ? "Caja recuperada sin duplicar la operación."
                : "Caja abierta correctamente."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func registerMovement() async {
        guard !isMutating else { return }
        guard let session = currentSession, session.status == "open" else {
            errorMessage = "Debes tener una caja abierta para registrar movimientos."
            return
        }
        guard canRegisterMovement else {
            errorMessage = "No tienes permiso para registrar este movimiento."
            return
        }
        guard validateAmount(movementAmount, fieldName: "monto del movimiento") else { return }

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
                currentSession = updatedSession
                state = .loaded(updatedSession)
            }

            movementAmount = ""
            movementNote = ""
            successMessage = response.idempotencyReplayed == true
                ? "Movimiento recuperado sin duplicar la operación."
                : "Movimiento registrado correctamente."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func closeCash() async {
        guard !isMutating else { return }
        guard let session = currentSession, session.status == "open" else {
            errorMessage = "No hay una caja abierta para cerrar."
            return
        }
        guard canClose else {
            errorMessage = "No tienes permiso para cerrar caja."
            return
        }
        guard validateAmount(countedAmount, fieldName: "monto contado") else { return }

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

            currentSession = response.session
            state = .loaded(response.session)
            successMessage = response.idempotencyReplayed == true
                ? "Cierre recuperado sin duplicar la operación."
                : "Caja cerrada correctamente."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hasAnyPermission(_ candidates: [String]) -> Bool {
        candidates.contains { permissions.contains($0) }
    }

    private func validateAmount(_ value: String, fieldName: String) -> Bool {
        let sanitized = sanitizedAmount(value)

        guard !sanitized.isEmpty else {
            errorMessage = "Ingresa el \(fieldName)."
            return false
        }

        guard let decimal = Decimal(string: sanitized), decimal >= 0 else {
            errorMessage = "El \(fieldName) no es válido."
            return false
        }

        return true
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
}
