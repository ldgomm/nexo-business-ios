//
//  BusinessAccountantPackSurfaceView.swift
//  Nexo Business
//
//  Created by José Ruiz on 23/6/26.
//

import Combine
import Foundation
import SwiftUI

struct BusinessAccountantPackMoreTile: View {
    let container: AppContainer

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
    let container: AppContainer
    @StateObject private var viewModel = BusinessAccountantPackViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero

                if viewModel.errorMessage != nil || viewModel.successMessage != nil {
                    messagesCard
                        .accountantPackSurface()
                }

                periodCard
                    .accountantPackSurface()

                scopeCard
                    .accountantPackSurface()

                downloadCard
                    .accountantPackSurface()

                contentsCard
                    .accountantPackSurface()

                limitsCard
                    .accountantPackSurface()
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Paquete contador")
        .navigationBarTitleDisplayMode(.large)
        .task { viewModel.configure(container: container) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                AccountantPackIconBadge(systemImage: "doc.zipper", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Accounting")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Paquete para contador")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("Un ZIP mensual, ordenado y trazable para revisión precontable externa.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                AccountantPackPill(
                    title: selectedPeriodText,
                    systemImage: "calendar",
                    tint: .accentColor
                )

                AccountantPackPill(
                    title: viewModel.canDownload ? "Listo" : "Pendiente",
                    systemImage: viewModel.canDownload ? "checkmark.seal" : "exclamationmark.triangle",
                    tint: viewModel.canDownload ? .green : .orange
                )
            }

            AccountantPackNotice(
                title: "Límite importante",
                message: "Nexo no reemplaza al contador. Entrega evidencia precontable clara, trazable y auditable para acelerar la revisión.",
                systemImage: "checkmark.shield",
                tint: .secondary
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.teal.opacity(0.16),
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
    private var messagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage = viewModel.errorMessage {
                AccountantPackNotice(
                    title: "No se pudo generar",
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }

            if let successMessage = viewModel.successMessage {
                AccountantPackNotice(
                    title: "Paquete listo",
                    message: successMessage,
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
            }
        }
    }

    private var periodCard: some View {
        AccountantPackSectionCard(
            title: "Periodo contable",
            subtitle: "Selecciona el mes que se entregará al contador.",
            systemImage: "calendar.badge.clock"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    AccountantPackMenuField(
                        title: "Mes",
                        value: viewModel.monthTitle(viewModel.month),
                        systemImage: "calendar"
                    ) {
                        Picker("Mes", selection: $viewModel.month) {
                            ForEach(1...12, id: \.self) { month in
                                Text(viewModel.monthTitle(month)).tag(month)
                            }
                        }
                        .labelsHidden()
                    }

                    AccountantPackMenuField(
                        title: "Año",
                        value: String(viewModel.year),
                        systemImage: "number"
                    ) {
                        Picker("Año", selection: $viewModel.year) {
                            ForEach(viewModel.yearOptions, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .labelsHidden()
                    }
                }

                AccountantPackNotice(
                    title: "Cómo se genera",
                    message: "El ZIP lee el cierre operativo mensual disponible en backend. No crea asientos, ATS ni declaraciones.",
                    systemImage: "info.circle",
                    tint: .secondary
                )
            }
        }
    }

    private var scopeCard: some View {
        AccountantPackSectionCard(
            title: "Alcance operativo",
            subtitle: "Sucursal y actividad que alimentan el paquete.",
            systemImage: "slider.horizontal.3"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                AccountantPackInputRow(
                    title: "Sucursal",
                    placeholder: "Sucursal",
                    text: $viewModel.branchId,
                    systemImage: "building.2"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                AccountantPackInputRow(
                    title: "Actividad",
                    placeholder: "Actividad",
                    text: $viewModel.activityId,
                    systemImage: "fork.knife"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                AccountantPackNotice(
                    title: "Piloto staging",
                    message: "Estos valores vienen prellenados para el piloto. En producción deben venir del selector real de sucursal y actividad.",
                    systemImage: "location.circle",
                    tint: .secondary
                )
            }
        }
    }

    private var downloadCard: some View {
        AccountantPackSectionCard(
            title: "Generación y entrega",
            subtitle: "Descarga el ZIP y compártelo desde iOS.",
            systemImage: "square.and.arrow.down"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.download() }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isDownloading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                        }

                        Text(viewModel.isDownloading ? "Generando paquete…" : "Generar paquete ZIP")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isDownloading || !viewModel.canDownload)
                .accessibilityIdentifier("business.accountantPack.downloadButton")

                if let localFileURL = viewModel.localFileURL {
                    ShareLink(item: localFileURL) {
                        Label("Compartir ZIP", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("business.accountantPack.shareButton")

                    AccountantPackFactRow(
                        title: "Archivo",
                        value: localFileURL.lastPathComponent,
                        systemImage: "doc.zipper"
                    )
                }
            }
        }
    }

    private var contentsCard: some View {
        AccountantPackSectionCard(
            title: "Contenido del ZIP",
            subtitle: "Archivos esperados para revisión precontable.",
            systemImage: "folder.badge.gearshape"
        ) {
            VStack(spacing: 8) {
                ForEach(viewModel.expectedFiles, id: \.self) { item in
                    AccountantPackFileRow(fileName: item)
                }
            }
        }
    }

    private var limitsCard: some View {
        AccountantPackSectionCard(
            title: "Límites claros",
            subtitle: "Qué sí entrega Nexo y qué queda fuera de esta superficie.",
            systemImage: "exclamationmark.shield"
        ) {
            VStack(spacing: 8) {
                BusinessAccountantPackLimitRow(text: "No es contabilidad legal.")
                BusinessAccountantPackLimitRow(text: "No genera ATS ni declaraciones.")
                BusinessAccountantPackLimitRow(text: "No reemplaza revisión del contador.")
                BusinessAccountantPackLimitRow(text: "No envía automáticamente información a terceros.")
            }
        }
    }

    private var selectedPeriodText: String {
        "\(viewModel.monthTitle(viewModel.month)) \(viewModel.year)"
    }
}

private struct AccountantPackSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 7, x: 0, y: 3)
    }
}

private extension View {
    func accountantPackSurface() -> some View {
        modifier(AccountantPackSurfaceModifier())
    }
}

private struct AccountantPackSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                AccountantPackIconBadge(systemImage: systemImage, tint: .accentColor, size: 34)

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

private struct AccountantPackIconBadge: View {
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

private struct AccountantPackPill: View {
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

private struct AccountantPackNotice: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct AccountantPackMenuField<PickerContent: View>: View {
    let title: String
    let value: String
    let systemImage: String
    @ViewBuilder let picker: PickerContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)

                picker
                    .pickerStyle(.menu)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AccountantPackInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AccountantPackFactRow: View {
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
                .font(.caption.monospaced().weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AccountantPackFileRow: View {
    let fileName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.green)

            Text(fileName)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessAccountantPackLimitRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "minus.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var container: AppContainer?

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

    func configure(container: AppContainer) {
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

    private func downloadPack(container: AppContainer) async throws -> URL {
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
