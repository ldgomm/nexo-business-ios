//
//  BusinessSupplierStatementViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSupplierStatementViewModelTests: XCTestCase {
    func testLoadRequiresActivePurchasesModuleBeforeNetworkCall() async {
        let client = QueuedSupplierStatementsAPIClient(responses: [Self.emptyStatementJSON])
        let viewModel = makeViewModel(
            activeModules: [],
            permissions: [BusinessProcurementPermission.supplierStatementsView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "El módulo Compras no está activo para esta organización."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testLoadRequiresStatementPermissionBeforeNetworkCall() async {
        let client = QueuedSupplierStatementsAPIClient(responses: [Self.emptyStatementJSON])
        let viewModel = makeViewModel(permissions: [], client: client)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.errorMessage,
            "No tienes permiso para consultar estados de cuenta de proveedores."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testExportRequiresViewAndExactExportPermissionBeforeNetworkCall() async {
        let client = QueuedSupplierStatementsAPIClient(
            responses: [],
            dataResponses: [Self.statementCSVResponse]
        )
        let withoutExport = makeViewModel(
            permissions: [BusinessProcurementPermission.supplierStatementsView],
            client: client
        )

        await withoutExport.exportCSV()

        XCTAssertFalse(withoutExport.canExportCSV)
        XCTAssertEqual(
            withoutExport.errorMessage,
            "No tienes permiso para exportar estados de cuenta de proveedores."
        )
        XCTAssertNil(withoutExport.downloadedCSVFile)
        XCTAssertTrue(client.capturedDataRequests.isEmpty)

        let withoutView = makeViewModel(
            permissions: [BusinessProcurementPermission.supplierStatementsExport],
            client: client
        )

        await withoutView.exportCSV()

        XCTAssertFalse(withoutView.canExportCSV)
        XCTAssertEqual(
            withoutView.errorMessage,
            "No tienes permiso para consultar estados de cuenta de proveedores."
        )
        XCTAssertTrue(client.capturedDataRequests.isEmpty)
    }

    func testExportUsesCurrentContextFiltersWithoutPagingAndKeepsServerFile() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nexo-statement-view-model-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let client = QueuedSupplierStatementsAPIClient(
            responses: [],
            dataResponses: [Self.statementCSVResponse]
        )
        let viewModel = makeViewModel(
            permissions: [
                BusinessProcurementPermission.supplierStatementsView,
                BusinessProcurementPermission.supplierStatementsExport,
            ],
            client: client,
            downloadDirectory: tempDirectory
        )
        viewModel.currency = " usd "
        viewModel.from = " 2026-07-01 "
        viewModel.to = " 2026-07-31 "
        viewModel.asOf = " 2026-07-31 "

        await viewModel.exportCSV()

        XCTAssertTrue(viewModel.canExportCSV)
        XCTAssertFalse(viewModel.isExportingCSV)
        XCTAssertFalse(viewModel.lastFailureWasExport)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(
            viewModel.infoMessage,
            "CSV autoritativo del servidor listo para compartir."
        )
        let request = try XCTUnwrap(client.capturedDataRequests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.supplierStatementCSV("sup_1")
        )
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.queryDictionary["branchId"], "br_1")
        XCTAssertEqual(request.queryDictionary["currency"], "USD")
        XCTAssertEqual(request.queryDictionary["from"], "2026-07-01")
        XCTAssertEqual(request.queryDictionary["to"], "2026-07-31")
        XCTAssertEqual(request.queryDictionary["asOf"], "2026-07-31")
        XCTAssertNil(request.queryDictionary["limit"])
        XCTAssertNil(request.queryDictionary["cursor"])

        let file = try XCTUnwrap(viewModel.downloadedCSVFile)
        XCTAssertTrue(file.localURL.isFileURL)
        XCTAssertEqual(file.fileName, "supplier-statement.csv")
        XCTAssertEqual(file.contentType, "text/csv; charset=utf-8")
        XCTAssertEqual(file.sizeBytes, Self.statementCSVResponse.data.count)
        XCTAssertEqual(
            file.responseHeaders["X-Nexo-Export-Version"],
            "27R.J.v1"
        )
        XCTAssertEqual(
            try Data(contentsOf: file.localURL),
            Self.statementCSVResponse.data
        )

        viewModel.from = "2026-07-02"

        XCTAssertNil(viewModel.downloadedCSVFile)
        XCTAssertNil(viewModel.infoMessage)
    }

    func testExportStepUpErrorIsExplicitAndDoesNotExposeAFile() async {
        let client = QueuedSupplierStatementsAPIClient(
            responses: [],
            dataFailures: [
                .server(
                    statusCode: 403,
                    code: "step_up_required",
                    message: "additional authentication required",
                    requestId: "req_statement_export"
                ),
            ]
        )
        let viewModel = makeViewModel(
            permissions: [
                BusinessProcurementPermission.supplierStatementsView,
                BusinessProcurementPermission.supplierStatementsExport,
            ],
            client: client
        )

        await viewModel.exportCSV()

        XCTAssertEqual(client.capturedDataRequests.count, 1)
        XCTAssertNil(viewModel.downloadedCSVFile)
        XCTAssertTrue(viewModel.lastFailureWasExport)
        XCTAssertEqual(
            viewModel.errorMessage,
            "La sesión necesita confirmación adicional para exportar este estado de cuenta. Vuelve a autenticarte e inténtalo nuevamente."
        )
    }

    func testConcurrentExportAttemptsIssueOneDownload() async {
        let client = QueuedSupplierStatementsAPIClient(
            responses: [],
            dataResponses: [Self.statementCSVResponse],
            dataDelayNanoseconds: 20_000_000
        )
        let viewModel = makeViewModel(
            permissions: [
                BusinessProcurementPermission.supplierStatementsView,
                BusinessProcurementPermission.supplierStatementsExport,
            ],
            client: client
        )

        let firstExport = Task { await viewModel.exportCSV() }
        while !viewModel.isExportingCSV {
            await Task.yield()
        }
        await viewModel.exportCSV()
        await firstExport.value

        XCTAssertEqual(client.capturedDataRequests.count, 1)
        XCTAssertNotNil(viewModel.downloadedCSVFile)
        XCTAssertFalse(viewModel.isExportingCSV)
    }

    func testSearchUsesSupplierContextCurrencyDatesCutoffAndFirstPageBoundary() async throws {
        let client = QueuedSupplierStatementsAPIClient(responses: [Self.firstPageJSON])
        let viewModel = makeViewModel(client: client)
        viewModel.currency = " usd "
        viewModel.from = " 2026-07-01 "
        viewModel.to = " 2026-07-31 "
        viewModel.asOf = " 2026-07-31 "

        await viewModel.search()

        XCTAssertEqual(viewModel.lines.map(\.id), ["stmt_1"])
        XCTAssertEqual(viewModel.openingBalance?.amount, "10.00")
        XCTAssertEqual(viewModel.closingBalance?.amount, "60.00")
        XCTAssertEqual(viewModel.statementCurrency, "USD")
        XCTAssertEqual(viewModel.statementFrom, "2026-07-01")
        XCTAssertEqual(viewModel.statementTo, "2026-07-31")
        XCTAssertEqual(viewModel.statementAsOf, "2026-07-31")
        XCTAssertEqual(viewModel.nextCursor, "cursor_2")
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertNil(viewModel.errorMessage)

        let request = try XCTUnwrap(client.capturedRequests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(
            request.path,
            BusinessProcurementRoutes.supplierStatement("sup_1")
        )
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.branchId], "br_1")
        XCTAssertEqual(request.queryDictionary["branchId"], "br_1")
        XCTAssertEqual(request.queryDictionary["currency"], "USD")
        XCTAssertEqual(request.queryDictionary["from"], "2026-07-01")
        XCTAssertEqual(request.queryDictionary["to"], "2026-07-31")
        XCTAssertEqual(request.queryDictionary["asOf"], "2026-07-31")
        XCTAssertEqual(request.queryDictionary["limit"], "100")
        XCTAssertNil(request.queryDictionary["cursor"])
    }

    func testInvalidCurrencyAndDateStopBeforeNetworkCall() async {
        let client = QueuedSupplierStatementsAPIClient(responses: [Self.emptyStatementJSON])
        let viewModel = makeViewModel(client: client)
        viewModel.currency = "US"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La moneda debe usar un código de tres letras, por ejemplo USD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)

        viewModel.currency = "USD"
        viewModel.from = "31/07/2026"
        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial debe usar el formato AAAA-MM-DD."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testInvertedRangeAndCutoffStopBeforeNetworkCall() async {
        let client = QueuedSupplierStatementsAPIClient(responses: [Self.emptyStatementJSON])
        let viewModel = makeViewModel(client: client)
        viewModel.from = "2026-08-01"
        viewModel.to = "2026-07-31"

        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha inicial no puede ser posterior a la final."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)

        viewModel.from = "2026-07-01"
        viewModel.to = "2026-07-31"
        viewModel.asOf = "2026-07-30"
        await viewModel.search()

        XCTAssertEqual(
            viewModel.errorMessage,
            "La fecha final no puede ser posterior a la fecha de corte."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testPaginationKeepsServerBalancesAndAppendsUniqueLinesWithoutLocalRecalculation() async throws {
        let client = QueuedSupplierStatementsAPIClient(
            responses: [Self.firstPageJSON, Self.secondPageJSON]
        )
        let viewModel = makeViewModel(client: client)
        viewModel.from = "2026-07-01"
        viewModel.to = "2026-07-31"
        viewModel.asOf = "2026-07-31"

        await viewModel.loadIfNeeded()
        let firstLine = try XCTUnwrap(viewModel.lines.first)
        await viewModel.loadNextPageIfNeeded(currentLine: firstLine)

        XCTAssertEqual(viewModel.lines.map(\.id), ["stmt_1", "stmt_2"])
        XCTAssertEqual(viewModel.openingBalance?.amount, "10.00")
        XCTAssertEqual(viewModel.closingBalance?.amount, "40.00")
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertNil(viewModel.nextCursor)
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests[1].queryDictionary["cursor"],
            "cursor_2"
        )
    }

    func testMismatchedServerContextIsRejectedWithoutMixingStatementTruth() async {
        let client = QueuedSupplierStatementsAPIClient(
            responses: [Self.mismatchedStatementJSON]
        )
        let viewModel = makeViewModel(client: client)

        await viewModel.loadIfNeeded()

        XCTAssertTrue(viewModel.lines.isEmpty)
        XCTAssertNil(viewModel.openingBalance)
        XCTAssertNil(viewModel.closingBalance)
        XCTAssertFalse(viewModel.hasLoaded)
        XCTAssertEqual(
            viewModel.errorMessage,
            "El servidor devolvió un estado de cuenta de otro contexto. No se mezclaron saldos ni movimientos."
        )
    }

    func testEmptyStatementAndAPIErrorHaveExplicitMessages() async {
        let emptyClient = QueuedSupplierStatementsAPIClient(
            responses: [Self.emptyStatementJSON]
        )
        let emptyViewModel = makeViewModel(client: emptyClient)

        await emptyViewModel.loadIfNeeded()

        XCTAssertTrue(emptyViewModel.lines.isEmpty)
        XCTAssertEqual(
            emptyViewModel.infoMessage,
            "No encontramos movimientos para este proveedor y estos filtros."
        )
        XCTAssertTrue(emptyViewModel.hasLoaded)

        let failingClient = QueuedSupplierStatementsAPIClient(
            responses: [],
            failures: [
                .server(
                    statusCode: 503,
                    code: "procurement_temporarily_unavailable",
                    message: "upstream exception",
                    requestId: "req_statement"
                ),
            ]
        )
        let failingViewModel = makeViewModel(client: failingClient)

        await failingViewModel.loadIfNeeded()

        XCTAssertEqual(
            failingViewModel.errorMessage,
            "El servidor no respondió correctamente. Inténtalo nuevamente en unos segundos."
        )
        XCTAssertFalse(failingViewModel.hasLoaded)
    }

    func testStatementPresentationMapsBusinessSourceDateAndAuditLabels() throws {
        let response = try JSONDecoder.nexoDefault.decode(
            BusinessProcurementSupplierStatementResponse.self,
            from: Data(Self.firstPageJSON.utf8)
        )
        let line = try XCTUnwrap(response.lines.first)

        XCTAssertEqual(
            line.businessSupplierStatementSourceName,
            "Documento de proveedor"
        )
        XCTAssertEqual(
            line.businessSupplierStatementOccurredAtText,
            "2026-07-15"
        )
        XCTAssertEqual(
            line.businessSupplierStatementAuditName,
            "Evidencia del documento"
        )
        XCTAssertEqual(
            line.runningBalance.businessDisplayText(
                locale: Locale(identifier: "en_US")
            ),
            "$60.00"
        )
    }

    func testStatementSurfaceKeepsBackendBalanceAndTraceabilityBoundariesExplicit() throws {
        let viewSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierStatementView.swift"
        )
        let viewModelSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSupplierStatementViewModel.swift"
        )

        XCTAssertTrue(viewSource.contains("Estado de cuenta operativo"))
        XCTAssertTrue(viewSource.contains("Saldo inicial"))
        XCTAssertTrue(viewSource.contains("Saldo final"))
        XCTAssertTrue(viewSource.contains("Saldo corriente"))
        XCTAssertTrue(viewSource.contains("proceden del backend"))
        XCTAssertTrue(viewSource.contains("no los suma ni recalcula localmente"))
        XCTAssertTrue(viewSource.contains("Referencia de origen verificada por el backend"))
        XCTAssertTrue(viewSource.contains("los identificadores internos no se muestran"))
        XCTAssertTrue(viewSource.contains("Reintentar"))
        XCTAssertTrue(viewSource.contains("Reintentar exportación"))
        XCTAssertTrue(viewSource.contains("Exportar estado de cuenta CSV"))
        XCTAssertTrue(viewSource.contains("cantidades e importes canónicos"))
        XCTAssertTrue(viewSource.contains("no reconstruye movimientos ni recalcula saldos"))
        XCTAssertTrue(viewSource.contains("ShareLink(item: file.localURL)"))
        XCTAssertTrue(viewSource.contains("no sustituye un libro o estado contable oficial"))
        XCTAssertTrue(
            viewModelSource.contains(
                "BusinessProcurementPermission.supplierStatementsExport"
            )
        )
        XCTAssertTrue(viewModelSource.contains("downloadSupplierStatementCSV"))
        XCTAssertTrue(viewModelSource.contains("filters: filters"))
        XCTAssertTrue(viewModelSource.contains("retryLastFailure"))
        XCTAssertFalse(viewSource.contains("Text(line.sourceId)"))
        XCTAssertFalse(viewSource.contains("Text(line.auditResourceId)"))
        XCTAssertFalse(viewSource.contains(".reduce("))
        XCTAssertFalse(viewModelSource.contains(".reduce("))
        XCTAssertFalse(viewSource.contains("Data("))
        XCTAssertFalse(viewSource.contains(".write("))
        XCTAssertFalse(viewSource.contains("NavigationLink"))
    }

    private func makeViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [
            BusinessProcurementPermission.supplierStatementsView,
        ],
        client: QueuedSupplierStatementsAPIClient,
        downloadDirectory: URL? = nil
    ) -> BusinessSupplierStatementViewModel {
        BusinessSupplierStatementViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            supplierId: "sup_1",
            supplierName: "Ferretería Uno",
            currency: "USD",
            activeModules: activeModules,
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(
                apiClient: client,
                downloadDirectory: downloadDirectory
            )
        )
    }

    private func sourceText(at repositoryRelativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(repositoryRelativePath),
            encoding: .utf8
        )
    }

    private static var statementCSVResponse: APIDataResponse {
        APIDataResponse(
            data: Data(
                "fecha,origen,descripcion,cargo,abono,saldo,moneda\n".utf8
            ),
            statusCode: 200,
            headers: [
                "Content-Type": "text/csv; charset=utf-8",
                "Content-Disposition": "attachment; filename=\"../supplier-statement.csv\"",
                "X-Nexo-Export-Type": "supplier_statement",
                "X-Nexo-Export-Version": "27R.J.v1",
            ]
        )
    }

    private static var firstPageJSON: String {
        statementJSON(
            lines: [
                lineJSON(
                    id: "stmt_1",
                    occurredAt: "2026-07-15T15:00:00Z",
                    sourceType: "SUPPLIER_DOCUMENT",
                    description: "Factura 001-001-0000123",
                    charge: "50.00",
                    credit: "0.00",
                    runningBalance: "60.00"
                ),
            ],
            openingBalance: "10.00",
            closingBalance: "60.00",
            nextCursor: "cursor_2",
            hasMore: true
        )
    }

    private static var secondPageJSON: String {
        statementJSON(
            lines: [
                lineJSON(
                    id: "stmt_1",
                    occurredAt: "2026-07-15T15:00:00Z",
                    sourceType: "SUPPLIER_DOCUMENT",
                    description: "Factura 001-001-0000123",
                    charge: "50.00",
                    credit: "0.00",
                    runningBalance: "60.00"
                ),
                lineJSON(
                    id: "stmt_2",
                    occurredAt: "2026-07-31T12:00:00Z",
                    sourceType: "SUPPLIER_PAYMENT",
                    description: "Pago PAG-0001",
                    charge: "0.00",
                    credit: "20.00",
                    runningBalance: "40.00",
                    auditResourceType: "supplier_payment"
                ),
            ],
            openingBalance: "10.00",
            closingBalance: "40.00",
            nextCursor: nil,
            hasMore: false
        )
    }

    private static var emptyStatementJSON: String {
        statementJSON(
            lines: [],
            openingBalance: "0.00",
            closingBalance: "0.00",
            nextCursor: nil,
            hasMore: false
        )
    }

    private static var mismatchedStatementJSON: String {
        statementJSON(
            supplierId: "sup_other",
            lines: [],
            openingBalance: "0.00",
            closingBalance: "0.00",
            nextCursor: nil,
            hasMore: false
        )
    }

    private static func statementJSON(
        supplierId: String = "sup_1",
        lines: [String],
        openingBalance: String,
        closingBalance: String,
        nextCursor: String?,
        hasMore: Bool
    ) -> String {
        let encodedCursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "supplierId":"\(supplierId)","branchId":"br_1","currency":"USD",
          "from":"2026-07-01","to":"2026-07-31","asOf":"2026-07-31",
          "openingBalance":{"amount":"\(openingBalance)","currency":"USD"},
          "lines":[\(lines.joined(separator: ","))],
          "closingBalance":{"amount":"\(closingBalance)","currency":"USD"},
          "nextCursor":\(encodedCursor),"hasMore":\(hasMore)
        }
        """
    }

    private static func lineJSON(
        id: String,
        occurredAt: String,
        sourceType: String,
        description: String,
        charge: String,
        credit: String,
        runningBalance: String,
        auditResourceType: String = "supplier_document"
    ) -> String {
        return """
        {
          "id":"\(id)","occurredAt":"\(occurredAt)","sourceType":"\(sourceType)",
          "sourceId":"source_\(id)","description":"\(description)",
          "charge":{"amount":"\(charge)","currency":"USD"},
          "credit":{"amount":"\(credit)","currency":"USD"},
          "runningBalance":{"amount":"\(runningBalance)","currency":"USD"},
          "currency":"USD","auditResourceType":"\(auditResourceType)",
          "auditResourceId":"audit_\(id)"
        }
        """
    }
}

private struct CapturedSupplierStatementRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }
}

private final class QueuedSupplierStatementsAPIClient: APIDataClient, @unchecked Sendable {
    private var responses: [Data]
    private var failures: [APIError]
    private var dataResponses: [APIDataResponse]
    private var dataFailures: [APIError]
    private let dataDelayNanoseconds: UInt64
    private(set) var capturedRequests: [CapturedSupplierStatementRequest] = []
    private(set) var capturedDataRequests: [CapturedSupplierStatementRequest] = []

    init(
        responses: [String],
        failures: [APIError] = [],
        dataResponses: [APIDataResponse] = [],
        dataFailures: [APIError] = [],
        dataDelayNanoseconds: UInt64 = 0
    ) {
        self.responses = responses.map { Data($0.utf8) }
        self.failures = failures
        self.dataResponses = dataResponses
        self.dataFailures = dataFailures
        self.dataDelayNanoseconds = dataDelayNanoseconds
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedSupplierStatementRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers
            )
        )
        if !failures.isEmpty {
            throw failures.removeFirst()
        }
        guard !responses.isEmpty else {
            throw APIError.emptyResponse
        }
        return try JSONDecoder.nexoDefault.decode(
            Response.self,
            from: responses.removeFirst()
        )
    }

    func sendData(_ request: APIRequest<EmptyResponse>) async throws -> APIDataResponse {
        capturedDataRequests.append(
            CapturedSupplierStatementRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers
            )
        )
        if dataDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: dataDelayNanoseconds)
        }
        if !dataFailures.isEmpty {
            throw dataFailures.removeFirst()
        }
        guard !dataResponses.isEmpty else {
            throw APIError.emptyResponse
        }
        return dataResponses.removeFirst()
    }
}
