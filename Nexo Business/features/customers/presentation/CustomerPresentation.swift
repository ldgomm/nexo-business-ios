//
//  BusinessCustomerPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessCustomerPresentation {
    public static let finalConsumer = BusinessCustomer(
        id: "cus_final_consumer",
        displayName: "Consumidor final",
        identificationType: .finalConsumer,
        identificationNumber: "9999999999999",
        email: nil,
        phone: nil,
        address: nil,
        status: "active",
        createdAt: nil,
        updatedAt: nil
    )

    public static func subtitle(for customer: BusinessCustomer) -> String {
        if customer.identificationType == .finalConsumer {
            return "Venta sin datos del cliente"
        }

        let type = customer.identificationType.displayName
        let identification = customer.identificationNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if identification.isEmpty {
            return type
        }

        return "\(type) • \(identification)"
    }

    public static func displayName(for customer: BusinessCustomer?) -> String {
        customer?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            ?? finalConsumer.displayName
    }

    public static func identificationText(for customer: BusinessCustomer?) -> String {
        guard let customer else {
            return subtitle(for: finalConsumer)
        }
        return subtitle(for: customer)
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
