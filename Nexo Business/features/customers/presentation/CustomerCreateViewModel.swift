//
//  CustomerCreateViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

struct CustomerDuplicateCandidate: Equatable, Identifiable, Sendable {
    let customer: BusinessCustomer
    let reason: String
    let matchedValue: String

    var id: String { customer.id }

    var title: String {
        "Ya existe un cliente parecido"
    }

    var message: String {
        "Encontramos a \(customer.displayName) con \(reason.lowercased()) \(matchedValue). Usa ese cliente para no partir su historial, ventas, comprobantes y cuentas por cobrar."
    }
}

@MainActor
@Observable
class CustomerCreateViewModel {
    var identificationType: BusinessCustomerIdentificationType = .cedula {
        didSet { clearDuplicateWarningForEdition() }
    }
    var identificationNumber = "" {
        didSet { clearDuplicateWarningForEdition() }
    }
    var displayName = "" {
        didSet { clearDuplicateWarningForEdition() }
    }
    var email = "" {
        didSet { clearDuplicateWarningForEdition() }
    }
    var phone = "" {
        didSet { clearDuplicateWarningForEdition() }
    }
    var address = ""
    private(set) var createdCustomer: BusinessCustomer?
    private(set) var duplicateCandidate: CustomerDuplicateCandidate?
    private(set) var isSaving = false
    var errorMessage: String?
    var infoMessage: String?

    private let organizationId: String
    private let repository: CustomersRepository

    init(
        organizationId: String,
        customersRepository: CustomersRepository
    ) {
        self.organizationId = organizationId
        self.repository = customersRepository
    }

    var canSave: Bool {
        !isSaving &&
        !normalized(displayName).isEmpty &&
        !normalized(identificationNumber).isEmpty
    }

    var canUseDuplicateCandidate: Bool {
        duplicateCandidate != nil && !isSaving
    }

    func save() async -> BusinessCustomer? {
        await save(allowDuplicate: false)
    }

    func saveIgnoringDuplicateWarning() async -> BusinessCustomer? {
        await save(allowDuplicate: true)
    }

    func useDuplicateCandidate() -> BusinessCustomer? {
        guard let customer = duplicateCandidate?.customer else { return nil }
        createdCustomer = customer
        errorMessage = nil
        infoMessage = "Usando cliente existente para mantener su historial junto."
        return customer
    }

    private func save(allowDuplicate: Bool) async -> BusinessCustomer? {
        guard canSave else {
            errorMessage = validationMessage()
            return nil
        }

        isSaving = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isSaving = false
        }

        if !allowDuplicate, let duplicate = await findDuplicateCandidate() {
            duplicateCandidate = duplicate
            infoMessage = "Revisa el cliente existente antes de crear otro."
            return nil
        }

        do {
            let response = try await repository.create(
                organizationId: organizationId,
                idempotencyKey: .generate(prefix: "customer-create"),
                request: CreateCustomerRequest(
                    displayName: normalized(displayName),
                    identificationType: identificationType,
                    identificationNumber: normalized(identificationNumber),
                    email: emptyToNil(email),
                    phone: emptyToNil(phone),
                    address: emptyToNil(address)
                )
            )

            duplicateCandidate = nil
            createdCustomer = response.customer
            infoMessage = response.idempotencyReplayed == true
                ? "Cliente recuperado de un intento anterior."
                : "Cliente creado correctamente."
            return response.customer
        } catch let error as APIError {
            errorMessage = error.userMessage
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func findDuplicateCandidate() async -> CustomerDuplicateCandidate? {
        guard identificationType != .finalConsumer else { return nil }

        let identification = normalizedIdentification(identificationNumber, type: identificationType)
        if !identification.isEmpty,
           let match = await findCandidate(query: identification, matching: { customer in
               guard customer.identificationType != .finalConsumer else { return false }
               return customer.identificationType == identificationType &&
                   normalizedIdentification(customer.identificationNumber, type: customer.identificationType) == identification
           }) {
            return CustomerDuplicateCandidate(
                customer: match,
                reason: identificationType.displayName,
                matchedValue: normalized(identificationNumber)
            )
        }

        let emailKey = normalizedEmail(email)
        if !emailKey.isEmpty,
           let match = await findCandidate(query: emailKey, matching: { customer in
               guard customer.identificationType != .finalConsumer else { return false }
               return normalizedEmail(customer.email ?? "") == emailKey
           }) {
            return CustomerDuplicateCandidate(
                customer: match,
                reason: "Correo",
                matchedValue: emailKey
            )
        }

        let phoneKey = normalizedPhone(phone)
        if phoneKey.count >= 7,
           let match = await findCandidate(query: normalized(phone), matching: { customer in
               guard customer.identificationType != .finalConsumer else { return false }
               return normalizedPhone(customer.phone ?? "") == phoneKey
           }) {
            return CustomerDuplicateCandidate(
                customer: match,
                reason: "Teléfono",
                matchedValue: normalized(phone)
            )
        }

        return nil
    }

    private func findCandidate(
        query: String,
        matching predicate: (BusinessCustomer) -> Bool
    ) async -> BusinessCustomer? {
        do {
            let response = try await repository.search(
                organizationId: organizationId,
                query: query,
                limit: 8
            )
            return response.customers.first(where: predicate)
        } catch {
            return nil
        }
    }

    private func validationMessage() -> String {
        if normalized(displayName).isEmpty {
            return "Ingresa el nombre del cliente."
        }

        if normalized(identificationNumber).isEmpty {
            return "Ingresa la identificación del cliente."
        }

        return "Revisa los datos del cliente."
    }

    private func clearDuplicateWarningForEdition() {
        duplicateCandidate = nil
        if infoMessage == "Revisa el cliente existente antes de crear otro." {
            infoMessage = nil
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = normalized(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedIdentification(_ value: String, type: BusinessCustomerIdentificationType) -> String {
        let trimmed = normalized(value)
        switch type {
        case .cedula, .ruc, .finalConsumer:
            return trimmed.filter { $0.isNumber }
        case .passport, .foreign, .unknown:
            return trimmed
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
        }
    }

    private func normalizedEmail(_ value: String) -> String {
        normalized(value).lowercased()
    }

    private func normalizedPhone(_ value: String) -> String {
        normalized(value).filter { $0.isNumber }
    }
}
