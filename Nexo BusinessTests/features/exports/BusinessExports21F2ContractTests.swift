//
//  BusinessExports21F2ContractTests.swift
//  Nexo BusinessTests
//

import XCTest
@testable import Nexo_Business

final class BusinessExports21F2ContractTests: XCTestCase {
    func testExportsRoutesMatch21DOperationalContract() {
        XCTAssertEqual(BusinessExportsRoutes.exports, "/api/v1/business/exports")
        XCTAssertEqual(BusinessExportsRoutes.daily, "/api/v1/business/exports/daily")
        XCTAssertEqual(BusinessExportsRoutes.dailyZip, "/api/v1/business/exports/daily.zip")
    }

    func testDecodesExportsCatalog() throws {
        let json = #"""
        {
          "exports": [
            {
              "id": "daily_operational_21d_v1",
              "kind": "daily_operational",
              "version": "21D.v1",
              "title": "Exportación operativa diaria",
              "contentType": "application/zip",
              "fileName": "nexo_daily_operational_2026-06-23.zip",
              "sizeBytes": 4096
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessExportsCatalogResponse.self, from: json)

        XCTAssertEqual(response.exports.first?.kind, "daily_operational")
        XCTAssertEqual(response.exports.first?.version, "21D.v1")
        XCTAssertEqual(response.exports.first?.contentType, "application/zip")
    }

    @MainActor
    func testCanExportWithOperationalReportPermissionFrom21D() {
        let viewModel = BusinessExportsViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            effectivePermissions: ["reports.dashboard.view"],
            exportsRepository: PreviewBusinessExportsRepository()
        )

        XCTAssertTrue(viewModel.canExport)
    }

    @MainActor
    func testCanExportWithExplicitBusinessExportPermission() {
        let viewModel = BusinessExportsViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            effectivePermissions: ["business.exports.download"],
            exportsRepository: PreviewBusinessExportsRepository()
        )

        XCTAssertTrue(viewModel.canExport)
    }

    func testEncodesDailyExportGenerateRequest() throws {
        let request = BusinessExportGenerateRequest(
            businessDate: "2026-06-23",
            branchId: "br_1"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["kind"] as? String, "daily_operational")
        XCTAssertEqual(object["businessDate"] as? String, "2026-06-23")
        XCTAssertEqual(object["branchId"] as? String, "br_1")
    }
}
