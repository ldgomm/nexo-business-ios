//
//  CustomerPickerViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class CustomerPickerViewModelTests: XCTestCase {
    func testSearchRequiresPermission() async {
        let repository = CustomersRepositorySpy()
        let viewModel = CustomerPickerViewModel(
            organizationId: "org_1",
            effectivePermissions: [],
            customersRepository: repository
        )

        await viewModel.search()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar clientes.")
        XCTAssertEqual(repository.searchCalls, 0)
    }

    func testSearchLoadsCustomers() async {
        let repository = CustomersRepositorySpy(
            searchResponse: CustomersSearchResponse(
                customers: [
                    BusinessCustomer(
                        id: "cus_1",
                        displayName: "Cliente Uno",
                        identificationType: .cedula,
                        identificationNumber: "1712345678"
                    )
                ]
            )
        )
        let viewModel = CustomerPickerViewModel(
            organizationId: "org_1",
            effectivePermissions: ["customers.view"],
            customersRepository: repository
        )
        viewModel.query = "cliente"

        await viewModel.search()

        XCTAssertEqual(repository.lastSearchQuery, "cliente")
        XCTAssertEqual(viewModel.customers.count, 1)
        XCTAssertEqual(viewModel.customers[0].id, "cus_1")
    }

    func testAddOrReplaceKeepsCustomerUnique() {
        let repository = CustomersRepositorySpy()
        let viewModel = CustomerPickerViewModel(
            organizationId: "org_1",
            effectivePermissions: ["customers.view"],
            customersRepository: repository
        )

        viewModel.addOrReplace(
            BusinessCustomer(
                id: "cus_1",
                displayName: "Cliente Uno",
                identificationType: .cedula,
                identificationNumber: "1712345678"
            )
        )
        viewModel.addOrReplace(
            BusinessCustomer(
                id: "cus_1",
                displayName: "Cliente Actualizado",
                identificationType: .cedula,
                identificationNumber: "1712345678"
            )
        )

        XCTAssertEqual(viewModel.customers.count, 1)
        XCTAssertEqual(viewModel.customers[0].displayName, "Cliente Actualizado")
    }
}

final class CustomersRepositorySpy: CustomersRepository, @unchecked Sendable {
    var searchCalls = 0
    var createCalls = 0
    var lastSearchQuery: String?
    var searchQueries: [String] = []
    var lastCreateRequest: CreateCustomerRequest?
    var lastCreateIdempotencyKey: IdempotencyKey?
    let searchResponse: CustomersSearchResponse
    let createResponse: CustomerResponse

    init(
        searchResponse: CustomersSearchResponse = CustomersSearchResponse(customers: []),
        createResponse: CustomerResponse = CustomerResponse(
            customer: BusinessCustomer(
                id: "cus_created",
                displayName: "Creado",
                identificationType: .cedula,
                identificationNumber: "1712345678"
            )
        )
    ) {
        self.searchResponse = searchResponse
        self.createResponse = createResponse
    }

    func search(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CustomersSearchResponse {
        searchCalls += 1
        lastSearchQuery = query
        searchQueries.append(query)
        return searchResponse
    }

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateCustomerRequest
    ) async throws -> CustomerResponse {
        createCalls += 1
        lastCreateIdempotencyKey = idempotencyKey
        lastCreateRequest = request
        return createResponse
    }
}

