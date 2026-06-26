//
//  OperationalHardeningView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct OperationalHardeningView: View {
    @Bindable private var viewModel: OperationalHardeningViewModel

    init(viewModel: OperationalHardeningViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Diagnóstico")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    if viewModel.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRunning)
                .accessibilityLabel("Actualizar diagnóstico")
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
            OperationalHardeningLoadingCard()
                .operationalHardeningHeroSurface()

        case let .failed(message):
            OperationalHardeningFailedCard(message: message) {
                Task { await viewModel.run() }
            }
            .operationalHardeningHeroSurface()

        case let .loaded(report):
            summarySection(report)
                .operationalHardeningHeroSurface()

            blockersSection(report)

            warningsSection(report)

            passedSection(report)
        }
    }

    private func summarySection(_ report: OperationalHardeningReport) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                OperationalHardeningIconBadge(
                    systemImage: report.isReadyForPilot ? "checkmark.seal.fill" : "xmark.octagon.fill",
                    tint: report.isReadyForPilot ? .green : .red
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Diagnostics")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(report.isReadyForPilot ? "Listo para piloto operativo" : "Hay bloqueantes antes del piloto")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("Lectura ejecutiva de readiness, advertencias y checks técnicos relevantes.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                OperationalHardeningPill(
                    title: "Bloqueantes \(report.blockers.count)",
                    systemImage: "xmark.octagon",
                    tint: report.blockers.isEmpty ? .secondary : .red
                )

                OperationalHardeningPill(
                    title: "WARN \(report.warnings.count)",
                    systemImage: "exclamationmark.triangle",
                    tint: report.warnings.isEmpty ? .secondary : .orange
                )

                OperationalHardeningPill(
                    title: "PASS \(report.passed.count)",
                    systemImage: "checkmark.circle",
                    tint: .green
                )
            }

            OperationalHardeningFactRow(
                title: "Revisado",
                value: report.checkedAt.formatted(date: .abbreviated, time: .shortened),
                systemImage: "clock"
            )
        }
    }

    @ViewBuilder
    private func blockersSection(_ report: OperationalHardeningReport) -> some View {
        if !report.blockers.isEmpty {
            OperationalHardeningSectionCard(
                title: "Bloqueantes",
                subtitle: "Debe resolverse antes de considerar listo el piloto.",
                systemImage: "xmark.octagon",
                tint: .red
            ) {
                VStack(spacing: 10) {
                    ForEach(report.blockers) { check in
                        OperationalHardeningCheckRow(check: check)
                    }
                }
            }
            .operationalHardeningSurface()
        }
    }

    @ViewBuilder
    private func warningsSection(_ report: OperationalHardeningReport) -> some View {
        if !report.warnings.isEmpty {
            OperationalHardeningSectionCard(
                title: "Advertencias",
                subtitle: "No bloquean necesariamente, pero conviene revisarlas.",
                systemImage: "exclamationmark.triangle",
                tint: .orange
            ) {
                VStack(spacing: 10) {
                    ForEach(report.warnings) { check in
                        OperationalHardeningCheckRow(check: check)
                    }
                }
            }
            .operationalHardeningSurface()
        }
    }

    private func passedSection(_ report: OperationalHardeningReport) -> some View {
        OperationalHardeningSectionCard(
            title: "Correcto",
            subtitle: "Checks que ya están en estado operativo aceptable.",
            systemImage: "checkmark.circle",
            tint: .green
        ) {
            if report.passed.isEmpty {
                OperationalHardeningEmptyCard(
                    title: "Sin checks aprobados todavía",
                    message: "Cuando el diagnóstico encuentre checks correctos aparecerán aquí.",
                    systemImage: "checkmark.circle"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(report.passed) { check in
                        OperationalHardeningCheckRow(check: check)
                    }
                }
            }
        }
        .operationalHardeningSurface()
    }
}

private struct OperationalHardeningSurfaceModifier: ViewModifier {
    var isHero: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(isHero ? 18 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isHero {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.16),
                            Color(uiColor: .secondarySystemGroupedBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(uiColor: .secondarySystemGroupedBackground)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: isHero ? 26 : 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: isHero ? 26 : 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isHero ? 0.04 : 0.025), radius: isHero ? 10 : 7, x: 0, y: isHero ? 5 : 3)
    }
}

private extension View {
    func operationalHardeningSurface() -> some View {
        modifier(OperationalHardeningSurfaceModifier())
    }

    func operationalHardeningHeroSurface() -> some View {
        modifier(OperationalHardeningSurfaceModifier(isHero: true))
    }
}

private struct OperationalHardeningLoadingCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ProgressView()
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 5) {
                Text("Revisando estado operativo…")
                    .font(.headline.weight(.bold))

                Text("Estamos validando readiness, permisos, dependencias y condiciones mínimas del piloto.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct OperationalHardeningFailedCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                OperationalHardeningIconBadge(systemImage: "exclamationmark.triangle.fill", tint: .red)

                VStack(alignment: .leading, spacing: 5) {
                    Text("No se pudo diagnosticar")
                        .font(.title3.weight(.bold))

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button("Reintentar", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

private struct OperationalHardeningSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                OperationalHardeningIconBadge(systemImage: systemImage, tint: tint, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.bold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
    }
}

private struct OperationalHardeningCheckRow: View {
    let check: OperationalHardeningCheck

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 26)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.10), lineWidth: 1)
        )
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

private struct OperationalHardeningIconBadge: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemImage)
            .font((size > 38 ? Font.headline : Font.subheadline).weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size > 38 ? 15 : 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size > 38 ? 15 : 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct OperationalHardeningPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct OperationalHardeningFactRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OperationalHardeningEmptyCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
