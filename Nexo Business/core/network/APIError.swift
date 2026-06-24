//
//  APIError.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case missingAccessToken
    case emptyResponse
    case encodingFailed(String)
    case decodingFailed(String)
    case transport(String)
    case server(statusCode: Int, code: String?, message: String, requestId: String?)

    var statusCode: Int? {
        switch self {
        case let .server(statusCode, _, _, _):
            return statusCode
        default:
            return nil
        }
    }

    var code: String? {
        switch self {
        case let .server(_, code, _, _):
            return code
        default:
            return nil
        }
    }

    var requestId: String? {
        switch self {
        case let .server(_, _, _, requestId):
            return requestId
        default:
            return nil
        }
    }

    var isUnauthorized: Bool {
        statusCode == 401
    }

    var isRevisionConflict: Bool {
        statusCode == 409 || statusCode == 428
    }

    var isBusinessRevisionConflict: Bool {
        guard isRevisionConflict else { return false }
        let normalizedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedCode == "business_revision_conflict" { return true }
        if normalizedCode == "catalog_revision_conflict" { return true }
        if normalizedCode == "tax_configuration_revision_conflict" { return true }
        return normalizedCode == nil
    }

    var isMaxSessionsReached: Bool {
        code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "max_sessions_reached"
    }

    var isLockedByTooManyAttempts: Bool {
        code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "account_locked_too_many_attempts"
    }

    var serverMessage: String? {
        switch self {
        case let .server(_, _, message, _):
            return message
        default:
            return nil
        }
    }

    var isRetriable: Bool {
        switch self {
        case .transport:
            return true
        case let .server(statusCode, _, _, _):
            return [408, 429, 500, 502, 503, 504].contains(statusCode)
        default:
            return false
        }
    }

    var userMessage: String {
        switch self {
        case .invalidURL:
            return "URL inválida."
        case .missingAccessToken:
            return "Sesión no activa."
        case .emptyResponse:
            return "Respuesta vacía."
        case .encodingFailed:
            return "No se pudo preparar la solicitud."
        case .decodingFailed:
            return "No se pudo leer la respuesta. Actualiza la app o contacta soporte."
        case .transport:
            return "No se pudo conectar. Revisa internet e inténtalo nuevamente."
        case let .server(statusCode, code, message, _):
            return APIErrorHumanizer.message(
                statusCode: statusCode,
                code: code,
                fallback: message
            )
        }
    }

    var supportMessage: String {
        if let requestId, !requestId.isEmpty {
            return "Código de soporte: \(requestId)"
        }
        return ""
    }
}

enum APIErrorHumanizer {
    static func message(
        statusCode: Int,
        code: String?,
        fallback: String
    ) -> String {
        let normalizedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedCode == "max_sessions_reached" {
            return "Ya alcanzaste el máximo de dispositivos activos. Puedes cerrar las sesiones anteriores e ingresar nuevamente."
        }

        if normalizedCode == "account_locked_too_many_attempts" {
            return "Usuario bloqueado temporalmente por demasiados intentos. Contacte al administrador de la empresa."
        }

        if let businessMessage = humanizedBusinessMessage(fallback) {
            return businessMessage
        }

        let safeFallback = safeVisibleFallback(fallback)

        switch statusCode {
        case 400:
            return safeFallback ?? "La solicitud no es válida."
        case 401:
            return "Tu sesión caducó. Vuelve a iniciar sesión."
        case 403:
            return "No tienes permiso para realizar esta acción."
        case 404:
            return safeFallback ?? "No encontramos la información solicitada."
        case 408:
            return "La solicitud tardó demasiado. Inténtalo nuevamente."
        case 409:
            return "La información del negocio cambió. Actualiza el contexto e inténtalo otra vez."
        case 422:
            return safeFallback ?? "Hay datos que deben corregirse antes de continuar."
        case 428:
            return "Falta una revisión requerida de catálogo o configuración tributaria. Actualiza el contexto."
        case 429:
            return "Hay demasiadas solicitudes en este momento. Espera unos segundos e inténtalo otra vez."
        case 500, 502, 503, 504:
            return "El servidor no respondió correctamente. Inténtalo nuevamente en unos segundos."
        default:
            return safeFallback ?? "Solicitud rechazada."
        }
    }

