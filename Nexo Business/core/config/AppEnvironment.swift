//
//  AppEnvironment.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct AppEnvironment: Equatable, Sendable {
    public let name: String
    public let baseURL: URL

    public init(name: String, baseURL: URL) {
        self.name = name
        self.baseURL = baseURL
    }

    public static let staging = AppEnvironment(
        name: "staging",
        baseURL: URL(string: "https://api-staging.premierdarkcoffee.com")!
    )

    public static let local = AppEnvironment(
        name: "local",
        baseURL: URL(string: "http://localhost:8080")!
    )
}
