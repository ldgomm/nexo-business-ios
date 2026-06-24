//
//  BusinessExportsView.swift
//  Nexo Business
//
//  Created by José Ruiz on 23/6/26.
//

import SwiftUI

struct BusinessExportsView: View {
    @Bindable private var viewModel: BusinessExportsViewModel

    init(viewModel: BusinessExportsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            periodSection
            messagesSection
            summarySection
            chartsSection
            availableExportsSection
            actionSection
        }
        .navigationTitle("Exportar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    if viewModel.isLoading || viewModel.isLoadingSummary {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isLoadingSummary || viewModel.isGenerating)
                .accessibilityLabel("Actualizar informe")
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onChange(of: viewModel.selectedPreset) { _, _ in
            viewModel.clearGeneratedReport()
            Task { await viewModel.loadSummary() }
        }
        .onChange(of: viewModel.customStartDate) { _, _ in
            guard viewModel.selectedPreset == .custom else { return }
            viewModel.clearGeneratedReport()
            Task { await viewModel.loadSummary() }
        }
        .onChange(of: viewModel.customEndDate) { _, _ in
            guard viewModel.selectedPreset == .custom else { return }
            viewModel.clearGeneratedReport()
            Task { await viewModel.loadSummary() }
        }
    }

    private var periodSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Label("Informe operativo inteligente", systemImage: "chart.xyaxis.line")
                    .font(.headline)

