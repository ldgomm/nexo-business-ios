//
//  OperationalHardeningView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct OperationalHardeningView: View {
    @Bindable private var viewModel: OperationalHardeningViewModel

    public init(viewModel: OperationalHardeningViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            content
        }
        .navigationTitle("Diagnóstico")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isRunning)
            }
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.run()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Revisando estado operativo…")
                        .foregroundStyle(.secondary)
                }
            }

        case let .failed(message):
            Section {
                ContentUnavailableView {
                    Label("No se pudo diagnosticar", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") {
                        Task { await viewModel.run() }
                    }
                }
            }

        case let .loaded(report):
            summarySection(report)
            blockersSection(report)
            warningsSection(report)
            passedSection(report)
        }
    }

    private func summarySection(_ report: OperationalHardeningReport) -> some View {
        Section("Resumen") {
            Label(
                report.isReadyForPilot ? "Listo para piloto operativo" : "Hay bloqueantes antes del piloto",
                systemImage: report.isReadyForPilot ? "checkmark.seal.fill" : "xmark.octagon.fill"
            )
            .foregroundStyle(report.isReadyForPilot ? .green : .red)

            LabeledContent("Bloqueantes", value: String(report.blockers.count))
            LabeledContent("Advertencias", value: String(report.warnings.count))
            LabeledContent("Checks OK", value: String(report.passed.count))
            LabeledContent("Revisado", value: report.checkedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    @ViewBuilder
    private func blockersSection(_ report: OperationalHardeningReport) -> some View {
        if !report.blockers.isEmpty {
            Section("Bloqueantes") {
                ForEach(report.blockers) { check in
                    OperationalHardeningCheckRow(check: check)
                }
            }
        }
    }

    @ViewBuilder
    private func warningsSection(_ report: OperationalHardeningReport) -> some View {
        if !report.warnings.isEmpty {
            Section("Advertencias") {
                ForEach(report.warnings) { check in
                    OperationalHardeningCheckRow(check: check)
                }
            }
        }
    }

    private func passedSection(_ report: OperationalHardeningReport) -> some View {
        Section("Correcto") {
            ForEach(report.passed) { check in
                OperationalHardeningCheckRow(check: check)
            }
        }
    }
}

private struct OperationalHardeningCheckRow: View {
    let check: OperationalHardeningCheck

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(.subheadline.weight(.semibold))

                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var systemImage: String {
        switch check.status {
        case .passed:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch check.status {
        case .passed:
            return .green
        case .warning:
            return .orange
        case .failed:
            return .red
        }
    }
}

#Preview {
    NavigationStack {
        OperationalHardeningView(
            viewModel: OperationalHardeningViewModel(
                context: PreviewData.businessContext,
                operationalSelection: PreviewData.operationalSelection,
                tokenStore: InMemoryAuthTokenStore(
                    tokens: AuthTokens(accessToken: "preview-token")
                ),
                networkStatusProvider: StaticNetworkStatusProvider(status: .satisfied)
            )
        )
    }
}
