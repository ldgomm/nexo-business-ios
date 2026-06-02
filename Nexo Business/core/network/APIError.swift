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
        switch statusCode {
        case 400:
            return fallback.isEmpty ? "La solicitud no es válida." : fallback
        case 401:
            return "Tu sesión caducó. Vuelve a iniciar sesión."
        case 403:
            return "No tienes permiso para realizar esta acción."
        case 404:
            return fallback.isEmpty ? "No encontramos la información solicitada." : fallback
        case 408:
            return "La solicitud tardó demasiado. Inténtalo nuevamente."
        case 409:
            return "La información del negocio cambió. Actualiza el contexto e inténtalo otra vez."
        case 422:
            return fallback.isEmpty ? "Hay datos inválidos en la solicitud." : fallback
        case 428:
            return "Falta una revisión requerida de catálogo o configuración tributaria. Actualiza el contexto."
        case 429:
            return "Hay demasiadas solicitudes en este momento. Espera unos segundos e inténtalo otra vez."
        case 500, 502, 503, 504:
            return "El servidor no respondió correctamente. Inténtalo nuevamente en unos segundos."
        default:
            return fallback.isEmpty ? "Solicitud rechazada." : fallback
        }
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
