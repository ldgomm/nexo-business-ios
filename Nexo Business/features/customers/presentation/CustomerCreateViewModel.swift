//
//  CustomerCreateViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class CustomerCreateViewModel {
    var identificationType: BusinessCustomerIdentificationType = .cedula
    var identificationNumber = ""
    var displayName = ""
    var email = ""
    var phone = ""
    var address = ""
    private(set) var createdCustomer: BusinessCustomer?
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

    func save() async -> BusinessCustomer? {
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

    private func validationMessage() -> String {
        if normalized(displayName).isEmpty {
            return "Ingresa el nombre del cliente."
        }

        if normalized(identificationNumber).isEmpty {
            return "Ingresa la identificación del cliente."
        }

        return "Revisa los datos del cliente."
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = normalized(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
