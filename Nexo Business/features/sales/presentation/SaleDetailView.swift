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

    @State private var preparedPaymentViewModel: PaymentRegisterViewModel?
    @State private var shouldShowPaymentRegister = false
    @State private var isPreparingPaymentNavigation = false
    @State private var paymentPreparationMessage: String?
    @State private var documentPreviewFile: BusinessDocumentDownloadedFile?
    @State private var documentShareFile: BusinessDocumentDownloadedFile?
    @State private var documentFileActionInFlight: SaleDetailDocumentFileAction?
    @State private var documentFileMessage: String?

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
        .navigationDestination(isPresented: $shouldShowPaymentRegister) {
            if let preparedPaymentViewModel {
                PaymentRegisterView(
                    viewModel: preparedPaymentViewModel,
                    customersRepository: customersRepository,
                    onSaleUpdated: { updatedSale in
                        viewModel.applySaleUpdate(updatedSale)
                    }
                )
            }
        }
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
        .sheet(item: $documentPreviewFile) { file in
            BusinessDocumentQuickLookPreview(fileURL: file.localURL)
        }
        .sheet(item: $documentShareFile) { file in
            BusinessDocumentShareSheet(items: [file.localURL])
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
        .onChange(of: shouldShowPaymentRegister) { _, isPresented in
            if !isPresented {
                preparedPaymentViewModel = nil
                paymentPreparationMessage = nil
            }
        }
    }

    private func heroSection(_ sale: BusinessSale) -> some View {
        SaleDetailHeroCard(
            saleNumber: sale.displayNumber,
            customerName: sale.displayCustomerName,
            saleStatus: SaleStatusPresentation.title(for: sale.status),
            paymentStatus: sale.collectionState.displayName,
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
                    systemImage: sale.collectionState.systemImage,
                    tint: collectionTint(for: sale.collectionState)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Cobro")
                        .font(.headline)

                    SaleDetailPill(
                        title: sale.collectionState.displayName,
                        systemImage: sale.collectionState.systemImage,
                        tint: collectionTint(for: sale.collectionState)
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

                        if let error = document.effectiveLastErrorMessage {
                            SaleDetailInlineMessage(message: error, systemImage: "exclamationmark.triangle.fill", tint: .red)
                        } else if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
                            SaleDetailInlineMessage(
                                message: document.hasRide ? "Factura autorizada por el SRI. Ya puedes abrir o compartir el RIDE desde esta venta." : "Factura autorizada por el SRI, pero todavía falta RIDE.",
                                systemImage: document.hasRide ? "checkmark.circle.fill" : "doc.badge.clock",
                                tint: document.hasRide ? .green : .orange
                            )
                        } else {
                            SaleDetailInlineMessage(
                                message: viewModel.electronicDocumentActionHint(for: document),
                                systemImage: "info.circle",
                                tint: .secondary
                            )
                        }

                        electronicDocumentActions(document)
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

        if let message = BusinessDocumentTextSanitizer.sanitizedMessage(documentFileMessage) {
            SaleDetailMessageBanner(message: message, systemImage: "doc.text.magnifyingglass", tint: .accentColor)
        }
    }

    @ViewBuilder
    private func electronicDocumentActions(_ document: BusinessDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.canViewElectronicDocumentDetail(document) {
                NavigationLink {
                    BusinessElectronicDocumentDetailView(
                        viewModel: BusinessElectronicDocumentDetailViewModel(
                            organizationId: viewModel.organizationId,
                            documentId: document.documentId,
                            effectivePermissions: viewModel.effectivePermissions,
                            documentsRepository: documentsRepository,
                            onDocumentMutated: { await viewModel.refresh() }
                        )
                    )
                } label: {
                    SaleDetailNavigationActionLabel(
                        title: "Ver factura",
                        subtitle: "Detalle, timeline, RIDE, XML, email y errores SRI",
                        systemImage: "doc.text.magnifyingglass",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)
            }

            let canUseFileRepository = fileDownloadingRepository != nil
            if viewModel.canDownloadElectronicDocumentRide(document), canUseFileRepository {
                SaleDetailActionButton(
                    title: "Abrir RIDE",
                    subtitle: "Visualiza la representación imprimible de esta factura",
                    systemImage: "doc.richtext",
                    tint: .accentColor,
                    isLoading: documentFileActionInFlight == .previewRide,
                    isDisabled: documentFileActionInFlight != nil
                ) {
                    prepareElectronicDocumentFile(document, action: .previewRide)
                }

                if viewModel.canShareElectronicDocumentRide(document) {
                    SaleDetailActionButton(
                        title: "Compartir RIDE",
                        subtitle: "Envía o guarda el PDF autorizado desde iOS",
                        systemImage: "square.and.arrow.up",
                        tint: .accentColor,
                        isLoading: documentFileActionInFlight == .shareRide,
                        isDisabled: documentFileActionInFlight != nil
                    ) {
                        prepareElectronicDocumentFile(document, action: .shareRide)
                    }
                }
            }

            if viewModel.canDownloadElectronicDocumentXml(document), canUseFileRepository {
                SaleDetailActionButton(
                    title: "Abrir XML",
                    subtitle: viewModel.electronicDocumentXmlAuthorizedOnly(document) ? "Consulta el XML autorizado por el SRI" : "Consulta el XML disponible para revisión",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    tint: .accentColor,
                    isLoading: documentFileActionInFlight == .previewXml,
                    isDisabled: documentFileActionInFlight != nil
                ) {
                    prepareElectronicDocumentFile(document, action: .previewXml)
                }
            }
        }
    }

    private var actionsSection: some View {
        SaleDetailCard(title: "Acciones", subtitle: "Continúa con el siguiente paso operativo de la venta") {
            VStack(alignment: .leading, spacing: 12) {
                if let sale = viewModel.sale, viewModel.canCollect {
                    SaleDetailActionButton(
                        title: collectionActionTitle(for: sale),
                        subtitle: collectionActionSubtitle(for: sale),
                        systemImage: "dollarsign.circle",
                        tint: .green,
                        isLoading: isPreparingPaymentNavigation,
                        isDisabled: isPreparingPaymentNavigation
                    ) {
                        preparePaymentNavigation(for: sale)
                    }
                } else if let sale = viewModel.sale, sale.hasReceivableReference {
                    SaleDetailInlineMessage(
                        message: sale.hasRealReceivable
                        ? "Esta venta ya tiene una cuenta por cobrar real. Registra abonos desde Más → Por cobrar para no duplicar cobros."
                        : "Esta venta tiene una cuenta por cobrar incompleta. Revisa cliente y saldo antes de registrar abonos.",
                        systemImage: sale.hasRealReceivable ? "person.crop.circle.badge.clock" : "exclamationmark.triangle.fill",
                        tint: sale.hasRealReceivable ? .orange : .red
                    )
                }

                if let paymentPreparationMessage {
                    SaleDetailInlineMessage(
                        message: paymentPreparationMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .red
                    )
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

    private func prepareElectronicDocumentFile(_ document: BusinessDocument, action: SaleDetailDocumentFileAction) {
        guard documentFileActionInFlight == nil else { return }
        guard let repository = fileDownloadingRepository else {
            documentFileMessage = "La descarga de archivos no está disponible en esta versión. Abre el detalle del comprobante para revisar su estado."
            return
        }

        documentFileActionInFlight = action
        documentFileMessage = nil

        Task {
            do {
                let file: BusinessDocumentDownloadedFile
                switch action {
                case .previewRide, .shareRide:
                    file = try await repository.downloadElectronicDocumentRideFile(
                        organizationId: viewModel.organizationId,
                        documentId: document.documentId
                    )
                case .previewXml, .shareXml:
                    file = try await repository.downloadElectronicDocumentXmlFile(
                        organizationId: viewModel.organizationId,
                        documentId: document.documentId,
                        authorizedOnly: viewModel.electronicDocumentXmlAuthorizedOnly(document)
                    )
                }

                await MainActor.run {
                    documentFileActionInFlight = nil
                    switch action {
                    case .previewRide, .previewXml:
                        documentPreviewFile = file
                    case .shareRide, .shareXml:
                        documentShareFile = file
                    }
                    documentFileMessage = file.preparedSummaryText
                }
            } catch let error as APIError {
                await MainActor.run {
                    documentFileActionInFlight = nil
                    documentFileMessage = error.userMessage
                }
            } catch {
                await MainActor.run {
                    documentFileActionInFlight = nil
                    documentFileMessage = error.localizedDescription
                }
            }
        }
    }

    private func preparePaymentNavigation(for sale: BusinessSale) {
        guard !isPreparingPaymentNavigation else { return }

        let branchId = sale.branchId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branchId.isEmpty else {
            paymentPreparationMessage = "No se puede cobrar esta venta porque no tiene sucursal asociada. Actualiza el detalle de venta y vuelve a intentar."
            return
        }

        isPreparingPaymentNavigation = true
        paymentPreparationMessage = nil

        preparedPaymentViewModel = PaymentRegisterViewModel(
            organizationId: viewModel.organizationId,
            branchId: branchId,
            sale: sale,
            effectivePermissions: viewModel.effectivePermissions,
            cashRepository: cashRepository,
            paymentsRepository: paymentsRepository,
            receivablesRepository: receivablesRepository,
            documentsRepository: documentsRepository,
            salesRepository: viewModel.salesRepositoryForPaymentReadiness,
            activityId: sale.activityId,
            revisions: viewModel.revisions
        )

        isPreparingPaymentNavigation = false
        shouldShowPaymentRegister = true
    }

    private func paymentExplanation(for sale: BusinessSale) -> String {
        switch sale.collectionState {
        case .paid:
            return "Esta venta ya está pagada. No debes registrar nuevos cobros desde aquí."
        case .realReceivable:
            return "Esta venta sí es una cuenta por cobrar: tiene cliente identificado y deuda formal. Los abonos se registran desde Por cobrar."
        case .receivableNeedsReview:
            return "La venta parece tener una cuenta por cobrar incompleta. Revisa cliente y saldo antes de registrar cualquier abono."
        case .partialWithoutReceivable:
            return "Tiene un pago parcial, pero todavía no es una cuenta por cobrar. Puedes cobrar el saldo o regularizarla con cliente real si corresponde."
        case .unpaidSavedSale:
            if BusinessElectronicInvoiceCustomerPolicy.isFinalConsumer(sale: sale) {
                return "Venta guardada sin cobrar. No es deuda ni fiado: Consumidor final solo puede continuar, cobrar ahora o cancelar."
            }
            return "Venta guardada sin cobrar. No es cuenta por cobrar hasta que se cree fiado con cliente identificado."
        case .cancelled:
            return "La venta está cancelada. No debe cobrarse ni convertirse en cuenta por cobrar."
        case .unknown:
            return "Estado de cobro no reconocido. Revisa la venta antes de continuar."
        }
    }

    private func collectionActionTitle(for sale: BusinessSale) -> String {
        switch sale.collectionState {
        case .partialWithoutReceivable:
            return "Cobrar saldo"
        default:
            return "Cobrar ahora"
        }
    }

    private func collectionActionSubtitle(for sale: BusinessSale) -> String {
        switch sale.collectionState {
        case .partialWithoutReceivable:
            return "Completa el saldo pendiente sin crear una cuenta por cobrar falsa"
        case .unpaidSavedSale:
            return "Registra el pago de esta venta guardada o sin cobrar"
        default:
            return "Registra el pago y actualiza el estado de cobro"
        }
    }

    private func collectionTint(for state: SaleCollectionState) -> Color {
        switch state {
        case .paid:
            return .green
        case .realReceivable, .partialWithoutReceivable, .unpaidSavedSale:
            return .orange
        case .receivableNeedsReview, .unknown:
            return .red
        case .cancelled:
            return .secondary
        }
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

    private var fileDownloadingRepository: BusinessDocumentFileDownloadingRepository? {
        documentsRepository as? BusinessDocumentFileDownloadingRepository
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

private enum SaleDetailDocumentFileAction: Equatable {
    case previewRide
    case shareRide
    case previewXml
    case shareXml
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
