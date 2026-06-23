//
//  BusinessDailyReport21F2DecodingTests.swift
//  Nexo BusinessTests
//

import XCTest
@testable import Nexo_Business

final class BusinessDailyReport21F2DecodingTests: XCTestCase {
    func testDecodes21CSummarySectionsWithoutLosingLegacyConvenienceFields() throws {
        let json = #"""
        {
          "report": {
            "reportVersion": "21C.v1",
            "businessDate": "2026-06-23",
            "branchId": "br_1",
            "salesSummary": {
              "count": 4,
              "cancelledCount": 1,
              "grandTotal": { "amount": "80.00", "currency": "USD" }
            },
            "paymentSummary": {
              "count": 3,
              "total": { "amount": "70.00", "currency": "USD" },
              "cashTotal": { "amount": "40.00", "currency": "USD" }
            },
            "cashSummary": {
              "cashSessionId": "cash_1",
              "status": "open",
              "expectedAmount": { "amount": "90.00", "currency": "USD" }
            },
            "productSummary": {
              "topProducts": [
                {
                  "productId": "prod_1",
                  "productName": "Cuy entero",
                  "soldQuantity": "2",
                  "salesTotal": { "amount": "48.00", "currency": "USD" }
                }
              ],
              "lowStockCount": 1
            },
            "receivablesSummary": {
              "openCount": 1,
              "openAmount": { "amount": "10.00", "currency": "USD" }
            },
            "documentSummary": {
              "authorizedCount": 2,
              "pendingCount": 1
            },
            "alerts": [
              {
                "severity": "warning",
                "code": "LOW_STOCK",
                "title": "Stock bajo",
                "message": "Revisar inventario"
              }
            ]
          }
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessDailyReportResponse.self, from: json)
        let report = response.report

        XCTAssertEqual(report.reportVersion, "21C.v1")
        XCTAssertEqual(report.salesCount, 4)
        XCTAssertEqual(report.salesTotal?.amount, "80.00")
        XCTAssertEqual(report.paymentsCount, 3)
        XCTAssertEqual(report.cashStatus, "open")
        XCTAssertEqual(report.cashExpectedAmount?.amount, "90.00")
        XCTAssertEqual(report.openReceivablesCount, 1)
        XCTAssertEqual(report.pendingDocumentsCount, 1)
        XCTAssertEqual(report.productSummary?.topProducts.first?.name, "Cuy entero")
        XCTAssertEqual(report.alerts.first?.code, "LOW_STOCK")
    }
}
