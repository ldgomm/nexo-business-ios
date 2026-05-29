//
//  APIError.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case missingAccessToken
    case emptyResponse
    case encodingFailed(String)
    case decodingFailed(String)
    case transport(String)
    case server(statusCode: Int, code: String?, message: String, requestId: String?)

    public var statusCode: Int? {
        switch self {
        case let .server(statusCode, _, _, _):
            return statusCode
        default:
            return nil
        }
    }

    public var isUnauthorized: Bool {
        statusCode == 401
    }

    public var userMessage: String {
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
            return "No se pudo leer la respuesta."
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
}

public enum APIErrorHumanizer {
    public static func message(
        statusCode: Int,
        code: String?,
        fallback: String
    ) -> String {
        switch statusCode {
        case 401:
            return "Tu sesión caducó. Vuelve a iniciar sesión."
        case 403:
            return "No tienes permiso para realizar esta acción."
        case 409:
            return "La información del negocio cambió. Actualiza el contexto e inténtalo otra vez."
        case 422:
            return fallback.isEmpty ? "Hay datos inválidos en la solicitud." : fallback
        case 428:
            return "Falta una revisión requerida de catálogo o configuración tributaria. Actualiza el contexto."
        default:
            return fallback.isEmpty ? "Solicitud rechazada." : fallback
        }
    }
}

public struct APIErrorEnvelope: Decodable, Sendable {
    public let error: APIErrorBody
}

public struct APIErrorBody: Decodable, Sendable {
    public let code: String?
    public let message: String
    public let requestId: String?
    public let details: [String: String]?
}
