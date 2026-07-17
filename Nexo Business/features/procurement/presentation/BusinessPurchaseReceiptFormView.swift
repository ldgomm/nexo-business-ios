//
//  BusinessPurchaseReceiptFormView.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import SwiftUI

struct BusinessPurchaseReceiptFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: BusinessPurchaseReceiptFormViewModel
    private let onSaved: (BusinessProcurementPurchaseReceiptResponse) -> Void

    init(
        viewModel: BusinessPurchaseReceiptFormViewModel,
        onSaved: @escaping (BusinessProcurementPurchaseReceiptResponse) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            accessSection
            identitySection
            receivedAtSection
            operationalEffectSection
            linesSection
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
                        if let receipt = await viewModel.save() {
                            onSaved(receipt)
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
            LabeledContent("Proveedor", value: viewModel.supplierName)
            LabeledContent("Orden de compra", value: viewModel.purchaseOrderNumber)
            Label(viewModel.warehouseDisplayText, systemImage: "building.2.fill")
                .foregroundStyle(.secondary)
        } header: {
            Text("Contexto de recepción")
        } footer: {
            Text("Proveedor, orden y bodega permanecen bloqueados para conservar el contexto operativo, sin exponer identificadores internos.")
        }
    }

    private var receivedAtSection: some View {
        Section {
            DatePicker(
                "Recepción física",
                selection: $viewModel.receivedAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .disabled(viewModel.isSaving)

            LabeledContent(
                "Fecha seleccionada",
                value: viewModel.receivedAt.formatted(date: .abbreviated, time: .shortened)
            )
            .foregroundStyle(.secondary)
        } header: {
            Text("Fecha y hora")
        } footer: {
            Text("La fecha se presenta en tu zona horaria y se envía al backend como un instante preciso.")
        }
    }

    private var operationalEffectSection: some View {
        Section("Antes de guardar") {
            Label {
                Text("Un borrador no cambia inventario. Solo al confirmar, el backend registra las cantidades aceptadas de artículos de stock exactamente una vez; lo rechazado no ingresa.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "shippingbox")
            }

            Label {
                Text("La recepción física no crea una cuenta por pagar. El documento del proveedor se registra por separado.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "doc.text")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var linesSection: some View {
        Section {
            if viewModel.lines.isEmpty {
                ContentUnavailableView(
                    "Recepción sin líneas",
                    systemImage: "shippingbox",
                    description: Text("La orden no contiene líneas disponibles para recibir.")
                )
            } else {
                ForEach($viewModel.lines) { $line in
                    VStack(alignment: .leading, spacing: 14) {
                        lineIdentity(line)

                        HStack(alignment: .firstTextBaseline, spacing: 20) {
                            quantityReference(
                                title: "Ordenado",
                                value: line.orderedQuantityText
                            )
                            quantityReference(
                                title: "Recibido acumulado",
                                value: line.cumulativeReceivedQuantityText
                            )
                        }

                        Divider()

                        TextField("Cantidad de este evento", text: $line.receivedQuantity)
                            .keyboardType(.decimalPad)

                        TextField("Cantidad aceptada", text: $line.acceptedQuantity)
                            .keyboardType(.decimalPad)

                        TextField("Cantidad rechazada", text: $line.rejectedQuantity)
                            .keyboardType(.decimalPad)

                        LabeledContent("Unidad", value: line.unitCode)

                        if let cost = line.unitCostDisplayText {
                            LabeledContent("Costo unitario", value: cost)
                        } else {
                            Label("Costo no disponible o protegido por permisos", systemImage: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        trackedUnitsSection(line: $line)

                        TextField("Notas de línea (opcional)", text: $line.notes, axis: .vertical)
                            .lineLimit(1...4)
                    }
                    .padding(.vertical, 8)
                    .disabled(viewModel.isSaving)
                }
            }
        } header: {
            Text("Cantidades recibidas, aceptadas y rechazadas")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("La cantidad aceptada más la rechazada debe coincidir con la cantidad de este evento.")
                if viewModel.isEditing {
                    Text("La edición conserva todas las líneas del borrador existente.")
                } else {
                    Text("Para una recepción parcial, deja las tres cantidades en cero en las líneas que no llegaron; no se incluirán en el nuevo borrador.")
                }
                Text("Ordenado y recibido acumulado provienen del backend. El pendiente permanece autoritativo en la orden y no se recalcula en el dispositivo.")
            }
        }
    }

    @ViewBuilder
    private func lineIdentity(_ line: BusinessPurchaseReceiptLineDraft) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(line.displayName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            if let sku = line.sku?.trimmingCharacters(in: .whitespacesAndNewlines),
               !sku.isEmpty {
                Text(sku)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func quantityReference(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trackedUnitsSection(
        line: Binding<BusinessPurchaseReceiptLineDraft>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Label("Series e identificadores", systemImage: "barcode.viewfinder")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    viewModel.addTrackedUnit(to: line.wrappedValue.id)
                } label: {
                    Label("Agregar", systemImage: "plus.circle")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isSaving)
            }

            if line.wrappedValue.trackedUnits.isEmpty {
                Text("Agrega series, IMEI, MAC u otros identificadores solo cuando el artículo recibido los requiera.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(line.trackedUnits) { $trackedUnit in
                    VStack(alignment: .leading, spacing: 9) {
                        Picker("Tipo", selection: $trackedUnit.trackingType) {
                            ForEach(BusinessPurchaseReceiptTrackingType.allCases) { type in
                                Text(type.title).tag(type.rawValue)
                            }
                        }

                        TextField("Serie o identificador", text: $trackedUnit.trackingValue)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        TextField("Notas del identificador (opcional)", text: $trackedUnit.notes, axis: .vertical)
                            .lineLimit(1...3)

                        Button(role: .destructive) {
                            viewModel.removeTrackedUnit(
                                lineId: line.wrappedValue.id,
                                trackedUnitId: trackedUnit.id
                            )
                        } label: {
                            Label("Eliminar identificador", systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isSaving)
                    }
                    .padding(12)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notas de la recepción") {
            TextField("Notas (opcional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...6)
                .disabled(viewModel.isSaving)
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if viewModel.accessValidationMessage == nil,
           let message = viewModel.inputValidationMessage {
            Section {
                Label {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                }
            }
        }

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
