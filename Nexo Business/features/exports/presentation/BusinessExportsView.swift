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
        ScrollView {
            LazyVStack(spacing: 12) {
                periodSection

                if hasMessages {
                    messagesSection
                }

                summarySection

                if viewModel.summary?.hasData == true {
                    chartsSection
                }

                availableExportsSection
                actionSection
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Exportar")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshButton
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

    private var isBusy: Bool {
        viewModel.isLoading || viewModel.isLoadingSummary || viewModel.isGenerating
    }

    private var hasMessages: Bool {
        (viewModel.errorMessage?.isEmpty == false) ||
        (viewModel.successMessage?.isEmpty == false) ||
        (viewModel.validationMessage?.isEmpty == false)
    }

    private var refreshButton: some View {
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
        .disabled(isBusy)
        .accessibilityLabel("Actualizar informe")
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 14) {
                BusinessExportIconBadge(systemImage: "chart.xyaxis.line", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Reports")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Informe operativo")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("Genera un paquete ejecutivo con PDF, HTML, JSON, CSV y manifest para revisar la operación del negocio.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                BusinessExportStatusPill(
                    title: exportStatusTitle,
                    systemImage: exportStatusIcon,
                    tint: exportStatusTint
                )

                BusinessExportStatusPill(
                    title: viewModel.selectedPreset.displayName,
                    systemImage: "calendar",
                    tint: .accentColor
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                BusinessExportPickerRow(
                    title: "Período",
                    subtitle: viewModel.periodDisplayText,
                    systemImage: "calendar.badge.clock"
                ) {
                    Picker("Período", selection: $viewModel.selectedPreset) {
                        ForEach(BusinessExportPeriodPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if viewModel.selectedPreset == .custom {
                    VStack(spacing: 10) {
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
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                BusinessExportHintCard(
                    icon: "info.circle",
                    text: "Este informe ayuda a revisar ventas, cobros, documentos y exportables. No reemplaza al contador ni a las obligaciones tributarias."
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.16),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message = viewModel.errorMessage, !message.isEmpty {
                BusinessExportNoticeCard(
                    title: "No se pudo completar la operación",
                    message: message,
                    systemImage: "exclamationmark.triangle",
                    tint: .red
                )
            }

            if let message = viewModel.successMessage, !message.isEmpty {
                BusinessExportNoticeCard(
                    title: "Informe listo",
                    message: message,
                    systemImage: "checkmark.circle",
                    tint: .green
                )
            }

            if let validation = viewModel.validationMessage, !validation.isEmpty {
                BusinessExportNoticeCard(
                    title: "Revisa el período",
                    message: validation,
                    systemImage: "calendar.badge.exclamationmark",
                    tint: .orange
                )
            }
        }
        .businessExportSurface()
    }

    @ViewBuilder
    private var summarySection: some View {
        BusinessExportCard(
            title: "Resumen ejecutivo",
            subtitle: "Indicadores principales del período seleccionado.",
            systemImage: "chart.bar.doc.horizontal"
        ) {
            if viewModel.isLoadingSummary {
                BusinessExportLoadingRow(
                    title: "Calculando informe…",
                    subtitle: "Preparando ventas, cobros, cartera y documentos."
                )
            } else if let summary = viewModel.summary {
                if !summary.hasData {
                    BusinessExportEmptyState(
                        title: "Sin movimientos",
                        message: "No hay datos en este período. Cambia las fechas para generar un informe con contenido.",
                        systemImage: "calendar.badge.exclamationmark"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        LazyVGrid(columns: metricColumns, spacing: 12) {
                            BusinessExportMetricCard(
                                title: "Vendido",
                                value: summary.totals.grandTotal.displayText,
                                systemImage: "cart.fill"
                            )

                            BusinessExportMetricCard(
                                title: "Cobrado",
                                value: summary.totals.paidTotal.displayText,
                                systemImage: "banknote.fill"
                            )

                            BusinessExportMetricCard(
                                title: "Por cobrar",
                                value: summary.totals.receivableTotal.displayText,
                                systemImage: "clock.fill"
                            )

                            BusinessExportMetricCard(
                                title: "Documentos",
                                value: "\(summary.totals.authorizedDocumentCount)/\(summary.totals.documentCount)",
                                systemImage: "doc.text.fill"
                            )
                        }

                        if let comparison = summary.comparisons.first {
                            BusinessExportInfoRow(
                                title: comparison.label,
                                value: comparison.deltaDisplayText,
                                systemImage: "arrow.left.arrow.right"
                            )
                        }

                        if !summary.recommendedSummary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lectura ejecutiva")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.4)

                                ForEach(summary.recommendedSummary, id: \.self) { item in
                                    BusinessExportBulletRow(text: item, systemImage: "sparkles")
                                }
                            }
                        }
                    }
                }
            } else {
                BusinessExportEmptyState(
                    title: "Sin resumen",
                    message: "Selecciona un período y actualiza para calcular el informe.",
                    systemImage: "chart.bar.doc.horizontal"
                )
            }
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        if let summary = viewModel.summary, summary.hasData {
            BusinessExportCard(
                title: "Diagramas",
                subtitle: "Vista rápida de patrones y puntos relevantes.",
                systemImage: "chart.bar.xaxis"
            ) {
                VStack(alignment: .leading, spacing: 14) {
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
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Alertas")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.4)

                            ForEach(summary.alerts) { alert in
                                BusinessExportNoticeCard(
                                    title: alert.severity == "warning" ? "Advertencia" : "Información",
                                    message: alert.message,
                                    systemImage: alert.severity == "warning" ? "exclamationmark.triangle" : "info.circle",
                                    tint: alert.severity == "warning" ? .orange : .secondary
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var availableExportsSection: some View {
        BusinessExportCard(
            title: "Archivos disponibles",
            subtitle: "Formatos operativos que el backend puede entregar.",
            systemImage: "tray.full"
        ) {
            switch viewModel.state {
            case .idle, .loading:
                BusinessExportLoadingRow(
                    title: "Consultando exportaciones…",
                    subtitle: "Revisando formatos disponibles para este negocio."
                )

            case let .failed(message):
                VStack(alignment: .leading, spacing: 12) {
                    BusinessExportEmptyState(
                        title: "No se pudo cargar",
                        message: message,
                        systemImage: "tray"
                    )

                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Label("Reintentar", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

            case let .loaded(exports):
                if exports.isEmpty {
                    BusinessExportEmptyState(
                        title: "Sin exportaciones disponibles",
                        message: "Cuando el backend tenga una exportación operativa disponible aparecerá aquí.",
                        systemImage: "tray"
                    )
                } else {
                    VStack(spacing: 10) {
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
    }

    private var actionSection: some View {
        BusinessExportCard(
            title: "Generar paquete",
            subtitle: "Crea y comparte el ZIP operativo del período.",
            systemImage: "square.and.arrow.down"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    Task { await viewModel.generateAndDownloadOperationalZip() }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.body.weight(.semibold))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.isGenerating ? "Generando informe…" : "Generar informe inteligente")
                                .font(.subheadline.weight(.semibold))

                            Text("PDF, HTML, JSON, CSV y manifest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canGenerateOperationalReport)

                if let file = viewModel.downloadedFile {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            BusinessExportIconBadge(systemImage: "doc.zipper", tint: .accentColor)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(file.fileName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)

                                Text("Tamaño: \(file.sizeText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        ShareLink(item: file.localURL) {
                            Label("Compartir archivo", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        if let sha256 = file.sha256, !sha256.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SHA-256")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(sha256)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                BusinessExportHintCard(
                    icon: "archivebox",
                    text: "El archivo queda temporalmente en el dispositivo para compartirlo desde iOS. Úsalo como evidencia operativa y apoyo administrativo."
                )
            }
        }
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var exportStatusTitle: String {
        if viewModel.isGenerating { return "Generando" }
        if viewModel.validationMessage?.isEmpty == false { return "Revisar" }
        if viewModel.summary?.hasData == true { return "Listo para exportar" }
        return "Preparar informe"
    }

    private var exportStatusIcon: String {
        if viewModel.isGenerating { return "arrow.triangle.2.circlepath" }
        if viewModel.validationMessage?.isEmpty == false { return "exclamationmark.triangle" }
        if viewModel.summary?.hasData == true { return "checkmark.seal" }
        return "doc.badge.plus"
    }

    private var exportStatusTint: Color {
        if viewModel.isGenerating { return .orange }
        if viewModel.validationMessage?.isEmpty == false { return .orange }
        if viewModel.summary?.hasData == true { return .green }
        return .secondary
    }
}

private struct BusinessExportCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BusinessExportSectionHeader(
                icon: systemImage,
                title: title,
                subtitle: subtitle
            )

            content
        }
        .businessExportSurface()
    }
}

private struct BusinessExportSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 4)
    }
}

private extension View {
    func businessExportSurface() -> some View {
        modifier(BusinessExportSurfaceModifier())
    }
}

private struct BusinessExportSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BusinessExportIconBadge(systemImage: icon, tint: .accentColor)

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
    }
}

private struct BusinessExportIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            }
    }
}

private struct BusinessExportStatusPill: View {
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
            .background(tint.opacity(0.11), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            }
    }
}

private struct BusinessExportPickerRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            accessory
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessExportMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        }
    }
}

private struct BusinessExportInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessExportBulletRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessExportNoticeCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct BusinessExportHintCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessExportLoadingRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct BusinessExportEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func toggle(_ point: BusinessExportChartPoint) {
        selectedId = selectedId == point.id ? nil : point.id
    }
}

private struct BusinessExportEmptyChartView: View {
    var body: some View {
        BusinessExportEmptyState(
            title: "Sin datos para graficar",
            message: "Este período no tiene datos suficientes para este diagrama.",
            systemImage: "chart.bar"
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
            VStack(alignment: .leading, spacing: 7) {
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

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
                        BusinessExportTinyBadge(title: contentType, systemImage: "doc.text")
                    }

                    if let sizeText {
                        BusinessExportTinyBadge(title: sizeText, systemImage: "externaldrive")
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BusinessExportTinyBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))
    }
}
