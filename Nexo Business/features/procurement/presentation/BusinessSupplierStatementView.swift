//
//  BusinessSupplierStatementView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessSupplierStatementView: View {
    @Bindable private var viewModel: BusinessSupplierStatementViewModel

    init(viewModel: BusinessSupplierStatementViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            summarySection
            filtersSection
            messagesSection
            balancesSection
            exportSection
            movementsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Estado de cuenta")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)
                .accessibilityLabel("Actualizar estado de cuenta")
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Estado de cuenta operativo", systemImage: "list.bullet.rectangle.portrait.fill")
                    .font(.headline)
                Text(viewModel.businessSupplierName)
                    .font(.subheadline.weight(.semibold))
                Text("El saldo inicial, los cargos, los abonos, el saldo corriente y el saldo final proceden del backend. La app no los suma ni recalcula localmente.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    BusinessSupplierStatementMetric(
                        title: "Movimientos",
                        value: String(viewModel.lines.count),
                        systemImage: "list.number"
                    )
                    BusinessSupplierStatementMetric(
                        title: "Filtro",
                        value: viewModel.hasActiveFilters ? "Activo" : "Libre",
                        systemImage: viewModel.hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var filtersSection: some View {
        Section("Filtros") {
            TextField("Moneda (USD)", text: $viewModel.currency)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            DisclosureGroup("Periodo y fecha de corte") {
                TextField("Desde (AAAA-MM-DD)", text: $viewModel.from)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                TextField("Hasta (AAAA-MM-DD)", text: $viewModel.to)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                TextField("Corte (AAAA-MM-DD)", text: $viewModel.asOf)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
            }

            HStack {
                Button("Aplicar") {
                    Task { await viewModel.search() }
                }
                .disabled(viewModel.isLoading || !viewModel.canView)

                Spacer()

                if viewModel.hasActiveFilters {
                    Button("Limpiar") {
                        Task { await viewModel.clearFilters() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
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

                    Button(
                        viewModel.lastFailureWasExport
                            ? "Reintentar exportación"
                            : "Reintentar"
                    ) {
                        Task { await viewModel.retryLastFailure() }
                    }
                    .disabled(
                        viewModel.isLoading ||
                        viewModel.isExportingCSV ||
                        (
                            viewModel.lastFailureWasExport
                                ? !viewModel.canExportCSV
                                : !viewModel.canView
                        )
                    )
                }
            }
        }

        if let infoMessage = viewModel.infoMessage {
            Section {
                Label(infoMessage, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var balancesSection: some View {
        if let openingBalance = viewModel.openingBalance,
           let closingBalance = viewModel.closingBalance {
            Section("Saldos del servidor") {
                BusinessSupplierStatementMoneyRow(
                    title: "Saldo inicial",
                    money: openingBalance
                )
                BusinessSupplierStatementMoneyRow(
                    title: "Saldo final",
                    money: closingBalance,
                    emphasized: true
                )

                if let statementAsOf = viewModel.statementAsOf {
                    LabeledContent("Fecha de corte", value: statementAsOf)
                }
                if let statementFrom = viewModel.statementFrom {
                    LabeledContent("Desde", value: statementFrom)
                }
                if let statementTo = viewModel.statementTo {
                    LabeledContent("Hasta", value: statementTo)
                }
                if let statementCurrency = viewModel.statementCurrency {
                    LabeledContent("Moneda", value: statementCurrency)
                }

                Text("Estos importes son la respuesta autoritativa del servidor; la app no deriva el saldo final a partir de los movimientos visibles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if viewModel.canExportCSV {
            Section("Exportación segura") {
                Text("El backend genera el CSV con cantidades e importes canónicos para los filtros actuales. La app no reconstruye movimientos ni recalcula saldos para exportar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await viewModel.exportCSV() }
                } label: {
                    HStack(spacing: 9) {
                        if viewModel.isExportingCSV {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(
                            viewModel.isExportingCSV
                                ? "Preparando CSV…"
                                : "Exportar estado de cuenta CSV"
                        )
                        .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.isLoading ||
                    viewModel.isExportingCSV ||
                    !viewModel.canExportCSV
                )

                if let file = viewModel.downloadedCSVFile {
                    ShareLink(item: file.localURL) {
                        Label(
                            "Compartir \(file.fileName)",
                            systemImage: "square.and.arrow.up.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("La exportación puede solicitar autenticación adicional. Es un reporte operativo y no sustituye un libro o estado contable oficial.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var movementsSection: some View {
        Section("Movimientos") {
            if viewModel.isLoading && viewModel.lines.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando estado de cuenta…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.lines.isEmpty {
                ContentUnavailableView(
                    "Sin movimientos",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Prueba otro periodo o confirma que tu usuario tenga acceso al estado de cuenta del proveedor.")
                )
            } else {
                ForEach(viewModel.lines) { line in
                    BusinessSupplierStatementLineRow(line: line)
                        .onAppear {
                            Task {
                                await viewModel.loadNextPageIfNeeded(
                                    currentLine: line
                                )
                            }
                        }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Cargando más…")
                            .font(.footnote)
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct BusinessSupplierStatementLineRow: View {
    let line: BusinessProcurementSupplierStatementLineResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.description)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text(line.businessSupplierStatementOccurredAtText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Label(
                line.businessSupplierStatementSourceName,
                systemImage: "doc.text.magnifyingglass"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Divider()

            BusinessSupplierStatementMoneyRow(
                title: "Cargo",
                money: line.charge
            )
            BusinessSupplierStatementMoneyRow(
                title: "Abono",
                money: line.credit
            )
            BusinessSupplierStatementMoneyRow(
                title: "Saldo corriente",
                money: line.runningBalance,
                emphasized: true
            )

            Label(
                line.businessSupplierStatementAuditName,
                systemImage: "link.badge.plus"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("Referencia de origen verificada por el backend; los identificadores internos no se muestran.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

private struct BusinessSupplierStatementMoneyRow: View {
    let title: String
    let money: BusinessProcurementMoneyResponse
    var emphasized = false

    var body: some View {
        LabeledContent(title) {
            Text(money.businessDisplayText())
                .fontWeight(emphasized ? .semibold : .regular)
                .monospacedDigit()
        }
    }
}

private struct BusinessSupplierStatementMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
