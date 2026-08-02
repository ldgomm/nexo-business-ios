//
//  BusinessFinanceControlSurfaceView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import SwiftUI

struct BusinessFinanceControlSurfaceView: View {
    @Bindable private var viewModel: BusinessFinanceControlViewModel

    init(
        scope: BusinessFinanceControlScope,
        effectivePermissions: Set<String>,
        repository: any BusinessFinanceControlRepository
    ) {
        self.viewModel = BusinessFinanceControlViewModel(
            scope: scope,
            effectivePermissions: effectivePermissions,
            repository: repository
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                hero

                if viewModel.isLoading, viewModel.snapshot == nil {
                    loadingCard
                } else if let snapshot = viewModel.snapshot {
                    safeStatusCard(snapshot)
                    if viewModel.canView(.configuration) {
                        configurationCard(snapshot)
                    }
                    navigationCards(snapshot)
                } else {
                    unavailableCard
                }
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Control financiero")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.cyan.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Finanzas operativas")
                        .font(.title2.weight(.bold))

                    Text("Lectura segura de movimientos, saldos, importaciones y conciliación.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            BusinessFinanceControlNotice(
                title: "Operativo · no contabilizado",
                message: "Esta superficie no crea asientos, no publica estados financieros y no reemplaza la revisión profesional.",
                systemImage: "checkmark.shield",
                tint: .orange
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.15),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    private var loadingCard: some View {
        BusinessFinanceControlSectionCard(
            title: "Cargando",
            subtitle: "Consultando la fuente autoritativa.",
            systemImage: "arrow.triangle.2.circlepath"
        ) {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
    }

    private var unavailableCard: some View {
        BusinessFinanceControlSectionCard(
            title: "Datos todavía no disponibles",
            subtitle: "La pantalla falla de forma cerrada y no inventa valores.",
            systemImage: "lock.shield"
        ) {
            BusinessFinanceControlNotice(
                title: "Conexión segura pendiente",
                message: viewModel.errorMessage ?? "No se recibió una respuesta financiera válida.",
                systemImage: "info.circle",
                tint: .secondary
            )

            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Reintentar", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func safeStatusCard(
        _ snapshot: BusinessFinanceControlSnapshot
    ) -> some View {
        BusinessFinanceControlSectionCard(
            title: "Estado de la fuente",
            subtitle: "Alcance, periodo y trazabilidad recibidos del backend.",
            systemImage: "server.rack"
        ) {
            BusinessFinanceControlFactRow(
                title: "Estado",
                value: snapshot.accountingStatus.safeDisplayTitle,
                systemImage: "checkmark.shield",
                tint: .orange
            )
            BusinessFinanceControlFactRow(
                title: "Periodo",
                value: snapshot.scope.periodLabel,
                systemImage: "calendar"
            )
            BusinessFinanceControlFactRow(
                title: "Revisión",
                value: snapshot.sourceRevision,
                systemImage: "number"
            )
        }
    }

    private func configurationCard(
        _ snapshot: BusinessFinanceControlSnapshot
    ) -> some View {
        BusinessFinanceControlSectionCard(
            title: "Configuración financiera",
            subtitle: "Resumen de solo lectura definido por organización y ledger.",
            systemImage: "slider.horizontal.3"
        ) {
            BusinessFinanceControlFactRow(
                title: "Entidad",
                value: snapshot.configuration.legalEntityName,
                systemImage: "building.2"
            )
            BusinessFinanceControlFactRow(
                title: "Ledger",
                value: snapshot.configuration.ledgerName,
                systemImage: "books.vertical"
            )
            BusinessFinanceControlFactRow(
                title: "Moneda funcional",
                value: snapshot.scope.functionalCurrencyCode,
                systemImage: "coloncurrencysign"
            )
            BusinessFinanceControlFactRow(
                title: "Política",
                value: snapshot.configuration.policyVersion,
                systemImage: "doc.badge.gearshape"
            )
        }
    }

    @ViewBuilder
    private func navigationCards(
        _ snapshot: BusinessFinanceControlSnapshot
    ) -> some View {
        BusinessFinanceControlSectionCard(
            title: "Operación financiera",
            subtitle: "Cada pantalla conserva evidencia y valores del backend.",
            systemImage: "square.grid.2x2"
        ) {
            VStack(spacing: 10) {
                if viewModel.canView(.movements) {
                    NavigationLink {
                        BusinessFinanceMovementListView(
                            snapshot: snapshot
                        )
                    } label: {
                        destinationRow(
                            title: "Movimientos de dinero",
                            subtitle: "\(snapshot.movements.count) movimientos",
                            systemImage: "arrow.left.arrow.right"
                        )
                    }
                }

                if viewModel.canView(.receivablesAndPayables) {
                    NavigationLink {
                        BusinessFinanceOpenItemsView(
                            snapshot: snapshot
                        )
                    } label: {
                        destinationRow(
                            title: "Por cobrar y por pagar",
                            subtitle: "\(snapshot.openItems.count) partidas abiertas",
                            systemImage: "person.2.badge.gearshape"
                        )
                    }
                }

                if viewModel.canView(.cashAndBank) {
                    NavigationLink {
                        BusinessFinanceCashBankView(
                            snapshot: snapshot
                        )
                    } label: {
                        destinationRow(
                            title: "Caja y bancos",
                            subtitle: "\(snapshot.cashAndBank.count) cuentas",
                            systemImage: "building.columns"
                        )
                    }
                }

                if viewModel.canView(.historicalImport) {
                    NavigationLink {
                        BusinessFinanceHistoricalImportView(
                            snapshot: snapshot,
                            canUpload: viewModel.allows(.uploadHistoricalImport),
                            canPreview: viewModel.allows(.previewHistoricalImport)
                        )
                    } label: {
                        destinationRow(
                            title: "Importación histórica",
                            subtitle: "\(snapshot.historicalImports.count) lotes",
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                }

                if viewModel.canView(.reconciliation) {
                    NavigationLink {
                        BusinessFinanceReconciliationView(
                            snapshot: snapshot,
                            canReview: viewModel.allows(.reviewReconciliation)
                        )
                    } label: {
                        destinationRow(
                            title: "Conciliación",
                            subtitle: snapshot.reconciliation.status,
                            systemImage: "checkmark.arrow.trianglehead.counterclockwise"
                        )
                    }
                }

                if viewModel.canView(.coverageAndCutover) {
                    NavigationLink {
                        BusinessFinanceCoverageView(snapshot: snapshot)
                    } label: {
                        destinationRow(
                            title: "Cobertura y cutover",
                            subtitle: snapshot.coverage.status,
                            systemImage: "square.stack.3d.up.badge.automatic"
                        )
                    }
                }

                if viewModel.canView(.unresolvedItems) {
                    NavigationLink {
                        BusinessFinanceUnresolvedItemsView(snapshot: snapshot)
                    } label: {
                        destinationRow(
                            title: "Pendientes por resolver",
                            subtitle: "\(snapshot.unresolvedItems.count) elementos",
                            systemImage: "exclamationmark.bubble"
                        )
                    }
                }
            }
        }
    }

    private func destinationRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    Color.accentColor.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            Color(uiColor: .tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
    }
}
