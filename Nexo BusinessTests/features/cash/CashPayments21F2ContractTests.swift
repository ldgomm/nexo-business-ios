//
//  CashPayments21F2ContractTests.swift
//  Nexo BusinessTests
//

import XCTest
@testable import Nexo_Business

final class CashPayments21F2ContractTests: XCTestCase {
    func testCashRoutesExpose21BOperationalEndpoints() {
        XCTAssertEqual(BusinessCashRoutes.current, "/api/v1/business/cash/current")
        XCTAssertEqual(BusinessCashRoutes.sessions, "/api/v1/business/cash/sessions")
        XCTAssertEqual(BusinessCashRoutes.movements(cashSessionId: "cash_1"), "/api/v1/business/cash/cash_1/movements")
        XCTAssertEqual(BusinessCashRoutes.close(cashSessionId: "cash_1"), "/api/v1/business/cash/cash_1/close")
    }

    func testDecodesCashSessionsAndMovementsLists() throws {
        let sessionsJSON = #"""
        {
          "sessions": [
            {
              "id": "cash_1",
              "branchId": "br_1",
              "status": "open",
              "openingBalance": { "amount": "20.00", "currency": "USD" },
              "expectedCashAmount": { "amount": "35.00", "currency": "USD" }
            }
          ],
          "totalCount": 1
        }
        """#.data(using: .utf8)!

        let movementsJSON = #"""
        {
          "cashMovements": [
            {
              "id": "mov_1",
              "cashSessionId": "cash_1",
              "direction": "inflow",
              "amount": { "amount": "15.00", "currency": "USD" },
              "notes": "Entrada manual"
            }
          ],
          "totalCount": 1
        }
        """#.data(using: .utf8)!

        let sessions = try JSONDecoder.nexoDefault.decode(CashSessionsResponse.self, from: sessionsJSON)
        let movements = try JSONDecoder.nexoDefault.decode(CashMovementsResponse.self, from: movementsJSON)

        XCTAssertEqual(sessions.sessions.first?.id, "cash_1")
        XCTAssertEqual(sessions.sessions.first?.expectedAmount?.amount, "35.00")
        XCTAssertEqual(movements.movements.first?.type, .inflow)
        XCTAssertEqual(movements.movements.first?.note, "Entrada manual")
    }

    func testPaymentsRoutesKeepPilotRegisterAndExpose21BRegisterAlias() {
        XCTAssertEqual(BusinessPaymentsRoutes.payments, "/api/v1/business/payments")
        XCTAssertEqual(BusinessPaymentsRoutes.register, "/api/v1/business/payments/register")
    }

    func testDecodesPaymentsList() throws {
        let json = #"""
        {
          "payments": [
            {
              "id": "pay_1",
              "saleId": "sale_1",
              "method": "CASH",
              "amount": { "amount": "10.00", "currency": "USD" },
              "status": "registered"
            }
          ],
          "totalCount": 1
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(PaymentsListResponse.self, from: json)

        XCTAssertEqual(response.payments.first?.id, "pay_1")
        XCTAssertEqual(response.payments.first?.amount.amount, "10.00")
    }
}
