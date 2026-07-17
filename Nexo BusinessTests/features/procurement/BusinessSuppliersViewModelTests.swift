//
//  BusinessSuppliersViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSuppliersViewModelTests: XCTestCase {
    func testLoadRequiresActivePurchasesModuleBeforeNetworkCall() async {
        let client = QueuedSuppliersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            activeModules: [],
            permissions: [BusinessProcurementPermission.suppliersView],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "El módulo Compras no está activo para esta organización.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testLoadRequiresSupplierViewPermissionBeforeNetworkCall() async {
        let client = QueuedSuppliersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(
            activeModules: [.modulePurchases],
            permissions: [],
            client: client
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar proveedores.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
        XCTAssertFalse(viewModel.hasLoaded)
    }

    func testSearchTrimsFiltersAndKeepsBackendSupplierOrder() async throws {
        let client = QueuedSuppliersAPIClient(responses: [Self.firstPageJSON])
        let viewModel = makeListViewModel(client: client)
        viewModel.query = "  proveedor  "
        viewModel.category = "  hardware  "
        viewModel.statusFilter = .active

        await viewModel.search()

        XCTAssertEqual(viewModel.suppliers.map(\.id), ["sup_1"])
        XCTAssertEqual(viewModel.suppliers.first?.businessDisplayName, "Proveedor Uno")
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.nextCursor, "cursor_2")
        XCTAssertNil(viewModel.errorMessage)

        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.suppliers)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.queryDictionary["query"], "proveedor")
        XCTAssertEqual(request.queryDictionary["category"], "hardware")
        XCTAssertEqual(request.queryDictionary["status"], "ACTIVE")
        XCTAssertEqual(request.queryDictionary["limit"], "50")
        XCTAssertNil(request.queryDictionary["cursor"])
    }

    func testPaginationUsesCursorAndDoesNotDuplicateSupplier() async throws {
        let client = QueuedSuppliersAPIClient(responses: [Self.firstPageJSON, Self.secondPageJSON])
        let viewModel = makeListViewModel(client: client)

        await viewModel.loadIfNeeded()
        let firstSupplier = try XCTUnwrap(viewModel.suppliers.first)
        await viewModel.loadNextPageIfNeeded(currentSupplier: firstSupplier)

        XCTAssertEqual(viewModel.suppliers.map(\.id), ["sup_1", "sup_2"])
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertNil(viewModel.nextCursor)
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(client.capturedRequests[1].queryDictionary["cursor"], "cursor_2")
    }

    func testEmptySearchPresentsExplicitEmptyState() async {
        let client = QueuedSuppliersAPIClient(responses: [Self.emptyListJSON])
        let viewModel = makeListViewModel(client: client)

        await viewModel.search()

        XCTAssertTrue(viewModel.suppliers.isEmpty)
        XCTAssertEqual(viewModel.infoMessage, "No encontramos proveedores con estos filtros.")
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testDetailRefreshPreservesRedactedSensitiveFields() async throws {
        let initial = try decodeEnvelope(Self.redactedSupplierEnvelopeJSON).data
        let client = QueuedSuppliersAPIClient(responses: [Self.redactedSupplierEnvelopeJSON])
        let repository = BusinessProcurementAPIRepository(apiClient: client)
        let viewModel = BusinessSupplierDetailViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [BusinessProcurementPermission.suppliersView],
            supplier: initial,
            repository: repository
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.supplier.id, "sup_1")
        XCTAssertEqual(viewModel.supplier.businessDisplayName, "Proveedor Uno")
        XCTAssertNil(viewModel.supplier.identificationNumber)
        XCTAssertNil(viewModel.supplier.contacts)
        XCTAssertNil(viewModel.supplier.businessIdentificationText)
        XCTAssertEqual(viewModel.supplier.paymentTerms.businessDisplayText, "Crédito a 30 días")
        XCTAssertTrue(viewModel.hasLoaded)
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.supplier("sup_1"))
        XCTAssertTrue(request.queryItems.isEmpty)
    }

    func testSupplierPresentationPrefersTradeNameAndBackendPrimaryContact() throws {
        let supplier = try decodeEnvelope(Self.supplierWithContactsEnvelopeJSON).data

        XCTAssertEqual(supplier.businessDisplayName, "Ferretería Uno")
        XCTAssertEqual(supplier.businessLegalNameDetail, "Proveedor Uno S.A.")
        XCTAssertEqual(supplier.businessIdentificationText, "RUC · 1790012345001")
        XCTAssertEqual(supplier.businessPrimaryContact?.id, "contact_primary")
        XCTAssertEqual(supplier.paymentTerms.businessDisplayText, "30 días proveedor")
    }

    func testSupplierViewKeepsProtectedDataExplicitAndDoesNotRenderInternalId() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSuppliersView.swift"
        )

        XCTAssertTrue(source.contains("Protegido por permisos"))
        XCTAssertTrue(source.contains("Protegida o no registrada"))
        XCTAssertFalse(source.contains("Text(supplier.id)"))
        XCTAssertFalse(source.contains("Text(viewModel.supplier.id)"))
    }

    private func makeListViewModel(
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String> = [BusinessProcurementPermission.suppliersView],
        client: QueuedSuppliersAPIClient
    ) -> BusinessSuppliersViewModel {
        BusinessSuppliersViewModel(
            organizationId: "org_1",
            activeModules: activeModules,
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )
    }

    private func decodeEnvelope(_ json: String) throws -> BusinessProcurementSupplierEnvelopeResponse {
        try JSONDecoder.nexoDefault.decode(
            BusinessProcurementSupplierEnvelopeResponse.self,
            from: Data(json.utf8)
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

    private static let emptyListJSON = #"{"suppliers":[],"nextCursor":null,"hasMore":false}"#

    private static let firstPageJSON = #"""
    {
      "suppliers": [
        {
          "id":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Proveedor Uno","identificationType":"RUC","identificationNumber":"1790012345001",
          "email":"compras@proveedor.test","phone":"0991112222","address":"Quito","categories":["hardware"],"contacts":[],
          "paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD","status":"ACTIVE","notes":null,
          "createdAt":"2026-07-01T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-02T12:00:00Z","updatedBy":"usr_1","version":2
        }
      ],
      "nextCursor":"cursor_2","hasMore":true
    }
    """#

    private static let secondPageJSON = #"""
    {
      "suppliers": [
        {
          "id":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Proveedor Uno","identificationType":"RUC","identificationNumber":"1790012345001",
          "email":null,"phone":null,"address":null,"categories":["hardware"],"contacts":null,
          "paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD","status":"ACTIVE","notes":null,
          "createdAt":"2026-07-01T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-02T12:00:00Z","updatedBy":"usr_1","version":2
        },
        {
          "id":"sup_2","legalName":"Servicios Dos Cía. Ltda.","tradeName":null,"identificationType":null,"identificationNumber":null,
          "email":null,"phone":null,"address":null,"categories":["services"],"contacts":null,
          "paymentTerms":{"mode":"IMMEDIATE","netDays":0,"label":null,"notes":null},"defaultCurrency":"USD","status":"INACTIVE","notes":null,
          "createdAt":"2026-07-03T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-03T12:00:00Z","updatedBy":"usr_1","version":1
        }
      ],
      "nextCursor":null,"hasMore":false
    }
    """#

    private static let redactedSupplierEnvelopeJSON = #"""
    {
      "data": {
        "id":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Proveedor Uno","identificationType":null,"identificationNumber":null,
        "email":null,"phone":null,"address":null,"categories":["hardware"],"contacts":null,
        "paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":null,"notes":null},"defaultCurrency":"USD","status":"ACTIVE","notes":null,
        "createdAt":"2026-07-01T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-02T12:00:00Z","updatedBy":"usr_1","version":2
      },
      "meta":{"requestId":"req_supplier","idempotencyReplayed":null}
    }
    """#

    private static let supplierWithContactsEnvelopeJSON = #"""
    {
      "data": {
        "id":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":"Ferretería Uno","identificationType":"RUC","identificationNumber":"1790012345001",
        "email":"compras@proveedor.test","phone":"0991112222","address":"Quito","categories":["hardware"],
        "contacts":[
          {"id":"contact_other","name":"Bodega","role":"Despacho","email":null,"phone":null,"isPrimary":false,"notes":null},
          {"id":"contact_primary","name":"Ana","role":"Ventas","email":"ana@proveedor.test","phone":"0993334444","isPrimary":true,"notes":null}
        ],
        "paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":"30 días proveedor","notes":null},"defaultCurrency":"USD","status":"ACTIVE","notes":"Preferido",
        "createdAt":"2026-07-01T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-02T12:00:00Z","updatedBy":"usr_1","version":2
      },
      "meta":{"requestId":"req_supplier","idempotencyReplayed":false}
    }
    """#
}

private struct CapturedSupplierRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }
}

private final class QueuedSuppliersAPIClient: APIClient, @unchecked Sendable {
    private var responses: [Data]
    private(set) var capturedRequests: [CapturedSupplierRequest] = []

    init(responses: [String]) {
        self.responses = responses.map { Data($0.utf8) }
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedSupplierRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers
            )
        )
        guard !responses.isEmpty else {
            throw APIError.emptyResponse
        }
        return try JSONDecoder.nexoDefault.decode(Response.self, from: responses.removeFirst())
    }
}
