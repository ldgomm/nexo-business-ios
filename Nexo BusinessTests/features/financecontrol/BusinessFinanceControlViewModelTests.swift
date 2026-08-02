//
//  BusinessFinanceControlViewModelTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
class BusinessFinanceControlViewModelTests: XCTestCase {
    private let scope = BusinessFinanceControlScope(
        organizationId: "org_synthetic",
        branchId: "branch_1",
        activityId: "activity_1"
    )

    func testLoadsValidatedBackendSnapshotWithoutLocalAggregation() async {
        let expected = BusinessFinanceControlTestFixtures.snapshot()
        let repository = BusinessFinanceControlRepositoryStub(
            result: .success(expected)
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.snapshot, expected)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(repository.requestedScopes, [scope])
    }

    func testUnsafeAuthoritativeSnapshotIsNotPresented() async {
        let repository = BusinessFinanceControlRepositoryStub(
            result: .success(
                BusinessFinanceControlTestFixtures.snapshot(
                    authoritativeAccounting: true
                )
            )
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertNil(viewModel.snapshot)
        XCTAssertEqual(
            viewModel.errorMessage,
            "No fue posible cargar la información financiera de forma segura."
        )
    }

    func testMissingPermissionStopsBeforeRepository() async {
        let repository = BusinessFinanceControlRepositoryStub(
            result: .success(BusinessFinanceControlTestFixtures.snapshot())
        )
        let viewModel = BusinessFinanceControlViewModel(
            scope: scope,
            effectivePermissions: [],
            repository: repository
        )

        await viewModel.load()

        XCTAssertTrue(repository.requestedScopes.isEmpty)
        XCTAssertNil(viewModel.snapshot)
        XCTAssertEqual(
            viewModel.errorMessage,
            "No tienes permiso para consultar esta información."
        )
    }

    func testDeferredRuntimeFailsClosedWithoutInventingValues() async {
        let repository = BusinessFinanceControlRepositoryStub(
            result: .failure(.runtimeEndpointUnavailable)
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertNil(viewModel.snapshot)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("cierre runtime de 28R") == true
        )
    }

    func testActionRequiresPermissionAndBackendCapability() async {
        let repository = BusinessFinanceControlRepositoryStub(
            result: .success(
                BusinessFinanceControlTestFixtures.snapshot(
                    capabilities: .init(
                        canUploadHistoricalImport: true,
                        canPreviewHistoricalImport: true,
                        canReviewReconciliation: true
                    )
                )
            )
        )
        let viewModel = BusinessFinanceControlViewModel(
            scope: scope,
            effectivePermissions: [
                BusinessFinanceControlPermission.movementsView,
                BusinessFinanceControlPermission.historicalImportUpload
            ],
            repository: repository
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.allows(.uploadHistoricalImport))
        XCTAssertFalse(viewModel.allows(.previewHistoricalImport))
        XCTAssertFalse(viewModel.allows(.reviewReconciliation))
    }

    private func makeViewModel(
        repository: BusinessFinanceControlRepositoryStub
    ) -> BusinessFinanceControlViewModel {
        BusinessFinanceControlViewModel(
            scope: scope,
            effectivePermissions: ["*"],
            repository: repository
        )
    }
}

private class BusinessFinanceControlRepositoryStub:
    BusinessFinanceControlRepository,
    @unchecked Sendable
{
    let result: Result<
        BusinessFinanceControlSnapshot,
        BusinessFinanceControlRepositoryError
    >
    var requestedScopes: [BusinessFinanceControlScope] = []

    init(
        result: Result<
            BusinessFinanceControlSnapshot,
            BusinessFinanceControlRepositoryError
        >
    ) {
        self.result = result
    }

    func loadSnapshot(
        scope: BusinessFinanceControlScope
    ) async throws -> BusinessFinanceControlSnapshot {
        requestedScopes.append(scope)
        return try result.get()
    }
}

