//
//  BusinessProcurementAttachmentsView.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/7/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct BusinessProcurementAttachmentsView: View {
    @State private var viewModel: BusinessProcurementAttachmentsViewModel
    @State private var isFileImporterPresented = false
    @State private var pendingDeletion: BusinessProcurementEvidenceItem?

    init(viewModel: BusinessProcurementAttachmentsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            contextSection
            messagesSection

            if viewModel.canViewEvidence {
                managementSection
                evidenceSection
            } else {
                restrictedSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Evidencia")
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.pdf, .jpeg, .png]
        ) { result in
            switch result {
            case .success(let fileURL):
                Task { await viewModel.importAndUpload(from: fileURL) }
            case .failure:
                viewModel.errorMessage = "No se pudo abrir el archivo seleccionado."
                viewModel.infoMessage = nil
            }
        }
        .confirmationDialog(
            "Eliminar evidencia",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar evidencia", role: .destructive) {
                guard let item = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await viewModel.delete(item) }
            }
            Button("Cancelar", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("Esta acción solicita al servidor retirar el archivo del recurso. No se repetirá automáticamente.")
        }
    }

    private var contextSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Evidencia del recurso", systemImage: "paperclip.circle.fill")
                    .font(.headline)

                if !viewModel.sourceDisplayName.isEmpty {
                    Text(viewModel.sourceDisplayName)
                        .font(.subheadline.weight(.semibold))
                }

                Text(viewModel.attachmentCountText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text("La app usa únicamente las referencias devueltas por el recurso autorizado. No solicita un listado global, no muestra identificadores internos y no expone rutas ni metadatos de almacenamiento.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let integrityWarning = viewModel.integrityWarning {
            Section {
                Label {
                    Text(integrityWarning)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                }
            }
        }

        if let errorMessage = viewModel.errorMessage {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text(errorMessage)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }

                    if viewModel.lastFailedAttachmentId != nil {
                        Button("Reintentar descarga") {
                            Task { await viewModel.retryLastDownload() }
                        }
                        .disabled(viewModel.isDownloading || viewModel.isMutating || !viewModel.canViewEvidence)
                    }

                    if viewModel.pendingUpload != nil {
                        Button("Reintentar la misma carga") {
                            Task { await viewModel.uploadPendingFile() }
                        }
                        .disabled(viewModel.isDownloading || viewModel.isMutating || !viewModel.canUploadEvidence)
                    }
                }
            }
        }

        if viewModel.needsSourceRefresh {
            Section {
                Button {
                    Task { await viewModel.refreshSourceState() }
                } label: {
                    Label(
                        viewModel.isRefreshingSource
                            ? "Actualizando recurso…"
                            : "Actualizar evidencia y versión",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(viewModel.isDownloading || viewModel.isMutating)
            }
        }

        if let infoMessage = viewModel.infoMessage {
            Section {
                Label(infoMessage, systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var managementSection: some View {
        if viewModel.canUploadEvidence || viewModel.pendingUpload != nil {
            Section("Gestionar evidencia") {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Adjuntar PDF o imagen", systemImage: "paperclip.badge.ellipsis")
                }
                .disabled(viewModel.isDownloading || viewModel.isMutating || !viewModel.canUploadEvidence)

                if viewModel.isUploading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Adjuntando evidencia…")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("La selección se valida localmente y el servidor vuelve a comprobar permisos, organización, tipo, tamaño y versión del recurso.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var evidenceSection: some View {
        Section("Archivos autorizados") {
            if viewModel.evidenceItems.isEmpty {
                ContentUnavailableView(
                    "Sin evidencia adjunta",
                    systemImage: "paperclip",
                    description: Text("Este recurso no contiene referencias de archivos autorizadas.")
                )
            } else {
                ForEach(viewModel.evidenceItems) { item in
                    evidenceRow(item)
                }
            }

            Text("Solo se aceptan descargas y cargas PDF, JPEG o PNG de hasta 10 MB. El servidor conserva la evidencia original y aplica el aislamiento por organización.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func evidenceRow(
        _ item: BusinessProcurementEvidenceItem
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(item.displayName, systemImage: "doc.text.fill")
                .font(.subheadline.weight(.semibold))

            if let file = viewModel.downloadedFile(for: item) {
                Text(file.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ShareLink(item: file.localURL) {
                    Label("Compartir archivo verificado", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isDownloading || viewModel.isMutating)
            } else {
                Button {
                    Task { await viewModel.download(item) }
                } label: {
                    HStack(spacing: 9) {
                        if viewModel.isDownloading(item) {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.doc")
                        }
                        Text(
                            viewModel.isDownloading(item)
                                ? "Descargando…"
                                : "Descargar de forma segura"
                        )
                        .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isDownloading || viewModel.isMutating || !viewModel.canViewEvidence)
            }

            if viewModel.canDeleteEvidence {
                Button(role: .destructive) {
                    pendingDeletion = item
                } label: {
                    HStack(spacing: 9) {
                        if viewModel.isDeleting(item) {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(viewModel.isDeleting(item) ? "Eliminando…" : "Eliminar evidencia")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isDownloading || viewModel.isMutating)
            }
        }
        .padding(.vertical, 4)
    }

    private var restrictedSection: some View {
        Section {
            ContentUnavailableView(
                "Evidencia protegida",
                systemImage: "lock.shield.fill",
                description: Text("Tu sesión no tiene todos los permisos necesarios para consultar los archivos de este recurso.")
            )
        }
    }
}