@MainActor
final class CustomerDetail360ViewModelTests: XCTestCase {
    func testLoadBuildsCustomer360FromSalesReceivablesAndDocuments() async {
        let customer = BusinessCustomer(
            id: "cus_001",
            displayName: "José Ruiz",
            identificationType: .cedula,
            identificationNumber: "1712345678",
            email: "jose@nexo.test"
        )
        let matchingSale = BusinessSale(
            id: "sale_001",
            number: "SALE-001",
            organizationId: "org_1",
            branchId: "branch_1",
            customerId: "cus_001",
            customerName: "José Ruiz",
            customer: BusinessSaleCustomer(id: "cus_001", displayName: "José Ruiz", identification: "1712345678"),
            status: "confirmed",
            paymentStatus: "paid",
            documentStatus: "authorized",
            totals: BusinessSaleTotals(subtotalWithoutTaxes: MoneyAmount(amount: "27.60"), discountTotal: MoneyAmount(amount: "0.00"), taxTotal: MoneyAmount(amount: "0.00"), grandTotal: MoneyAmount(amount: "27.60")),
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let otherSale = BusinessSale(
            id: "sale_other",
            number: "SALE-OTHER",
            organizationId: "org_1",
            branchId: "branch_1",
            customerId: "cus_other",
            customerName: "Otro Cliente",
            customer: BusinessSaleCustomer(id: "cus_other", displayName: "Otro Cliente", identification: "1799999999001"),
            status: "confirmed",
            paymentStatus: "paid",
            totals: BusinessSaleTotals(subtotalWithoutTaxes: MoneyAmount(amount: "10.00"), discountTotal: MoneyAmount(amount: "0.00"), taxTotal: MoneyAmount(amount: "0.00"), grandTotal: MoneyAmount(amount: "10.00")),
            createdAt: Date(timeIntervalSince1970: 900)
        )
        let receivable = ReceivableRecord(
            id: "recv_001",
            saleId: "sale_001",
            customerId: "cus_001",
            customerName: "José Ruiz",
            status: "open",
            amount: MoneyAmount(amount: "27.60"),
            balance: MoneyAmount(amount: "12.60"),
            createdAt: Date(timeIntervalSince1970: 1_010)
        )
        let document = BusinessDocument(
            id: "doc_001",
            saleId: "sale_001",
            type: "electronic_invoice",
            status: "AUTHORIZED",
            number: "001-001-000000001",
            createdAt: Date(timeIntervalSince1970: 1_020),
            documentId: "doc_001",
            customerName: "José Ruiz",
            customerIdentification: "1712345678",
            total: "27.60"
        )

        let sales = Customer360SalesHistoryRepositorySpy(sales: [matchingSale, otherSale])
        let receivables = Customer360ReceivablesRepositorySpy(receivables: [receivable])
        let documents = Customer360DocumentsRepositorySpy(documentsBySaleId: ["sale_001": [document]])
        let viewModel = CustomerDetail360ViewModel(
            organizationId: "org_1",
            branchId: "branch_1",
            revisions: BusinessRevisions(catalogRevision: "cat_1", taxConfigurationRevision: "tax_1"),
            customer: customer,
            effectivePermissions: [
                "customers.view",
                "sales.view",
                "receivables.view",
                "documents.view"
            ],
            salesHistoryRepository: sales,
            receivablesRepository: receivables,
            documentsRepository: documents
        )

        await viewModel.refresh()

        XCTAssertEqual(receivables.lastCustomerId, "cus_001")
        XCTAssertEqual(viewModel.sales.map(\.id), ["sale_001"])
        XCTAssertEqual(viewModel.receivables.map(\.id), ["recv_001"])
        XCTAssertEqual(viewModel.documents.map(\.id), ["doc_001"])
        XCTAssertEqual(viewModel.openReceivables.count, 1)
        XCTAssertEqual(viewModel.pendingBalanceDisplay, "USD 12.60")
        XCTAssertEqual(viewModel.salesTotalDisplay, "USD 27.60")
        XCTAssertEqual(documents.requestedSaleIds, ["sale_001"])
    }


    func testCustomer360SeedFactoryAllowsRealSaleAndBlocksFinalConsumer() {
        let identifiedSale = BusinessSale(
            id: "sale_real",
            number: "SALE-REAL",
            organizationId: "org_1",
            branchId: "branch_1",
            customerId: "cus_real",
            customerName: "José Ruiz",
            customer: BusinessSaleCustomer(id: "cus_real", displayName: "José Ruiz", identification: "1712345678"),
            status: "confirmed",
            paymentStatus: "paid",
            totals: BusinessSaleTotals(subtotalWithoutTaxes: MoneyAmount(amount: "20.00"), discountTotal: MoneyAmount(amount: "0.00"), taxTotal: MoneyAmount(amount: "0.00"), grandTotal: MoneyAmount(amount: "20.00"))
        )
        let finalConsumerSale = BusinessSale(
            id: "sale_final",
            number: "SALE-FINAL",
            organizationId: "org_1",
            branchId: "branch_1",
            customerId: nil,
            customerName: "Consumidor final",
            customer: BusinessSaleCustomer(id: nil, displayName: "Consumidor final", identification: "9999999999999"),
            status: "confirmed",
            paymentStatus: "pending",
            totals: BusinessSaleTotals(subtotalWithoutTaxes: MoneyAmount(amount: "5.00"), discountTotal: MoneyAmount(amount: "0.00"), taxTotal: MoneyAmount(amount: "0.00"), grandTotal: MoneyAmount(amount: "5.00"))
        )

        XCTAssertEqual(identifiedSale.customer360Seed?.id, "cus_real")
        XCTAssertEqual(identifiedSale.customer360Seed?.identificationType, .cedula)
        XCTAssertNil(finalConsumerSale.customer360Seed)
    }

    func testCustomer360SeedFactoryAllowsReceivableWithRealCustomer() {
        let receivable = ReceivableRecord(
            id: "recv_001",
            saleId: "sale_001",
            customerId: "cus_001",
            customerName: "José Ruiz",
            status: "open",
            amount: MoneyAmount(amount: "27.60"),
            balance: MoneyAmount(amount: "12.60")
        )
        let missingCustomerReceivable = ReceivableRecord(
            id: "recv_missing",
            saleId: "sale_002",
            customerId: nil,
            customerName: nil,
            status: "open",
            amount: MoneyAmount(amount: "10.00"),
            balance: MoneyAmount(amount: "10.00")
        )

        XCTAssertEqual(receivable.customer360Seed?.id, "cus_001")
        XCTAssertEqual(receivable.customer360Seed?.displayName, "José Ruiz")
        XCTAssertNil(missingCustomerReceivable.customer360Seed)
    }

    func testLoadSkipsRepositoriesWithoutPermissions() async {
        let customer = BusinessCustomer(
            id: "cus_001",
            displayName: "José Ruiz",
            identificationType: .cedula,
            identificationNumber: "1712345678"
        )
        let sales = Customer360SalesHistoryRepositorySpy(sales: [])
        let receivables = Customer360ReceivablesRepositorySpy(receivables: [])
        let documents = Customer360DocumentsRepositorySpy(documentsBySaleId: [:])
        let viewModel = CustomerDetail360ViewModel(
            organizationId: "org_1",
            branchId: "branch_1",
            revisions: BusinessRevisions(catalogRevision: "cat_1", taxConfigurationRevision: "tax_1"),
            customer: customer,
            effectivePermissions: ["customers.view"],
            salesHistoryRepository: sales,
            receivablesRepository: receivables,
            documentsRepository: documents
        )

        await viewModel.refresh()

        XCTAssertEqual(sales.searchCalls, 0)
        XCTAssertEqual(receivables.listCalls, 0)
        XCTAssertEqual(documents.requestedSaleIds, [])
        XCTAssertEqual(viewModel.infoMessage, "Este cliente todavía no tiene ventas, cuentas por cobrar ni comprobantes en Nexo.")
    }
}

private final class Customer360SalesHistoryRepositorySpy: SalesHistoryRepository, @unchecked Sendable {
    var searchCalls = 0
    var requestedQueries: [String] = []
    let sales: [BusinessSale]