                Picker("Período", selection: $viewModel.selectedPreset) {
                    ForEach(BusinessExportPeriodPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)

                if viewModel.selectedPreset == .custom {
                    DatePicker(
                        "Desde",
                        selection: $viewModel.customStartDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )

                    DatePicker(
                        "Hasta",
                        selection: $viewModel.customEndDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.periodDisplayText)
                        .font(.subheadline.weight(.semibold))
                    Text("PDF ejecutivo, HTML con diagramas, resumen JSON y CSV operativos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("No reemplaza al contador ni a obligaciones tributarias.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let validation = viewModel.validationMessage {
                    Label(validation, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.successMessage, !message.isEmpty {
            Section {
                Label(message, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section("Resumen") {
            if viewModel.isLoadingSummary {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Calculando informe…")
                        .foregroundStyle(.secondary)
                }
            } else if let summary = viewModel.summary {
                if !summary.hasData {
                    ContentUnavailableView(
                        "Sin movimientos",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No hay datos en este período. Cambia las fechas para generar un informe con contenido.")
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        BusinessExportMetricCard(title: "Vendido", value: summary.totals.grandTotal.displayText, systemImage: "cart")
                        BusinessExportMetricCard(title: "Cobrado", value: summary.totals.paidTotal.displayText, systemImage: "banknote")
                        BusinessExportMetricCard(title: "Por cobrar", value: summary.totals.receivableTotal.displayText, systemImage: "clock")
                        BusinessExportMetricCard(title: "Documentos", value: "\(summary.totals.authorizedDocumentCount)/\(summary.totals.documentCount)", systemImage: "doc.text")
                    }
                    .padding(.vertical, 4)

                    if let comparison = summary.comparisons.first {
                        Label("\(comparison.label): \(comparison.deltaDisplayText)", systemImage: "arrow.left.arrow.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ForEach(summary.recommendedSummary, id: \.self) { item in
                        Label(item, systemImage: "sparkles")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Sin resumen",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Selecciona un período y actualiza para calcular el informe.")
                )
            }
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        if let summary = viewModel.summary, summary.hasData {
            Section("Diagramas") {
                Picker("Diagrama", selection: $viewModel.selectedChart) {
                    ForEach(BusinessExportChartKind.allCases) { chart in
                        Text(chart.displayName).tag(chart)
                    }
                }
                .pickerStyle(.segmented)

                BusinessExportInteractiveBarsView(
                    title: viewModel.selectedChart.displayName,
                    points: viewModel.chartPoints(for: viewModel.selectedChart)
                )

                if !summary.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alertas")
                            .font(.subheadline.weight(.semibold))
                        ForEach(summary.alerts) { alert in
                            Label(alert.message, systemImage: alert.severity == "warning" ? "exclamationmark.triangle" : "info.circle")
                                .font(.caption)
                                .foregroundStyle(alert.severity == "warning" ? .orange : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var availableExportsSection: some View {
        Section("Disponible") {
            switch viewModel.state {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Consultando exportaciones…")
                        .foregroundStyle(.secondary)
                }

            case let .failed(message):
                ContentUnavailableView {
                    Label("No se pudo cargar", systemImage: "tray")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") {
                        Task { await viewModel.load() }
                    }
                }

            case let .loaded(exports):
                if exports.isEmpty {
                    ContentUnavailableView(
                        "Sin exportaciones disponibles",
                        systemImage: "tray",
                        description: Text("Cuando el backend tenga una exportación operativa disponible aparecerá aquí.")
                    )
                } else {
                    ForEach(exports) { export in
                        BusinessExportDescriptorRow(
                            export: export,
                            sizeText: viewModel.sizeText(for: export)
                        )
                    }
                }
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                Task { await viewModel.generateAndDownloadOperationalZip() }
            } label: {
                HStack {
                    Label("Generar informe inteligente", systemImage: "square.and.arrow.down")
                    Spacer(minLength: 12)
                    if viewModel.isGenerating {
                        ProgressView()
                    }
                }
            }
            .disabled(!viewModel.canGenerateOperationalReport)

            if let file = viewModel.downloadedFile {
                ShareLink(item: file.localURL) {
                    Label("Compartir \(file.fileName)", systemImage: "square.and.arrow.up")
                }

                LabeledContent("Tamaño", value: file.sizeText)

                if let sha256 = file.sha256, !sha256.isEmpty {
                    LabeledContent("SHA-256", value: sha256)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        } footer: {
            Text("El ZIP incluye PDF, HTML con diagramas, JSON de resumen, CSV operativos y manifest. El archivo queda temporalmente en el dispositivo para compartirlo desde iOS.")
        }
    }
}

private struct BusinessExportMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BusinessExportInteractiveBarsView: View {
    let title: String
    let points: [BusinessExportChartPoint]

    @State private var selectedId: String?

    private var visiblePoints: [BusinessExportChartPoint] {
        Array(points.prefix(10))
    }

    private var maxValue: Double {
        max(visiblePoints.map { $0.value }.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if visiblePoints.isEmpty {
                BusinessExportEmptyChartView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(visiblePoints, id: \.id) { point in
                        BusinessExportInteractiveBarRow(
                            point: point,
                            maxValue: maxValue,
                            isSelected: selectedId == point.id
                        ) {
                            toggle(point)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func toggle(_ point: BusinessExportChartPoint) {
        selectedId = selectedId == point.id ? nil : point.id
    }
}

private struct BusinessExportEmptyChartView: View {
    var body: some View {
        ContentUnavailableView(
            "Sin datos para graficar",
            systemImage: "chart.bar",
            description: Text("Este período no tiene datos suficientes para este diagrama.")
        )
    }
}

private struct BusinessExportInteractiveBarRow: View {
    let point: BusinessExportChartPoint
    let maxValue: Double
    let isSelected: Bool
    let onTap: () -> Void

    private var progress: CGFloat {
        guard maxValue > 0 else { return 0 }
        let rawValue = point.value / maxValue
        let clampedValue = min(max(rawValue, 0), 1)
        return CGFloat(clampedValue)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                header
                BusinessExportInteractiveBar(progress: progress, isSelected: isSelected)
                subtitle
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(point.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(point.valueText)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if isSelected, let subtitle = point.subtitle, !subtitle.isEmpty {
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct BusinessExportInteractiveBar: View {
    let progress: CGFloat
    let isSelected: Bool

    private var safeProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var barFillColor: Color {
        isSelected
            ? Color.primary.opacity(0.55)
            : Color.primary.opacity(0.28)
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let filledWidth = max(availableWidth * safeProgress, 8)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.14))

                Capsule()
                    .fill(barFillColor)
                    .frame(width: filledWidth)
            }
        }
        .frame(height: 12)
        .animation(.snappy(duration: 0.18), value: safeProgress)
        .animation(.snappy(duration: 0.18), value: isSelected)
    }
}

private struct BusinessExportDescriptorRow: View {
    let export: BusinessExportDescriptor
    let sizeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(export.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Spacer(minLength: 12)

                if let version = export.version, !version.isEmpty {
                    Text(version)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let description = export.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let contentType = export.contentType, !contentType.isEmpty {
                    Label(contentType, systemImage: "doc.zipper")
                }

                if let sizeText {
                    Label(sizeText, systemImage: "externaldrive")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
