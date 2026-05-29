//
//  PilotReadinessViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class PilotReadinessViewModelTests: XCTestCase {
    func testInitialLoadUsesDefaultChecklistWhenStoreIsEmpty() async {
        let store = PreviewPilotChecklistStore()
        let viewModel = makeViewModel(store: store)

        await viewModel.load()

        XCTAssertFalse(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.snapshot.isReadyForPilot)
        XCTAssertGreaterThan(viewModel.snapshot.blockers.count, 0)
    }

    func testTogglePersistsItemAndImprovesScore() async {
        let store = PreviewPilotChecklistStore()
        let viewModel = makeViewModel(store: store)

        await viewModel.load()
        let originalScore = viewModel.snapshot.score
        let itemId = viewModel.items.first(where: { $0.isRequired })!.id

        await viewModel.toggle(itemId: itemId)

        XCTAssertGreaterThanOrEqual(viewModel.snapshot.score, originalScore)

        let saved = await store.load(organizationId: PreviewData.businessContext.organization.id)
        XCTAssertEqual(saved?.first(where: { $0.id == itemId })?.isDone, true)
    }

    func testMarkAllRequiredDoneMakesPilotReadyWhenContextIsHealthy() async {
        let store = PreviewPilotChecklistStore()
        let viewModel = makeViewModel(store: store)

        await viewModel.load()
        await viewModel.markAllRequiredDone()

        XCTAssertEqual(viewModel.snapshot.score, 100)
        XCTAssertTrue(viewModel.snapshot.isReadyForPilot)
    }

    func testMissingOperationalSelectionCreatesBlockerEvenWithCompletedChecklist() async {
        let store = PreviewPilotChecklistStore(items: PreviewPilotData.completedPilotChecklist)
        let viewModel = PilotReadinessViewModel(
            context: PreviewData.businessContext,
            selectedBranchId: "",
            selectedActivityId: "",
            store: store
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.snapshot.isReadyForPilot)
        XCTAssertTrue(viewModel.snapshot.blockers.contains { $0.id == "missing_branch_selection" })
        XCTAssertTrue(viewModel.snapshot.blockers.contains { $0.id == "missing_activity_selection" })
    }

    func testExportTextContainsOperationalSummary() async {
        let store = PreviewPilotChecklistStore(items: PreviewPilotData.completedPilotChecklist)
        let viewModel = makeViewModel(store: store)

        await viewModel.load()
        let export = viewModel.makeExportText()

        XCTAssertTrue(export.contains("Nexo Business — Cierre Fase 15 / Piloto"))
        XCTAssertTrue(export.contains(PreviewData.businessContext.organization.commercialName))
        XCTAssertTrue(export.contains("Checklist"))
    }

    private func makeViewModel(
        store: PilotChecklistStoring
    ) -> PilotReadinessViewModel {
        PilotReadinessViewModel(
            context: PreviewData.businessContext,
            selectedBranchId: PreviewData.businessContext.branches.first?.id ?? "br_001",
            selectedActivityId: PreviewData.businessContext.activities.first?.id ?? "act_restaurant",
            store: store
        )
    }
}