    init(sales: [BusinessSale]) {
        self.sales = sales
    }

    func searchSales(
        organizationId: String,
        request: SalesHistorySearchRequest
    ) async throws -> BusinessSalesHistoryResponse {
        searchCalls += 1
        requestedQueries.append(request.query ?? "")
        return BusinessSalesHistoryResponse(sales: sales, total: sales.count, hasMore: false)
    }
}

private final class Customer360ReceivablesRepositorySpy: ReceivablesRepository, @unchecked Sendable {
    var listCalls = 0
    var lastCustomerId: String?
    let receivables: [ReceivableRecord]

    init(receivables: [ReceivableRecord]) {
        self.receivables = receivables
    }

    func list(
        organizationId: String,
        customerId: String?,
        status: String?,
        limit: Int
    ) async throws -> ReceivablesListResponse {
        listCalls += 1
        lastCustomerId = customerId
        return ReceivablesListResponse(receivables: receivables, total: receivables.count, hasMore: false)
    }

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateReceivableRequest
    ) async throws -> ReceivableResponse { fatalError("Not needed") }

    func collect(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CollectReceivableRequest
    ) async throws -> ReceivableCollectionResponse { fatalError("Not needed") }
}

private final class Customer360DocumentsRepositorySpy: BusinessDocumentsRepository, @unchecked Sendable {
    var requestedSaleIds: [String] = []
    let documentsBySaleId: [String: [BusinessDocument]]

    init(documentsBySaleId: [String: [BusinessDocument]]) {
        self.documentsBySaleId = documentsBySaleId
    }

    func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse {
        requestedSaleIds.append(saleId)
        return BusinessDocumentsResponse(documents: documentsBySaleId[saleId] ?? [])
    }

    func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse { fatalError("Not needed") }

    func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse { fatalError("Not needed") }

    func issueElectronicInvoice(
        organizationId: String,
        saleId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: IssueBusinessElectronicDocumentRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse { fatalError("Not needed") }

    func retryElectronicInvoiceReception(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RetryBusinessElectronicInvoiceReceptionRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse { fatalError("Not needed") }

    func retryElectronicInvoiceAuthorization(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RetryBusinessElectronicInvoiceAuthorizationRequest
    ) async throws -> BusinessElectronicDocumentActionResponse { fatalError("Not needed") }

    func regenerateElectronicDocumentRide(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RegenerateBusinessElectronicDocumentRideRequest
    ) async throws -> BusinessElectronicDocumentActionResponse { fatalError("Not needed") }

    func listElectronicDocuments(
        organizationId: String,
        filters: BusinessElectronicDocumentFilters
    ) async throws -> BusinessElectronicDocumentsResponse { fatalError("Not needed") }

    func electronicDocumentDetail(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessElectronicDocumentDetailEnvelopeResponse { fatalError("Not needed") }

    func electronicDocumentRide(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse { fatalError("Not needed") }

    func electronicDocumentXml(
        organizationId: String,
        documentId: String,
        authorizedOnly: Bool
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse { fatalError("Not needed") }

    func electronicDocumentTimeline(
        organizationId: String,
        documentId: String,
        limit: Int
    ) async throws -> BusinessElectronicDocumentTimelineResponse { fatalError("Not needed") }

    func resendElectronicDocumentEmail(
        organizationId: String,
        documentId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessDocumentEmailResendRequest
    ) async throws -> BusinessDocumentEmailResendResponse { fatalError("Not needed") }
}
