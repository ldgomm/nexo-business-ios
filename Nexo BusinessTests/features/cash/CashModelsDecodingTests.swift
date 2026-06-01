//
//  CashModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class CashModelsDecodingTests: XCTestCase {
    func testDecodesCurrentSessionResponseWithOpenSession() throws {
        let json = #"""
        {
          "session": {
            "id": "cash_1",
            "branchId": "br_1",
            "status": "open",
            "openedAt": null,
            "closedAt": null,
            "openingAmount": { "amount": "20.00", "currency": "USD" },
            "countedAmount": null,
            "expectedAmount": { "amount": "20.00", "currency": "USD" },
            "differenceAmount": null
          }
        }
        """#.data(using: .utf8)!
        
        let response = try JSONDecoder.nexoDefault.decode(
            CashCurrentSessionResponse.self,
            from: json
        )
        
        XCTAssertEqual(response.session?.id, "cash_1")
        XCTAssertEqual(response.session?.status, "open")
        XCTAssertEqual(response.session?.openingAmount?.amount, "20.00")
    }
    
    func testDecodesCurrentSessionResponseWithoutOpenSession() throws {
        let json = #"""
        {
          "session": null
        }
        """#.data(using: .utf8)!
        
        let response = try JSONDecoder.nexoDefault.decode(
            CashCurrentSessionResponse.self,
            from: json
        )
        
        XCTAssertNil(response.session)
    }

    func testDecodesCurrentSessionResponseWithCashSessionNull() throws {
        let json = #"""
        {
          "cashSession": null
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            CashCurrentSessionResponse.self,
            from: json
        )

        XCTAssertNil(response.session)
    }

}
