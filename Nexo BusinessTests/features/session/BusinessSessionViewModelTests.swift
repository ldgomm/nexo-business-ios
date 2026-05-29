//
//  BusinessSessionViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSessionViewModelTests: XCTestCase {
    func testBootstrapWithoutStoredTokensShowsLogin() async {
        let tokenStore = InMemoryAuthTokenStore()
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: "org_1",
                branchId: "br_1",
                activityId: "act_1"
            )
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(viewModel.state, BusinessSessionState.signedOut())
        XCTAssertNil(viewModel.context)
        XCTAssertNil(viewModel.operationalSelection)
    }

    func testBootstrapWithStoredOrganizationAndOperationalSelectionSignsIn() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: "org_1",
                branchId: "br_1",
                activityId: "act_1"
            )
        )
        let context = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1")],
            activities: [makeActivity(id: "act_1")]
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            contextResult: .success(context)
        )

        await viewModel.bootstrapIfNeeded()

        let expectedSelection = BusinessOperationalSelection(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1"
        )
        XCTAssertEqual(viewModel.state, BusinessSessionState.signedIn(context, expectedSelection))
        XCTAssertEqual(viewModel.context, context)
        XCTAssertEqual(viewModel.operationalSelection, expectedSelection)
    }

    func testBootstrapWithSingleOrganizationAndSingleOperationAutoSelectsAndPersistsSelection() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let selectionStore = InMemoryBusinessSelectionStore()
        let context = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1")],
            activities: [makeActivity(id: "act_1")]
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            organizationsResult: .success(
                BusinessOrganizationAccessResponse(
                    organizations: [makeOrganization(id: "org_1")]
                )
            ),
            contextResult: .success(context)
        )

        await viewModel.bootstrapIfNeeded()

        let expectedSelection = BusinessOperationalSelection(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1"
        )
        XCTAssertEqual(viewModel.state, BusinessSessionState.signedIn(context, expectedSelection))
        XCTAssertEqual(viewModel.operationalSelection, expectedSelection)

        let snapshot = await selectionStore.snapshot()
        XCTAssertEqual(snapshot.organizationId, "org_1")
        XCTAssertEqual(snapshot.branchId, "br_1")
        XCTAssertEqual(snapshot.activityId, "act_1")
    }

    func testBootstrapWithMultipleOrganizationsRequiresOrganizationSelection() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let organizations = [
            makeOrganization(id: "org_1", name: "Altos del Murco"),
            makeOrganization(id: "org_2", name: "Sucursal Demo")
        ]
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            organizationsResult: .success(
                BusinessOrganizationAccessResponse(organizations: organizations)
            )
        )

        await viewModel.bootstrapIfNeeded()

        guard case let .needsOrganizationSelection(result) = viewModel.state else {
            return XCTFail("Expected needsOrganizationSelection, got: \(viewModel.state)")
        }

        XCTAssertEqual(result.map(\.id), ["org_1", "org_2"])
        XCTAssertNil(viewModel.context)
        XCTAssertNil(viewModel.operationalSelection)
    }

    func testBootstrapWithStoredOrganizationButMissingOperationalSelectionRequiresOperationalSelection() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(organizationId: "org_1")
        )
        let context = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1"), makeBranch(id: "br_2", name: "Sucursal Norte")],
            activities: [makeActivity(id: "act_1"), makeActivity(id: "act_2", name: "Turismo")]
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            contextResult: .success(context)
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(
            viewModel.state,
            BusinessSessionState.needsOperationalSelection(
                context: context,
                reason: "Selecciona la sucursal y actividad antes de vender, cobrar o cerrar caja."
            )
        )
        XCTAssertEqual(viewModel.context, context)
        XCTAssertNil(viewModel.operationalSelection)
    }

    func testSelectOperationalContextSignsInAndPersistsSelection() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(organizationId: "org_1")
        )
        let context = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1"), makeBranch(id: "br_2", name: "Sucursal Norte")],
            activities: [makeActivity(id: "act_1"), makeActivity(id: "act_2", name: "Turismo")]
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            contextResult: .success(context)
        )

        await viewModel.bootstrapIfNeeded()
        await viewModel.selectOperationalContext(branchId: "br_2", activityId: "act_2")

        let expectedSelection = BusinessOperationalSelection(
            organizationId: "org_1",
            branchId: "br_2",
            activityId: "act_2"
        )
        XCTAssertEqual(viewModel.state, BusinessSessionState.signedIn(context, expectedSelection))
        XCTAssertEqual(viewModel.operationalSelection, expectedSelection)

        let snapshot = await selectionStore.snapshot()
        XCTAssertEqual(snapshot.organizationId, "org_1")
        XCTAssertEqual(snapshot.branchId, "br_2")
        XCTAssertEqual(snapshot.activityId, "act_2")
    }

    func testUnauthorizedContextClearsTokensSelectionAndReturnsToLogin() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "expired-token")
        )
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: "org_1",
                branchId: "br_1",
                activityId: "act_1"
            )
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            contextResult: .failure(
                APIError.server(
                    statusCode: 401,
                    code: "unauthorized",
                    message: "Unauthorized",
                    requestId: "req_401"
                )
            )
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(
            viewModel.state,
            BusinessSessionState.signedOut(message: "Tu sesión caducó. Vuelve a iniciar sesión.")
        )
        XCTAssertNil(viewModel.context)
        XCTAssertNil(viewModel.operationalSelection)

        let storedTokens = await tokenStore.tokens()
        let snapshot = await selectionStore.snapshot()
        XCTAssertNil(storedTokens)
        XCTAssertNil(snapshot.organizationId)
        XCTAssertNil(snapshot.branchId)
        XCTAssertNil(snapshot.activityId)
    }

    func testLogoutClearsTokensSelectionAndReturnsToLogin() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: "org_1",
                branchId: "br_1",
                activityId: "act_1"
            )
        )
        let context = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1")],
            activities: [makeActivity(id: "act_1")]
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            contextResult: .success(context)
        )

        await viewModel.bootstrapIfNeeded()
        await viewModel.logout()

        XCTAssertEqual(viewModel.state, BusinessSessionState.signedOut())
        XCTAssertNil(viewModel.context)
        XCTAssertNil(viewModel.operationalSelection)

        let storedTokens = await tokenStore.tokens()
        let snapshot = await selectionStore.snapshot()
        XCTAssertNil(storedTokens)
        XCTAssertNil(snapshot.organizationId)
        XCTAssertNil(snapshot.branchId)
        XCTAssertNil(snapshot.activityId)
    }

    func testRefreshContextKeepsSignedInWhenSelectionExists() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: "org_1",
                branchId: "br_1",
                activityId: "act_1"
            )
        )
        let context = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1")],
            activities: [makeActivity(id: "act_1")]
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            contextResult: .success(context)
        )

        await viewModel.refreshContext()

        let expectedSelection = BusinessOperationalSelection(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1"
        )
        XCTAssertEqual(viewModel.state, BusinessSessionState.signedIn(context, expectedSelection))
        XCTAssertEqual(viewModel.context, context)
        XCTAssertEqual(viewModel.operationalSelection, expectedSelection)
    }

    private func makeViewModel(
        tokenStore: AuthTokenStoring = InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "valid-token")),
        selectionStore: BusinessSelectionStoring = InMemoryBusinessSelectionStore(),
        organizationsResult: Result<BusinessOrganizationAccessResponse, Error> = .success(
            BusinessOrganizationAccessResponse(
                organizations: [makeOrganization(id: "org_1")]
            )
        ),
        contextResult: Result<BusinessContextResponse, Error> = .success(
            makeContext(
                organizationId: "org_1",
                branches: [makeBranch(id: "br_1")],
                activities: [makeActivity(id: "act_1")]
            )
        )
    ) -> BusinessSessionViewModel {
        BusinessSessionViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            organizationAccessRepository: OrganizationAccessRepositoryStub(result: organizationsResult),
            contextRepository: BusinessContextRepositoryStub(result: contextResult)
        )
    }
}

