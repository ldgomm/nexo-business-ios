//
//  BusinessAccountantPackSurfaceView.swift
//  Nexo Business
//
//  21I.16B — Minimal accountant pack surface
//

import Combine
import Foundation
import SwiftUI

struct BusinessAccountantPackMoreTile: View {
    let container: BusinessAppContainer

    var body: some View {
        NavigationLink {
            BusinessAccountantPackSurfaceView(container: container)
        } label: {
            BusinessToolTile(
                title: "Paquete contador",
                subtitle: "ZIP mensual",
                systemImage: "doc.zipper",
                tint: .purple
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("business.accountantPack.moreTile")
    }
}

struct BusinessAccountantPackSurfaceView: View {
    let container: BusinessAppContainer
    @StateObject private var viewModel = BusinessAccountantPackViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                periodCard
                scopeCard
                downloadCard
                contentsCard
                limitsCard
            }
            .padding(18)
        }
        .navigationTitle("Paquete contador")
        .task { viewModel.configure(container: container) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cierre para contador", systemImage: "doc.zipper")
                .font(.title3.weight(.bold))
            Text("Descarga un ZIP mensual con datos operativos y precontables para revisión externa.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Nexo no reemplaza al contador. Nexo arma un paquete precontable claro, trazable y auditable para que el contador revise más rápido.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Periodo")
                .font(.headline)
            HStack(spacing: 12) {
                Picker("Mes", selection: $viewModel.month) {
                    ForEach(1...12, id: \.self) { month in
                        Text(viewModel.monthTitle(month)).tag(month)
                    }
                }
                Picker("Año", selection: $viewModel.year) {
                    ForEach(viewModel.yearOptions, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
            }
            .pickerStyle(.menu)
            Text("El ZIP se genera leyendo el cierre operativo mensual disponible en backend. No crea asientos ni declaraciones.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alcance")
                .font(.headline)
            TextField("Sucursal", text: $viewModel.branchId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            TextField("Actividad", text: $viewModel.activityId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            Text("Para staging se prellenan branch/activity conocidos. Luego esto debe venir del selector real de sucursal/actividad.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Descarga")
                .font(.headline)
            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let successMessage = viewModel.successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button {
                Task { await viewModel.download() }
            } label: {
                HStack {
                    if viewModel.isDownloading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                    }
                    Text(viewModel.isDownloading ? "Generando ZIP…" : "Descargar paquete ZIP")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isDownloading || !viewModel.canDownload)
            .accessibilityIdentifier("business.accountantPack.downloadButton")

            if let localFileURL = viewModel.localFileURL {
                ShareLink(item: localFileURL) {
                    Label("Compartir ZIP", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("business.accountantPack.shareButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var contentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contenido esperado")
                .font(.headline)
            ForEach(viewModel.expectedFiles, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Límites claros")
                .font(.headline)
            BusinessAccountantPackLimitRow(text: "No es contabilidad legal.")
            BusinessAccountantPackLimitRow(text: "No genera ATS ni declaraciones.")
            BusinessAccountantPackLimitRow(text: "No reemplaza revisión del contador.")
            BusinessAccountantPackLimitRow(text: "No envía automáticamente información a terceros.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BusinessAccountantPackLimitRow: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "minus.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

@MainActor
final class BusinessAccountantPackViewModel: ObservableObject {
    @Published var year: Int
    @Published var month: Int
    @Published var branchId: String = "br_staging_matriz"
    @Published var activityId: String = "act_staging_restaurant"
    @Published private(set) var isDownloading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?
    @Published private(set) var localFileURL: URL?

    private var container: BusinessAppContainer?

    init(calendar: Calendar = .current) {
        let now = Date()
        year = calendar.component(.year, from: now)
        month = calendar.component(.month, from: now)
    }

    var yearOptions: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 2)...(current + 1)).reversed()
    }

    var canDownload: Bool {
        container != nil
        && (1...12).contains(month)
        && !branchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !activityId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    let expectedFiles = [
        "manifest.json",
        "resumen_precontable.json",
        "cierre_mensual.json",
        "cierres_diarios.json",
        "alertas.json",
        "ventas.csv",
        "pagos.csv",
        "caja.csv",
        "documentos_electronicos.csv",
        "cuentas_por_cobrar.csv",
        "README_CONTADOR.md",
    ]

    func configure(container: BusinessAppContainer) {
        self.container = container
    }

    func monthTitle(_ value: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        return formatter.monthSymbols[max(0, min(11, value - 1))].capitalized
    }

    func download() async {
        guard let container else {
            errorMessage = "No se pudo preparar el cliente de descarga."
            return
        }

        isDownloading = true
        errorMessage = nil
        successMessage = nil

        do {
            let fileURL = try await downloadPack(container: container)
            localFileURL = fileURL
            successMessage = "ZIP descargado: \(fileURL.lastPathComponent)"
        } catch {
            errorMessage = "No se pudo descargar el ZIP: \(error.localizedDescription)"
        }

        isDownloading = false
    }


    private func downloadPack(container: BusinessAppContainer) async throws -> URL {
        let snapshot = await container.selectionStore.snapshot()
        guard let organizationId = snapshot.organizationId?.trimmingCharacters(in: .whitespacesAndNewlines), !organizationId.isEmpty else {
            throw BusinessAccountantPackDownloadError.message("No hay organización seleccionada para descargar el paquete.")
        }

        let trimmedBranchId = branchId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedActivityId = activityId.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveBranchId = trimmedBranchId.isEmpty ? snapshot.branchId : trimmedBranchId
        let effectiveActivityId = trimmedActivityId.isEmpty ? snapshot.activityId : trimmedActivityId

        let downloadedFile = try await container.exportsRepository.downloadAccountantPackDraftZip(
            organizationId: organizationId,
            branchId: effectiveBranchId,
            activityId: effectiveActivityId,
            year: year,
            month: month
        )
        return downloadedFile.localURL
    }
}

private enum BusinessAccountantPackDownloadError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(value): return value
        }
    }
}
