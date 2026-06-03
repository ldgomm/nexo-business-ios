import XCTest
@testable import Nexo_Business

final class BusinessTeamModelsDecodingTests: XCTestCase {
    func testDecodesUserEnvelopeWithRolesFallback() throws {
        let json = Data(
            """
            {
              "user": {
                "id": "usr_1",
                "email": "user@nexo.test",
                "displayName": "Usuario",
                "status": "ACTIVE",
                "membershipId": "mem_1",
                "roleIds": ["role_cashier"],
                "roleNames": ["Cajero"],
                "activeSessionCount": 2,
                "createdAt": "2026-06-03T10:00:00Z",
                "updatedAt": "2026-06-03T10:00:00Z"
              }
            }
            """.utf8
        )

        let response = try JSONDecoder.nexoDefault.decode(BusinessTeamUserEnvelope.self, from: json)

        XCTAssertEqual(response.user.id, "usr_1")
        XCTAssertEqual(response.user.scopeType, "ORGANIZATION")
        XCTAssertEqual(response.user.scopeId, "mem_1")
        XCTAssertEqual(response.user.roleIds, ["role_cashier"])
        XCTAssertEqual(response.user.rolesSummary, "Cajero")
    }

    func testDecodesRoleTemplateResponse() throws {
        let json = Data(
            """
            {
              "templates": [
                {
                  "templateCode": "core.discount_manager",
                  "vertical": "CORE",
                  "roleCode": "encargado_descuentos",
                  "name": "Encargado de descuentos",
                  "description": "Puede aplicar descuentos.",
                  "permissionKeys": ["sales.apply_discount"],
                  "requiredModules": ["core.sales"],
                  "assignableByBusiness": true,
                  "editableByBusiness": true,
                  "critical": false,
                  "rank": 320
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder.nexoDefault.decode(BusinessRoleTemplatesResponse.self, from: json)

        XCTAssertEqual(response.templates.count, 1)
        XCTAssertEqual(response.templates.first?.id, "core.discount_manager")
        XCTAssertEqual(response.templates.first?.readableVertical, "General")
        XCTAssertEqual(response.templates.first?.permissionKeys, ["sales.apply_discount"])
    }

    func testEncodesCreateRoleFromTemplateInput() throws {
        let input = CreateBusinessRoleFromTemplateInput(
            templateCode: "core.cashier",
            reason: "Crear cajero"
        )

        let data = try JSONEncoder.nexoDefault.encode(input)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["templateCode"] as? String, "core.cashier")
        XCTAssertEqual(object?["reason"] as? String, "Crear cajero")
        XCTAssertFalse(object?.keys.contains("code") ?? true)
    }
}
