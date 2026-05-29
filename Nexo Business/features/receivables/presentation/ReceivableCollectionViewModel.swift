//
//  ReceivableCollectionViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class ReceivableCollectionViewModel {
    public let receivable: ReceivableRecord
    public private(set) var currentCashSession: CashSession?
    public private(set) var isLoadingCash = false
    public private(set) var isSubmitting = false
    public private(set) var paymentResult: PaymentRecord?
    public private(set) var updatedReceivable: ReceivableRecord?
    public var selectedMethod: BusinessPaymentMethod = .cash
    public var amount: String
    public var reference = ""
    public var note = ""
    public var errorMessage: String?
    public var infoMessage: String?

    private let organizationId: String
    private let branchId: String
    private let effectivePermissions: Set<String>
    private let cashRepository: CashRepository
    private let receivablesRepository: ReceivablesRepository

    public init(
        organizationId: String,
        branchId: String,
        receivable: ReceivableRecord,
        effectivePermissions: Set<String>,
        cashRepository: CashRepository,
        receivablesRepository: ReceivablesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.receivable = receivable
        self.effectivePermissions = effectivePermissions
        self.cashRepository = cashRepository
        self.receivablesRepository = receivablesRepository
        self.amount = receivable.balance?.amount ?? receivable.amount.amount
    }

    public var canCollect: Bool {
        guard !isSubmitting else { return false }
        guard hasPermission([
            "business.receivables.collect",
            "receivables.collect",
            "business.payments.collect",
            "payments.collect"
        ]) else { return false }
        guard isValidAmount(amount) else { return false }

        if selectedMethod == .cash {
            return currentCashSession?.status == "open"
        }

        return true
    }

    public func load() async {
        guard !branchId.isEmpty else {
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        guard !isLoadingCash else { return }

        isLoadingCash = true
        errorMessage = nil

        defer { isLoadingCash = false }

        do {
            let response = try await cashRepository.current(
                organizationId: organizationId,
                branchId: branchId
            )
            currentCashSession = response.session
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func collect() async {
        guard canCollect else {
            errorMessage = validationMessage()
            return
        }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil

        defer { isSubmitting = false }

        do {
            let response = try await receivablesRepository.collect(
                organizationId: organizationId,
                idempotencyKey: .generate(prefix: "receivable-collect"),
                request: CollectReceivableRequest(
                    receivableId: receivable.id,
                    cashSessionId: selectedMethod == .cash ? currentCashSession?.id : nil,
                    method: selectedMethod.rawValue,
                    amount: normalized(amount),
                    reference: emptyToNil(reference),
                    note: emptyToNil(note)
                )
            )

            updatedReceivable = response.receivable
            paymentResult = response.payment
            infoMessage = response.idempotencyReplayed == true
                ? "Abono recuperado de un intento anterior."
                : "Abono registrado correctamente."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validationMessage() -> String {
        if !hasPermission(["business.receivables.collect", "receivables.collect", "business.payments.collect", "payments.collect"]) {
            return "No tienes permiso para registrar abonos."
        }

        if !isValidAmount(amount) {
            return "Ingresa un monto válido mayor a cero."
        }

        if selectedMethod == .cash && currentCashSession?.status != "open" {
            return "Necesitas una caja abierta para registrar abonos en efectivo."
        }

        return "No se puede registrar el abono con el estado actual."
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        candidates.contains { effectivePermissions.contains($0) }
    }

    private func isValidAmount(_ text: String) -> Bool {
        guard let value = Decimal(
            string: normalized(text).replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        ) else { return false }
        return value > Decimal.zero
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ text: String) -> String? {
        let value = normalized(text)
        return value.isEmpty ? nil : value
    }
}
