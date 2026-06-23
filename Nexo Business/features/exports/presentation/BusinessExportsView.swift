//
//  BusinessExportsView.swift
//  Nexo Business
//

import SwiftUI

struct BusinessExportsView: View {
    @Bindable private var viewModel: BusinessExportsViewModel

    init(viewModel: BusinessExportsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            guideSection
            messagesSection
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
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isGenerating)
                .accessibilityLabel("Actualizar exportaciones")
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private var guideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("Exportación operativa diaria", systemImage: "square.and.arrow.down")
                    .font(.headline)

                DatePicker(
                    "Fecha",
                    selection: $viewModel.businessDate,
                    displayedComponents: [.date]
                )

                Text("Genera un ZIP operativo para revisar ventas, pagos, caja, documentos y cuentas por cobrar del día seleccionado.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("No reemplaza al contador ni a obligaciones tributarias.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                Task { await viewModel.generateAndDownloadDailyZip() }
            } label: {
                HStack {
                    Label("Generar y descargar ZIP", systemImage: "square.and.arrow.down")
                    Spacer(minLength: 12)
                    if viewModel.isGenerating {
                        ProgressView()
                    }
                }
            }
            .disabled(!viewModel.canExport || viewModel.isLoading || viewModel.isGenerating)

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
            Text("El archivo queda guardado temporalmente en el dispositivo para que puedas compartirlo desde la hoja nativa de iOS.")
        }
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
