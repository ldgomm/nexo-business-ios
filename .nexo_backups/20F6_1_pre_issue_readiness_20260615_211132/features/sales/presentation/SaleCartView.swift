import SwiftUI

struct SaleCartView: View {
    @Bindable private var viewModel: SaleCartViewModel
    private let customersRepository: CustomersRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository
    @State private var showStartNewOrderConfirmation = false

    init(
        viewModel: SaleCartViewModel,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        Form {
            orderStateSection
            cashSection
            customerSection

            if viewModel.createdSale == nil {
                searchSection
                resultsSection
                cartSection
                discountSection
                previewSection
            } else {
                lockedCartSection
            }

            saleSection
            messagesSection
            actionsSection
        }
        .nexoKeyboardDismissable()
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.canStartNewOrder {
                    Button("Nueva") {
                        requestStartNewOrder()
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
        .onAppear {
            viewModel.recalculateLocalTotalsIfNeeded()
        }
        .onDisappear {
            viewModel.cancelScheduledPreview()
        }
    }

    private var orderStateSection: some View {
        Section {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(orderStateTitle)
                        .font(.headline)

                    Text(orderStateDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NexoStatusBadge(
                    viewModel.orderState.displayName,
                    systemImage: orderStateIcon,
                    style: orderStateStyle
                )
            }
        }
    }

    private var cashSection: some View {
        Section("Caja") {
            SaleCartCashCard(
                organizationId: viewModel.organizationId,
                branchId: viewModel.branchId,
                permissions: viewModel.effectivePermissions,
                cashRepository: cashRepository,
                onSessionChanged: { session in
                    viewModel.cashSessionId = session?.isOpen == true ? session?.id : nil
                },
                dashboardDestination: {
                    CashDashboardView(
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
    }

    private var customerSection: some View {
        Section("Cliente") {
            if let customer = viewModel.selectedCustomer {
                CustomerRowView(customer: customer)

                Button(role: .destructive) {
                    viewModel.clearCustomer()
                } label: {
                    Label("Quitar cliente", systemImage: "xmark.circle")
                }
                .disabled(!viewModel.canEditCart)
            } else {
                Label("Consumidor final", systemImage: "person.crop.circle")
                    .foregroundStyle(.secondary)
            }

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
                Label("Seleccionar cliente", systemImage: "person.text.rectangle")
            }
            .disabled(!viewModel.canEditCart)
        }
    }

    private var searchSection: some View {
        Section("Agregar producto") {
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

                if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        viewModel.clearSearch()
                        NexoKeyboard.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Limpiar búsqueda")
                }
            }

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.searchCatalog() }
            } label: {
                if viewModel.isSearching {
                    ProgressView()
                } else {
                    Label("Buscar producto", systemImage: "magnifyingglass")
                }
            }
            .disabled(!viewModel.canSearchCatalog)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !viewModel.searchResults.isEmpty {
            Section("Resultados") {
                ForEach(viewModel.searchResults) { item in
                    Button {
                        viewModel.addToCart(item)
                        NexoKeyboard.dismiss()
                    } label: {
                        CatalogResultRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canEditCart)
                }
            }
        }
    }

    private var cartSection: some View {
        Section("Carrito") {
            if viewModel.cartItems.isEmpty {
                ContentUnavailableView(
                    "Carrito vacío",
                    systemImage: "cart",
                    description: Text("Busca productos o servicios y agrégalos a la venta.")
                )
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
                }
            }
        }
    }

    private var lockedCartSection: some View {
        Section("Carrito registrado") {
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
            }
        }
    }

