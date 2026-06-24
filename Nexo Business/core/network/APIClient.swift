//
//  APIClient.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

protocol APIClient: Sendable {
    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response
}

struct EmptyResponse: Decodable, Sendable {
    init() {}
}

final class URLSessionAPIClient: APIDataClient, @unchecked Sendable {
    private let environment: AppEnvironment
    private let session: URLSession
    private let tokenStore: AuthTokenStoring
    private let deviceMetadataProvider: DeviceMetadataProviding
    private let decoder: JSONDecoder

    init(
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

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        let urlRequest = try await makeURLRequest(from: request, acceptHeader: "application/json")

        #if DEBUG
        debugPrintRequest(urlRequest, includeBody: true)
        #endif

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

        #if DEBUG
        debugPrintJSONResponse(data: data, http: http, urlRequest: urlRequest)
        #endif

        try validate(http: http, data: data)

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        guard !data.isEmpty else {
            throw APIError.emptyResponse
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            #if DEBUG
            print("❌ DECODING ERROR")
            print(error)
            if let responseString = String(data: data, encoding: .utf8) {
                print("RAW BODY:")
                print(responseString)
            }
            print("EXPECTED RESPONSE TYPE:", Response.self)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif

            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    func sendData(_ request: APIRequest<EmptyResponse>) async throws -> APIDataResponse {
        let urlRequest = try await makeURLRequest(from: request, acceptHeader: "*/*")

        #if DEBUG
        debugPrintRequest(urlRequest, includeBody: false)
        #endif

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

        #if DEBUG
        debugPrintBinaryResponse(data: data, http: http, urlRequest: urlRequest)
        #endif

        try validate(http: http, data: data)

        return APIDataResponse(
            data: data,
            statusCode: http.statusCode,
            headers: http.allHeaderFields.reduce(into: [String: String]()) { result, entry in
                guard let key = entry.key as? String else { return }
                result[key] = String(describing: entry.value)
            }
        )
    }

    private func makeURLRequest<Response: Decodable>(
        from request: APIRequest<Response>,
        acceptHeader: String
    ) async throws -> URLRequest {
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
        urlRequest.setValue(acceptHeader, forHTTPHeaderField: "Accept")

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

        return urlRequest
    }

    private func validate(http: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            let tolerantEnvelope = try? decoder.decode(APITolerantErrorEnvelope.self, from: data)
            let flatEnvelope = try? decoder.decode(APIFlatErrorEnvelope.self, from: data)
            throw APIError.server(
                statusCode: http.statusCode,
                code: envelope?.error.code ?? tolerantEnvelope?.error.code ?? flatEnvelope?.error,
                message: envelope?.error.message ?? tolerantEnvelope?.error.message ?? flatEnvelope?.message ?? "Solicitud rechazada.",
                requestId: envelope?.error.requestId ?? tolerantEnvelope?.error.requestId ?? flatEnvelope?.requestId
            )
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

    #if DEBUG
    private func debugPrintRequest(_ request: URLRequest, includeBody: Bool) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("➡️ API REQUEST")
        print("METHOD:", request.httpMethod ?? "")
        print("URL:", request.url?.absoluteString ?? "")
        print("HEADERS:")
        request.allHTTPHeaderFields?.forEach { key, value in
            if key.lowercased() == "authorization" {
                print("  \(key): Bearer <redacted>")
            } else {
                print("  \(key): \(value)")
            }
        }

        if includeBody,
           let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("BODY:")
            print(bodyString)
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private func debugPrintJSONResponse(data: Data, http: HTTPURLResponse, urlRequest: URLRequest) {
        print("⬅️ API RESPONSE")
        print("STATUS:", http.statusCode)
        print("URL:", urlRequest.url?.absoluteString ?? "")

        if let responseString = String(data: data, encoding: .utf8) {
            print("BODY:")
            print(responseString)
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private func debugPrintBinaryResponse(data: Data, http: HTTPURLResponse, urlRequest: URLRequest) {
        print("⬅️ API DATA RESPONSE")
        print("STATUS:", http.statusCode)
        print("URL:", urlRequest.url?.absoluteString ?? "")
        print("BYTES:", data.count)
        if let contentType = http.value(forHTTPHeaderField: "Content-Type") {
            print("CONTENT-TYPE:", contentType)
        }
        if let disposition = http.value(forHTTPHeaderField: "Content-Disposition") {
            print("CONTENT-DISPOSITION:", disposition)
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    #endif
}
