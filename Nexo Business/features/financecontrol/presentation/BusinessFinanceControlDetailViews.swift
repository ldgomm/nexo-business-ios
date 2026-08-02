//
//  BusinessFinanceControlDetailViews.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import SwiftUI

struct BusinessFinanceMovementListView: View {
    let snapshot: BusinessFinanceControlSnapshot

    var body: some View {
        List {
            if snapshot.movements.isEmpty {
                BusinessFinanceControlEmptyRow(
                    message: "No existen movimientos para el periodo seleccionado."
                )
            } else {
                ForEach(snapshot.movements) { movement in
                    NavigationLink {
                        BusinessFinanceMovementDetailView(
                            movement: movement,
                            localeIdentifier: snapshot.scope.localeIdentifier
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(movement.title)
                                    .font(.headline)
                                Spacer()
                                Text(formatted(movement.amount))
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                            }

                            Text("\(movement.businessDate) · \(movement.lifecycleStatus)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Movimientos")
    }

    private func formatted(_ amount: BusinessFinanceAmount) -> String {
        BusinessFinanceAmountFormatter().string(
            from: amount,
            localeIdentifier: snapshot.scope.localeIdentifier
        ) ?? "\(amount.currencyCode) \(amount.decimalValue)"
    }
}

struct BusinessFinanceMovementDetailView: View {
    let movement: BusinessFinanceMovementSummary
    let localeIdentifier: String

    var body: some View {
        List {
            Section("Movimiento") {
                LabeledContent("Fecha", value: movement.businessDate)
                LabeledContent("Importe", value: formatted(movement.amount))
                LabeledContent("Dirección", value: movement.direction.rawValue)
                LabeledContent("Estado", value: movement.lifecycleStatus)
            }

            Section("Trazabilidad") {
                LabeledContent("Evidencias", value: String(movement.evidenceCount))
                if let sourceFactId = movement.sourceFactId {
                    LabeledContent("Hecho fuente", value: sourceFactId)
                }
            }

            Section {
                BusinessFinanceControlNotice(
                    title: "Operativo · no contabilizado",
                    message: "El detalle identifica su hecho fuente; no representa un asiento contable.",
                    systemImage: "checkmark.shield",
                    tint: .orange
                )
            }
        }
        .navigationTitle(movement.title)
    }

    private func formatted(_ amount: BusinessFinanceAmount) -> String {
        BusinessFinanceAmountFormatter().string(
            from: amount,
            localeIdentifier: localeIdentifier
        ) ?? "\(amount.currencyCode) \(amount.decimalValue)"
    }
}

struct BusinessFinanceOpenItemsView: View {
    let snapshot: BusinessFinanceControlSnapshot

    var body: some View {
        List {
            Section("Por cobrar") {
                openItems(.receivable)
            }

            Section("Por pagar") {
                openItems(.payable)
            }
        }
        .navigationTitle("Partidas abiertas")
    }

    @ViewBuilder
    private func openItems(_ side: BusinessFinanceOpenItemSide) -> some View {
        let items = snapshot.openItems.filter { $0.side == side }
        if items.isEmpty {
            Text("Sin partidas.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.partyDisplayName)
                            .font(.headline)
                        Spacer()
                        Text(formatted(item.outstandingAmount))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }

                    Text([item.dueDate, item.status].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatted(_ amount: BusinessFinanceAmount) -> String {
        BusinessFinanceAmountFormatter().string(
            from: amount,
            localeIdentifier: snapshot.scope.localeIdentifier
        ) ?? "\(amount.currencyCode) \(amount.decimalValue)"
    }
}

struct BusinessFinanceCashBankView: View {
    let snapshot: BusinessFinanceControlSnapshot

    var body: some View {
        List {
            if snapshot.cashAndBank.isEmpty {
                Text("Sin cuentas disponibles.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.cashAndBank) { account in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(
                                account.displayName,
                                systemImage: account.kind == .cash
                                    ? "banknote"
                                    : "building.columns"
                            )
                            .font(.headline)

                            Spacer()

                            Text(formatted(account.balance))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }

                        Text("\(account.asOf) · \(account.reconciliationStatus)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let masked = account.maskedExternalReference {
                            Text(masked)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Caja y bancos")
    }

    private func formatted(_ amount: BusinessFinanceAmount) -> String {
        BusinessFinanceAmountFormatter().string(
            from: amount,
            localeIdentifier: snapshot.scope.localeIdentifier
        ) ?? "\(amount.currencyCode) \(amount.decimalValue)"
    }
}

struct BusinessFinanceHistoricalImportView: View {
    let snapshot: BusinessFinanceControlSnapshot
    let canUpload: Bool
    let canPreview: Bool
    @State private var runtimeActionMessage: String? = nil

    var body: some View {
        List {
            Section {
                BusinessFinanceControlNotice(
                    title: "Revisión antes de aplicar",
                    message: "Toda carga conserva archivo original, checksum y errores por fila. Nunca crea detalle histórico ausente.",
                    systemImage: "doc.badge.ellipsis",
                    tint: .blue
                )
            }

            Section("Acciones autorizadas") {
                Button("Seleccionar archivo para carga") {
                    runtimeActionMessage = "La autorización está vigente. La transferencia del archivo se conecta al endpoint seguro durante 28R.P."
                }
                    .disabled(!canUpload)
                Button("Abrir vista previa") {
                    runtimeActionMessage = "La autorización está vigente. La vista previa real se conecta al endpoint seguro durante 28R.P."
                }
                    .disabled(!canPreview)

                if !canUpload || !canPreview {
                    Text("Las acciones permanecen bloqueadas hasta recibir permiso y capacidad del backend.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Lotes") {
                if snapshot.historicalImports.isEmpty {
                    Text("Sin importaciones.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.historicalImports) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.fileDisplayName)
                                .font(.headline)
                            Text(
                                "\(item.status) · \(item.acceptedRows) aceptadas · \(item.rejectedRows) rechazadas"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Importación histórica")
        .alert(
            "Conexión runtime pendiente",
            isPresented: Binding(
                get: { runtimeActionMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        runtimeActionMessage = nil
                    }
                }
            )
        ) {
            Button("Entendido", role: .cancel) {
                runtimeActionMessage = nil
            }
        } message: {
            Text(runtimeActionMessage ?? "")
        }
    }
}

struct BusinessFinanceReconciliationView: View {
    let snapshot: BusinessFinanceControlSnapshot
    let canReview: Bool
    @State private var runtimeActionMessage: String? = nil

    var body: some View {
        List {
            Section("Resumen") {
                LabeledContent("Estado", value: snapshot.reconciliation.status)
                LabeledContent(
                    "Coincidencias",
                    value: String(snapshot.reconciliation.matchedCount)
                )
                LabeledContent(
                    "Sin coincidencia",
                    value: String(snapshot.reconciliation.unmatchedCount)
                )
                LabeledContent(
                    "Duplicados",
                    value: String(snapshot.reconciliation.duplicateCount)
                )
                LabeledContent(
                    "Diferencia exacta",
                    value: formatted(snapshot.reconciliation.exactDifference)
                )
            }

            Section {
                Button("Revisar propuestas") {
                    runtimeActionMessage = "La autorización está vigente. La revisión vinculante se conecta al endpoint seguro durante 28R.P."
                }
                    .disabled(!canReview)

                Text("La app revisa propuestas; nunca contabiliza ni concilia silenciosamente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Conciliación")
        .alert(
            "Conexión runtime pendiente",
            isPresented: Binding(
                get: { runtimeActionMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        runtimeActionMessage = nil
                    }
                }
            )
        ) {
            Button("Entendido", role: .cancel) {
                runtimeActionMessage = nil
            }
        } message: {
            Text(runtimeActionMessage ?? "")
        }
    }

    private func formatted(_ amount: BusinessFinanceAmount) -> String {
        BusinessFinanceAmountFormatter().string(
            from: amount,
            localeIdentifier: snapshot.scope.localeIdentifier
        ) ?? "\(amount.currencyCode) \(amount.decimalValue)"
    }
}

struct BusinessFinanceCoverageView: View {
    let snapshot: BusinessFinanceControlSnapshot

    var body: some View {
        List {
            Section("Cobertura") {
                LabeledContent("Estado", value: snapshot.coverage.status)
                LabeledContent(
                    "Rubros conciliados",
                    value: "\(snapshot.coverage.reconciledRubrics)/\(snapshot.coverage.requiredRubrics)"
                )
                LabeledContent(
                    "Pendientes",
                    value: String(snapshot.coverage.unresolvedCount)
                )
                LabeledContent(
                    "Readiness",
                    value: snapshot.coverage.readinessDecision
                )
                if let cutoverDate = snapshot.coverage.cutoverDate {
                    LabeledContent("Cutover", value: cutoverDate)
                }
            }

            Section {
                Text("El negocio puede revisar el estado. La aprobación de cutover pertenece a la supervisión administrativa.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cobertura y cutover")
    }
}

struct BusinessFinanceUnresolvedItemsView: View {
    let snapshot: BusinessFinanceControlSnapshot

    var body: some View {
        List {
            if snapshot.unresolvedItems.isEmpty {
                Text("No existen pendientes reportados.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.unresolvedItems) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.title)
                                .font(.headline)
                            Spacer()
                            Text(item.severity)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        }

                        Text(item.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(item.evidenceIds.count) evidencias")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle("Pendientes")
    }
}
