//
//  BusinessSupplierFormViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSupplierFormViewModelTests: XCTestCase {
    func testCreateRequiresPermissionBeforeNetworkCall() async {
        let client = SupplierFormAPIClient(outcomes: [.response(Self.createdEnvelopeJSON)])
        let viewModel = makeCreateViewModel(permissions: [], client: client)
        viewModel.legalName = "Proveedor Uno"

        let supplier = await viewModel.save()

        XCTAssertNil(supplier)
        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para crear proveedores.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testCreateMapsTrimmedSupplierDataAndStableIdempotencyKey() async throws {
        let client = SupplierFormAPIClient(outcomes: [.response(Self.createdEnvelopeJSON)])
        let viewModel = makeCreateViewModel(client: client)
        viewModel.legalName = "  Proveedor Uno S.A.  "
        viewModel.tradeName = "  Ferretería Uno  "
        viewModel.identificationKind = .ruc
        viewModel.identificationNumber = " 1790012345001 "
        viewModel.email = " compras@proveedor.test "
        viewModel.phone = " 0991112222 "
        viewModel.address = " Quito "
        viewModel.categoriesText = " Hardware, services, hardware "
        viewModel.paymentTermsKind = .netDays
        viewModel.netDaysText = " 30 "
        viewModel.paymentTermsLabel = " Crédito 30 días "
        viewModel.contacts = [
            BusinessSupplierContactDraft(
                name: " Ana ",
                role: " Ventas ",
                email: " ana@proveedor.test ",
                phone: " 0993334444 ",
                isPrimary: true
            )
        ]

        let supplier = await viewModel.save()

        XCTAssertEqual(supplier?.id, "sup_created")
        XCTAssertEqual(viewModel.infoMessage, "Proveedor creado correctamente.")
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.suppliers)
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(request.headers[BusinessHeaders.idempotencyKey], "supplier-create-fixed")

        let body = try request.jsonObject()
        XCTAssertEqual(body["legalName"] as? String, "Proveedor Uno S.A.")
        XCTAssertEqual(body["tradeName"] as? String, "Ferretería Uno")
        XCTAssertEqual(body["identificationType"] as? String, "RUC")
        XCTAssertEqual(body["identificationNumber"] as? String, "1790012345001")
        XCTAssertEqual(body["defaultCurrency"] as? String, "USD")
        XCTAssertNil(body["expectedVersion"])
        XCTAssertEqual(body["categories"] as? [String], ["hardware", "services"])

        let contacts = try XCTUnwrap(body["contacts"] as? [[String: Any]])
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0]["name"] as? String, "Ana")
        XCTAssertEqual(contacts[0]["role"] as? String, "Ventas")
        XCTAssertEqual(contacts[0]["isPrimary"] as? Bool, true)
        XCTAssertNil(contacts[0]["id"])

        let terms = try XCTUnwrap(body["paymentTerms"] as? [String: Any])
        XCTAssertEqual(terms["mode"] as? String, "NET_DAYS")
        XCTAssertEqual(terms["netDays"] as? Int, 30)
        XCTAssertEqual(terms["label"] as? String, "Crédito 30 días")
    }

    func testCreateRetryReusesTheSameIdempotencyKey() async {
        let client = SupplierFormAPIClient(outcomes: [
            .error(.transport("offline")),
            .response(Self.replayedEnvelopeJSON),
        ])
        let viewModel = makeCreateViewModel(client: client)
        viewModel.legalName = "Proveedor Uno"

        let first = await viewModel.save()
        let second = await viewModel.save()

        XCTAssertNil(first)
        XCTAssertEqual(second?.id, "sup_created")
        XCTAssertEqual(client.capturedRequests.count, 2)
        XCTAssertEqual(
            client.capturedRequests.map { $0.headers[BusinessHeaders.idempotencyKey] },
            ["supplier-create-fixed", "supplier-create-fixed"]
        )
        XCTAssertEqual(viewModel.infoMessage, "Proveedor recuperado de un intento anterior.")
    }

    func testPaymentTermsAndIdentificationAreValidatedBeforeNetworkCall() async {
        let client = SupplierFormAPIClient(outcomes: [.response(Self.createdEnvelopeJSON)])
        let viewModel = makeCreateViewModel(client: client)
        viewModel.legalName = "Proveedor Uno"
        viewModel.identificationKind = .ruc
        viewModel.paymentTermsKind = .netDays
        viewModel.netDaysText = "0"

        _ = await viewModel.save()

        XCTAssertEqual(viewModel.errorMessage, "Ingresa el número de identificación del proveedor.")
        XCTAssertTrue(client.capturedRequests.isEmpty)

        viewModel.identificationNumber = "1790012345001"
        _ = await viewModel.save()

        XCTAssertEqual(viewModel.errorMessage, "Ingresa un plazo entre 1 y 365 días.")
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testEditRequiresSensitiveSnapshotToAvoidOverwritingRedactedData() async {
        let client = SupplierFormAPIClient(outcomes: [.response(Self.updatedEnvelopeJSON)])
        let supplier = Self.makeSupplier(contacts: nil)
        let viewModel = BusinessSupplierFormViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.suppliersUpdate,
                BusinessProcurementPermission.suppliersSensitiveView,
            ],
            supplier: supplier,
            repository: BusinessProcurementAPIRepository(apiClient: client)
        )

        let result = await viewModel.save()

        XCTAssertNil(result)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Actualiza el detalle antes de editar para no sobrescribir datos protegidos."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testEditPreservesContactIdAndSendsNumericExpectedVersionWithoutIdempotency() async throws {
        let client = SupplierFormAPIClient(outcomes: [.response(Self.updatedEnvelopeJSON)])
        let supplier = Self.makeSupplier(contacts: [
            BusinessProcurementSupplierContactResponse(
                id: "scon_existing",
                name: "Ana",
                role: "Ventas",
                email: "ana@proveedor.test",
                phone: nil,
                isPrimary: true,
                notes: nil
            )
        ])
        let viewModel = makeEditViewModel(supplier: supplier, client: client)
        viewModel.tradeName = " Ferretería Actualizada "

        let updated = await viewModel.save()

        XCTAssertEqual(updated?.version, 8)
        XCTAssertEqual(viewModel.infoMessage, "Proveedor actualizado correctamente.")
        let request = try XCTUnwrap(client.capturedRequests.last)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.supplier("sup_1"))
        XCTAssertNil(request.headers[BusinessHeaders.idempotencyKey])
        let body = try request.jsonObject()
        XCTAssertEqual(body["expectedVersion"] as? Int, 7)
        XCTAssertFalse(body["expectedVersion"] is String)
        let contacts = try XCTUnwrap(body["contacts"] as? [[String: Any]])
        XCTAssertEqual(contacts[0]["id"] as? String, "scon_existing")
    }

    func testVersionConflictRequiresDetailRefresh() async {
        let client = SupplierFormAPIClient(outcomes: [
            .error(
                .server(
                    statusCode: 409,
                    code: "procurement_version_conflict",
                    message: "Supplier version is stale.",
                    requestId: "req_conflict"
                )
            )
        ])
        let viewModel = makeEditViewModel(supplier: Self.makeSupplier(), client: client)

        let updated = await viewModel.save()

        XCTAssertNil(updated)
        XCTAssertEqual(
            viewModel.errorMessage,
            "El proveedor cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        )
    }

    func testSupplierSurfacesGateCreateAndEditAndUseTheSharedForm() throws {
        let source = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessSuppliersView.swift"
        )

        XCTAssertTrue(source.contains("if viewModel.canCreate"))
        XCTAssertTrue(source.contains("if viewModel.canEdit"))
        XCTAssertTrue(source.contains("BusinessSupplierFormView"))
        XCTAssertTrue(source.contains("onSupplierChanged"))
    }

    private func makeCreateViewModel(
        permissions: Set<String> = [BusinessProcurementPermission.suppliersCreate],
        client: SupplierFormAPIClient
    ) -> BusinessSupplierFormViewModel {
        BusinessSupplierFormViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: permissions,
            repository: BusinessProcurementAPIRepository(apiClient: client),
            createIdempotencyKey: IdempotencyKey(rawValue: "supplier-create-fixed")
        )
    }

    private func makeEditViewModel(
        supplier: BusinessProcurementSupplierResponse,
        client: SupplierFormAPIClient
    ) -> BusinessSupplierFormViewModel {
        BusinessSupplierFormViewModel(
            organizationId: "org_1",
            activeModules: [.modulePurchases],
            effectivePermissions: [
                BusinessProcurementPermission.suppliersUpdate,
                BusinessProcurementPermission.suppliersSensitiveView,
            ],
            supplier: supplier,
            repository: BusinessProcurementAPIRepository(apiClient: client)
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

    private static func makeSupplier(
        contacts: [BusinessProcurementSupplierContactResponse]? = []
    ) -> BusinessProcurementSupplierResponse {
        BusinessProcurementSupplierResponse(
            id: "sup_1",
            legalName: "Proveedor Uno S.A.",
            tradeName: "Proveedor Uno",
            identificationType: "RUC",
            identificationNumber: "1790012345001",
            email: "compras@proveedor.test",
            phone: "0991112222",
            address: "Quito",
            categories: ["hardware"],
            contacts: contacts,
            paymentTerms: BusinessProcurementPaymentTermsResponse(
                mode: "NET_DAYS",
                netDays: 30,
                label: nil,
                notes: nil
            ),
            defaultCurrency: "USD",
            status: .active,
            notes: nil,
            createdAt: "2026-07-01T12:00:00Z",
            createdBy: "usr_1",
            updatedAt: "2026-07-02T12:00:00Z",
            updatedBy: "usr_1",
            version: 7
        )
    }

    private static let createdEnvelopeJSON = #"""
    {
      "data": {
        "id":"sup_created","legalName":"Proveedor Uno S.A.","tradeName":"Ferretería Uno","identificationType":"RUC","identificationNumber":"1790012345001",
        "email":"compras@proveedor.test","phone":"0991112222","address":"Quito","categories":["hardware","services"],
        "contacts":[{"id":"scon_created","name":"Ana","role":"Ventas","email":"ana@proveedor.test","phone":"0993334444","isPrimary":true,"notes":null}],
        "paymentTerms":{"mode":"NET_DAYS","netDays":30,"label":"Crédito 30 días","notes":null},"defaultCurrency":"USD","status":"ACTIVE","notes":null,
        "createdAt":"2026-07-15T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-15T12:00:00Z","updatedBy":"usr_1","version":1
      },
      "meta":{"requestId":"req_create","idempotencyReplayed":false}
    }
    """#

    private static let replayedEnvelopeJSON = createdEnvelopeJSON.replacingOccurrences(
        of: "\"idempotencyReplayed\":false",
        with: "\"idempotencyReplayed\":true"
    )

    private static let updatedEnvelopeJSON = createdEnvelopeJSON
        .replacingOccurrences(of: "\"id\":\"sup_created\"", with: "\"id\":\"sup_1\"")
        .replacingOccurrences(of: "\"version\":1", with: "\"version\":8")
}

private struct CapturedSupplierFormRequest {
    let method: HTTPMethod
    let path: String
    let headers: [String: String]
    let body: Data?

    func jsonObject() throws -> [String: Any] {
        let body = try XCTUnwrap(body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private final class SupplierFormAPIClient: APIClient, @unchecked Sendable {
    enum Outcome {
        case response(String)
        case error(APIError)
    }

    private var outcomes: [Outcome]
    private(set) var capturedRequests: [CapturedSupplierFormRequest] = []

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        capturedRequests.append(
            CapturedSupplierFormRequest(
                method: request.method,
                path: request.path,
                headers: request.headers,
                body: request.body
            )
        )
        guard !outcomes.isEmpty else {
            throw APIError.emptyResponse
        }
        switch outcomes.removeFirst() {
        case .response(let json):
            return try JSONDecoder.nexoDefault.decode(Response.self, from: Data(json.utf8))
        case .error(let error):
            throw error
        }
    }
}
