//
//  SaleCartView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct SaleCartView: View {
    @Bindable private var viewModel: SaleCartViewModel
    private let customersRepository: CustomersRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let salesHistoryRepository: SalesHistoryRepository?
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository
    @State private var showStartNewOrderConfirmation = false
    @State private var isPendingSalesExpanded = false
    @State private var pendingSaleDeletionCandidate: BusinessSale?

    @State private var preparedPaymentViewModel: PaymentRegisterViewModel?
    @State private var isPreparingPaymentNavigation = false
    @State private var shouldShowPaymentRegister = false
    @State private var paymentPreparationMessage: String?
    
    init(
        viewModel: SaleCartViewModel,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        salesHistoryRepository: SalesHistoryRepository? = nil,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.salesHistoryRepository = salesHistoryRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 11) {
                operationGroup

                saleBuilderGroup

                if shouldShowSummaryGroup {
                    summaryGroup
                }
                
                if viewModel.shouldShowPendingSalesGroup {
                    pendingSalesGroup
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .nexoKeyboardDismissable()
        .navigationTitle(navigationTitle)
        .navigationDestination(isPresented: $shouldShowPaymentRegister) {
            if let preparedPaymentViewModel {
                PaymentRegisterView(
                    viewModel: preparedPaymentViewModel,
                    autoPrepareCashOnAppear: true,
                    customersRepository: customersRepository,
                    onSaleUpdated: { updatedSale in
                        viewModel.updateCreatedSale(updatedSale)
                        Task { await viewModel.refreshPendingSales() }
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.canStartNewOrder {
                    Button {
                        requestStartNewOrder()
                    } label: {
                        Label("Nueva", systemImage: "plus.circle")
                    }
                }
            }
        }
        .alert(viewModel.startNewOrderConfirmationTitle, isPresented: $showStartNewOrderConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Sí, dejar pendiente", role: .destructive) {
                viewModel.startNewOrder()
            }
        } message: {
            Text(viewModel.startNewOrderConfirmationMessage)
        }
        .alert("Eliminar venta pendiente", isPresented: pendingSaleDeletionConfirmationBinding) {
            Button("Cancelar", role: .cancel) {
                pendingSaleDeletionCandidate = nil
            }
            Button("Eliminar", role: .destructive) {
                guard let sale = pendingSaleDeletionCandidate else { return }
                pendingSaleDeletionCandidate = nil
                Task {
                    await viewModel.deletePendingSale(sale)
                }
            }
        } message: {
            Text(pendingSaleDeletionConfirmationMessage)
        }
        .onAppear {
            viewModel.recalculateLocalTotalsIfNeeded()
        }
        .task {
            await viewModel.loadPendingSalesIfNeeded()
        }
        .onDisappear {
            viewModel.cancelScheduledPreview()
        }
    }

    private var shouldShowSummaryGroup: Bool {
        !viewModel.cartItems.isEmpty ||
        viewModel.createdSale != nil ||
        viewModel.errorMessage != nil ||
        viewModel.finalConsumerInvoiceWarning != nil ||
        viewModel.infoMessage != nil
    }

    private var operationGroup: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                SaleCartHeroIconBadge(systemImage: "sparkles.rectangle.stack.fill", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Sales")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(orderStateTitle)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(orderStateDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                SaleCartHeroPill(
                    title: viewModel.orderState.displayName,
                    systemImage: orderStateIcon,
                    tint: operationStateTint
                )

                SaleCartHeroPill(
                    title: viewModel.selectedCustomer == nil ? "Consumidor final" : "Cliente identificado",
                    systemImage: viewModel.selectedCustomer == nil ? "person.crop.circle" : "person.crop.circle.fill",
                    tint: viewModel.selectedCustomer == nil ? .orange : .accentColor
                )
            }

            VStack(spacing: 12) {
                operationalCustomerBlock
                if viewModel.supportsRestaurantServiceType {
                    operationalServiceTypeBlock
                }
                operationalCashBlock
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
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

    private var operationalCustomerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: viewModel.selectedCustomer == nil ? "person.crop.circle" : "person.crop.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cliente")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.selectedCustomer?.displayName ?? "Consumidor final")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                NavigationLink {
                    CustomerPickerView(
                        viewModel: CustomerPickerViewModel(
                            organizationId: viewModel.organizationId,
                            effectivePermissions: viewModel.effectivePermissions,
                            customersRepository: customersRepository
                        ),
                        onSelect: { customer in
                            viewModel.selectCustomer(customer)
                        }
                    )
                } label: {
                    Text(viewModel.selectedCustomer == nil ? "Elegir" : "Cambiar")
                        .font(.footnote.weight(.semibold))
                }
                .disabled(!viewModel.canEditCart)
            }

            if let customer = viewModel.selectedCustomer {
                CustomerRowView(customer: customer)

                Button(role: .destructive) {
                    viewModel.clearCustomer()
                } label: {
                    Label("Quitar cliente", systemImage: "xmark.circle")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canEditCart)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var operationalServiceTypeBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.selectedServiceType.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tipo de servicio")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.selectedServiceType.displayName)
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 8)
            }

            Picker("Tipo de servicio", selection: $viewModel.selectedServiceType) {
                ForEach(viewModel.availableServiceTypes) { serviceType in
                    Label(serviceType.shortDisplayName, systemImage: serviceType.systemImage)
                        .tag(serviceType)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!viewModel.canEditCart)

            Text("Metadata operativa sobre la venta core. No crea mesas, cocina ni venta restaurante paralela.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var operationalCashBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "banknote")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text("Caja")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            SaleCartCashCard(
                organizationId: viewModel.organizationId,
                branchId: viewModel.branchId,
                permissions: viewModel.effectivePermissions,
                cashRepository: cashRepository,
                onSessionChanged: { session in
                    viewModel.cashSessionId = session?.isOpen == true ? session?.id : nil
                },
                dashboardDestination: {
                    CashDashboardRouteView(
                        viewModel: CashDashboardViewModel(
                            organizationId: viewModel.organizationId,
                            branchId: viewModel.branchId,
                            permissions: viewModel.effectivePermissions,
                            cashRepository: cashRepository
                        )
                    )
                }
            )
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var saleBuilderGroup: some View {
        SaleCartGroupedCard(
            title: saleBuilderTitle,
            subtitle: saleBuilderSubtitle,
            systemImage: "cart.badge.plus"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.createdSale == nil || viewModel.canEditRegisteredSaleItems {
                    productSearchBlock

                    if !viewModel.searchResults.isEmpty {
                        Divider()
                        searchResultsBlock
                    }

                    if !viewModel.suggestionResults.isEmpty || viewModel.isSearchingSuggestions {
                        Divider()
                        suggestionResultsBlock
                    }

                    Divider()
                    cartBlock

                    if !viewModel.cartItems.isEmpty {
                        Divider()
                        discountBlock
                    }

                    if viewModel.createdSale != nil {
                        Divider()
                        registeredSaleEditBlock
                    }
                } else {
                    lockedCartBlock
                }
            }
        }
    }

    private var productSearchBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Buscar producto, SKU o código", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .disabled(!viewModel.canSearchCatalog)
                    .onSubmit {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.searchCatalog() }
                    }

                if !viewModel.searchQuery.trimmed.isEmpty {
                    Button {
                        viewModel.clearSearch()
                        NexoKeyboard.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Limpiar búsqueda")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Text("Agrega productos y el total se actualizará en pantalla.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.searchCatalog() }
                } label: {
                    if viewModel.isSearching || viewModel.isSearchingSuggestions {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Buscar", systemImage: "magnifyingglass")
                            .font(.footnote.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.canSearchCatalog)
            }
        }
    }

    private var searchResultsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resultados")
                .font(.subheadline.weight(.semibold))

            ForEach(viewModel.searchResults) { item in
                Button {
                    viewModel.addToCart(item)
                    NexoKeyboard.dismiss()
                } label: {
                    CatalogResultRow(item: item)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canEditCart)

                if item.id != viewModel.searchResults.last?.id {
                    Divider()
                }
            }
        }
    }

    private var suggestionResultsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sugerencias de Nexo")
                        .font(.subheadline.weight(.semibold))

                    Text("Copia el producto a tu negocio antes de venderlo. El precio e impuesto se guardan como configuración local.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if viewModel.isSearchingSuggestions {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ForEach(viewModel.suggestionResults) { template in
                CatalogSuggestionRow(
                    template: template,
                    isAdopting: viewModel.adoptingTemplateId == template.id,
                    canAdopt: viewModel.canAdoptCatalogSuggestion && template.canAdoptFromBusiness,
                    adoptAction: {
                        Task { await viewModel.adoptSuggestion(template) }
                    }
                )

                if template.id != viewModel.suggestionResults.last?.id {
                    Divider()
                }
            }
        }
    }

    private var cartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Carrito")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(cartCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if viewModel.cartItems.isEmpty {
                ContentUnavailableView(
                    "Carrito vacío",
                    systemImage: "cart",
                    description: Text("Busca productos o servicios y agrégalos a la venta.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else {
                ForEach(viewModel.cartItems) { item in
                    SaleCartRow(
                        item: item,
                        quantity: quantityBinding(for: item),
                        taxTreatment: taxTreatmentBinding(for: item),
                        isSelectedForDiscount: viewModel.isSelectedForDiscount(item.id),
                        showsDiscountSelection: shouldShowLineDiscountSelection,
                        toggleDiscountSelection: { viewModel.toggleDiscountSelection(item.id) },
                        lineNote: lineNoteBinding(for: item),
                        isEditable: viewModel.canEditCart,
                        removeAction: {
                            viewModel.removeFromCart(cartItemId: item.id)
                        }
                    )

                    if item.id != viewModel.cartItems.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var lockedCartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Carrito registrado")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(cartCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ForEach(viewModel.cartItems) { item in
                SaleCartRow(
                    item: item,
                    quantity: quantityBinding(for: item),
                    taxTreatment: taxTreatmentBinding(for: item),
                    isSelectedForDiscount: false,
                    showsDiscountSelection: false,
                    toggleDiscountSelection: {},
                    lineNote: lineNoteBinding(for: item),
                    isEditable: false,
                    removeAction: {}
                )

                if item.id != viewModel.cartItems.last?.id {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private var discountBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: discountEditorBinding.wrappedValue ? "percent" : "tag")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(discountEditorBinding.wrappedValue ? "Descuento activo" : "Sin descuento")
                        .font(.subheadline.weight(.semibold))

                    Text(discountEditorBinding.wrappedValue ? discountActiveDescription : "Actívalo solo si aplica a esta venta.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: discountEditorBinding)
                    .labelsHidden()
                    .disabled(!viewModel.canEditCart)
                    .accessibilityLabel(discountEditorBinding.wrappedValue ? "Desactivar descuento" : "Activar descuento")
            }

            if discountEditorBinding.wrappedValue {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Aplicar a", selection: $viewModel.discountTarget) {
                        ForEach(SaleDiscountTarget.allCases) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!viewModel.canEditCart)

                    Picker("Tipo", selection: $viewModel.discountType) {
                        ForEach(SaleDiscountInputType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!viewModel.canEditCart)

                    HStack(spacing: 10) {
                        TextField(discountFieldPrompt, text: $viewModel.discountValue)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .textFieldStyle(.roundedBorder)
                            .disabled(!viewModel.canEditCart)
                            .accessibilityLabel("Valor del descuento")

                        Stepper("", value: discountStepperBinding, in: discountRange, step: discountStep)
                            .labelsHidden()
                            .disabled(!viewModel.canEditCart)
                    }

                    HStack(spacing: 8) {
                        ForEach(discountPresetValues, id: \.self) { preset in
                            discountPresetButton(for: preset)
                        }
                    }

                    TextField("Motivo opcional", text: $viewModel.discountReason)
                        .textInputAutocapitalization(.sentences)
                        .disabled(!viewModel.canEditCart)

                    if viewModel.discountTarget == .selectedItems {
                        Label(selectedItemsDiscountHint, systemImage: selectedItemsDiscountIcon)
                            .font(.caption)
                            .foregroundStyle(viewModel.canApplyDiscount ? .secondary : Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Label(discountAutoApplyStatusText, systemImage: discountAutoApplyStatusIcon)
                            .font(.caption)
                            .foregroundStyle(viewModel.canApplyDiscount ? .secondary : Color.orange)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Text(discountEstimatedValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    if viewModel.canClearDiscounts || !viewModel.discountValue.trimmed.isEmpty || !viewModel.discountReason.trimmed.isEmpty {
                        Button(role: .destructive) {
                            viewModel.clearDiscounts()
                            NexoKeyboard.dismiss()
                        } label: {
                            Text("Quitar descuento")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canEditCart)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .onChange(of: viewModel.discountTarget) { _, _ in
            autoApplyDiscountDraft()
        }
        .onChange(of: viewModel.discountType) { _, _ in
            normalizeDiscountValueForCurrentType()
            autoApplyDiscountDraft()
        }
        .onChange(of: viewModel.discountValue) { _, _ in
            autoApplyDiscountDraft()
        }
        .onChange(of: viewModel.discountReason) { _, _ in
            autoApplyDiscountDraft()
        }
    }
    
    private func isSelectedDiscountPreset(_ preset: String) -> Bool {
        viewModel.discountValue.trimmed == preset
    }

    private func discountPresetButton(for preset: String) -> some View {
        let title = discountPresetTitle(for: preset)
        let isSelected = isSelectedDiscountPreset(preset)

        return Button {
            viewModel.discountValue = preset
            normalizeDiscountValueForCurrentType()
            autoApplyDiscountDraft()
            NexoKeyboard.dismiss()
        } label: {
            DiscountPresetChip(title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canEditCart)
    }

    private var registeredSaleEditBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edición antes de facturar")
                .font(.subheadline.weight(.semibold))

            if viewModel.registeredSaleHasUnsavedChanges {
                Label("Hay cambios sin guardar. Guarda antes de cobrar o facturar.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Color.orange)
            } else {
                Label("Puedes corregir productos mientras la venta no tenga factura electrónica enviada o autorizada.", systemImage: "pencil.and.list.clipboard")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.saveRegisteredSaleChanges() }
            } label: {
                if viewModel.isCreatingSale {
                    ProgressView()
                } else {
                    Label("Guardar cambios de productos", systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSaveRegisteredSaleChanges)
        }
    }

    private var summaryGroup: some View {
        SaleCartGroupedCard(
            title: "Resumen y acción",
            subtitle: summarySubtitle,
            systemImage: "checkmark.seal"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                messagesBlock

                if viewModel.createdSale != nil && hasVisibleMessage {
                    Divider()
                }

                if let sale = viewModel.createdSale {
                    NexoSaleSuccessCard(sale: sale)

                    if !viewModel.cartItems.isEmpty || viewModel.createdSale != nil {
                        Divider()
                    }
                }

                if !viewModel.cartItems.isEmpty {
                    totalBlock
                    Divider()
                }

                actionsBlock
            }
        }
    }

    @ViewBuilder
    private var messagesBlock: some View {
        if let message = viewModel.errorMessage {
            NexoMessageBanner(message, style: .error)
        }

        if let warning = viewModel.finalConsumerInvoiceWarning {
            NexoMessageBanner(warning, style: .warning)
        }

        if let message = viewModel.infoMessage {
            NexoMessageBanner(message, style: viewModel.createdSale == nil ? .info : viewModel.createdSaleMessageStyle)
        }
    }

    private var hasVisibleMessage: Bool {
        viewModel.errorMessage != nil ||
        viewModel.finalConsumerInvoiceWarning != nil ||
        viewModel.infoMessage != nil
    }

    @ViewBuilder
    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Total estimado")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.localCalculation.totals.grandTotal.displayText)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                }

                Spacer()

                if viewModel.isPreviewing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            VStack(spacing: 8) {
                NexoMoneyTotalView(title: "Subtotal", amount: viewModel.localCalculation.totals.subtotalWithoutTaxes)

                if viewModel.localCalculation.hasDiscount {
                    NexoMoneyTotalView(title: "Descuentos", amount: viewModel.localCalculation.totals.discountTotal)
                }

                NexoMoneyTotalView(title: "Impuestos", amount: viewModel.localCalculation.totals.taxTotal)
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.localCalculation.lines) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))

                                    Text("Cantidad: \(item.quantity.cleanQuantityText) · \(item.taxTreatment.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(item.total.displayText)
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                            }

                            if item.discount.amount != "0.00" {
                                LabeledContent("Descuento", value: item.discount.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if item.taxAmount.amount != "0.00" {
                                LabeledContent("IVA \(item.taxRatePercent)%", value: item.taxAmount.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let warning = item.warning {
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        if item.id != viewModel.localCalculation.lines.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Detalle del cálculo")
                    .font(.footnote.weight(.semibold))
            }
        }
    }
    
    private struct DiscountPresetChip: View {
        let title: String
        let isSelected: Bool

        var body: some View {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule(style: .continuous)
                        .fill(backgroundColor)
                }
        }

        private var backgroundColor: Color {
            isSelected
            ? Color.accentColor.opacity(0.12)
            : Color(uiColor: .secondarySystemGroupedBackground)
        }
    }

    @ViewBuilder
    private var actionsBlock: some View {
        if let sale = viewModel.createdSale {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.registeredSaleHasUnsavedChanges {
                    Label("Guarda los cambios de productos antes de cobrar o facturar.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Color.orange)
                }

                if viewModel.canSaveRegisteredSaleChanges {
                    Button {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.saveRegisteredSaleChanges() }
                    } label: {
                        Label("Guardar cambios de productos", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if viewModel.canCollectCreatedSale {
                    Button {
                        preparePaymentNavigation(for: sale)
                    } label: {
                        if isPreparingPaymentNavigation {
                            Label("Preparando cobro…", systemImage: "clock")
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Cobrar ahora", systemImage: "dollarsign.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isPreparingPaymentNavigation)
                } else {
                    Label("Este usuario puede registrar ventas, pero no cobrar.", systemImage: "lock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        requestStartNewOrder()
                    } label: {
                        Label(
                            viewModel.createdSaleNeedsCollection ? "Guardar" : "Nueva venta",
                            systemImage: "plus.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        SaleDetailView(
                            viewModel: viewModel.makeSaleDetailViewModel(for: sale),
                            customersRepository: customersRepository,
                            salesHistoryRepository: salesHistoryRepository ?? PreviewSaleCartSalesHistoryRepository(),
                            cashRepository: cashRepository,
                            paymentsRepository: paymentsRepository,
                            receivablesRepository: receivablesRepository,
                            documentsRepository: documentsRepository
                        )
                    } label: {
                        Label("Detalle", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        } else if !viewModel.cartItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if let status = viewModel.calculationStatusText {
                    Label(status, systemImage: viewModel.isPreviewing ? "arrow.triangle.2.circlepath" : "checkmark.seal")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.createQuickSale() }
                } label: {
                    if viewModel.isPreviewing || viewModel.isCreatingSale {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Registrar venta", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canCreateSale)

                if viewModel.canClearCart {
                    Button(role: .destructive) {
                        viewModel.clearCart()
                        NexoKeyboard.dismiss()
                    } label: {
                        Label("Limpiar carrito", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var pendingSaleDeletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingSaleDeletionCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    pendingSaleDeletionCandidate = nil
                }
            }
        )
    }

    private var pendingSaleDeletionConfirmationMessage: String {
        guard let sale = pendingSaleDeletionCandidate else {
            return "La venta se cancelará y saldrá de pendientes."
        }

        let displayNumber = sale.number?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForSaleCart ?? sale.id
        return "Se cancelará \(displayNumber) y saldrá de ventas pendientes. No se borra historial fiscal ni comprobantes."
    }

    private var selectedCustomerSummary: String {
        if let customer = viewModel.selectedCustomer {
            return customer.displayName
        }

        return "Consumidor final"
    }

    private var operationStateTint: Color {
        switch viewModel.orderState {
        case .editing:
            return .accentColor
        case .previewing, .creating:
            return .orange
        case .created:
            return viewModel.createdSaleNeedsCollection ? .orange : .green
        }
    }

    private var pendingSalesGroup: some View {
        SaleCartPendingSalesSummaryCard(
            subtitle: viewModel.pendingSalesSubtitle,
            badgeTitle: viewModel.pendingSalesBadgeTitle,
            isExpanded: isPendingSalesExpanded,
            isLoading: viewModel.isLoadingPendingSales,
            hasError: viewModel.pendingSalesErrorMessage != nil,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isPendingSalesExpanded.toggle()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let message = viewModel.pendingSalesErrorMessage {
                    NexoMessageBanner(message, style: .warning)
                }

                if viewModel.isLoadingPendingSales && viewModel.visiblePendingSales.isEmpty {
                    ProgressView("Buscando ventas pendientes…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isPendingSalesExpanded {
                    ForEach(Array(viewModel.visiblePendingSales.prefix(5))) { sale in
                        NavigationLink {
                            SaleDetailView(
                                viewModel: viewModel.makeSaleDetailViewModel(for: sale),
                                customersRepository: customersRepository,
                                salesHistoryRepository: salesHistoryRepository ?? PreviewSaleCartSalesHistoryRepository(),
                                cashRepository: cashRepository,
                                paymentsRepository: paymentsRepository,
                                receivablesRepository: receivablesRepository,
                                documentsRepository: documentsRepository
                            )
                        } label: {
                            SaleCartPendingSaleRow(
                                sale: sale,
                                reason: viewModel.pendingSaleReasonText(for: sale),
                                isDeleting: viewModel.isDeletingPendingSale(sale)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isDeletingPendingSale(sale))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if viewModel.canDeletePendingSale(sale) {
                                Button(role: .destructive) {
                                    pendingSaleDeletionCandidate = sale
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Label("Seguimiento operativo: Proformas solo convierte; Sales confirma y cobra.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var saleBuilderTitle: String {
        if viewModel.createdSale == nil || viewModel.canEditRegisteredSaleItems {
            return "Construir venta"
        }

        return "Venta registrada"
    }

    private var saleBuilderSubtitle: String {
        if viewModel.cartItems.isEmpty {
            return "Busca y agrega productos"
        }

        return cartCountText
    }

    private var summarySubtitle: String {
        if let sale = viewModel.createdSale {
            return sale.displayNumber
        }

        if viewModel.cartItems.isEmpty {
            return "Sin productos todavía"
        }

        return viewModel.localCalculation.totals.grandTotal.displayText
    }

    private var cartCountText: String {
        let count = viewModel.cartItems.count
        return count == 1 ? "1 ítem" : "\(count) ítems"
    }
    private func preparePaymentNavigation(for sale: BusinessSale) {
        guard !isPreparingPaymentNavigation else { return }

        isPreparingPaymentNavigation = true
        paymentPreparationMessage = nil

        Task {
            let paymentViewModel = PaymentRegisterViewModel(
                organizationId: viewModel.organizationId,
                branchId: sale.branchId,
                sale: sale,
                effectivePermissions: viewModel.effectivePermissions,
                cashRepository: cashRepository,
                paymentsRepository: paymentsRepository,
                receivablesRepository: receivablesRepository,
                documentsRepository: documentsRepository,
                salesRepository: viewModel.salesRepositoryForPaymentReadiness,
                activityId: sale.activityId ?? viewModel.activityId,
                revisions: viewModel.revisions
            )

            await paymentViewModel.prepareForCashCollectionIfNeeded()

            await MainActor.run {
                self.preparedPaymentViewModel = paymentViewModel
                self.isPreparingPaymentNavigation = false
                self.shouldShowPaymentRegister = true
            }
        }
    }
    
    private var shouldShowLineDiscountSelection: Bool {
        discountEditorBinding.wrappedValue && viewModel.discountTarget == .selectedItems
    }

    private var discountEditorBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.canClearDiscounts ||
                !viewModel.discountValue.trimmed.isEmpty ||
                !viewModel.discountReason.trimmed.isEmpty
            },
            set: { enabled in
                if enabled {
                    seedDefaultDiscountIfNeeded()
                    normalizeDiscountValueForCurrentType()
                    autoApplyDiscountDraft()
                } else {
                    viewModel.clearDiscounts()
                    NexoKeyboard.dismiss()
                }
            }
        )
    }

    private var discountStepperBinding: Binding<Double> {
        Binding(
            get: { normalizedDiscountDouble },
            set: { value in
                if viewModel.discountType == .percentage {
                    viewModel.discountValue = String(Int(value.rounded()))
                } else {
                    viewModel.discountValue = String(format: "%.2f", value)
                }
                autoApplyDiscountDraft()
            }
        )
    }

    private var discountRange: ClosedRange<Double> {
        switch viewModel.discountType {
        case .percentage:
            return 0...100
        default:
            return 0...9_999
        }
    }

    private var discountStep: Double {
        switch viewModel.discountType {
        case .percentage:
            return 1
        default:
            return 0.50
        }
    }

    private var discountDisplayValue: String {
        switch viewModel.discountType {
        case .percentage:
            return "\(Int(normalizedDiscountDouble.rounded()))%"
        default:
            return String(format: "$%.2f", normalizedDiscountDouble)
        }
    }

    private var discountEstimatedValue: String {
        guard viewModel.localCalculation.hasDiscount else { return "$0.00" }
        return viewModel.localCalculation.totals.discountTotal.displayText
    }

    private var discountValueTitle: String {
        switch viewModel.discountType {
        case .percentage:
            return "Porcentaje"
        default:
            return "Valor en dólares"
        }
    }

    private var discountFieldPrompt: String {
        switch viewModel.discountType {
        case .percentage:
            return "0-100"
        default:
            return "0.00"
        }
    }

    private var discountPresetValues: [String] {
        switch viewModel.discountType {
        case .percentage:
            return ["5", "10", "15", "20"]
        default:
            return ["1.00", "2.00", "5.00", "10.00"]
        }
    }

    private var discountActiveDescription: String {
        switch viewModel.discountTarget {
        case .selectedItems:
            return "Se aplicará solo a los productos marcados en el carrito."
        default:
            return "Se aplicará automáticamente a esta venta antes de registrarla."
        }
    }

    private var selectedItemsDiscountHint: String {
        if viewModel.canApplyDiscount {
            return "Marca en el carrito cada producto que recibirá el descuento."
        }

        return "Marca al menos un producto del carrito para aplicar este descuento."
    }

    private var selectedItemsDiscountIcon: String {
        viewModel.canApplyDiscount ? "checklist" : "exclamationmark.triangle"
    }

    private var discountAutoApplyStatusText: String {
        if viewModel.canApplyDiscount {
            return "Listo: el descuento se aplica solo. No necesitas tocar otro botón."
        }

        return "Completa el valor o selecciona productos para que el descuento se aplique."
    }

    private var discountAutoApplyStatusIcon: String {
        viewModel.canApplyDiscount ? "checkmark.circle" : "exclamationmark.triangle"
    }

    private var discountFooterText: String {
        if discountEditorBinding.wrappedValue {
            return "Activar o cambiar el descuento actualiza el total en pantalla. El servidor volverá a validar antes de registrar la venta."
        }

        return "El descuento queda apagado hasta que lo actives."
    }

    private var normalizedDiscountDouble: Double {
        Double(viewModel.discountValue.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func seedDefaultDiscountIfNeeded() {
        if viewModel.discountValue.trimmed.isEmpty {
            viewModel.discountValue = viewModel.discountType == .percentage ? "5" : "1.00"
        }
    }

    private func normalizeDiscountValueForCurrentType() {
        let value = normalizedDiscountDouble

        switch viewModel.discountType {
        case .percentage:
            viewModel.discountValue = String(Int(min(max(value, 0), 100).rounded()))
        default:
            viewModel.discountValue = String(format: "%.2f", max(value, 0))
        }
    }

    private func autoApplyDiscountDraft() {
        guard discountEditorBinding.wrappedValue else { return }
        guard viewModel.canEditCart else { return }
        guard viewModel.canApplyDiscount else {
            viewModel.recalculateLocalTotalsIfNeeded()
            return
        }

        viewModel.applyDiscountDraft()
        viewModel.recalculateLocalTotalsIfNeeded()
    }

    private func discountPresetTitle(for preset: String) -> String {
        switch viewModel.discountType {
        case .percentage:
            return "\(preset)%"
        default:
            let value = Double(preset.replacingOccurrences(of: ",", with: ".")) ?? 0
            return String(format: "$%.0f", value)
        }
    }

    private func discountPresetBackground(for preset: String) -> Color {
        let isSelected = viewModel.discountValue.trimmed == preset
        return isSelected ? Color.accentColor.opacity(0.16) : Color(uiColor: .tertiarySystemGroupedBackground)
    }

    private func quantityBinding(for item: SaleCartItem) -> Binding<String> {
        Binding(
            get: { viewModel.quantity(for: item.id) },
            set: { viewModel.updateQuantity(cartItemId: item.id, quantity: $0) }
        )
    }

    private func taxTreatmentBinding(for item: SaleCartItem) -> Binding<SaleLineTaxTreatmentOption> {
        Binding(
            get: { viewModel.taxTreatment(for: item.id) },
            set: { viewModel.updateTaxTreatment(cartItemId: item.id, taxTreatment: $0) }
        )
    }

    private func lineDiscountBinding(for item: SaleCartItem) -> Binding<String> {
        Binding(
            get: { viewModel.lineDiscount(for: item.id) },
            set: { viewModel.updateLineDiscount(cartItemId: item.id, discount: $0) }
        )
    }

    private func lineNoteBinding(for item: SaleCartItem) -> Binding<String> {
        Binding(
            get: { viewModel.lineNote(for: item.id) },
            set: { viewModel.updateLineNote(cartItemId: item.id, note: $0) }
        )
    }

    private var orderStateDescription: String {
        switch viewModel.orderState {
        case .editing:
            return "Agrega productos, revisa cantidades, tratamiento tributario y registra una sola venta por carrito."
        case .previewing:
            return "Estamos calculando subtotal, impuestos y total con el backend."
        case .creating:
            return "Registrando venta. No cierres esta pantalla."
        case .created:
            return viewModel.createdSaleNeedsCollection
                ? "La venta quedó registrada, pero queda sin cobrar."
                : "Esta venta ya quedó registrada y el carrito está bloqueado."
        }
    }

    private var orderStateTitle: String {
        if viewModel.createdSaleNeedsCollection {
            return "Venta sin cobrar"
        }

        if viewModel.createdSale != nil {
            return "Venta registrada"
        }

        return "Venta en curso"
    }

    private var navigationTitle: String {
        if viewModel.createdSaleNeedsCollection {
            return "Venta sin cobrar"
        }

        return viewModel.createdSale == nil ? "Nueva venta" : "Venta registrada"
    }

    private var orderStateIcon: String {
        switch viewModel.orderState {
        case .editing:
            return "pencil"
        case .previewing:
            return "clock"
        case .creating:
            return "arrow.triangle.2.circlepath"
        case .created:
            return viewModel.createdSaleNeedsCollection ? "exclamationmark.triangle" : "checkmark"
        }
    }

    private var orderStateStyle: NexoMessageStyle {
        switch viewModel.orderState {
        case .editing:
            return .info
        case .previewing, .creating:
            return .warning
        case .created:
            return viewModel.createdSaleMessageStyle
        }
    }
    
    private func requestStartNewOrder() {
        if viewModel.createdSaleNeedsCollection {
            showStartNewOrderConfirmation = true
        } else {
            viewModel.startNewOrder()
        }
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

private struct SaleCartPendingSalesSummaryCard<Content: View>: View {
    let subtitle: String
    let badgeTitle: String
    let isExpanded: Bool
    let isLoading: Bool
    let hasError: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    private var shouldShowContent: Bool {
        isExpanded || hasError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "tray.full")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ventas pendientes")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        Text(subtitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(badgeTitle)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.accentColor.opacity(0.10), in: Capsule())
                        }

                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 18, height: 34)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Ocultar ventas pendientes" : "Mostrar ventas pendientes")

            if shouldShowContent {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    content
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 5)
    }
}

private struct SaleCartPendingSaleRow: View {
    let sale: BusinessSale
    let reason: String
    let isDeleting: Bool

    private var customerName: String {
        sale.customer?.displayName ?? sale.customerName ?? "Consumidor final"
    }

    private var saleTitle: String {
        sale.number?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForSaleCart ?? sale.id
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(saleTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(customerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(sale.totals.grandTotal.displayText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    NexoStatusBadge(
                        SaleStatusPresentation.title(for: sale.status),
                        systemImage: SaleStatusPresentation.systemImage(for: sale.status),
                        style: SaleStatusPresentation.requiresConfirmationBeforeCollection(status: sale.status) ? .warning : .info
                    )

                    NexoStatusBadge(
                        PaymentStatusPresentation.shortName(sale.paymentStatus),
                        systemImage: PaymentStatusPresentation.systemImage(sale.paymentStatus),
                        style: PaymentStatusPresentation.isCollected(sale.paymentStatus) ? .success : .warning
                    )
                }

                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isDeleting {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Eliminando venta pendiente")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isDeleting ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension String {
    var nilIfEmptyForSaleCart: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private final class PreviewSaleCartSalesHistoryRepository: SalesHistoryRepository, @unchecked Sendable {
    func searchSales(
        organizationId: String,
        request: SalesHistorySearchRequest
    ) async throws -> BusinessSalesHistoryResponse {
        BusinessSalesHistoryResponse(sales: [])
    }
}

private struct SaleCartHeroIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(0.16), lineWidth: 1)
            }
    }
}

private struct SaleCartHeroPill: View {
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
            .background(tint.opacity(0.11), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            }
    }
}

private struct SaleCartGroupedCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isHero: Bool = false
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        isHero: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isHero = isHero
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font((isHero ? Font.title3 : Font.body).weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: isHero ? 36 : 30, height: isHero ? 36 : 30)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: isHero ? 13 : 11, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(isHero ? .headline.weight(.bold) : .subheadline.weight(.bold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(isHero ? 18 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: isHero ? 24 : 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: isHero ? 24 : 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(isHero ? 0.055 : 0.025), radius: isHero ? 12 : 7, x: 0, y: isHero ? 7 : 3)
    }
}

private struct DiscountMiniMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SaleCartCashCard<DashboardDestination: View>: View {
    @State private var viewModel: CashDashboardViewModel
    private let onSessionChanged: (CashSession?) -> Void
    private let dashboardDestination: () -> DashboardDestination

    init(
        organizationId: String,
        branchId: String,
        permissions: Set<String>,
        cashRepository: CashRepository,
        onSessionChanged: @escaping (CashSession?) -> Void,
        @ViewBuilder dashboardDestination: @escaping () -> DashboardDestination
    ) {
        _viewModel = State(
            initialValue: CashDashboardViewModel(
                organizationId: organizationId,
                branchId: branchId,
                permissions: permissions,
                cashRepository: cashRepository
            )
        )
        self.onSessionChanged = onSessionChanged
        self.dashboardDestination = dashboardDestination
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isLoading {
                ProgressView("Consultando caja…")
            } else if let session = viewModel.currentSession, session.isOpen {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Caja abierta", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)

                        if let expected = session.expectedAmount {
                            Text("Efectivo esperado: \(expected.displayText)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    NavigationLink("Ver caja") {
                        dashboardDestination()
                    }
                    .font(.footnote.weight(.semibold))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Caja cerrada", systemImage: "lock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)

                    Text("Puedes registrar ventas pendientes, pero para cobrar en efectivo necesitas abrir caja.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            Task {
                                viewModel.openingAmount = "0.00"
                                await viewModel.openCash()
                                onSessionChanged(viewModel.currentSession)
                            }
                        } label: {
                            if viewModel.isMutating {
                                ProgressView()
                            } else {
                                Label("Abrir caja", systemImage: "lock.open")
                            }
                        }
                        .disabled(!viewModel.canOpen || viewModel.isMutating)

                        NavigationLink("Ver caja") {
                            dashboardDestination()
                        }
                    }
                }
            }

            if let message = viewModel.errorMessage {
                NexoMessageBanner(message, style: .error)
            }
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.load()
                onSessionChanged(viewModel.currentSession)
            }
        }
    }
}

private struct CatalogSuggestionRow: View {
    let template: PlatformCatalogTemplateSuggestion
    let isAdopting: Bool
    let canAdopt: Bool
    let adoptAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.displayName)
                    .font(.subheadline.weight(.semibold))

                if let code = template.primaryCode, !code.isEmpty {
                    Text("Código sugerido: \(code)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let price = template.suggestedPrice {
                        Text(price.displayText)
                            .font(.caption.weight(.semibold))
                    } else {
                        Text("Sin precio sugerido")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    if let tax = template.suggestedTaxProfileCode {
                        Text(tax)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: adoptAction) {
                if isAdopting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Copiar", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canAdopt || isAdopting)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch template.type.lowercased() {
        case "service":
            return "person.text.rectangle"
        case "activity":
            return "calendar.badge.clock"
        case "package", "combo":
            return "shippingbox"
        default:
            return "sparkles"
        }
    }
}

private struct CatalogResultRow: View {
    let item: BusinessCatalogItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let sku = item.sku, !sku.isEmpty {
                    Text("SKU: \(sku)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let price = item.price {
                    Text(price.displayText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.type {
        case "service":
            return "person.text.rectangle"
        case "activity":
            return "calendar.badge.clock"
        case "package", "combo":
            return "shippingbox"
        default:
            return "tag"
        }
    }
}

private struct SaleCartRow: View {
    let item: SaleCartItem
    @Binding var quantity: String
    @Binding var taxTreatment: SaleLineTaxTreatmentOption
    let isSelectedForDiscount: Bool
    let showsDiscountSelection: Bool
    let toggleDiscountSelection: () -> Void
    @Binding var lineNote: String
    let isEditable: Bool
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.catalogItem.name)
                        .font(.subheadline.weight(.semibold))

                    if let price = item.catalogItem.price {
                        Text(price.displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                TextField("Cant.", text: $quantity)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditable)

                if isEditable {
                    Button(role: .destructive, action: removeAction) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("Tratamiento", systemImage: "percent")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isEditable {
                    Picker("Tratamiento tributario", selection: $taxTreatment) {
                        ForEach(SaleLineTaxTreatmentOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    Text(taxTreatment.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(taxTreatment.detailText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if taxTreatment == .ivaTourism8 {
                Label("Verifica que el negocio y la fecha estén habilitados antes de emitir comprobante.", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if isEditable && showsDiscountSelection {
                Button {
                    toggleDiscountSelection()
                } label: {
                    Label(
                        isSelectedForDiscount ? "Recibe descuento" : "Seleccionar para descuento",
                        systemImage: isSelectedForDiscount ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            TextField("Nota de línea opcional", text: $lineNote)
                .textInputAutocapitalization(.sentences)
                .disabled(!isEditable)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SaleCartView(
            viewModel: SaleCartViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                activityId: PreviewData.businessContext.activities[0].id,
                revisions: PreviewData.businessContext.revisions,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                verticalContext: PreviewData.businessContext.verticals,
                catalogRepository: PreviewCatalogRepository(),
                salesRepository: PreviewSalesRepository(),
                salesHistoryRepository: PreviewSaleCartSalesHistoryRepository(),
                contextRepository: PreviewBusinessContextRepository()
            ),
            customersRepository: PreviewCustomersRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            salesHistoryRepository: PreviewSaleCartSalesHistoryRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}
