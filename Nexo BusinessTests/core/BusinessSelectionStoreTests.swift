//
//  BusinessSelectionStoreTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessSelectionStoreTests: XCTestCase {
    func testInMemorySelectionPersistsOrganizationAndOperationalContext() async throws {
        let store = InMemoryBusinessSelectionStore()

        try await store.saveOrganizationId("org_1")
        try await store.saveOperationalContext(branchId: "br_1", activityId: "act_1")

        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.organizationId, "org_1")
        XCTAssertEqual(snapshot.branchId, "br_1")
        XCTAssertEqual(snapshot.activityId, "act_1")
    }

    func testSavingOrganizationClearsBranchAndActivity() async throws {
        let store = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: "org_1",
                branchId: "br_1",
                activityId: "act_1"
            )
        )

        try await store.saveOrganizationId("org_2")

        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.organizationId, "org_2")
        XCTAssertNil(snapshot.branchId)
        XCTAssertNil(snapshot.activityId)
    }

    func testClearAllRemovesEverything() async throws {
        let store = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: "org_1",
                branchId: "br_1",
                activityId: "act_1"
            )
        )

        try await store.clearAll()

        let snapshot = await store.snapshot()

        XCTAssertNil(snapshot.organizationId)
        XCTAssertNil(snapshot.branchId)
        XCTAssertNil(snapshot.activityId)
    }
}
