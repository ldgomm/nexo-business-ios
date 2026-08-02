//
//  BusinessFinanceControlAccessPolicyTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import XCTest
@testable import Nexo_Business

class BusinessFinanceControlAccessPolicyTests: XCTestCase {
    func testNoPermissionCannotOpenSurface() {
        let policy = BusinessFinanceControlAccessPolicy(
            effectivePermissions: []
        )

        XCTAssertFalse(policy.canViewSurface)
        XCTAssertFalse(policy.canView(.movements))
    }

    func testReadPermissionOnlyOpensItsSurface() {
        let policy = BusinessFinanceControlAccessPolicy(
            effectivePermissions: [
                BusinessFinanceControlPermission.movementsView
            ]
        )

        XCTAssertTrue(policy.canViewSurface)
        XCTAssertTrue(policy.canView(.movements))
        XCTAssertFalse(policy.canView(.historicalImport))
        XCTAssertFalse(policy.canView(.coverageAndCutover))
    }

    func testSuperuserCanViewEverySurface() {
        let policy = BusinessFinanceControlAccessPolicy(
            effectivePermissions: ["*"]
        )

        XCTAssertTrue(policy.canViewSurface)
        for surface in BusinessFinanceControlSurface.allCases {
            XCTAssertTrue(policy.canView(surface))
        }
    }

    func testUploadRequiresPermissionAndBackendCapability() {
        let policy = BusinessFinanceControlAccessPolicy(
            effectivePermissions: [
                BusinessFinanceControlPermission.historicalImportUpload
            ]
        )

        XCTAssertFalse(
            policy.allows(
                .uploadHistoricalImport,
                capabilities: .init(canUploadHistoricalImport: false)
            )
        )
        XCTAssertTrue(
            policy.allows(
                .uploadHistoricalImport,
                capabilities: .init(canUploadHistoricalImport: true)
            )
        )
    }

    func testReviewRequiresPermissionAndBackendCapability() {
        let capability = BusinessFinanceControlCapabilities(
            canReviewReconciliation: true
        )

        XCTAssertFalse(
            BusinessFinanceControlAccessPolicy(
                effectivePermissions: []
            ).allows(.reviewReconciliation, capabilities: capability)
        )
        XCTAssertTrue(
            BusinessFinanceControlAccessPolicy(
                effectivePermissions: [
                    BusinessFinanceControlPermission.reconciliationReview
                ]
            ).allows(.reviewReconciliation, capabilities: capability)
        )
    }
}

