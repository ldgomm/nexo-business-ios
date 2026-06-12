//
//  APIDataResponse.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

struct APIDataResponse: Sendable, Equatable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    func headerValue(_ name: String) -> String? {
        let expected = name.lowercased()
        return headers.first { key, _ in key.lowercased() == expected }?.value
    }
}

protocol APIDataClient: APIClient {
    func sendData(_ request: APIRequest<EmptyResponse>) async throws -> APIDataResponse
}
