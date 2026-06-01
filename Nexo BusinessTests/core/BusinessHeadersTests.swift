//
//  BusinessHeadersTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessHeadersTests: XCTestCase {
    func testBusinessHeadersMatchBackendContract() {
        XCTAssertEqual(BusinessHeaders.organizationId, "X-Organization-Id")
        XCTAssertEqual(BusinessHeaders.branchId, "X-Branch-Id")
        XCTAssertEqual(BusinessHeaders.activityId, "X-Activity-Id")
        XCTAssertEqual(BusinessHeaders.idempotencyKey, "Idempotency-Key")
        XCTAssertEqual(BusinessHeaders.catalogRevision, "X-Catalog-Revision")
        XCTAssertEqual(BusinessHeaders.taxConfigurationRevision, "X-Tax-Configuration-Revision")
        XCTAssertEqual(BusinessHeaders.deviceId, "X-Device-Id")
    }

    func testRevisionHeaders() {
        let revisions = BusinessRevisions(
            catalogRevision: "cat_rev_001",
            taxConfigurationRevision: "tax_rev_001"
        )

        XCTAssertEqual(
            revisions.headers[BusinessHeaders.catalogRevision],
            "cat_rev_001"
        )
        XCTAssertEqual(
            revisions.headers[BusinessHeaders.taxConfigurationRevision],
            "tax_rev_001"
        )
    }
}
