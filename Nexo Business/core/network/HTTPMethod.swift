//
//  HTTPMethod.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
