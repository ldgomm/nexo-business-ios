//
//  BusinessSupplierFormViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 15/7/26.
//

import Foundation
import Observation

enum BusinessSupplierIdentificationKind: String, CaseIterable, Identifiable, Sendable {
    case none = ""
    case ruc = "RUC"
    case cedula = "CEDULA"
    case passport = "PASSPORT"
    case foreignTaxId = "FOREIGN_TAX_ID"
    case other = "OTHER"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Sin identificación"
        case .ruc: return "RUC"
        case .cedula: return "Cédula"
        case .passport: return "Pasaporte"
        case .foreignTaxId: return "Identificación tributaria extranjera"
        case .other: return "Otra"
        }
    }
}

enum BusinessSupplierPaymentTermsKind: String, CaseIterable, Identifiable, Sendable {
    case immediate = "IMMEDIATE"
    case netDays = "NET_DAYS"
    case custom = "CUSTOM"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediate: return "Pago inmediato"
        case .netDays: return "Crédito por días"
        case .custom: return "Condición personalizada"
        }
    }
}

struct BusinessSupplierContactDraft: Equatable, Identifiable, Sendable {
    let id: UUID
    let serverId: String?
    var name: String
    var role: String
    var email: String
    var phone: String
    var isPrimary: Bool
    var notes: String

    init(
        id: UUID = UUID(),
        serverId: String? = nil,
        name: String = "",
        role: String = "",
        email: String = "",
        phone: String = "",
        isPrimary: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.serverId = serverId
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
        self.isPrimary = isPrimary
        self.notes = notes
    }

    init(response: BusinessProcurementSupplierContactResponse) {
        self.init(
            serverId: response.id,
            name: response.name,
            role: response.role ?? "",
            email: response.email ?? "",
            phone: response.phone ?? "",
            isPrimary: response.isPrimary,
            notes: response.notes ?? ""
        )
    }
}

@MainActor
@Observable
final class BusinessSupplierFormViewModel {
    var legalName: String
    var tradeName: String
    var identificationKind: BusinessSupplierIdentificationKind
    var identificationNumber: String
    var email: String
    var phone: String
    var address: String
    var categoriesText: String
    var contacts: [BusinessSupplierContactDraft]
    var paymentTermsKind: BusinessSupplierPaymentTermsKind
    var netDaysText: String
    var paymentTermsLabel: String
    var paymentTermsNotes: String
    var notes: String

    private(set) var isSaving = false
    private(set) var savedSupplier: BusinessProcurementSupplierResponse?
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    private let supplierId: String?
    private let expectedVersion: Int64?
    private let hasCompleteSensitiveSnapshot: Bool
    private let createIdempotencyKey: IdempotencyKey

    init(
        organizationId: String,
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        supplier: BusinessProcurementSupplierResponse? = nil,
        repository: BusinessProcurementRepository,
        createIdempotencyKey: IdempotencyKey? = nil
    ) {
        self.organizationId = organizationId
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository
        self.supplierId = supplier?.id
        self.expectedVersion = supplier?.version
        self.hasCompleteSensitiveSnapshot = supplier == nil || supplier?.contacts != nil
        self.createIdempotencyKey = createIdempotencyKey ?? .generate(prefix: "supplier-create")

        legalName = supplier?.legalName ?? ""
        tradeName = supplier?.tradeName ?? ""
        identificationKind = BusinessSupplierIdentificationKind(
            rawValue: supplier?.identificationType ?? ""
        ) ?? .none
        identificationNumber = supplier?.identificationNumber ?? ""
        email = supplier?.email ?? ""
        phone = supplier?.phone ?? ""
        address = supplier?.address ?? ""
        categoriesText = supplier?.categories.joined(separator: ", ") ?? ""
        contacts = supplier?.contacts?.map { BusinessSupplierContactDraft(response: $0) } ?? []
        let resolvedPaymentTermsKind = BusinessSupplierPaymentTermsKind(
            rawValue: supplier?.paymentTerms.mode.uppercased() ?? "IMMEDIATE"
        ) ?? .immediate
        paymentTermsKind = resolvedPaymentTermsKind
        if resolvedPaymentTermsKind == .netDays, let netDays = supplier?.paymentTerms.netDays {
            netDaysText = String(netDays)
        } else {
            netDaysText = ""
        }
        paymentTermsLabel = supplier?.paymentTerms.label ?? ""
        paymentTermsNotes = supplier?.paymentTerms.notes ?? ""
        notes = supplier?.notes ?? ""
    }

    var isEditing: Bool {
        supplierId != nil
    }

    var navigationTitle: String {
        isEditing ? "Editar proveedor" : "Nuevo proveedor"
    }

    var saveButtonTitle: String {
        isEditing ? "Guardar cambios" : "Crear proveedor"
    }

    var canSave: Bool {
        !isSaving && accessValidationMessage == nil && inputValidationMessage == nil
    }

    var accessValidationMessage: String? {
        guard accessPolicy.isModuleActive else {
            return "El módulo Compras no está activo para esta organización."
        }
        if isEditing {
            guard accessPolicy.allows(BusinessProcurementPermission.suppliersUpdate) else {
                return "No tienes permiso para editar proveedores."
            }
            guard accessPolicy.allows(BusinessProcurementPermission.suppliersSensitiveView) else {
                return "La edición requiere permiso para consultar los datos sensibles del proveedor."
            }
            guard hasCompleteSensitiveSnapshot else {
                return "Actualiza el detalle antes de editar para no sobrescribir datos protegidos."
            }
            guard let expectedVersion, expectedVersion > 0 else {
                return "No se encontró una versión válida del proveedor."
            }
        } else if !accessPolicy.allows(BusinessProcurementPermission.suppliersCreate) {
            return "No tienes permiso para crear proveedores."
        }
        return nil
    }

