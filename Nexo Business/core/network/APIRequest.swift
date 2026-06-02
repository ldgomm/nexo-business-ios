//
//  APIRequest.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct APIRequest<Response: Decodable>: Sendable {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?
    let requiresAuth: Bool

    init(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        requiresAuth: Bool = true
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

extension APIRequest {
    static func json<Body: Encodable>(
        method: HTTPMethod,
        path: String,
        body: Body,
        headers: [String: String] = [:],
        requiresAuth: Bool = true
    ) throws -> APIRequest<Response> {
        do {
            return APIRequest(
                method: method,
                path: path,
                headers: headers.merging(
                    ["Content-Type": "application/json"],
                    uniquingKeysWith: { current, _ in current }
                ),
                body: try JSONEncoder.nexoDefault.encode(body),
                requiresAuth: requiresAuth
            )
        } catch {
            throw APIError.encodingFailed(error.localizedDescription)
        }
    }
}