    @ViewBuilder
    private var discountSection: some View {
        if !viewModel.cartItems.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    discountHeaderCard

                    if discountEditorBinding.wrappedValue {
                        discountConfigurationCard
                        discountValueCard
                        discountReasonCard
                        discountFooterActions
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("Descuento")
            } footer: {
                Text(discountFooterText)
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
    }

    private var discountHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(width: 44, height: 44)

                    Image(systemName: discountEditorBinding.wrappedValue ? "percent" : "tag")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(discountEditorBinding.wrappedValue ? .secondary : .primary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(discountEditorBinding.wrappedValue ? "Descuento activo" : "Sin descuento")
                            .font(.headline)

                        if discountEditorBinding.wrappedValue {
                            Text("AUTO")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.tint.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(discountEditorBinding.wrappedValue ? discountActiveDescription : "Actívalo cuando esta venta tenga cortesía, promoción o ajuste autorizado.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: discountEditorBinding)
                    .labelsHidden()
                    .disabled(!viewModel.canEditCart)
                    .accessibilityLabel(discountEditorBinding.wrappedValue ? "Desactivar descuento" : "Activar descuento")
            }

            if discountEditorBinding.wrappedValue {
                HStack(spacing: 8) {
                    DiscountMiniMetric(title: "Valor", value: discountDisplayValue, systemImage: "number")
                    DiscountMiniMetric(title: "Ahorro", value: discountEstimatedValue, systemImage: "arrow.down.forward")
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var discountConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Aplicar a")
                    .font(.subheadline.weight(.semibold))

                Picker("Aplicar a", selection: $viewModel.discountTarget) {
                    ForEach(SaleDiscountTarget.allCases) { target in
                        Text(target.displayName).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.canEditCart)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Tipo de descuento")
                    .font(.subheadline.weight(.semibold))

                Picker("Tipo", selection: $viewModel.discountType) {
                    ForEach(SaleDiscountInputType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.canEditCart)
            }

            if viewModel.discountTarget == .selectedItems {
                Label(selectedItemsDiscountHint, systemImage: selectedItemsDiscountIcon)
                    .font(.caption)
                    .foregroundStyle(viewModel.canApplyDiscount ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var discountValueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(discountValueTitle)
                        .font(.subheadline.weight(.semibold))

                    Text("Se recalcula en vivo en el total.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(discountDisplayValue)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                TextField(discountFieldPrompt, text: $viewModel.discountValue)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(!viewModel.canEditCart)
                    .accessibilityLabel("Valor del descuento")

                Stepper("", value: discountStepperBinding, in: discountRange, step: discountStep)
                    .labelsHidden()
                    .disabled(!viewModel.canEditCart)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(discountPresetValues, id: \.self) { preset in
                        Button {
                            viewModel.discountValue = preset
                            normalizeDiscountValueForCurrentType()
                            autoApplyDiscountDraft()
                            NexoKeyboard.dismiss()
                        } label: {
                            Text(discountPresetTitle(for: preset))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(discountPresetBackground(for: preset), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canEditCart)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var discountReasonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Motivo", systemImage: "text.badge.checkmark")
                    .font(.subheadline.weight(.semibold))

                Text("opcional")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
            }

            TextField("Ej. cortesía, promoción, cliente frecuente", text: $viewModel.discountReason)
                .textInputAutocapitalization(.sentences)
                .disabled(!viewModel.canEditCart)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var discountFooterActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(discountAutoApplyStatusText, systemImage: discountAutoApplyStatusIcon)
                .font(.caption)
                .foregroundStyle(viewModel.canApplyDiscount ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.canClearDiscounts || !viewModel.discountValue.trimmed.isEmpty || !viewModel.discountReason.trimmed.isEmpty {
                Button(role: .destructive) {
                    viewModel.clearDiscounts()
                    NexoKeyboard.dismiss()
                } label: {
                    Label("Quitar descuento", systemImage: "xmark.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canEditCart)
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if !viewModel.cartItems.isEmpty {
            Section {
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
                    .padding(.vertical, 4)
                }

                NexoMoneyTotalView(title: "Subtotal", amount: viewModel.localCalculation.totals.subtotalWithoutTaxes)

                if viewModel.localCalculation.hasDiscount {
                    NexoMoneyTotalView(title: "Descuentos", amount: viewModel.localCalculation.totals.discountTotal)
                }

                NexoMoneyTotalView(title: "Impuestos", amount: viewModel.localCalculation.totals.taxTotal)
                NexoMoneyTotalView(title: "Total estimado", amount: viewModel.localCalculation.totals.grandTotal, isProminent: true)

                if viewModel.isPreviewing {
                    Label("Validando con servidor…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Calculado en este dispositivo. El servidor validará antes de registrar.", systemImage: "iphone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Total")
            } footer: {
                if let warning = viewModel.localCalculation.primaryWarning {
                    Text(warning)
                } else {
                    Text("El total se actualiza en pantalla al cambiar productos, cantidades, impuestos o descuentos.")
                }
            }
        }
    }

    @ViewBuilder
    private var saleSection: some View {
        if let sale = viewModel.createdSale {
            Section {
                NexoSaleSuccessCard(sale: sale)
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                NexoMessageBanner(message, style: .error)
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                NexoMessageBanner(message, style: viewModel.createdSale == nil ? .info : viewModel.createdSaleMessageStyle)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if let sale = viewModel.createdSale {
            Section("Siguiente acción") {
                if viewModel.canCollectCreatedSale {
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
                                activityId: sale.activityId ?? viewModel.activityId,
                                revisions: viewModel.revisions
                            ),
                            customersRepository: customersRepository,
                            onSaleUpdated: { updatedSale in
                                viewModel.updateCreatedSale(updatedSale)
                            }
                        )
                    } label: {
                        Label("Cobrar ahora", systemImage: "dollarsign.circle.fill")
                    }
                } else {
                    Label("Este usuario puede registrar ventas, pero no cobrar.", systemImage: "lock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    requestStartNewOrder()
                } label: {
                    Label(
                        viewModel.createdSaleNeedsCollection ? "Guardar pendiente y crear otra" : "Nueva venta",
                        systemImage: "plus.circle"
                    )
                }

                NavigationLink {
                    SaleDetailView(
                        viewModel: viewModel.makeSaleDetailViewModel(for: sale),
                        customersRepository: customersRepository,
                        cashRepository: cashRepository,
                        paymentsRepository: paymentsRepository,
                        receivablesRepository: receivablesRepository,
                        documentsRepository: documentsRepository
                    )
                } label: {
                    Label("Ver detalle", systemImage: "doc.text.magnifyingglass")
                }
            }
        } else if !viewModel.cartItems.isEmpty {
            Section("Acciones") {
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
                    } else {
                        Label("Registrar venta", systemImage: "checkmark.seal.fill")
                    }
                }
                .disabled(!viewModel.canCreateSale)

                if viewModel.canClearCart {
                    Button(role: .destructive) {
                        viewModel.clearCart()
                        NexoKeyboard.dismiss()
                    } label: {
                        Label("Limpiar carrito", systemImage: "trash")
                    }
                }
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
                ? "La venta quedó registrada, pero todavía falta cobrarla."
                : "Esta venta ya quedó registrada y el carrito está bloqueado."
        }
    }

    private var orderStateTitle: String {
        if viewModel.createdSaleNeedsCollection {
            return "Venta pendiente de cobro"
        }

        if viewModel.createdSale != nil {
            return "Venta registrada"
        }

        return "Venta en curso"
    }

    private var navigationTitle: String {
        if viewModel.createdSaleNeedsCollection {
            return "Pendiente de cobro"
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
                catalogRepository: PreviewCatalogRepository(),
                salesRepository: PreviewSalesRepository(),
                contextRepository: PreviewBusinessContextRepository()
            ),
            customersRepository: PreviewCustomersRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}
