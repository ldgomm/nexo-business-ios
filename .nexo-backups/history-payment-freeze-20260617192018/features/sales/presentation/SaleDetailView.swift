//
//  SaleDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//
 
import SwiftUI

struct SaleDetailView: View {
    @Bindable private var viewModel: SaleDetailViewModel
    private let customersRepository: CustomersRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository
    private let onSaleUpdated: (BusinessSale) -> Void

    init(
        viewModel: SaleDetailViewModel,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository,
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
        self.onSaleUpdated = onSaleUpdated
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if viewModel.isLoading, viewModel.sale == nil {
                    SaleDetailLoadingCard()
                }

                if let sale = viewModel.sale {
                    messagesSection
                    heroSection(sale)
                    itemsSection(sale)
                    totalsSection(sale)
                    paymentSection(sale)
                    electronicDocumentSection(sale)
                    actionsSection
                } else if !viewModel.isLoading {
                    SaleDetailEmptyState()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .nexoKeyboardDismissable()
        .navigationTitle("Detalle de venta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
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
        .task {
            if viewModel.shouldLoadOnAppear {
                await viewModel.load()
            }
        }
        .onChange(of: viewModel.sale) { _, sale in
            if let sale {
                onSaleUpdated(sale)
            }
        }
    }

    private func heroSection(_ sale: BusinessSale) -> some View {
        SaleDetailHeroCard(
            saleNumber: sale.displayNumber,
            customerName: sale.displayCustomerName,
            saleStatus: SaleStatusPresentation.title(for: sale.status),
            paymentStatus: PaymentStatusPresentation.displayName(sale.paymentStatus),
            total: money(sale.totals.grandTotal),
            createdAt: sale.createdAt,
            confirmedAt: sale.confirmedAt
        )
    }

    @ViewBuilder
    private func itemsSection(_ sale: BusinessSale) -> some View {
        if !sale.items.isEmpty {
            SaleDetailCard(
                title: "Ítems",
                subtitle: "\(sale.items.count) línea\(sale.items.count == 1 ? "" : "s") en esta venta"
            ) {
                VStack(spacing: 10) {
                    ForEach(sale.items, id: \.id) { item in
                        SaleDetailItemRow(
                            name: item.name,
                            quantity: item.quantity.cleanQuantityText,
                            lineTotal: money(lineTotal(for: item))
                        )
                    }
                }
            }
        }
    }

    private func totalsSection(_ sale: BusinessSale) -> some View {
        SaleDetailCard(title: "Totales", subtitle: "Desglose calculado de la venta") {
            VStack(spacing: 10) {
                SaleDetailAmountRow(title: "Subtotal", value: money(sale.totals.subtotalWithoutTaxes))
                SaleDetailAmountRow(title: "Descuento", value: money(sale.totals.discountTotal))
                SaleDetailAmountRow(title: "Impuestos", value: money(sale.totals.taxTotal))

                Divider()

                SaleDetailAmountRow(
                    title: "Total",
                    value: money(sale.totals.grandTotal),
                    isHighlighted: true
                )
            }
        }
    }

    private func paymentSection(_ sale: BusinessSale) -> some View {
        SaleDetailCard {
            HStack(alignment: .top, spacing: 12) {
                SaleDetailIconBadge(
                    systemImage: PaymentStatusPresentation.systemImage(sale.paymentStatus),
                    tint: sale.needsCollection ? .orange : .green
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Cobro")
                        .font(.headline)

                    SaleDetailPill(
                        title: PaymentStatusPresentation.displayName(sale.paymentStatus),
                        systemImage: PaymentStatusPresentation.systemImage(sale.paymentStatus),
                        tint: sale.needsCollection ? .orange : .green
                    )

                    Text(paymentExplanation(for: sale))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func electronicDocumentSection(_ sale: BusinessSale) -> some View {
        let status = sale.effectiveDocumentStatus ?? "not_required"
        let document = sale.primaryElectronicDocument

        return SaleDetailCard {
            HStack(alignment: .top, spacing: 12) {
                SaleDetailIconBadge(
                    systemImage: BusinessDocumentStatusPresentation.systemImage(status),
                    tint: documentTint(status)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Comprobante electrónico")
                        .font(.headline)

                    SaleDetailPill(
                        title: BusinessDocumentStatusPresentation.displayName(status),
                        systemImage: BusinessDocumentStatusPresentation.systemImage(status),
                        tint: documentTint(status)
                    )

                    if let document {
                        VStack(spacing: 8) {
                            SaleDetailMetaRow(title: "Número", value: document.businessDisplayNumber)

                            if let authorizationNumber = document.shortAuthorizationDisplay {
                                SaleDetailMetaRow(title: "Autorización SRI", value: authorizationNumber, isMonospaced: true)
                            }
                        }

                        if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                            SaleDetailInlineMessage(message: error, systemImage: "exclamationmark.triangle.fill", tint: .red)
                        } else if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
                            SaleDetailInlineMessage(
                                message: document.hasRide ? "Factura autorizada. RIDE y XML se revisan desde Comprobantes." : "Factura autorizada, pero todavía falta RIDE.",
                                systemImage: document.hasRide ? "checkmark.circle.fill" : "doc.badge.clock",
                                tint: document.hasRide ? .green : .orange
                            )
                        } else {
                            SaleDetailInlineMessage(
                                message: "Revisa el comprobante para ver autorización, RIDE, XML, correo y errores si existieran.",
                                systemImage: "info.circle",
                                tint: .secondary
                            )
                        }
                    } else if BusinessDocumentStatusPresentation.isMissingElectronicDocument(status) {
                        Text("Sin factura electrónica emitida. Esta venta puede estar cobrada y seguir como registro interno hasta que alguien con permiso emita el comprobante.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let reason = viewModel.electronicInvoiceBlockedReason {
                            SaleDetailInlineMessage(message: reason, systemImage: "lock.fill", tint: .secondary)

                            if let detail = sale.electronicInvoiceReadiness.detailedMessage {
                                Text(detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else if viewModel.canIssueElectronicInvoice(for: sale) {
                            SaleDetailInlineMessage(
                                message: "Puedes emitir factura electrónica desde Comprobantes.",
                                systemImage: "doc.badge.plus",
                                tint: .accentColor
                            )
                        }
                    } else {
                        Text("La venta indica un comprobante electrónico en estado \(BusinessDocumentStatusPresentation.displayName(status)). Abre Comprobantes para cargar el detalle real.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.errorMessage) {
            SaleDetailMessageBanner(message: message, systemImage: "exclamationmark.triangle.fill", tint: .red)
        }

        if let message = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.infoMessage) {
            SaleDetailMessageBanner(message: message, systemImage: "info.circle.fill", tint: .accentColor)
        }
    }

    private var actionsSection: some View {
        SaleDetailCard(title: "Acciones", subtitle: "Continúa con el siguiente paso operativo de la venta") {
            VStack(alignment: .leading, spacing: 12) {
                if let sale = viewModel.sale, viewModel.canCollect {
                    NavigationLink {
                        PaymentRegisterView(
                            viewModel: PaymentRegisterViewModel(
                                organizationId: viewModel.organizationId,
                                branchId: sale.branchId,
                                sale: sale,
                                effectivePermissions: viewModel.effectivePermissions,
                                cashRepository: cashRepository,
                                paymentsRepository: paymentsRepository,
                                receivablesRepository: receivablesRepository,
                                documentsRepository: documentsRepository,
                                salesRepository: viewModel.salesRepositoryForPaymentReadiness,
                                activityId: sale.activityId,
                                revisions: viewModel.revisions
                            ),
                            customersRepository: customersRepository,
                            onSaleUpdated: { updatedSale in
                                viewModel.applySaleUpdate(updatedSale)
                            }
                        )
                    } label: {
                        SaleDetailNavigationActionLabel(
                            title: "Cobrar venta",
                            subtitle: "Registra el pago y actualiza el estado de cobro",
                            systemImage: "dollarsign.circle",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let sale = viewModel.sale, viewModel.canViewDocuments {
                    NavigationLink {
                        BusinessDocumentsRouteView(
                            organizationId: viewModel.organizationId,
                            sale: sale,
                            effectivePermissions: viewModel.effectivePermissions,
                            branchId: sale.branchId,
                            activityId: sale.activityId,
                            revisions: viewModel.revisions,
                            documentsRepository: documentsRepository,
                            onSaleUpdated: { updatedSale in
                                viewModel.applySaleUpdate(updatedSale)
                            }
                        )
                    } label: {
                        SaleDetailNavigationActionLabel(
                            title: viewModel.documentActionTitle(for: sale),
                            subtitle: "Factura electrónica, RIDE, XML y respaldo interno",
                            systemImage: viewModel.documentActionSystemImage(for: sale),
                            tint: .accentColor
                        )
                    }
                    .buttonStyle(.plain)
                }

                SaleDetailActionButton(
                    title: "Confirmar venta",
                    subtitle: "Marca la venta como confirmada",
                    systemImage: "checkmark.seal",
                    tint: .accentColor,
                    isLoading: viewModel.isConfirming,
                    isDisabled: !viewModel.canConfirm
                ) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.confirm() }
                }

                Divider()
                    .padding(.vertical, 2)

                TextField("Motivo de cancelación opcional", text: $viewModel.cancelReason, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                SaleDetailActionButton(
                    title: "Cancelar venta",
                    subtitle: "Anula la venta si todavía está permitido",
                    systemImage: "xmark.circle",
                    tint: .red,
                    isLoading: viewModel.isCanceling,
                    isDisabled: !viewModel.canCancel
                ) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.cancel() }
                }
            }
        }
    }

    private func lineTotal(for item: BusinessSaleItem) -> MoneyAmount {
        item.total ?? item.subtotal ?? MoneyAmount(amount: "0.00")
    }

    private func paymentExplanation(for sale: BusinessSale) -> String {
        if sale.needsCollection {
            return "Registrada no significa cobrada. Esta venta todavía debe cobrarse o dejarse claramente como cuenta por cobrar."
        }

        return "El estado de cobro indica que esta venta ya no está pendiente de cobro operativo."
    }

    private func documentTint(_ status: String) -> Color {
        if BusinessDocumentStatusPresentation.isError(status) {
            return .red
        }

        if BusinessDocumentStatusPresentation.isAuthorized(status) {
            return .green
        }

        if BusinessDocumentStatusPresentation.isMissingElectronicDocument(status) {
            return .secondary
        }

        return .accentColor
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

private struct SaleDetailHeroCard: View {
    let saleNumber: String
    let customerName: String
    let saleStatus: String
    let paymentStatus: String
    let total: String
    let createdAt: Date?
    let confirmedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                SaleDetailIconBadge(systemImage: "receipt.fill", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Venta")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(saleNumber)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(customerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(total)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 8) {
                SaleDetailPill(title: saleStatus, systemImage: "checkmark.seal", tint: .accentColor)
                SaleDetailPill(title: paymentStatus, systemImage: "creditcard", tint: .green)
            }

            VStack(spacing: 8) {
                if let createdAt {
                    SaleDetailDateStrip(
                        title: "Creada",
                        value: createdAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                }

                if let confirmedAt {
                    SaleDetailDateStrip(
                        title: "Confirmada",
                        value: confirmedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "checkmark.circle"
                    )
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct SaleDetailCard<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct SaleDetailItemRow: View {
    let name: String
    let quantity: String
    let lineTotal: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SaleDetailIconBadge(systemImage: "takeoutbag.and.cup.and.straw", tint: .accentColor)

            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Cantidad: \(quantity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(lineTotal)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SaleDetailAmountRow: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(isHighlighted ? .headline : .subheadline)
                .foregroundStyle(isHighlighted ? .primary : .secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(isHighlighted ? .title3.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(isHighlighted ? 12 : 0)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
            }
        }
    }
}

private struct SaleDetailNavigationActionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            SaleDetailIconBadge(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SaleDetailActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .foregroundStyle(isDisabled ? Color.secondary : tint)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isDisabled ? Color(.tertiarySystemGroupedBackground) : tint.opacity(0.10))
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

private struct SaleDetailMetaRow: View {
    let title: String
    let value: String
    var isMonospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(isMonospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

private struct SaleDetailInlineMessage: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SaleDetailMessageBanner: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SaleDetailDateStrip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SaleDetailPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct SaleDetailIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct SaleDetailLoadingCard: View {
    var body: some View {
        SaleDetailCard {
            HStack(spacing: 12) {
                ProgressView()
                Text("Cargando venta…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

private struct SaleDetailEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Venta no disponible")
                .font(.headline)

            Text("Actualiza para volver a consultar el estado de la venta.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        SaleDetailView(
            viewModel: SaleDetailViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                saleId: PreviewData.confirmedSaleResponse.sale.id,
                revisions: PreviewData.businessContext.revisions,
                initialSale: PreviewData.confirmedSaleResponse.sale,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                salesRepository: PreviewSalesRepository()
            ),
            customersRepository: PreviewCustomersRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}
