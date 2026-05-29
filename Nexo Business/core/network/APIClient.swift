//
//  APIClient.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol APIClient: Sendable {
    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response
}

public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

public final class URLSessionAPIClient: APIClient, @unchecked Sendable {
    private let environment: AppEnvironment
    private let session: URLSession
    private let tokenStore: AuthTokenStoring
    private let deviceMetadataProvider: DeviceMetadataProviding
    private let decoder: JSONDecoder

    public init(
        environment: AppEnvironment,
        session: URLSession = .shared,
        tokenStore: AuthTokenStoring,
        deviceMetadataProvider: DeviceMetadataProviding,
        decoder: JSONDecoder = .nexoDefault
    ) {
        self.environment = environment
        self.session = session
        self.tokenStore = tokenStore
        self.deviceMetadataProvider = deviceMetadataProvider
        self.decoder = decoder
    }

    public func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        var components = URLComponents(
            url: environment.baseURL,
            resolvingAgainstBaseURL: false
        )

        components?.path = request.path.hasPrefix("/")
            ? request.path
            : "/\(request.path)"
        components?.queryItems = request.queryItems.isEmpty ? nil : request.queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        applyDeviceHeaders(to: &urlRequest)
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if request.requiresAuth {
            guard let token = await tokenStore.accessToken(), !token.isEmpty else {
                throw APIError.missingAccessToken
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Respuesta HTTP inválida.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIError.server(
                statusCode: http.statusCode,
                code: envelope?.error.code,
                message: envelope?.error.message ?? "Solicitud rechazada.",
                requestId: envelope?.error.requestId
            )
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        guard !data.isEmpty else {
            throw APIError.emptyResponse
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    private func applyDeviceHeaders(to request: inout URLRequest) {
        let metadata = deviceMetadataProvider.deviceMetadata()

        [
            BusinessHeaders.requestId: metadata.requestId,
            BusinessHeaders.correlationId: metadata.correlationId,
            BusinessHeaders.deviceId: metadata.deviceId,
            BusinessHeaders.appName: metadata.appName,
            BusinessHeaders.appVersion: metadata.appVersion,
            BusinessHeaders.appBuild: metadata.appBuild,
            BusinessHeaders.platform: metadata.platform
        ].forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}
