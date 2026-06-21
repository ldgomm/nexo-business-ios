//
//  ReceivableCollectionView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI
import Observation

struct ReceivableCollectionView: View {
    @Bindable private var viewModel: ReceivableCollectionViewModel
    private let onCollected: (ReceivableRecord) -> Void

    init(
        viewModel: ReceivableCollectionViewModel,
        onCollected: @escaping (ReceivableRecord) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onCollected = onCollected
    }

    var body: some View {
        Form {
            Section("Cuenta por cobrar") {
                LabeledContent("ID", value: viewModel.currentReceivable.id)
                LabeledContent("Estado", value: ReceivableStatusPresentation.displayName(viewModel.currentReceivable.status))
                LabeledContent("Monto", value: money(viewModel.currentReceivable.amount))
                LabeledContent("Saldo", value: money(viewModel.currentBalance))

                if viewModel.currentReceivable.isMissingCustomer {
                    Label("Revisar: esta cuenta no tiene cliente identificado. No registres abonos hasta corregirla.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if viewModel.isSettled {
                    Label("Cuenta cobrada. No hay saldo pendiente.", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }

            if !viewModel.isSettled && !viewModel.currentReceivable.isMissingCustomer {
                Section("Abono") {
                Picker("Método", selection: $viewModel.selectedMethod) {
                    ForEach([BusinessPaymentMethod.cash, .transfer, .card], id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }

                TextField("Monto", text: $viewModel.amount)
                    .keyboardType(.decimalPad)

                if viewModel.selectedMethod != .cash {
                    TextField("Referencia", text: $viewModel.reference)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                    TextField("Nota opcional", text: $viewModel.note, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                }
            }

            if !viewModel.isSettled && !viewModel.currentReceivable.isMissingCustomer && viewModel.selectedMethod == .cash {
                Section("Caja") {
                    if viewModel.isLoadingCash {
                        ProgressView("Consultando caja…")
                    } else if let session = viewModel.currentCashSession, session.isOpen {
                        Label("Caja abierta", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        LabeledContent("Sesión", value: session.id)
                    } else {
                        Label("Necesitas una caja abierta para abonos en efectivo.", systemImage: "lock")
                            .foregroundStyle(.red)
                    }
                }
            }

            if let payment = viewModel.paymentResult {
                Section("Abono registrado") {
                    LabeledContent("Pago", value: payment.id)
                    LabeledContent("Monto", value: money(payment.amount))
                    LabeledContent("Método", value: payment.method)
                }
            }

            if let updated = viewModel.updatedReceivable {
                Section("Estado actualizado") {
                    LabeledContent("Estado", value: ReceivableStatusPresentation.displayName(updated.status))
                    LabeledContent("Saldo", value: money(updated.effectiveBalance))
                    if updated.isSettled {
                        Label("Cuenta cobrada. No hay saldo pendiente.", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let message = viewModel.infoMessage {
                Section {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.isSettled && !viewModel.currentReceivable.isMissingCustomer {
                Section {
                    Button {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.collect() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Label(viewModel.primaryActionTitle, systemImage: "checkmark.seal")
                        }
                    }
                    .disabled(!viewModel.canCollect)
                }
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle(viewModel.currentReceivable.isMissingCustomer ? "Revisar cuenta" : (viewModel.isSettled ? "Cuenta cobrada" : "Registrar abono"))
        .task { await viewModel.load() }
        .onChange(of: viewModel.updatedReceivable) { _, updated in
            if let updated {
                onCollected(updated)
            }
        }
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

#Preview {
    NavigationStack {
        ReceivableCollectionView(
            viewModel: ReceivableCollectionViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                receivable: PreviewData.receivableResponse.receivable,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                cashRepository: PreviewCashRepository(),
                receivablesRepository: PreviewReceivablesRepository()
            )
        )
    }
}

// MARK: - Receivables list / customer debt history

enum ReceivablesListFilter: String, CaseIterable, Identifiable, Sendable {
    case active
    case all
    case settled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Pendientes"
        case .all:
            return "Todas"
        case .settled:
            return "Cobradas"
        }
    }

    var queryValue: String? {
        switch self {
        case .active:
            return "open,partially_paid,partially_collected,overdue"
        case .all:
            return "open,partially_paid,partially_collected,overdue,paid,collected,closed,settled"
        case .settled:
            return "paid,collected,closed,settled"
        }
    }
}

@MainActor
@Observable
final class ReceivablesListViewModel {
    private(set) var receivables: [ReceivableRecord] = []
    private(set) var total: Int?
    private(set) var hasMore: Bool?
    private(set) var isLoading = false
    var query = ""
    var selectedFilter: ReceivablesListFilter = .active
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let branchId: String
    let customerId: String?
    let title: String
    let effectivePermissions: Set<String>

    private let receivablesRepository: ReceivablesRepository
    private var lastLoadedAt: Date?

    init(
        organizationId: String,
        branchId: String,
        customerId: String? = nil,
        title: String = "Cuentas por cobrar",
        effectivePermissions: Set<String>,
        receivablesRepository: ReceivablesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        let normalizedCustomerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.customerId = normalizedCustomerId.isEmpty ? nil : normalizedCustomerId
        self.title = title
        self.effectivePermissions = effectivePermissions
        self.receivablesRepository = receivablesRepository
    }

    var canView: Bool {
        hasPermission([
            "business.receivables.view",
            "receivables.view",
            "business.receivables.collect",
            "receivables.collect",
            "business.receivables.create",
            "receivables.create"
        ])
    }

    var canCollect: Bool {
        hasPermission([
            "business.receivables.collect",
            "receivables.collect",
            "business.payments.collect",
            "payments.collect"
        ])
    }

    func canCollect(_ receivable: ReceivableRecord) -> Bool {
        canCollect && !receivable.isSettled && !receivable.isMissingCustomer
    }

    var visibleReceivables: [ReceivableRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return receivables }

        return receivables.filter { receivable in
            [
                receivable.id,
                receivable.saleId,
                receivable.customerId ?? "",
                receivable.customerName ?? "",
                receivable.status,
                receivable.amount.amount,
                receivable.effectiveBalance.amount
            ]
                .joined(separator: " ")
                .lowercased()
                .contains(normalizedQuery)
        }
    }

    var activeSummaryText: String {
        let count = visibleReceivables.count
        let suffix = count == 1 ? "cuenta" : "cuentas"
        if let total {
            return "\(count) de \(total) \(suffix)"
        }
        return "\(count) \(suffix)"
    }

    func loadIfNeeded() async {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < 8, !receivables.isEmpty {
            return
        }
        await load(force: false)
    }

    func refresh() async {
        await load(force: true)
    }

    func applyCollectionUpdate(_ updated: ReceivableRecord) {
        if let index = receivables.firstIndex(where: { $0.id == updated.id }) {
            receivables[index] = updated
        } else {
            receivables.insert(updated, at: 0)
        }
    }

    private func load(force: Bool) async {
        guard canView else {
            receivables = []
            errorMessage = "No tienes permiso para consultar cuentas por cobrar."
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
            lastLoadedAt = Date()
        }

        do {
            let response = try await receivablesRepository.list(
                organizationId: organizationId,
                customerId: customerId,
                status: selectedFilter.queryValue,
                limit: 100
            )

            receivables = response.receivables.sorted(by: sortReceivables)
            total = response.total
            hasMore = response.hasMore
            infoMessage = receivables.isEmpty ? "No hay cuentas por cobrar con este filtro." : nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sortReceivables(_ lhs: ReceivableRecord, _ rhs: ReceivableRecord) -> Bool {
        if lhs.isSettled != rhs.isSettled { return !lhs.isSettled }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (lhs?, rhs?):
            return lhs < rhs
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }
}

struct ReceivablesListView: View {
    @Bindable private var viewModel: ReceivablesListViewModel
    private let cashRepository: CashRepository
    private let receivablesRepository: ReceivablesRepository

    init(
        viewModel: ReceivablesListViewModel,
        cashRepository: CashRepository,
        receivablesRepository: ReceivablesRepository
    ) {
        self.viewModel = viewModel
        self.cashRepository = cashRepository
        self.receivablesRepository = receivablesRepository
    }

    var body: some View {
        Form {
            filtersSection
            summarySection
            receivablesSection
            messagesSection
        }
        .nexoKeyboardDismissable()
        .navigationTitle(viewModel.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            Task { await viewModel.refresh() }
        }
    }

    private var filtersSection: some View {
        Section("Filtros") {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Cliente, venta o saldo", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { NexoKeyboard.dismiss() }

                if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        viewModel.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Limpiar búsqueda")
                }
            }

            Picker("Estado", selection: $viewModel.selectedFilter) {
                ForEach(ReceivablesListFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var summarySection: some View {
        Section("Resumen") {
            LabeledContent("Resultado", value: viewModel.activeSummaryText)
            if viewModel.hasMore == true {
                Label("Hay más cuentas disponibles. Refina la búsqueda si necesitas menos resultados.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var receivablesSection: some View {
        Section("Cuentas") {
            if viewModel.isLoading && viewModel.receivables.isEmpty {
                ProgressView("Cargando cuentas por cobrar…")
            } else if viewModel.visibleReceivables.isEmpty {
                ContentUnavailableView(
                    "Sin cuentas por cobrar",
                    systemImage: "person.crop.circle.badge.clock",
                    description: Text("Cuando una venta quede fiada con cliente identificado aparecerá aquí.")
                )
            } else {
                ForEach(viewModel.visibleReceivables) { receivable in
                    if viewModel.canCollect(receivable) {
                        NavigationLink {
                            ReceivableCollectionView(
                                viewModel: ReceivableCollectionViewModel(
                                    organizationId: viewModel.organizationId,
                                    branchId: viewModel.branchId,
                                    receivable: receivable,
                                    effectivePermissions: viewModel.effectivePermissions,
                                    cashRepository: cashRepository,
                                    receivablesRepository: receivablesRepository
                                ),
                                onCollected: { updated in
                                    viewModel.applyCollectionUpdate(updated)
                                }
                            )
                        } label: {
                            ReceivableListRow(receivable: receivable, showsAccessory: true)
                        }
                    } else {
                        ReceivableListRow(receivable: receivable, showsAccessory: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReceivableListRow: View {
    let receivable: ReceivableRecord
    let showsAccessory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: receivable.isSettled ? "checkmark.circle.fill" : "person.crop.circle.badge.clock")
                    .foregroundStyle(receivable.isSettled ? .green : .orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(receivable.displayCustomerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Venta \(String(receivable.saleId.suffix(10)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if receivable.isMissingCustomer {
                        Text("Revisar: cuenta histórica sin cliente identificado")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(receivable.effectiveBalance.displayText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()

                    Text(ReceivableStatusPresentation.displayName(receivable.status))
                        .font(.caption)
                        .foregroundStyle(receivable.isSettled ? .green : .orange)
                }

                if showsAccessory {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 5)
                }
            }

            if let dueDate = receivable.dueDate {
                Label("Vence \(dueDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let createdAt = receivable.createdAt {
                Label("Creada \(createdAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Cuentas por cobrar") {
    NavigationStack {
        ReceivablesListView(
            viewModel: ReceivablesListViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                receivablesRepository: PreviewReceivablesRepository()
            ),
            cashRepository: PreviewCashRepository(),
            receivablesRepository: PreviewReceivablesRepository()
        )
    }
}
