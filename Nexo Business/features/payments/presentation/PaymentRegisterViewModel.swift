import Foundation
import Observation

enum PaymentRegisterMode: String, CaseIterable, Identifiable, Sendable, Hashable {
    case cash
    case transfer
    case card
    case credit

    var id: String { rawValue }

    var title: String {
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

    var systemImage: String {
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

    var paymentMethod: BusinessPaymentMethod? {
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
final class PaymentRegisterViewModel {
    let sale: BusinessSale
    private(set) var currentCashSession: CashSession?
    private(set) var selectedCustomer: BusinessCustomer?
    private(set) var isLoadingCash = false
    private(set) var isSubmitting = false
    private(set) var paymentResult: PaymentRecord?
    private(set) var receivableResult: ReceivableRecord?
    var selectedMode: PaymentRegisterMode = .cash
    var amount: String
    var reference = ""
    var note = ""
    var customerId: String
    var dueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var useDueDate = false
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let effectivePermissions: Set<String>

    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository

    init(
        organizationId: String,
        branchId: String,
        sale: BusinessSale,
        effectivePermissions: Set<String>,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        customersRepository: CustomersRepository = UnavailableCustomersRepository()
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

    var canSubmitPayment: Bool {
        guard !isSubmitting, selectedMode != .credit else { return false }
        guard hasPaymentPermission else { return false }
        guard SaleStatusPresentation.canCollect(status: sale.status) else { return false }
        guard PaymentStatusPresentation.canCollect(status: sale.paymentStatus) else { return false }
        guard isValidAmount(amount) else { return false }

        if selectedMode == .cash {
            return currentCashSession?.isOpen == true
        }

        return true
    }

    var canCreateReceivable: Bool {
        guard !isSubmitting, selectedMode == .credit else { return false }
        guard hasReceivablePermission else { return false }
        guard SaleStatusPresentation.canCollect(status: sale.status) else { return false }
        guard PaymentStatusPresentation.canCollect(status: sale.paymentStatus) else { return false }
        guard isValidAmount(amount) else { return false }
        return !normalized(customerId).isEmpty
    }

    var shouldShowCashWarning: Bool {
        selectedMode == .cash && currentCashSession?.isOpen != true
    }

    var hasPaymentPermission: Bool {
        hasPermission([
            "business.payments.collect",
            "payments.collect",
            "business.payments.register",
            "payments.register"
        ])
    }

    var hasReceivablePermission: Bool {
        hasPermission([
            "business.receivables.create",
            "receivables.create",
            "business.payments.mark_as_credit",
            "payments.mark_as_credit"
        ])
    }

    var amountMoney: String {
        "\(sale.totals.grandTotal.currency) \(amount)"
    }

    func selectCustomer(_ customer: BusinessCustomer) {
        selectedCustomer = customer
        customerId = customer.identificationType == .finalConsumer ? "" : customer.id
        resetResultMessages()
    }

    func clearCustomer() {
        selectedCustomer = nil
        customerId = sale.customerId ?? ""
        resetResultMessages()
    }

    func load() async {
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
            print("❌ Preview APIError:", error)
            errorMessage = error.userMessage
        } catch {
            print("❌ Preview Error:", error)
            errorMessage = error.localizedDescription
        }
    }

    func submit() async {
        if selectedMode == .credit {
            await createReceivable()
        } else {
            await registerPayment()
        }
    }

    func registerPayment() async {
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
            let identity = BusinessMutationIdentity.generate(prefix: "payment-register")
            let response = try await paymentsRepository.register(
                organizationId: organizationId,
                idempotencyKey: identity.idempotencyKey,
                request: RegisterPaymentRequest(
                    saleId: sale.id,
                    cashSessionId: selectedMode == .cash ? currentCashSession?.id : nil,
                    method: method.rawValue,
                    amount: normalized(amount),
                    reference: emptyToNil(reference),
                    note: emptyToNil(note),
                    requestId: identity.requestId
                )
            )

            paymentResult = response.payment
            if let cashSession = response.cashSession {
                currentCashSession = cashSession
            }
            infoMessage = response.idempotencyReplayed == true
                ? "Cobro recuperado de un intento anterior."
                : "Cobro registrado correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createReceivable() async {
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

    func resetResultMessages() {
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

        if selectedMode == .cash && currentCashSession?.isOpen != true {
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
