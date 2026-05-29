//
//  BusinessSessionOperationalSelectionTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSessionOperationalSelectionTests: XCTestCase {
    func testBootstrapWithoutTokenSignsOut() async {
        let viewModel = makeViewModel(tokenStore: InMemoryAuthTokenStore())

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(viewModel.state, .signedOut())
    }

    func testBootstrapWithOneOrganizationAndOneOperationalContextSignsIn() async {
        let tokenStore = InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "token"))
        let selectionStore = InMemoryBusinessSelectionStore()
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            organizations: [makeOrganization(id: "org_1")],
            context: makeContext(
                organizationId: "org_1",
                branches: [makeBranch(id: "br_1")],
                activities: [makeActivity(id: "act_1")]
            )
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(
            viewModel.state,
            .signedIn(
                makeContext(
                    organizationId: "org_1",
                    branches: [makeBranch(id: "br_1")],
                    activities: [makeActivity(id: "act_1")]
                ),
                BusinessOperationalSelection(
                    organizationId: "org_1",
                    branchId: "br_1",
                    activityId: "act_1"
                )
            )
        )
    }

    func testBootstrapWithMultipleOrganizationsRequestsOrganizationSelection() async {
        let tokenStore = InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "token"))
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            organizations: [
                makeOrganization(id: "org_1"),
                makeOrganization(id: "org_2", name: "Tienda Demo")
            ]
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(
            viewModel.state,
            .needsOrganizationSelection([
                makeOrganization(id: "org_1"),
                makeOrganization(id: "org_2", name: "Tienda Demo")
            ])
        )
    }

    func testContextWithMultipleBranchesRequestsOperationalSelection() async {
        let tokenStore = InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "token"))
        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(organizationId: "org_1")
        )
        let context = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1"), makeBranch(id: "br_2", name: "Sucursal Norte")],
            activities: [makeActivity(id: "act_1")]
        )
        let viewModel = makeViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            context: context
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(
            viewModel.state,
            .needsOperationalSelection(
                context: context,
                reason: "Selecciona la sucursal y actividad antes de vender, cobrar o cerrar caja."
            )
        )
    }

    func testSelectOperationalContextSignsInAndPersistsSelection() async {
        let tokenStore = InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "token"))
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
            context: context
        )

        await viewModel.bootstrapIfNeeded()
        await viewModel.selectOperationalContext(branchId: "br_2", activityId: "act_2")

        XCTAssertEqual(
            viewModel.state,
            .signedIn(
                context,
                BusinessOperationalSelection(
                    organizationId: "org_1",
                    branchId: "br_2",
                    activityId: "act_2"
                )
            )
        )

        let snapshot = await selectionStore.snapshot()
        XCTAssertEqual(snapshot.branchId, "br_2")
        XCTAssertEqual(snapshot.activityId, "act_2")
    }

    private func makeViewModel(
        tokenStore: AuthTokenStoring = InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "token")),
        selectionStore: BusinessSelectionStoring = InMemoryBusinessSelectionStore(),
        organizations: [BusinessOrganizationAccess] = [makeOrganization(id: "org_1")],
        context: BusinessContextResponse = makeContext(
            organizationId: "org_1",
            branches: [makeBranch(id: "br_1")],
            activities: [makeActivity(id: "act_1")]
        )
    ) -> BusinessSessionViewModel {
        BusinessSessionViewModel(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            organizationAccessRepository: OrganizationAccessRepositoryStub(organizations: organizations),
            contextRepository: BusinessContextRepositoryStub(context: context)
        )
    }
}

private final class OrganizationAccessRepositoryStub: BusinessOrganizationAccessRepository, @unchecked Sendable {
    let organizations: [BusinessOrganizationAccess]

    init(organizations: [BusinessOrganizationAccess]) {
        self.organizations = organizations
    }

    func listOrganizations() async throws -> BusinessOrganizationAccessResponse {
        BusinessOrganizationAccessResponse(organizations: organizations)
    }
}

private final class BusinessContextRepositoryStub: BusinessContextRepository, @unchecked Sendable {
    let context: BusinessContextResponse

    init(context: BusinessContextResponse) {
        self.context = context
    }

    func getContext(organizationId: String) async throws -> BusinessContextResponse {
        context
    }
}

private func makeOrganization(
    id: String,
    name: String = "Altos del Murco"
) -> BusinessOrganizationAccess {
    BusinessOrganizationAccess(
        id: id,
        commercialName: name,
        legalName: name,
        taxId: "1799999999001",
        countryCode: "EC",
        roleName: "Operador",
        status: "active"
    )
}

private func makeContext(
    organizationId: String,
    branches: [BusinessBranch],
    activities: [BusinessActivity]
) -> BusinessContextResponse {
    BusinessContextResponse(
        user: BusinessUser(
            id: "usr_1",
            displayName: "Operador",
            email: "op@nexo.test"
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
        activeModules: [.coreSales, .coreCash],
        effectivePermissions: ["business.sales.create", "cash.open"],
        revisions: BusinessRevisions(
            catalogRevision: "cat_rev_1",
            taxConfigurationRevision: "tax_rev_1"
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
        code: id,
        name: name,
        activityType: "restaurant",
        workflowMode: "quick_sale",
        status: status
    )
}
