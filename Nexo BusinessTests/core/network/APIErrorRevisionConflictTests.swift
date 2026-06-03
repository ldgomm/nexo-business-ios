//
//  APIErrorRevisionConflictTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import XCTest
@testable import Nexo_Business

final class APIErrorRevisionConflictTests: XCTestCase {
    func testBusinessRevisionConflictIsDetectedByBackendCode() {
        let error = APIError.server(
            statusCode: 409,
            code: "business_revision_conflict",
            message: "Tax configuration revision is stale. Current revision is taxrev_altos_staging_3.",
            requestId: "req_1"
        )

        XCTAssertTrue(error.isRevisionConflict)
        XCTAssertTrue(error.isBusinessRevisionConflict)
        XCTAssertEqual(error.serverMessage, "Tax configuration revision is stale. Current revision is taxrev_altos_staging_3.")
    }

    func testNonRevisionConflict409IsNotTreatedAsBusinessRevisionConflictWhenCodeIsSpecific() {
        let error = APIError.server(
            statusCode: 409,
            code: "cash_session_already_open",
            message: "Cash session already exists.",
            requestId: "req_2"
        )

        XCTAssertTrue(error.isRevisionConflict)
        XCTAssertFalse(error.isBusinessRevisionConflict)
    }
}
