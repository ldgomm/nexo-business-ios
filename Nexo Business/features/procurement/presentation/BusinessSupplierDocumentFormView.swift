//
//  BusinessSupplierDocumentFormView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessSupplierDocumentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: BusinessSupplierDocumentFormViewModel
    private let onSaved: (BusinessProcurementSupplierDocumentResponse) -> Void

    init(
        viewModel: BusinessSupplierDocumentFormViewModel,
        onSaved: @escaping (BusinessProcurementSupplierDocumentResponse) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            accessSection
            identitySection
            datesSection
            linesSection
            sourceEvidenceSection
            notesSection
            messagesSection
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(viewModel.isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if let document = await viewModel.save() {
                            onSaved(document)
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(viewModel.saveButtonTitle)
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .task {
            await viewModel.loadReferenceDataIfNeeded()
        }
    }

    @ViewBuilder
    private var accessSection: some View {
        if let message = viewModel.accessValidationMessage {
            Section {
                Label {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.trianglebadge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var identitySection: some View {
        Section {
            if viewModel.isLoadingReferenceData {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando proveedores activos…")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Proveedor", selection: $viewModel.selectedSupplierId) {
                if viewModel.selectedSupplierId.isEmpty {
                    Text("Selecciona un proveedor").tag("")
                }
                ForEach(viewModel.supplierOptions) { supplier in
                    Text(supplier.name).tag(supplier.id)
                }
            }
            .disabled(viewModel.isLoadingReferenceData || viewModel.isSaving)

            Picker("Tipo", selection: $viewModel.documentType) {
                ForEach(BusinessSupplierDocumentType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }

            TextField("Número del documento", text: $viewModel.documentNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            TextField("Moneda (por ejemplo, USD)", text: $viewModel.currency)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            if let message = viewModel.referenceErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Reintentar proveedores") {
                    Task { await viewModel.retryReferenceData() }
                }
                .disabled(viewModel.isLoadingReferenceData || viewModel.isSaving)
            }
        } header: {
            Text("Documento")
        } footer: {
            Text("Este registro representa el cargo del proveedor. Crear un borrador no cambia inventario ni crea una cuenta por pagar.")
        }
    }

    private var datesSection: some View {
        Section {
            TextField("Fecha del documento (AAAA-MM-DD)", text: $viewModel.documentDate)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Vencimiento (AAAA-MM-DD, opcional)", text: $viewModel.dueDate)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Fechas")
        } footer: {
            Text("La fecha del documento y el vencimiento se conservan por separado; no se convierten a una zona horaria.")
        }
    }

    private var linesSection: some View {
        Section {
            if viewModel.lines.isEmpty {
                ContentUnavailableView(
                    "Documento sin líneas",
                    systemImage: "doc.badge.plus",
                    description: Text("Agrega el primer producto, servicio o gasto.")
                )
            } else {
                ForEach($viewModel.lines) { $line in
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Descripción", text: $line.description, axis: .vertical)
                            .lineLimit(1...3)

                        Picker("Clase", selection: $line.kind) {
                            Text("Gasto").tag("EXPENSE")
                            Text("Servicio").tag("SERVICE")
                            Text("Artículo sin inventario").tag("NON_STOCK_ITEM")
                            if line.kind == "STOCK_ITEM" {
                                Text("Artículo con inventario").tag("STOCK_ITEM")
                            }
                        }

                        HStack(spacing: 12) {
                            TextField("Cantidad", text: $line.quantity)
                                .keyboardType(.decimalPad)
                            TextField("Unidad", text: $line.unitCode)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Toggle("Permitir cantidad decimal", isOn: $line.allowsDecimal)

                        TextField("Costo unitario", text: $line.unitCost)
                            .keyboardType(.decimalPad)

                        TextField("Descuento de línea", text: $line.discountAmount)
                            .keyboardType(.decimalPad)

                        Picker("Impuestos", selection: $line.priceTaxMode) {
                            ForEach(BusinessSupplierDocumentPriceTaxMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        TextField(
                            "Categoría operativa (opcional)",
                            text: $line.expenseCategoryCode
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                        TextField("Notas de línea (opcional)", text: $line.notes, axis: .vertical)
                            .lineLimit(1...3)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: viewModel.removeLines)
            }

            Menu {
                Button("Agregar gasto") { viewModel.addLine(kind: "EXPENSE") }
                Button("Agregar servicio") { viewModel.addLine(kind: "SERVICE") }
                Button("Agregar artículo sin inventario") {
                    viewModel.addLine(kind: "NON_STOCK_ITEM")
                }
            } label: {
                Label("Agregar línea", systemImage: "plus.circle")
            }
            .disabled(viewModel.isSaving)
        } header: {
            Text("Líneas")
        } footer: {
            Text("El backend valida impuestos y calcula los totales finales. Confirmar el documento no sustituye una recepción física ni modifica inventario.")
        }
    }

    private var sourceEvidenceSection: some View {
        Section("Evidencia de origen") {
            DisclosureGroup("Identificación fiscal opcional") {
                TextField("Clave de acceso", text: $viewModel.accessKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Número de autorización", text: $viewModel.authorizationNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }

            DisclosureGroup("Totales informados por el origen") {
                TextField("Total informado", text: $viewModel.sourceTotal)
                    .keyboardType(.decimalPad)
                TextField("Impuesto informado", text: $viewModel.sourceTaxTotal)
                    .keyboardType(.decimalPad)
                Text("Estos valores son evidencia para conciliación; no reemplazan los totales calculados por el servidor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup("Pago inmediato informado") {
                TextField("Importe", text: $viewModel.sourcePaymentAmount)
                    .keyboardType(.decimalPad)
                TextField("Método", text: $viewModel.sourcePaymentMethod)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Fecha (AAAA-MM-DD)", text: $viewModel.sourcePaymentDate)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Referencia (opcional)", text: $viewModel.sourcePaymentReference)
            }
        }
    }

    private var notesSection: some View {
        Section("Notas internas") {
            TextField("Notas (opcional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
