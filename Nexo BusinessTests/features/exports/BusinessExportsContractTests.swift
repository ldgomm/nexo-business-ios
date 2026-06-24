//
//  BusinessExports21F2ContractTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessExportsContractTests: XCTestCase {
    func testExportsRoutesMatch21DOperationalContract() {
        XCTAssertEqual(BusinessExportsRoutes.exports, "/api/v1/business/exports")
        XCTAssertEqual(BusinessExportsRoutes.daily, "/api/v1/business/exports/daily")
        XCTAssertEqual(BusinessExportsRoutes.dailyZip, "/api/v1/business/exports/daily.zip")
        XCTAssertEqual(BusinessExportsRoutes.operationalSummary, "/api/v1/business/exports/operational/summary")
        XCTAssertEqual(BusinessExportsRoutes.operationalZip, "/api/v1/business/exports/operational.zip")
    }

    func testDecodesExportsCatalog() throws {
        let json = #"""
        {
          "exports": [
            {
              "type": "operational_intelligent",
              "version": "21D.2-21F.4",
              "title": "Informe operativo inteligente",
              "description": "PDF ejecutivo, HTML con diagramas y CSV por período.",
              "contentType": "application/zip",
              "path": "/api/v1/business/exports/operational.zip",
              "files": ["informe_operativo.pdf"]
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessExportsCatalogResponse.self, from: json)

        XCTAssertEqual(response.exports.first?.kind, "operational_intelligent")
        XCTAssertEqual(response.exports.first?.version, "21D.2-21F.4")
        XCTAssertEqual(response.exports.first?.title, "Informe operativo inteligente")
        XCTAssertEqual(response.exports.first?.contentType, "application/zip")
    }

    func testDecodesOperationalSummary() throws {
        let json = #"""
        {
          "period": {
            "from": "2026-06-01",
            "to": "2026-06-23",
            "label": "Este mes",
            "timezone": "America/Guayaquil",
            "isSingleDay": false,
            "isPartialMonth": true,
            "daysInPeriod": 23,
            "daysWithData": 1
          },
          "hasData": true,
          "totals": {
            "saleCount": 2,
            "closedSaleCount": 2,
            "canceledSaleCount": 0,
            "itemCount": 4,
            "grandTotal": { "amount": "48.00", "currency": "USD" },
            "paidTotal": { "amount": "48.00", "currency": "USD" },
            "receivableTotal": { "amount": "0.00", "currency": "USD" },
            "pendingReceivables": { "amount": "0.00", "currency": "USD" },
            "pendingReceivablesCount": 0,
            "cashInTotal": { "amount": "48.00", "currency": "USD" },
            "cashOutTotal": { "amount": "0.00", "currency": "USD" },
            "netCashMovement": { "amount": "48.00", "currency": "USD" },
            "cashDifferenceTotal": { "amount": "0.00", "currency": "USD" },
            "documentCount": 2,
            "authorizedDocumentCount": 2,
            "pendingDocumentCount": 0,
            "taxTotal": { "amount": "6.26", "currency": "USD" }
          },
          "comparisons": [],
          "charts": {
            "salesByDay": [
              { "date": "2026-06-23", "label": "23/6", "saleCount": 2, "grandTotal": { "amount": "48.00", "currency": "USD" }, "paidTotal": { "amount": "48.00", "currency": "USD" } }
            ],
            "topItems": [
              { "catalogItemId": "cuy", "name": "Cuy entero", "quantity": "2", "netTotal": { "amount": "48.00", "currency": "USD" }, "lineTotal": { "amount": "48.00", "currency": "USD" } }
            ],
            "paymentStatuses": [{ "status": "paid", "count": 2 }],
            "documentStatuses": [{ "status": "authorized", "count": 2 }],
            "cashMovementTypes": []
          },
          "alerts": [],
          "availableExports": ["pdf", "html", "csv", "zip"],
          "recommendedSummary": ["Ventas registradas: 2"]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessOperationalSummaryResponse.self, from: json)

        XCTAssertTrue(response.hasData)
        XCTAssertEqual(response.period.label, "Este mes")
        XCTAssertEqual(response.period.daysWithData, 1)
        XCTAssertEqual(response.totals.grandTotal.amount, "48.00")
        XCTAssertEqual(response.charts.topItems.first?.name, "Cuy entero")
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

    @MainActor
    func testFutureCustomPeriodIsBlocked() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23))!
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 6, day: 24))!
        let viewModel = BusinessExportsViewModel(
            organizationId: "org_1",
            branchId: "br_1",
            effectivePermissions: ["reports.dashboard.view"],
            exportsRepository: PreviewBusinessExportsRepository(),
            calendar: calendar,
            nowProvider: { today }
        )
        viewModel.selectedPreset = .custom
        viewModel.customStartDate = today
        viewModel.customEndDate = tomorrow

        XCTAssertEqual(viewModel.validationMessage, "No puedes generar informes de fechas futuras.")
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