    static func humanizedBusinessMessage(_ rawMessage: String?) -> String? {
        guard let rawMessage else { return nil }
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let invoiceTaxMessage = electronicInvoiceTaxBlockerMessage(from: trimmed) {
            return invoiceTaxMessage
        }

        let normalized = normalize(trimmed)

        if normalized.contains("error en la identificacion del receptor") ||
            (normalized.contains("identificacion") && normalized.contains("receptor")) ||
            (normalized.contains("identification") && normalized.contains("receiver")) ||
            (normalized.contains("comprador") && normalized.contains("identificacion")) {
            return "La identificación del cliente no fue aceptada. Revisa cédula, RUC o pasaporte, o usa Consumidor final cuando corresponda."
        }

        if (normalized.contains("accounts receivable") && normalized.contains("identified customer")) ||
            (normalized.contains("cuenta") && normalized.contains("cobrar") && normalized.contains("cliente")) ||
            (normalized.contains("credito") && normalized.contains("cliente")) ||
            (normalized.contains("credit") && normalized.contains("customer")) {
            return "Para dejar una venta por cobrar necesitas seleccionar un cliente identificado. Consumidor final no puede quedar fiado."
        }

        if normalized.contains("firma") ||
            normalized.contains("signature") ||
            normalized.contains("certificate") ||
            normalized.contains("certificado") ||
            normalized.contains("pkcs12") ||
            normalized.contains("p12") ||
            normalized.contains("pfx") {
            return "Falta configurar o validar la firma electrónica del negocio. Revisa la firma antes de emitir factura electrónica."
        }

        if normalized.contains("sequence") ||
            normalized.contains("secuencia") ||
            normalized.contains("secuencial") ||
            normalized.contains("emission point") ||
            normalized.contains("punto de emision") {
            return "Hay un problema con la secuencia del punto de emisión. Revisa la configuración fiscal antes de emitir."
        }

        if normalized.contains("ride") && (normalized.contains("missing") || normalized.contains("not found") || normalized.contains("no disponible") || normalized.contains("no encontrado")) {
            return "La factura existe, pero el RIDE no está disponible todavía. Intenta actualizar o revisa el detalle del comprobante."
        }

        if (normalized.contains("authorized xml") || normalized.contains("xml autorizado")) &&
            (normalized.contains("missing") || normalized.contains("not found") || normalized.contains("no disponible") || normalized.contains("no encontrado")) {
            return "La factura existe, pero el XML autorizado no está disponible todavía. Actualiza el comprobante o revisa su detalle."
        }

        if normalized.contains("clave de acceso") && normalized.contains("49") {
            return "La clave de acceso del comprobante no es válida. Revisa la configuración fiscal y vuelve a intentar."
        }

        if normalized.contains("ambiente") && (normalized.contains("pruebas") || normalized.contains("produccion") || normalized.contains("production") || normalized.contains("test")) {
            return "El ambiente de emisión no coincide con la configuración actual. Revisa si el negocio está en pruebas o producción."
        }

        if normalized.contains("collection amount cannot exceed receivable balance") ||
            (normalized.contains("receivable") && normalized.contains("balance") && normalized.contains("exceed")) {
            return "El monto no puede ser mayor al saldo pendiente."
        }

        return nil
    }

    static func electronicInvoiceTaxBlockerMessage(from rawMessage: String?) -> String? {
        guard let rawMessage else { return nil }
        let normalized = normalize(rawMessage)

        let hasNoSriTaxCode = normalized.contains("no_sri_tax_code") || normalized.contains("no sri tax code")
        let hasTaxProfile = normalized.contains("tax profile") || normalized.contains("perfil tributario") || normalized.contains("configuracion tributaria")
        let hasElectronicInvoicing = normalized.contains("electronic invoicing") || normalized.contains("facturacion electronica") || normalized.contains("factura electronica")
        let hasSoloRegistro = normalized.contains("solo registro") || normalized.contains("no_tax_internal") || normalized.contains("internal_no_tax") || normalized.contains("operational_no_tax") || normalized.contains("altos_staging_no_tax_internal")

        if hasNoSriTaxCode || hasSoloRegistro || (hasTaxProfile && hasElectronicInvoicing) || normalized.contains("not valid for electronic invoicing") {
            return "Esta venta contiene productos configurados como “Solo registro” o sin código tributario válido para factura electrónica. Puedes cobrarla como venta interna, pero no emitir factura electrónica."
        }

        return nil
    }

    private static func safeVisibleFallback(_ fallback: String?) -> String? {
        guard let fallback else { return nil }
        let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if looksTechnical(trimmed) {
            return nil
        }

        return trimmed
    }

    private static func looksTechnical(_ message: String) -> Bool {
        let normalized = normalize(message)
        let fragments = [
            "domain_rule_violation",
            "sritaxcode",
            "sri_tax_code",
            "taxprofile",
            "tax profile",
            "sitem_",
            "sale item",
            "objectkey",
            "storagekey",
            "bucket",
            "electronic-invoicing/",
            "ride_pdf/",
            "signed_xml",
            "authorized_xml",
            "generated_xml",
            "sri_request",
            "sri_response",
            "/tmp/",
            "/var/",
            ".p12",
            ".pfx",
            "privatekey",
            "stacktrace",
            "exception",
            "traceback"
        ]

        return fragments.contains { normalized.contains($0) }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}

struct APIErrorEnvelope: Decodable, Sendable {
    let error: APIErrorBody
}

struct APIErrorBody: Decodable, Sendable {
    let code: String?
    let message: String
    let requestId: String?
    let details: [String: String]?
}


struct APIFlatErrorEnvelope: Decodable, Sendable {
    let error: String?
    let message: String?
    let requestId: String?
}


struct APITolerantErrorEnvelope: Decodable, Sendable {
    let error: APITolerantErrorBody
}

struct APITolerantErrorBody: Decodable, Sendable {
    let code: String?
    let message: String
    let requestId: String?
}
