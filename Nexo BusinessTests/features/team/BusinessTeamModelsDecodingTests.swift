//
//  BusinessTeamModelsDecodingTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

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
                  "rank": 320,
                  "permissionCount": 1,
                  "knownPermissionCount": 1,
                  "capabilityGroupCodes": ["SALES_DISCOUNTS"],
                  "capabilityGroups": [
                    {
                      "code": "SALES_DISCOUNTS",
                      "title": "Descuentos",
                      "description": "Permite aplicar y quitar descuentos.",
                      "humanBullets": ["Puede aplicar descuentos"],
                      "permissionKeys": ["sales.apply_discount"],
                      "requiredModules": ["core.sales"],
                      "sensitive": true,
                      "rank": 160
                    }
                  ]
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
        XCTAssertEqual(response.templates.first?.permissionCount, 1)
        XCTAssertEqual(response.templates.first?.knownPermissionCount, 1)
        XCTAssertEqual(response.templates.first?.capabilityGroupCodes, ["SALES_DISCOUNTS"])
        XCTAssertEqual(response.templates.first?.capabilityGroups.first?.title, "Descuentos")
    }

    func testDecodesCapabilityGroupsResponse() throws {
        let json = Data(
            """
            {
              "groups": [
                {
                  "code": "CASH",
                  "title": "Caja",
                  "description": "Operación de caja.",
                  "humanBullets": ["Puede abrir caja"],
                  "permissionKeys": ["cash.open"],
                  "requiredModules": ["core.cash"],
                  "sensitive": true,
                  "rank": 180
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder.nexoDefault.decode(BusinessHumanCapabilityGroupsResponse.self, from: json)

        XCTAssertEqual(response.groups.count, 1)
        XCTAssertEqual(response.groups.first?.id, "CASH")
        XCTAssertEqual(response.groups.first?.title, "Caja")
        XCTAssertEqual(response.groups.first?.permissionKeys, ["cash.open"])
        XCTAssertTrue(response.groups.first?.sensitive == true)
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
