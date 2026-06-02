//
//  PreviewCustomersData.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum PreviewCustomersData {
    static let customers: [BusinessCustomer] = [
        BusinessCustomerPresentation.finalConsumer,
        BusinessCustomer(
            id: "cus_maria",
            displayName: "María Fernanda López",
            identificationType: .cedula,
            identificationNumber: "1712345678",
            email: "maria@nexo.test",
            phone: "0999999999",
            address: "Quito",
            status: "active",
            createdAt: Date().addingTimeInterval(-7200),
            updatedAt: Date().addingTimeInterval(-3600)
        ),
        BusinessCustomer(
            id: "cus_altos_ruc",
            displayName: "Cliente RUC Demo",
            identificationType: .ruc,
            identificationNumber: "1799999999001",
            email: "cliente.ruc@nexo.test",
            phone: "022222222",
            address: "Tambillo",
            status: "active",
            createdAt: Date().addingTimeInterval(-86_000),
            updatedAt: Date().addingTimeInterval(-86_000)
        )
    ]

    static let searchResponse = CustomersSearchResponse(
        customers: customers
    )

    static let createdCustomer = BusinessCustomer(
        id: "cus_created_preview",
        displayName: "Cliente creado preview",
        identificationType: .cedula,
        identificationNumber: "1700000001",
        email: "nuevo@nexo.test",
        phone: "0988888888",
        address: "Machachi",
        status: "active",
        createdAt: Date(),
        updatedAt: Date()
    )

    static let createResponse = CustomerResponse(
        customer: createdCustomer,
        idempotencyReplayed: false
    )
}
