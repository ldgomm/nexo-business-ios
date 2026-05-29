//
//  PaymentRegisterViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

public enum PaymentRegisterMode: String, CaseIterable, Identifiable, Sendable, Hashable {
    case cash
    case transfer
    case card
    case credit

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cash:
            return "Efectivo"
        case .transfer:
            return "Transferencia"
        case .card:
            return "Tarjeta"
        case .credit:
            return "Cuenta por cobrar"
        }
    }

    public var systemImage: String {
        switch self {
        case .cash:
            return "banknote"
        case .transfer:
            return "arrow.left.arrow.right"
        case .card:
            return "creditcard"
        case .credit:
            return "person.crop.circle.badge.clock"
        }
    }

    public var paymentMethod: BusinessPaymentMethod? {
        switch self {
        case .cash:
            return .cash
        case .transfer:
            return .transfer
        case .card:
            return .card
        case .credit:
            return nil
        }
    }
}

@MainActor
@Observable
public final class PaymentRegisterViewModel {
    public let sale: BusinessSale
    public private(set) var currentCashSession: CashSession?
    public private(set) var isLoadingCash = false
    public private(set) var isSubmitting = false
    public private(set) var paymentResult: PaymentRecord?
    public private(set) var receivableResult: ReceivableRecord?
    public var selectedMode: PaymentRegisterMode = .cash
    public var amount: String
    public var reference = ""
    public var note = ""
    public var customerId: String
    public var dueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    public var useDueDate = false
    public var errorMessage: String?
    public var infoMessage: String?

    private let organizationId: String
    private let branchId: String
    private let effectivePermissions: Set<String>
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository

    public init(
        organizationId: String,
        branchId: String,
        sale: BusinessSale,
        effectivePermissions: Set<String>,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.sale = sale
        self.effectivePermissions = effectivePermissions
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.amount = sale.totals.grandTotal.amount
        self.customerId = sale.customerId ?? ""
    }

    public var canSubmitPayment: Bool {
        guard !isSubmitting, selectedMode != .credit else { return false }
        guard hasPaymentPermission else { return false }
        guard SaleStatusPresentation.canCollect(status: sale.status) else { return false }
        guard PaymentStatusPresentation.canCollect(status: sale.paymentStatus) else { return false }
        guard isValidAmount(amount) else { return false }

        if selectedMode == .cash {
            return currentCashSession?.status == "open"
        }

        return true
    }

    public var canCreateReceivable: Bool {
        guard !isSubmitting, selectedMode == .credit else { return false }
        guard hasReceivablePermission else { return false }
        guard SaleStatusPresentation.canCollect(status: sale.status) else { return false }
        guard PaymentStatusPresentation.canCollect(status: sale.paymentStatus) else { return false }
        guard isValidAmount(amount) else { return false }
        return !normalized(customerId).isEmpty
    }

    public var shouldShowCashWarning: Bool {
        selectedMode == .cash && currentCashSession?.status != "open"
    }

    public var hasPaymentPermission: Bool {
        hasPermission([
            "business.payments.collect",
            "payments.collect",
            "business.payments.register",
            "payments.register"
        ])
    }

    public var hasReceivablePermission: Bool {
        hasPermission([
            "business.receivables.create",
            "receivables.create",
            "business.payments.mark_as_credit",
            "payments.mark_as_credit"
        ])
    }

    public var amountMoney: String {
        "\(sale.totals.grandTotal.currency) \(amount)"
    }

    public func load() async {
        guard !branchId.isEmpty else {
            errorMessage = "Falta sucursal activa. Actualiza el contexto."
            return
        }

        guard !isLoadingCash else { return }

        isLoadingCash = true
        errorMessage = nil

        defer {
            isLoadingCash = false
        }

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

    public func submit() async {
        if selectedMode == .credit {
            await createReceivable()
        } else {
            await registerPayment()
        }
    }

    public func registerPayment() async {
        guard selectedMode != .credit else {
            errorMessage = "Selecciona efectivo, transferencia o tarjeta para registrar un cobro."
            return
        }

        guard canSubmitPayment else {
            errorMessage = paymentValidationMessage()
            return
        }

        guard let method = selectedMode.paymentMethod else {
            errorMessage = "Método de cobro no válido."
            return
        }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isSubmitting = false
        }

        do {
            let response = try await paymentsRepository.register(
                organizationId: organizationId,
                idempotencyKey: .generate(prefix: "payment-register"),
                request: RegisterPaymentRequest(
                    saleId: sale.id,
                    cashSessionId: selectedMode == .cash ? currentCashSession?.id : nil,
                    method: method.rawValue,
                    amount: normalized(amount),
                    reference: emptyToNil(reference),
                    note: emptyToNil(note)
                )
            )

            paymentResult = response.payment
            infoMessage = response.idempotencyReplayed == true
                ? "Cobro recuperado de un intento anterior."
                : "Cobro registrado correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createReceivable() async {
        guard canCreateReceivable else {
            errorMessage = receivableValidationMessage()
            return
        }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isSubmitting = false
        }

        do {
            let response = try await receivablesRepository.create(
                organizationId: organizationId,
                idempotencyKey: .generate(prefix: "receivable-create"),
                request: CreateReceivableRequest(
                    saleId: sale.id,
                    customerId: normalized(customerId),
                    amount: normalized(amount),
                    dueDate: useDueDate ? dueDate : nil,
                    note: emptyToNil(note)
                )
            )

            receivableResult = response.receivable
            infoMessage = response.idempotencyReplayed == true
                ? "Cuenta por cobrar recuperada de un intento anterior."
                : "Cuenta por cobrar creada correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func resetResultMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func paymentValidationMessage() -> String {
        if !hasPaymentPermission {
            return "No tienes permiso para registrar cobros."
        }

        if !isValidAmount(amount) {
            return "Ingresa un monto válido mayor a cero."
        }

        if selectedMode == .cash && currentCashSession?.status != "open" {
            return "Necesitas una caja abierta para cobrar en efectivo."
        }

        return "No se puede registrar el cobro con el estado actual."
    }

    private func receivableValidationMessage() -> String {
        if !hasReceivablePermission {
            return "No tienes permiso para crear cuentas por cobrar."
        }

        if !isValidAmount(amount) {
            return "Ingresa un monto válido mayor a cero."
        }

        if normalized(customerId).isEmpty {
            return "Para dejar una venta por cobrar necesitas un cliente identificado."
        }

        return "No se puede crear la cuenta por cobrar con el estado actual."
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        candidates.contains { effectivePermissions.contains($0) }
    }

    private func isValidAmount(_ text: String) -> Bool {
        guard let value = decimal(from: text) else { return false }
        return value > Decimal.zero
    }

    private func decimal(from text: String) -> Decimal? {
        Decimal(
            string: normalized(text).replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ text: String) -> String? {
        let value = normalized(text)
        return value.isEmpty ? nil : value
    }
}
