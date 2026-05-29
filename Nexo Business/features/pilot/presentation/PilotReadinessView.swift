//
//  PilotReadinessView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct PilotReadinessView: View {
    @Bindable private var viewModel: PilotReadinessViewModel
    @State private var exportText: String?

    public init(viewModel: PilotReadinessViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            summarySection
            contextSection
            issuesSection
            checklistSection
            exportSection
            messagesSection
            actionsSection
        }
        .navigationTitle("Cierre piloto")
        .task {
            if viewModel.items.isEmpty {
                await viewModel.load()
            }
        }
    }

    private var summarySection: some View {
        Section("Estado de piloto") {
            let snapshot = viewModel.snapshot

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(snapshot.score)%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.statusTitle)
                            .font(.headline)
                        Text(viewModel.readyStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: Double(snapshot.completedRequired), total: Double(max(snapshot.totalRequired, 1)))

                Text("Requeridos: \(snapshot.completedRequired)/\(snapshot.totalRequired) · Opcionales: \(snapshot.completedOptional)/\(snapshot.totalOptional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var contextSection: some View {
        Section("Contexto operativo") {
            LabeledContent("Negocio", value: viewModel.context.organization.commercialName)
            LabeledContent("Organización", value: viewModel.context.organization.id)
            LabeledContent("Sucursal", value: emptyFallback(viewModel.selectedBranchId))
            LabeledContent("Actividad", value: emptyFallback(viewModel.selectedActivityId))
            LabeledContent("Readiness", value: viewModel.context.readiness.status)
            LabeledContent("Catalog revision", value: viewModel.context.revisions.catalogRevision)
            LabeledContent("Tax revision", value: viewModel.context.revisions.taxConfigurationRevision)
        }
    }

    @ViewBuilder
    private var issuesSection: some View {
        if !viewModel.snapshot.blockers.isEmpty {
            Section("Bloqueantes") {
                ForEach(viewModel.snapshot.blockers) { issue in
                    PilotIssueRow(issue: issue)
                }
            }
        }

        if !viewModel.snapshot.warnings.isEmpty {
            Section("Advertencias") {
                ForEach(viewModel.snapshot.warnings) { issue in
                    PilotIssueRow(issue: issue)
                }
            }
        }
    }

    private var checklistSection: some View {
        ForEach(viewModel.groupedItems, id: \.category.id) { group in
            Section(group.category.displayName) {
                ForEach(group.items) { item in
                    PilotChecklistRow(item: item) {
                        Task { await viewModel.toggle(itemId: item.id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if let exportText {
            Section("Reporte de cierre") {
                Text(exportText)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.infoMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section("Acciones") {
            Button {
                Task { await viewModel.markAllRequiredDone() }
            } label: {
                Label("Marcar requeridos como revisados", systemImage: "checkmark.seal")
            }
            .disabled(viewModel.isSaving)

            Button {
                exportText = viewModel.makeExportText()
            } label: {
                Label("Generar reporte de cierre", systemImage: "doc.plaintext")
            }

            Button(role: .destructive) {
                Task { await viewModel.reset() }
            } label: {
                Label("Reiniciar checklist", systemImage: "arrow.counterclockwise")
            }
            .disabled(viewModel.isSaving)
        }
    }

    private func emptyFallback(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sin selección" : value
    }
}

private struct PilotIssueRow: View {
    let issue: PilotReadinessIssue

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.subheadline.weight(.semibold))
                Text(issue.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: issue.severity == .blocker ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
        }
    }
}

private struct PilotChecklistRow: View {
    let item: PilotChecklistItem
    let toggleAction: () -> Void

    var body: some View {
        Button(action: toggleAction) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? .green : .secondary)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if item.isRequired {
                            Text("Requerido")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                    }

                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let updatedAt = item.updatedAt {
                        Text("Actualizado: \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PilotReadinessView(
            viewModel: PilotReadinessViewModel(
                context: PreviewData.businessContext,
                selectedBranchId: PreviewData.businessContext.branches.first?.id ?? "",
                selectedActivityId: PreviewData.businessContext.activities.first?.id ?? "",
                store: PreviewPilotChecklistStore()
            )
        )
    }
}