private final class OrganizationAccessRepositoryStub: BusinessOrganizationAccessRepository, @unchecked Sendable {
    private let result: Result<BusinessOrganizationAccessResponse, Error>

    init(result: Result<BusinessOrganizationAccessResponse, Error>) {
        self.result = result
    }

    func listOrganizations() async throws -> BusinessOrganizationAccessResponse {
        try result.get()
    }
}

private final class BusinessContextRepositoryStub: BusinessContextRepository, @unchecked Sendable {
    private let result: Result<BusinessContextResponse, Error>

    init(result: Result<BusinessContextResponse, Error>) {
        self.result = result
    }

    func getContext(organizationId: String) async throws -> BusinessContextResponse {
        try result.get()
    }
}

private func makeOrganization(
    id: String,
    name: String = "Altos del Murco",
    status: String? = "active"
) -> BusinessOrganizationAccess {
    BusinessOrganizationAccess(
        id: id,
        commercialName: name,
        legalName: name,
        taxId: "1799999999001",
        countryCode: "EC",
        roleName: "Operador",
        status: status
    )
}

private func makeContext(
    organizationId: String,
    branches: [BusinessBranch],
    activities: [BusinessActivity]
) -> BusinessContextResponse {
    BusinessContextResponse(
        user: BusinessUser(
            id: "usr_test",
            displayName: "Operador Test",
            email: "operador@nexo.test"
        ),
        organization: BusinessOrganization(
            id: organizationId,
            commercialName: "Altos del Murco",
            legalName: "Altos del Murco",
            taxId: "1799999999001",
            countryCode: "EC"
        ),
        branches: branches,
        activities: activities,
        activeModules: [
            .coreSales,
            .coreCash,
            .coreDocuments,
            .foundationIdempotency,
            .foundationCatalogRevision,
            .foundationTaxRevision
        ],
        effectivePermissions: [
            "business.sales.create",
            "business.sales.preview",
            "business.sales.confirm",
            "business.sales.cancel",
            "cash.open",
            "cash.close",
            "cash.view_current",
            "business.cash.open",
            "business.cash.close",
            "business.cash.view_current",
            "business.documents.view",
            "documents.issue_internal_ticket"
        ],
        revisions: BusinessRevisions(
            catalogRevision: "cat_rev_test",
            taxConfigurationRevision: "tax_rev_test"
        ),
        readiness: BusinessReadiness(
            status: "ready",
            score: 100,
            blockers: [],
            warnings: []
        )
    )
}

private func makeBranch(
    id: String,
    name: String = "Matriz",
    status: String = "active"
) -> BusinessBranch {
    BusinessBranch(
        id: id,
        name: name,
        code: "001",
        status: status
    )
}

private func makeActivity(
    id: String,
    name: String = "Restaurante",
    status: String = "active"
) -> BusinessActivity {
    BusinessActivity(
        id: id,
        code: "restaurant",
        name: name,
        activityType: "restaurant",
        workflowMode: "quick_sale",
        status: status
    )
}
