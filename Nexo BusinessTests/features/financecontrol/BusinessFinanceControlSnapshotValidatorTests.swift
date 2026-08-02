//
//  BusinessFinanceControlSnapshotValidatorTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import XCTest
@testable import Nexo_Business

class BusinessFinanceControlSnapshotValidatorTests: XCTestCase {
    private let validator = BusinessFinanceControlSnapshotValidator()
    private let scope = BusinessFinanceControlScope(
        organizationId: "org_synthetic",
        branchId: "branch_1",
        activityId: "activity_1"
    )

    func testAcceptsOperationalNotPostedSnapshot() throws {
        XCTAssertNoThrow(
            try validator.validate(
                BusinessFinanceControlTestFixtures.snapshot(),
                requestedScope: scope
            )
        )
    }

    func testRejectsCrossOrganisationSnapshot() {
        XCTAssertThrowsError(
            try validator.validate(
                BusinessFinanceControlTestFixtures.snapshot(
                    organizationId: "another_org"
                ),
                requestedScope: scope
            )
        ) { error in
            XCTAssertEqual(
                error as? BusinessFinanceControlSnapshotValidationError,
                .scopeMismatch
            )
        }
    }

    func testRejectsAuthoritativeAccountingClaim() {
        XCTAssertThrowsError(
            try validator.validate(
                BusinessFinanceControlTestFixtures.snapshot(
                    authoritativeAccounting: true
                ),
                requestedScope: scope
            )
        ) { error in
            XCTAssertEqual(
                error as? BusinessFinanceControlSnapshotValidationError,
                .authoritativeAccountingNotAllowed
            )
        }
    }

    func testRejectsPostedAccountingStatus() {
        XCTAssertThrowsError(
            try validator.validate(
                BusinessFinanceControlTestFixtures.snapshot(
                    accountingStatus: .accountingPosted
                ),
                requestedScope: scope
            )
        ) { error in
            XCTAssertEqual(
                error as? BusinessFinanceControlSnapshotValidationError,
                .unsafeAccountingStatus
            )
        }
    }

    func testRejectsMixedCurrency() {
        XCTAssertThrowsError(
            try validator.validate(
                BusinessFinanceControlTestFixtures.snapshot(
                    functionalCurrency: "EUR",
                    amountCurrency: "GBP"
                ),
                requestedScope: scope
            )
        ) { error in
            XCTAssertEqual(
                error as? BusinessFinanceControlSnapshotValidationError,
                .mixedCurrency
            )
        }
    }

    func testRejectsUnmaskedExternalAccountReference() {
        XCTAssertThrowsError(
            try validator.validate(
                BusinessFinanceControlTestFixtures.snapshot(
                    maskedExternalReference: "123456789012"
                ),
                requestedScope: scope
            )
        ) { error in
            XCTAssertEqual(
                error as? BusinessFinanceControlSnapshotValidationError,
                .unmaskedExternalReference
            )
        }
    }
}

