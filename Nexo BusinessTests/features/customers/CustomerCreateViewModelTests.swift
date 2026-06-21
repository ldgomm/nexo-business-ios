//
//  CustomerCreateViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class CustomerCreateViewModelTests: XCTestCase {
    func testSaveRequiresNameAndIdentification() async {
        let repository = CustomersRepositorySpy()
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )

        let customer = await viewModel.save()

        XCTAssertNil(customer)
        XCTAssertEqual(viewModel.errorMessage, "Ingresa el nombre del cliente.")
        XCTAssertNil(repository.lastCreateRequest)
    }

    func testSaveCreatesCustomerWithIdempotencyKey() async {
        let expected = BusinessCustomer(
            id: "cus_1",
            displayName: "Cliente Uno",
            identificationType: .cedula,
            identificationNumber: "1712345678",
            email: "cliente@nexo.test"
        )
        let repository = CustomersRepositorySpy(
            createResponse: CustomerResponse(
                customer: expected,
                idempotencyReplayed: false
            )
        )
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )
        viewModel.displayName = " Cliente Uno "
        viewModel.identificationType = .cedula
        viewModel.identificationNumber = " 1712345678 "
        viewModel.email = " cliente@nexo.test "

        let customer = await viewModel.save()

        XCTAssertEqual(customer, expected)
        XCTAssertEqual(repository.lastCreateRequest?.displayName, "Cliente Uno")
        XCTAssertEqual(repository.lastCreateRequest?.identificationNumber, "1712345678")
        XCTAssertEqual(repository.lastCreateRequest?.email, "cliente@nexo.test")
        XCTAssertTrue(repository.lastCreateIdempotencyKey?.rawValue.hasPrefix("customer-create-") == true)
        XCTAssertEqual(viewModel.infoMessage, "Cliente creado correctamente.")
    }

    func testSaveStopsBeforeCreateWhenIdentificationDuplicateExists() async {
        let existing = BusinessCustomer(
            id: "cus_existing",
            displayName: "José Ruiz",
            identificationType: .cedula,
            identificationNumber: "1712345678",
            email: "jose@nexo.test",
            phone: "0999999999"
        )
        let repository = CustomersRepositorySpy(
            searchResponse: CustomersSearchResponse(customers: [existing])
        )
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )
        viewModel.displayName = "Jose Ruiz Nuevo"
        viewModel.identificationType = .cedula
        viewModel.identificationNumber = "171-234-5678"

        let customer = await viewModel.save()

        XCTAssertNil(customer)
        XCTAssertEqual(repository.searchCalls, 1)
        XCTAssertEqual(repository.createCalls, 0)
        XCTAssertEqual(viewModel.duplicateCandidate?.customer, existing)
        XCTAssertEqual(viewModel.duplicateCandidate?.reason, "Cédula")
        XCTAssertEqual(viewModel.infoMessage, "Revisa el cliente existente antes de crear otro.")
    }

    func testUseDuplicateCandidateReturnsExistingCustomerWithoutCreating() async {
        let existing = BusinessCustomer(
            id: "cus_existing",
            displayName: "José Ruiz",
            identificationType: .cedula,
            identificationNumber: "1712345678"
        )
        let repository = CustomersRepositorySpy(
            searchResponse: CustomersSearchResponse(customers: [existing])
        )
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )
        viewModel.displayName = "Jose Ruiz Nuevo"
        viewModel.identificationType = .cedula
        viewModel.identificationNumber = "1712345678"

        _ = await viewModel.save()
        let selected = viewModel.useDuplicateCandidate()

        XCTAssertEqual(selected, existing)
        XCTAssertEqual(repository.createCalls, 0)
        XCTAssertEqual(viewModel.createdCustomer, existing)
        XCTAssertEqual(viewModel.infoMessage, "Usando cliente existente para mantener su historial junto.")
    }

    func testSaveIgnoringDuplicateWarningCreatesAnyway() async {
        let existing = BusinessCustomer(
            id: "cus_existing",
            displayName: "José Ruiz",
            identificationType: .cedula,
            identificationNumber: "1712345678"
        )
        let created = BusinessCustomer(
            id: "cus_created",
            displayName: "José Ruiz Nuevo",
            identificationType: .cedula,
            identificationNumber: "1712345678"
        )
        let repository = CustomersRepositorySpy(
            searchResponse: CustomersSearchResponse(customers: [existing]),
            createResponse: CustomerResponse(customer: created)
        )
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )
        viewModel.displayName = "José Ruiz Nuevo"
        viewModel.identificationType = .cedula
        viewModel.identificationNumber = "1712345678"

        _ = await viewModel.save()
        let customer = await viewModel.saveIgnoringDuplicateWarning()

        XCTAssertEqual(customer, created)
        XCTAssertEqual(repository.createCalls, 1)
        XCTAssertNil(viewModel.duplicateCandidate)
    }

    func testDuplicateGuardMatchesEmailIgnoringCaseAndSpaces() async {
        let existing = BusinessCustomer(
            id: "cus_email",
            displayName: "Cliente Email",
            identificationType: .cedula,
            identificationNumber: "1700000001",
            email: "cliente@nexo.test"
        )
        let repository = CustomersRepositorySpy(
            searchResponse: CustomersSearchResponse(customers: [existing])
        )
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )
        viewModel.displayName = "Cliente Duplicado"
        viewModel.identificationType = .cedula
        viewModel.identificationNumber = "1711111111"
        viewModel.email = " CLIENTE@NEXO.TEST "

        let customer = await viewModel.save()

        XCTAssertNil(customer)
        XCTAssertEqual(repository.createCalls, 0)
        XCTAssertEqual(viewModel.duplicateCandidate?.customer, existing)
        XCTAssertEqual(viewModel.duplicateCandidate?.reason, "Correo")
        XCTAssertEqual(repository.searchQueries, ["1711111111", "cliente@nexo.test"])
    }

    func testDuplicateGuardIgnoresFinalConsumerCandidate() async {
        let repository = CustomersRepositorySpy(
            searchResponse: CustomersSearchResponse(customers: [BusinessCustomerPresentation.finalConsumer])
        )
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )
        viewModel.displayName = "Cliente Real"
        viewModel.identificationType = .cedula
        viewModel.identificationNumber = "9999999999999"

        let customer = await viewModel.save()

        XCTAssertNotNil(customer)
        XCTAssertEqual(repository.createCalls, 1)
        XCTAssertNil(viewModel.duplicateCandidate)
    }

}