    var inputValidationMessage: String? {
        if normalized(legalName).isEmpty {
            return "Ingresa la razón social del proveedor."
        }

        let hasIdentificationNumber = !normalized(identificationNumber).isEmpty
        if identificationKind == .none, hasIdentificationNumber {
            return "Selecciona el tipo de identificación o elimina el número."
        }
        if identificationKind != .none, !hasIdentificationNumber {
            return "Ingresa el número de identificación del proveedor."
        }

        switch paymentTermsKind {
        case .immediate:
            break
        case .netDays:
            guard let days = Int(normalized(netDaysText)), (1...365).contains(days) else {
                return "Ingresa un plazo entre 1 y 365 días."
            }
        case .custom:
            if normalized(paymentTermsLabel).isEmpty {
                return "Describe la condición de pago personalizada."
            }
        }

        if contacts.contains(where: { normalized($0.name).isEmpty }) {
            return "Cada persona de contacto necesita un nombre."
        }
        if contacts.filter(\.isPrimary).count > 1 {
            return "Selecciona como máximo un contacto principal."
        }
        return nil
    }

    func addContact() {
        contacts.append(BusinessSupplierContactDraft(isPrimary: contacts.isEmpty))
    }

    func removeContacts(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            contacts.remove(at: index)
        }
    }

    func setPrimaryContact(_ contactId: UUID, isPrimary: Bool) {
        for index in contacts.indices {
            contacts[index].isPrimary = isPrimary && contacts[index].id == contactId
        }
    }

    func save() async -> BusinessProcurementSupplierResponse? {
        guard !isSaving else { return nil }
        if let accessValidationMessage {
            errorMessage = accessValidationMessage
            return nil
        }
        if let inputValidationMessage {
            errorMessage = inputValidationMessage
            return nil
        }

        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        let request = makeRequest()
        do {
            let response: BusinessProcurementSupplierEnvelopeResponse
            if let supplierId {
                response = try await repository.updateSupplier(
                    organizationId: organizationId,
                    supplierId: supplierId,
                    request: request
                )
            } else {
                response = try await repository.createSupplier(
                    organizationId: organizationId,
                    idempotencyKey: createIdempotencyKey,
                    request: request
                )
            }

            savedSupplier = response.data
            if response.meta.idempotencyReplayed == true {
                infoMessage = "Proveedor recuperado de un intento anterior."
            } else {
                infoMessage = isEditing
                    ? "Proveedor actualizado correctamente."
                    : "Proveedor creado correctamente."
            }
            return response.data
        } catch let error as APIError {
            errorMessage = supplierErrorMessage(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func makeRequest() -> BusinessProcurementSupplierWriteRequest {
        let terms: BusinessProcurementPaymentTermsRequest
        switch paymentTermsKind {
        case .immediate:
            terms = BusinessProcurementPaymentTermsRequest(
                mode: paymentTermsKind.rawValue,
                netDays: 0,
                label: nil,
                notes: optional(paymentTermsNotes)
            )
        case .netDays:
            terms = BusinessProcurementPaymentTermsRequest(
                mode: paymentTermsKind.rawValue,
                netDays: Int(normalized(netDaysText)),
                label: optional(paymentTermsLabel),
                notes: optional(paymentTermsNotes)
            )
        case .custom:
            terms = BusinessProcurementPaymentTermsRequest(
                mode: paymentTermsKind.rawValue,
                netDays: nil,
                label: optional(paymentTermsLabel),
                notes: optional(paymentTermsNotes)
            )
        }

        return BusinessProcurementSupplierWriteRequest(
            legalName: normalized(legalName),
            tradeName: optional(tradeName),
            identificationType: identificationKind == .none ? nil : identificationKind.rawValue,
            identificationNumber: identificationKind == .none ? nil : optional(identificationNumber),
            email: optional(email),
            phone: optional(phone),
            address: optional(address),
            categories: normalizedCategories,
            contacts: contacts.map { contact in
                BusinessProcurementSupplierContactRequest(
                    id: contact.serverId,
                    name: normalized(contact.name),
                    role: optional(contact.role),
                    email: optional(contact.email),
                    phone: optional(contact.phone),
                    isPrimary: contact.isPrimary,
                    notes: optional(contact.notes)
                )
            },
            paymentTerms: terms,
            defaultCurrency: "USD",
            notes: optional(notes),
            expectedVersion: expectedVersion
        )
    }

    private var normalizedCategories: [String] {
        let values = categoriesText
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { normalized(String($0)).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set(values)).sorted()
    }

    private func supplierErrorMessage(_ error: APIError) -> String {
        let code = error.code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "procurement_version_conflict", "procurement_version_precondition_required":
            return "El proveedor cambió en el servidor. Cierra este formulario, actualiza el detalle e inténtalo nuevamente."
        case "procurement_duplicate_supplier_identification":
            return "Ya existe un proveedor con esa identificación."
        default:
            return error.userMessage
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optional(_ value: String) -> String? {
        let value = normalized(value)
        return value.isEmpty ? nil : value
    }
}
